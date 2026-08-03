import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/realtime/realtime_transcription_client.dart';
import '../../domain/realtime/realtime_transcription_events.dart';

abstract interface class RealtimeWebSocketConnector {
  WebSocketChannel connect(
    Uri uri, {
    required Map<String, dynamic> headers,
    required Duration connectTimeout,
    required Duration pingInterval,
  });
}

final class IoRealtimeWebSocketConnector implements RealtimeWebSocketConnector {
  const IoRealtimeWebSocketConnector();

  @override
  WebSocketChannel connect(
    Uri uri, {
    required Map<String, dynamic> headers,
    required Duration connectTimeout,
    required Duration pingInterval,
  }) => IOWebSocketChannel.connect(
    uri,
    headers: headers,
    connectTimeout: connectTimeout,
    pingInterval: pingInterval,
  );
}

final class OpenAIRealtimeTranscriptionClient
    implements RealtimeTranscriptionClient {
  factory OpenAIRealtimeTranscriptionClient({
    required RealtimeSecretProvider secretProvider,
    RealtimeWebSocketConnector connector = const IoRealtimeWebSocketConnector(),
    Duration connectTimeout = const Duration(seconds: 10),
    Duration pingInterval = const Duration(seconds: 20),
  }) => OpenAIRealtimeTranscriptionClient._(
    secretProvider,
    connector,
    connectTimeout,
    pingInterval,
  );

  OpenAIRealtimeTranscriptionClient._(
    this._secretProvider,
    this._connector,
    this.connectTimeout,
    this.pingInterval,
  );

  static const int maxKeywordCount = 100;
  static const int maxKeywordLength = 128;
  static const int maxPromptLength = 4096;
  static const int _maxRememberedEventIds = 4096;

  final RealtimeSecretProvider _secretProvider;
  final RealtimeWebSocketConnector _connector;
  final Duration connectTimeout;
  final Duration pingInterval;
  final StreamController<RealtimeTranscriptEvent> _events =
      StreamController<RealtimeTranscriptEvent>.broadcast(sync: true);
  final Map<String, String> _drafts = <String, String>{};
  final Set<String> _finalKeys = <String>{};
  final Set<String> _pendingItemIds = <String>{};
  final LinkedHashSet<String> _seenEventIds = LinkedHashSet<String>();
  final Map<String, int> _turnEndSamples = <String, int>{};
  final Map<String, String?> _commitsWaitingForBoundary = <String, String?>{};
  final Queue<int> _manualCommitBoundaries = Queue<int>();

  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  RealtimeTranscriptionConfig? _config;
  RealtimeAudioFrame? _lastFrame;
  String? _audioSessionId;
  bool _hasUncommittedAudio = false;
  bool _intentionalClose = false;
  Completer<void>? _sessionReady;
  RealtimeConnectionState _connectionState =
      RealtimeConnectionState.disconnected;

  @override
  Stream<RealtimeTranscriptEvent> get events => _events.stream;

  @override
  RealtimeConnectionState get connectionState => _connectionState;

  @override
  Future<void> connect(RealtimeTranscriptionConfig config) async {
    if (_connectionState == RealtimeConnectionState.connecting ||
        _connectionState == RealtimeConnectionState.connected ||
        _connectionState == RealtimeConnectionState.closing) {
      throw const RealtimeClientException(
        code: 'operation_in_progress',
        message: '实时转写连接正在使用中。',
        isRetryable: false,
      );
    }

    _validateConfig(config);
    final uri = _connectionUri(config);
    _resetSession(config);
    _transition(RealtimeConnectionState.connecting);

    try {
      final apiKey = await _readSecret(config.secret);
      final headers = <String, dynamic>{'Authorization': 'Bearer $apiKey'};
      final safetyIdentifier = config.safetyIdentifier?.trim();
      if (safetyIdentifier != null && safetyIdentifier.isNotEmpty) {
        headers['OpenAI-Safety-Identifier'] = safetyIdentifier;
      }

      final channel = _connector.connect(
        uri,
        headers: headers,
        connectTimeout: connectTimeout,
        pingInterval: pingInterval,
      );
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleMessage,
        onError: _handleStreamError,
        onDone: _handleStreamDone,
        cancelOnError: false,
      );
      await channel.ready.timeout(connectTimeout);
      final sessionReady = Completer<void>();
      _sessionReady = sessionReady;
      _sendJson(_sessionUpdate(config));
      await sessionReady.future.timeout(
        connectTimeout,
        onTimeout: () => throw const RealtimeClientException(
          code: 'session_update_timeout',
          message: '实时转写服务未确认当前配置。',
          isRetryable: true,
        ),
      );
      _transition(RealtimeConnectionState.connected);
    } on Object catch (error) {
      final safeError = error is RealtimeClientException
          ? error
          : _mapConnectionError(error);
      await _closeTransport();
      _transition(RealtimeConnectionState.failed, reasonCode: safeError.code);
      _emitServiceError(safeError);
      throw safeError;
    }
  }

  @override
  Future<void> append(RealtimeAudioFrame frame) async {
    final config = _config;
    if (config == null ||
        _connectionState != RealtimeConnectionState.connected) {
      _events.add(
        TranscriptGapDetected(
          reason: TranscriptGapReason.transportUnavailable,
          receivedSequence: frame.sequence,
          startSample: frame.startSample,
          endSample: frame.startSample + _safeSampleCount(frame),
        ),
      );
      throw const RealtimeClientException(
        code: 'not_connected',
        message: '实时转写当前未连接。',
        isRetryable: true,
      );
    }

    _validateFrame(frame, config);
    _detectFrameGap(frame);
    try {
      _sendJson(<String, Object?>{
        'type': 'input_audio_buffer.append',
        'audio': base64Encode(frame.bytes),
      });
      _lastFrame = frame;
      _audioSessionId ??= frame.sessionId;
      _hasUncommittedAudio = true;
    } on Object {
      _events.add(
        TranscriptGapDetected(
          reason: TranscriptGapReason.transportUnavailable,
          receivedSequence: frame.sequence,
          startSample: frame.startSample,
          endSample: frame.startSample + frame.sampleCount,
        ),
      );
      const safeError = RealtimeClientException(
        code: 'send_failed',
        message: '实时音频发送失败。',
        isRetryable: true,
      );
      _emitServiceError(safeError);
      throw safeError;
    }
  }

  @override
  Future<void> commitTurn() async {
    _requireConnected();
    final lastFrame = _lastFrame;
    if (lastFrame != null) {
      _manualCommitBoundaries.add(
        lastFrame.startSample + lastFrame.sampleCount,
      );
    }
    _sendJson(const <String, Object?>{'type': 'input_audio_buffer.commit'});
    _hasUncommittedAudio = false;
  }

  @override
  Future<void> flushAndClose() async {
    if (_channel == null) {
      _transition(RealtimeConnectionState.closed);
      return;
    }
    if (_connectionState == RealtimeConnectionState.connected &&
        _hasUncommittedAudio) {
      await commitTurn();
    }
    _markUnfinishedItemsAsGaps();
    _intentionalClose = true;
    _transition(RealtimeConnectionState.closing);
    await _closeTransport();
    _transition(RealtimeConnectionState.closed);
  }

  @override
  Future<void> abort() async {
    _intentionalClose = true;
    await _closeTransport();
    _transition(RealtimeConnectionState.closed);
  }

  Future<String> _readSecret(SecretReference reference) async {
    try {
      final secret = await _secretProvider.read(reference);
      if (secret.trim().isEmpty) {
        throw const RealtimeClientException(
          code: 'missing_api_key',
          message: '实时转写密钥未配置。',
          isRetryable: false,
        );
      }
      return secret;
    } on RealtimeClientException {
      rethrow;
    } on Object {
      throw const RealtimeClientException(
        code: 'secret_unavailable',
        message: '无法从系统安全区读取实时转写密钥。',
        isRetryable: false,
      );
    }
  }

  void _resetSession(RealtimeTranscriptionConfig config) {
    _config = config;
    _lastFrame = null;
    _audioSessionId = null;
    _hasUncommittedAudio = false;
    _intentionalClose = false;
    _drafts.clear();
    _finalKeys.clear();
    _pendingItemIds.clear();
    _seenEventIds.clear();
    _turnEndSamples.clear();
    _commitsWaitingForBoundary.clear();
    _manualCommitBoundaries.clear();
    _sessionReady = null;
  }

  void _handleMessage(Object? raw) {
    try {
      final text = switch (raw) {
        String value => value,
        List<int> value => utf8.decode(value),
        _ => throw const FormatException(),
      };
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw const FormatException();
      }
      final event = Map<String, Object?>.from(decoded);
      final eventId = event['event_id'];
      if (eventId is String && !_rememberEvent(eventId)) {
        return;
      }
      switch (event['type']) {
        case 'session.updated':
          final ready = _sessionReady;
          if (ready != null && !ready.isCompleted) ready.complete();
        case 'conversation.item.input_audio_transcription.delta':
          _handleDelta(event);
        case 'conversation.item.input_audio_transcription.completed':
          _handleCompleted(event);
        case 'input_audio_buffer.committed':
          _handleCommitted(event);
        case 'input_audio_buffer.speech_stopped':
          _handleSpeechStopped(event);
        case 'input_audio_buffer.cleared':
          _hasUncommittedAudio = false;
        case 'error':
          _handleProviderError(event);
        default:
          break;
      }
    } on FormatException {
      _emitServiceError(
        const RealtimeClientException(
          code: 'invalid_server_event',
          message: '实时转写服务返回了无法识别的事件。',
          isRetryable: true,
        ),
      );
    } on Object {
      _emitServiceError(
        const RealtimeClientException(
          code: 'invalid_server_event',
          message: '实时转写服务返回了无法识别的事件。',
          isRetryable: true,
        ),
      );
    }
  }

  void _handleDelta(Map<String, Object?> event) {
    final itemId = event['item_id'];
    final contentIndex = event['content_index'];
    final delta = event['delta'];
    if (itemId is! String ||
        itemId.isEmpty ||
        contentIndex is! int ||
        delta is! String) {
      throw const FormatException();
    }
    final key = _itemKey(itemId, contentIndex);
    if (_finalKeys.contains(key)) {
      return;
    }
    final draft = '${_drafts[key] ?? ''}$delta';
    _drafts[key] = draft;
    _pendingItemIds.add(itemId);
    _events.add(
      TranscriptDelta(
        itemId: itemId,
        contentIndex: contentIndex,
        delta: delta,
        draftTranscript: draft,
      ),
    );
  }

  void _handleCompleted(Map<String, Object?> event) {
    final itemId = event['item_id'];
    final contentIndex = event['content_index'];
    final transcript = event['transcript'];
    if (itemId is! String ||
        itemId.isEmpty ||
        contentIndex is! int ||
        transcript is! String) {
      throw const FormatException();
    }
    final key = _itemKey(itemId, contentIndex);
    if (!_finalKeys.add(key)) {
      return;
    }
    _drafts.remove(key);
    _pendingItemIds.remove(itemId);
    _events.add(
      TranscriptCompleted(
        itemId: itemId,
        contentIndex: contentIndex,
        transcript: transcript,
        languages: _readLanguages(event['languages']),
      ),
    );
  }

  void _handleCommitted(Map<String, Object?> event) {
    final itemId = event['item_id'];
    if (itemId is! String || itemId.isEmpty) {
      throw const FormatException();
    }
    _pendingItemIds.add(itemId);
    _hasUncommittedAudio = false;
    final previousItemId = event['previous_item_id'] as String?;
    final endSample =
        _turnEndSamples.remove(itemId) ??
        (_manualCommitBoundaries.isEmpty
            ? null
            : _manualCommitBoundaries.removeFirst());
    if (endSample == null) {
      _commitsWaitingForBoundary[itemId] = previousItemId;
      return;
    }
    _emitTurnCommitted(itemId, previousItemId, endSample);
  }

  void _handleSpeechStopped(Map<String, Object?> event) {
    final itemId = event['item_id'];
    final audioEndMs = event['audio_end_ms'];
    if (itemId is! String || itemId.isEmpty || audioEndMs is! num) {
      throw const FormatException();
    }
    final sampleRate = _config?.sampleRate ?? 24000;
    final endSample = (audioEndMs * sampleRate / 1000).round();
    final waiting = _commitsWaitingForBoundary.containsKey(itemId);
    if (waiting) {
      final previousItemId = _commitsWaitingForBoundary.remove(itemId);
      _emitTurnCommitted(itemId, previousItemId, endSample);
    } else {
      _turnEndSamples[itemId] = endSample;
    }
  }

  void _emitTurnCommitted(
    String itemId,
    String? previousItemId,
    int endSample,
  ) {
    _events.add(
      TranscriptTurnCommitted(
        itemId: itemId,
        previousItemId: previousItemId,
        endSample: endSample,
      ),
    );
  }

  void _handleProviderError(Map<String, Object?> event) {
    final error = event['error'];
    final payload = error is Map
        ? Map<String, Object?>.from(error)
        : const <String, Object?>{};
    final providerCode = '${payload['code'] ?? payload['type'] ?? ''}'
        .toLowerCase();
    final statusCode = payload['status'] ?? payload['status_code'];
    final safeError = switch ((providerCode, statusCode)) {
      (final code, 401 || 403) when code.isNotEmpty =>
        const RealtimeClientException(
          code: 'authentication_failed',
          message: '实时转写鉴权失败，请检查密钥。',
          isRetryable: false,
        ),
      (final code, _) when code.contains('auth') || code.contains('api_key') =>
        const RealtimeClientException(
          code: 'authentication_failed',
          message: '实时转写鉴权失败，请检查密钥。',
          isRetryable: false,
        ),
      (_, 429) => const RealtimeClientException(
        code: 'rate_limited',
        message: '实时转写请求过于频繁或额度不足。',
        isRetryable: true,
      ),
      (final code, _) when code.contains('rate_limit') =>
        const RealtimeClientException(
          code: 'rate_limited',
          message: '实时转写请求过于频繁或额度不足。',
          isRetryable: true,
        ),
      _ => const RealtimeClientException(
        code: 'service_error',
        message: '实时转写服务返回错误。',
        isRetryable: true,
      ),
    };
    _emitServiceError(safeError);
    final ready = _sessionReady;
    if (ready != null && !ready.isCompleted) ready.completeError(safeError);
    if (safeError.code == 'authentication_failed') {
      _transition(RealtimeConnectionState.failed, reasonCode: safeError.code);
    }
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    final safeError = _mapConnectionError(error);
    final ready = _sessionReady;
    if (ready != null && !ready.isCompleted) ready.completeError(safeError);
    _markUnfinishedItemsAsGaps();
    _emitServiceError(safeError);
    _transition(RealtimeConnectionState.failed, reasonCode: safeError.code);
  }

  void _handleStreamDone() {
    _channel = null;
    _subscription = null;
    if (_intentionalClose) {
      return;
    }
    final ready = _sessionReady;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(
        const RealtimeClientException(
          code: 'connection_closed',
          message: '实时转写连接已关闭。',
          isRetryable: true,
        ),
      );
    }
    _markUnfinishedItemsAsGaps();
    if (_connectionState != RealtimeConnectionState.failed) {
      _transition(
        RealtimeConnectionState.disconnected,
        reasonCode: 'connection_closed',
      );
    }
  }

  void _detectFrameGap(RealtimeAudioFrame frame) {
    final previous = _lastFrame;
    // A reconnected session intentionally starts at the next live frame rather
    // than replaying old PCM. The application controller owns cross-session
    // gap detection; this adapter only validates continuity after its baseline.
    if (previous == null) return;
    final expectedSequence = previous.sequence + 1;
    final expectedStartSample = previous.startSample + previous.sampleCount;
    if (frame.sequence < expectedSequence ||
        frame.startSample < expectedStartSample) {
      throw const RealtimeClientException(
        code: 'out_of_order_audio_frame',
        message: '实时音频帧顺序无效。',
        isRetryable: false,
      );
    }
    if (frame.sequence > expectedSequence) {
      _events.add(
        TranscriptGapDetected(
          reason: TranscriptGapReason.sequenceDiscontinuity,
          expectedSequence: expectedSequence,
          receivedSequence: frame.sequence,
          startSample: expectedStartSample,
          endSample: frame.startSample,
        ),
      );
    } else if (frame.startSample > expectedStartSample) {
      _events.add(
        TranscriptGapDetected(
          reason: TranscriptGapReason.sampleDiscontinuity,
          expectedSequence: expectedSequence,
          receivedSequence: frame.sequence,
          startSample: expectedStartSample,
          endSample: frame.startSample,
        ),
      );
    }
  }

  void _markUnfinishedItemsAsGaps() {
    final itemIds = <String>{
      ..._pendingItemIds,
      ..._drafts.keys.map((key) => key.split('\u0000').first),
    };
    for (final itemId in itemIds) {
      _events.add(
        TranscriptGapDetected(
          reason: TranscriptGapReason.unfinishedItem,
          itemId: itemId,
        ),
      );
    }
    _pendingItemIds.clear();
    _drafts.clear();
  }

  void _validateFrame(
    RealtimeAudioFrame frame,
    RealtimeTranscriptionConfig config,
  ) {
    if (frame.sessionId.trim().isEmpty ||
        frame.sequence < 0 ||
        frame.startSample < 0 ||
        frame.sampleRate != config.sampleRate ||
        frame.channels != 1 ||
        frame.bytes.isEmpty ||
        frame.bytes.lengthInBytes.isOdd ||
        (_audioSessionId != null && _audioSessionId != frame.sessionId)) {
      throw const RealtimeClientException(
        code: 'invalid_audio_frame',
        message: '实时音频帧格式无效。',
        isRetryable: false,
      );
    }
  }

  void _validateConfig(RealtimeTranscriptionConfig config) {
    if (config.protocol != RealtimeProtocol.openAiRealtime) {
      throw const RealtimeClientException(
        code: 'protocol_disabled',
        message: '实时转写协议未启用。',
        isRetryable: false,
      );
    }
    final uri = config.websocketUrl;
    if (!uri.hasScheme || uri.host.isEmpty || uri.hasFragment) {
      throw const RealtimeClientException(
        code: 'invalid_websocket_url',
        message: '实时转写 WebSocket 地址无效。',
        isRetryable: false,
      );
    }
    if (uri.userInfo.isNotEmpty) {
      throw const RealtimeClientException(
        code: 'credentials_in_url',
        message: 'WebSocket 地址不能包含凭据。',
        isRetryable: false,
      );
    }
    if (uri.scheme != 'wss' &&
        !(uri.scheme == 'ws' && _isLoopbackHost(uri.host))) {
      throw const RealtimeClientException(
        code: 'insecure_websocket',
        message: '生产实时转写必须使用安全的 wss:// 连接。',
        isRetryable: false,
      );
    }
    for (final name in uri.queryParameters.keys) {
      if (_isSensitiveQueryName(name)) {
        throw const RealtimeClientException(
          code: 'credentials_in_url',
          message: 'WebSocket 地址不能通过查询参数携带凭据。',
          isRetryable: false,
        );
      }
    }
    final model = config.model.trim();
    if (model.isEmpty || model.length > 200 || _containsNewline(model)) {
      throw const RealtimeClientException(
        code: 'invalid_model',
        message: '实时转写模型配置无效。',
        isRetryable: false,
      );
    }
    if (config.secret.id.trim().isEmpty || config.sampleRate <= 0) {
      throw const RealtimeClientException(
        code: 'invalid_configuration',
        message: '实时转写配置不完整。',
        isRetryable: false,
      );
    }
    final prompt = config.contextPrompt;
    if (prompt != null && prompt.length > maxPromptLength) {
      throw const RealtimeClientException(
        code: 'invalid_prompt',
        message: '实时转写上下文过长。',
        isRetryable: false,
      );
    }
    if (config.keywords.length > maxKeywordCount ||
        config.keywords.any(
          (keyword) =>
              keyword.trim().isEmpty ||
              keyword.length > maxKeywordLength ||
              keyword.contains('<') ||
              keyword.contains('>') ||
              _containsNewline(keyword),
        )) {
      throw const RealtimeClientException(
        code: 'invalid_keywords',
        message: '实时转写关键词格式无效。',
        isRetryable: false,
      );
    }
    final languagePattern = RegExp(r'^[A-Za-z]{2,3}(?:-[A-Za-z]{2})?$');
    if (config.languages.length > 8 ||
        config.languages.any(
          (language) => !languagePattern.hasMatch(language),
        )) {
      throw const RealtimeClientException(
        code: 'invalid_languages',
        message: '实时转写语言代码无效。',
        isRetryable: false,
      );
    }
    final safetyIdentifier = config.safetyIdentifier;
    if (safetyIdentifier != null &&
        (safetyIdentifier.length > 200 || _containsNewline(safetyIdentifier))) {
      throw const RealtimeClientException(
        code: 'invalid_safety_identifier',
        message: '实时转写安全标识无效。',
        isRetryable: false,
      );
    }
  }

  Uri _connectionUri(RealtimeTranscriptionConfig config) {
    final query = <String, String>{...config.websocketUrl.queryParameters};
    query['model'] = config.model.trim();
    return config.websocketUrl.replace(queryParameters: query);
  }

  Map<String, Object?> _sessionUpdate(RealtimeTranscriptionConfig config) {
    final transcription = <String, Object?>{'model': config.model.trim()};
    final prompt = config.contextPrompt?.trim();
    if (prompt != null && prompt.isNotEmpty) {
      transcription['prompt'] = prompt;
    }
    if (config.keywords.isNotEmpty) {
      transcription['keywords'] = config.keywords
          .map((keyword) => keyword.trim())
          .toList(growable: false);
    }
    if (config.languages.isNotEmpty) {
      transcription['languages'] = config.languages
          .map((language) => language.toLowerCase())
          .toList(growable: false);
    }
    return <String, Object?>{
      'type': 'session.update',
      'session': <String, Object?>{
        'type': 'transcription',
        'audio': <String, Object?>{
          'input': <String, Object?>{
            'format': <String, Object?>{
              'type': 'audio/pcm',
              'rate': config.sampleRate,
            },
            'transcription': transcription,
            'turn_detection':
                config.turnDetection == RealtimeTurnDetection.serverVad
                ? const <String, Object?>{'type': 'server_vad'}
                : null,
          },
        },
      },
    };
  }

  void _requireConnected() {
    if (_connectionState != RealtimeConnectionState.connected ||
        _channel == null) {
      throw const RealtimeClientException(
        code: 'not_connected',
        message: '实时转写当前未连接。',
        isRetryable: true,
      );
    }
  }

  void _sendJson(Map<String, Object?> event) {
    final channel = _channel;
    if (channel == null) {
      throw const RealtimeClientException(
        code: 'not_connected',
        message: '实时转写当前未连接。',
        isRetryable: true,
      );
    }
    channel.sink.add(jsonEncode(event));
  }

  Future<void> _closeTransport() async {
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    if (subscription != null) {
      await subscription.cancel();
    }
    if (channel != null) {
      try {
        await channel.sink.close(status.normalClosure);
      } on Object {
        // Closing is best-effort and no raw transport error crosses this boundary.
      }
    }
  }

  void _transition(RealtimeConnectionState state, {String? reasonCode}) {
    if (_connectionState == state && reasonCode == null) {
      return;
    }
    _connectionState = state;
    _events.add(TranscriptConnectionChanged(state, reasonCode: reasonCode));
  }

  void _emitServiceError(RealtimeClientException error) {
    _events.add(
      TranscriptServiceError(
        code: error.code,
        message: error.message,
        isRetryable: error.isRetryable,
      ),
    );
  }

  bool _rememberEvent(String eventId) {
    if (!_seenEventIds.add(eventId)) {
      return false;
    }
    if (_seenEventIds.length > _maxRememberedEventIds) {
      _seenEventIds.remove(_seenEventIds.first);
    }
    return true;
  }

  RealtimeClientException _mapConnectionError(Object error) {
    Object current = error;
    if (current is WebSocketChannelException && current.inner != null) {
      current = current.inner!;
    }
    if (current is TimeoutException) {
      return const RealtimeClientException(
        code: 'connection_timeout',
        message: '连接实时转写服务超时。',
        isRetryable: true,
      );
    }
    if (current is TlsException ||
        current is HandshakeException ||
        current is CertificateException) {
      return const RealtimeClientException(
        code: 'tls_error',
        message: '实时转写安全连接验证失败。',
        isRetryable: false,
      );
    }
    final description = current.toString();
    if (RegExp(r'HTTP status code:\s*(401|403)').hasMatch(description)) {
      return const RealtimeClientException(
        code: 'authentication_failed',
        message: '实时转写鉴权失败，请检查密钥。',
        isRetryable: false,
      );
    }
    if (RegExp(r'HTTP status code:\s*429').hasMatch(description)) {
      return const RealtimeClientException(
        code: 'rate_limited',
        message: '实时转写请求过于频繁或额度不足。',
        isRetryable: true,
      );
    }
    return const RealtimeClientException(
      code: 'network_error',
      message: '实时转写网络连接失败。',
      isRetryable: true,
    );
  }

  static List<String> _readLanguages(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((entry) {
          if (entry is String) {
            return entry;
          }
          if (entry is Map && entry['code'] is String) {
            return entry['code'] as String;
          }
          return '';
        })
        .where((language) => language.isNotEmpty)
        .toList(growable: false);
  }

  static String _itemKey(String itemId, int contentIndex) =>
      '$itemId\u0000$contentIndex';

  static bool _containsNewline(String value) =>
      value.contains('\n') || value.contains('\r');

  static bool _isSensitiveQueryName(String name) {
    final normalized = name.toLowerCase().replaceAll(RegExp(r'[-_]'), '');
    return normalized == 'token' ||
        normalized == 'accesstoken' ||
        normalized == 'apikey' ||
        normalized == 'authorization' ||
        normalized == 'secret';
  }

  static bool _isLoopbackHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }

  static int _safeSampleCount(RealtimeAudioFrame frame) {
    if (frame.channels <= 0) {
      return 0;
    }
    return frame.bytes.lengthInBytes ~/ (frame.channels * 2);
  }
}
