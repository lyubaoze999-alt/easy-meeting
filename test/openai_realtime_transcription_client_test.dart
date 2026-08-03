import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_meeting/domain/realtime/realtime_transcription_client.dart';
import 'package:easy_meeting/domain/realtime/realtime_transcription_events.dart';
import 'package:easy_meeting/infrastructure/network/openai_realtime_transcription_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  group('OpenAIRealtimeTranscriptionClient protocol', () {
    late _MockRealtimeServer server;

    setUp(() async {
      server = await _MockRealtimeServer.start();
    });

    tearDown(() => server.close());

    test(
      'sends configured session, authenticated PCM, and commit events',
      () async {
        const secret = 'sk-private-realtime-key';
        final client = OpenAIRealtimeTranscriptionClient(
          secretProvider: const _StaticSecretProvider(secret),
        );
        final config = _config(
          server.uri.replace(queryParameters: const {'tenant': 'mock'}),
          model: 'configured-live-model',
          prompt: '产品发布会议',
          keywords: const ['Easy Meeting'],
          languages: const ['zh-CN', 'en'],
        );

        await client.connect(config);

        final update = await server.nextEvent('session.update');
        final session = update['session']! as Map<String, Object?>;
        final audio = session['audio']! as Map<String, Object?>;
        final input = audio['input']! as Map<String, Object?>;
        final transcription = input['transcription']! as Map<String, Object?>;
        expect(server.authorization, 'Bearer $secret');
        expect(server.requestedUri.queryParameters['tenant'], 'mock');
        expect(
          server.requestedUri.queryParameters['model'],
          'configured-live-model',
        );
        expect(session['type'], 'transcription');
        expect(input['format'], {'type': 'audio/pcm', 'rate': 24000});
        expect(input['turn_detection'], {'type': 'server_vad'});
        expect(transcription['model'], 'configured-live-model');
        expect(transcription['prompt'], '产品发布会议');
        expect(transcription['keywords'], ['Easy Meeting']);
        expect(transcription['languages'], ['zh-cn', 'en']);

        final pcm = Uint8List.fromList([1, 2, 3, 4]);
        await client.append(_frame(sequence: 0, startSample: 0, bytes: pcm));
        final append = await server.nextEvent('input_audio_buffer.append');
        expect(base64Decode(append['audio']! as String), pcm);

        await client.commitTurn();
        await server.nextEvent('input_audio_buffer.commit');
        await client.flushAndClose();
        expect(client.connectionState, RealtimeConnectionState.closed);
      },
    );

    test('connect waits for session.updated acknowledgement', () async {
      await server.close();
      server = await _MockRealtimeServer.start(autoAcknowledgeSession: false);
      final client = OpenAIRealtimeTranscriptionClient(
        secretProvider: const _StaticSecretProvider('test-key'),
      );
      var connected = false;
      final connecting = client.connect(_config(server.uri)).then((_) {
        connected = true;
      });
      await server.nextEvent('session.update');
      await pumpEventQueue(times: 2);
      expect(connected, isFalse);
      server.send({'type': 'session.updated', 'event_id': 'session-ready'});
      await connecting;
      expect(connected, isTrue);
      await client.abort();
    });

    test(
      'aggregates deltas by item and keeps completed events item-safe',
      () async {
        final client = OpenAIRealtimeTranscriptionClient(
          secretProvider: const _StaticSecretProvider('test-key'),
        );
        final events = <RealtimeTranscriptEvent>[];
        final subscription = client.events.listen(events.add);
        addTearDown(subscription.cancel);
        await client.connect(_config(server.uri));

        server.send({
          'event_id': 'delta-a-1',
          'type': 'conversation.item.input_audio_transcription.delta',
          'item_id': 'item-a',
          'content_index': 0,
          'delta': '你',
        });
        server.send({
          'event_id': 'delta-a-2',
          'type': 'conversation.item.input_audio_transcription.delta',
          'item_id': 'item-a',
          'content_index': 0,
          'delta': '好',
        });
        // A transport retry with the same event_id must not duplicate text.
        server.send({
          'event_id': 'delta-a-2',
          'type': 'conversation.item.input_audio_transcription.delta',
          'item_id': 'item-a',
          'content_index': 0,
          'delta': '好',
        });
        // Completion order across turns is intentionally reversed.
        server.send({
          'event_id': 'completed-b',
          'type': 'conversation.item.input_audio_transcription.completed',
          'item_id': 'item-b',
          'content_index': 0,
          'transcript': '第二段',
        });
        server.send({
          'event_id': 'completed-a',
          'type': 'conversation.item.input_audio_transcription.completed',
          'item_id': 'item-a',
          'content_index': 0,
          'transcript': '你好。',
        });
        // A late delta after completion cannot reopen or corrupt the final item.
        server.send({
          'event_id': 'late-delta-a',
          'type': 'conversation.item.input_audio_transcription.delta',
          'item_id': 'item-a',
          'content_index': 0,
          'delta': '不应出现',
        });

        await _waitUntil(
          () => events.whereType<TranscriptCompleted>().length == 2,
        );
        final deltas = events.whereType<TranscriptDelta>().toList();
        final completed = events.whereType<TranscriptCompleted>().toList();
        expect(deltas.map((event) => event.draftTranscript), ['你', '你好']);
        expect(completed.map((event) => event.itemId), ['item-b', 'item-a']);
        expect(completed.map((event) => event.transcript), ['第二段', '你好。']);
        expect(
          events.whereType<TranscriptDelta>().any(
            (event) => event.delta == '不应出现',
          ),
          isFalse,
        );
        await client.abort();
      },
    );

    test(
      'committed turn keeps the sample boundary captured at commit',
      () async {
        final client = OpenAIRealtimeTranscriptionClient(
          secretProvider: const _StaticSecretProvider('test-key'),
        );
        final events = <RealtimeTranscriptEvent>[];
        final subscription = client.events.listen(events.add);
        addTearDown(subscription.cancel);
        await client.connect(_config(server.uri));

        await client.append(
          _frame(
            sequence: 0,
            startSample: 0,
            bytes: Uint8List.fromList([0, 0, 0, 0]),
          ),
        );
        await client.commitTurn();
        await client.append(
          _frame(
            sequence: 1,
            startSample: 2,
            bytes: Uint8List.fromList([0, 0, 0, 0]),
          ),
        );
        server.send({
          'event_id': 'commit-a',
          'type': 'input_audio_buffer.committed',
          'item_id': 'item-a',
          'previous_item_id': null,
        });

        await _waitUntil(
          () => events.whereType<TranscriptTurnCommitted>().isNotEmpty,
        );
        expect(events.whereType<TranscriptTurnCommitted>().single.endSample, 2);
        await client.abort();
      },
    );

    test('emits audio sequence gaps and unfinished item gaps', () async {
      final client = OpenAIRealtimeTranscriptionClient(
        secretProvider: const _StaticSecretProvider('test-key'),
      );
      final events = <RealtimeTranscriptEvent>[];
      final subscription = client.events.listen(events.add);
      addTearDown(subscription.cancel);
      await client.connect(_config(server.uri));

      await client.append(
        _frame(
          sequence: 0,
          startSample: 0,
          bytes: Uint8List.fromList([0, 0, 0, 0]),
        ),
      );
      await client.append(
        _frame(
          sequence: 2,
          startSample: 6,
          bytes: Uint8List.fromList([0, 0, 0, 0]),
        ),
      );
      server.send({
        'event_id': 'unfinished-delta',
        'type': 'conversation.item.input_audio_transcription.delta',
        'item_id': 'unfinished-item',
        'content_index': 0,
        'delta': '未完成',
      });
      await _waitUntil(() => events.whereType<TranscriptDelta>().isNotEmpty);
      await client.flushAndClose();

      final gaps = events.whereType<TranscriptGapDetected>().toList();
      final sequenceGap = gaps.singleWhere(
        (gap) => gap.reason == TranscriptGapReason.sequenceDiscontinuity,
      );
      expect(sequenceGap.expectedSequence, 1);
      expect(sequenceGap.receivedSequence, 2);
      expect(sequenceGap.startSample, 2);
      expect(sequenceGap.endSample, 6);
      expect(sequenceGap.missingFrameCount, 1);
      expect(
        gaps.any(
          (gap) =>
              gap.reason == TranscriptGapReason.unfinishedItem &&
              gap.itemId == 'unfinished-item',
        ),
        isTrue,
      );
    });
  });

  group('OpenAIRealtimeTranscriptionClient security', () {
    test(
      'rejects insecure or credential-bearing URLs before reading secrets',
      () async {
        var secretReads = 0;
        final provider = _CallbackSecretProvider(() async {
          secretReads += 1;
          return 'must-not-be-read';
        });
        final client = OpenAIRealtimeTranscriptionClient(
          secretProvider: provider,
        );
        final credentialUrl = Uri.parse(
          'wss://realtime.example/v1/realtime?access_token=top-secret',
        );
        final credentialConfig = _config(credentialUrl);

        await expectLater(
          client.connect(credentialConfig),
          throwsA(
            isA<RealtimeClientException>()
                .having((error) => error.code, 'code', 'credentials_in_url')
                .having(
                  (error) => error.toString(),
                  'safe message',
                  isNot(contains('top-secret')),
                ),
          ),
        );
        expect(credentialConfig.toString(), isNot(contains('top-secret')));
        expect(secretReads, 0);

        await expectLater(
          client.connect(
            _config(Uri.parse('ws://realtime.example/v1/realtime')),
          ),
          throwsA(
            isA<RealtimeClientException>().having(
              (error) => error.code,
              'code',
              'insecure_websocket',
            ),
          ),
        );
        expect(secretReads, 0);
      },
    );

    test('maps TLS failures without exposing key, URL, or raw error', () async {
      const secret = 'tls-secret-key';
      final client = OpenAIRealtimeTranscriptionClient(
        secretProvider: const _StaticSecretProvider(secret),
        connector: const _TlsFailingConnector(),
      );

      try {
        await client.connect(
          _config(Uri.parse('wss://private.example/v1/realtime')),
        );
        fail('TLS failure should be mapped');
      } on RealtimeClientException catch (error) {
        expect(error.code, 'tls_error');
        expect(error.toString(), isNot(contains(secret)));
        expect(error.toString(), isNot(contains('private.example')));
        expect(error.toString(), isNot(contains('certificate detail')));
      }
    });

    test('redacts provider error messages and response content', () async {
      final server = await _MockRealtimeServer.start();
      addTearDown(server.close);
      const secret = 'provider-secret';
      final client = OpenAIRealtimeTranscriptionClient(
        secretProvider: const _StaticSecretProvider(secret),
      );
      final errors = <TranscriptServiceError>[];
      final subscription = client.events
          .where((event) => event is TranscriptServiceError)
          .cast<TranscriptServiceError>()
          .listen(errors.add);
      addTearDown(subscription.cancel);
      await client.connect(_config(server.uri));

      server.send({
        'type': 'error',
        'error': {
          'code': 'invalid_api_key',
          'message': '$secret transcript=private meeting text',
        },
      });
      await _waitUntil(() => errors.isNotEmpty);

      expect(errors.single.code, 'authentication_failed');
      expect(errors.single.message, isNot(contains(secret)));
      expect(errors.single.message, isNot(contains('private meeting text')));
      expect(errors.single.toString(), isNot(contains(secret)));
      await client.abort();
    });

    for (final statusCode in [401, 403, 429]) {
      test('maps HTTP $statusCode handshake failure to a safe code', () async {
        final client = OpenAIRealtimeTranscriptionClient(
          secretProvider: const _StaticSecretProvider('handshake-secret'),
          connector: _HttpFailingConnector(statusCode),
        );
        final expectedCode = statusCode == 429
            ? 'rate_limited'
            : 'authentication_failed';

        await expectLater(
          client.connect(_config(Uri.parse('wss://private.example/realtime'))),
          throwsA(
            isA<RealtimeClientException>()
                .having((error) => error.code, 'code', expectedCode)
                .having(
                  (error) => error.toString(),
                  'safe message',
                  isNot(contains('handshake-secret')),
                ),
          ),
        );
      });
    }
  });
}

RealtimeTranscriptionConfig _config(
  Uri uri, {
  String model = 'mock-live-model',
  String? prompt,
  List<String> keywords = const [],
  List<String> languages = const [],
}) => RealtimeTranscriptionConfig(
  websocketUrl: uri,
  model: model,
  secret: const SecretReference('realtime-key'),
  contextPrompt: prompt,
  keywords: keywords,
  languages: languages,
);

RealtimeAudioFrame _frame({
  required int sequence,
  required int startSample,
  required Uint8List bytes,
}) => RealtimeAudioFrame(
  sessionId: 'meeting-1',
  sequence: sequence,
  startSample: startSample,
  sampleRate: 24000,
  channels: 1,
  bytes: bytes,
);

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for asynchronous protocol event');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

final class _MockRealtimeServer {
  _MockRealtimeServer._(this._server, this.autoAcknowledgeSession);

  final HttpServer _server;
  final bool autoAcknowledgeSession;
  final List<Map<String, Object?>> _events = <Map<String, Object?>>[];
  final StreamController<void> _eventSignal =
      StreamController<void>.broadcast();
  final Completer<WebSocket> _socket = Completer<WebSocket>();
  bool _closed = false;
  String? authorization;
  Uri requestedUri = Uri();

  Uri get uri =>
      Uri.parse('ws://${_server.address.address}:${_server.port}/v1/realtime');

  static Future<_MockRealtimeServer> start({
    bool autoAcknowledgeSession = true,
  }) async {
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final server = _MockRealtimeServer._(httpServer, autoAcknowledgeSession);
    httpServer.listen(server._handleRequest);
    return server;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    authorization = request.headers.value(HttpHeaders.authorizationHeader);
    requestedUri = request.uri;
    final socket = await WebSocketTransformer.upgrade(request);
    if (!_socket.isCompleted) {
      _socket.complete(socket);
    }
    socket.listen((raw) {
      if (_closed) {
        return;
      }
      final decoded = jsonDecode(raw as String);
      final event = Map<String, Object?>.from(decoded as Map);
      _events.add(event);
      _eventSignal.add(null);
      if (autoAcknowledgeSession && event['type'] == 'session.update') {
        socket.add(
          jsonEncode({
            'type': 'session.updated',
            'event_id': 'auto-session-ready',
          }),
        );
      }
    });
  }

  Future<Map<String, Object?>> nextEvent(String type) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (true) {
      final index = _events.indexWhere((event) => event['type'] == type);
      if (index >= 0) {
        return _events.removeAt(index);
      }
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('Mock server did not receive $type');
      }
      await _eventSignal.stream.first.timeout(const Duration(seconds: 2));
    }
  }

  void send(Map<String, Object?> event) async {
    final socket = await _socket.future;
    socket.add(jsonEncode(event));
  }

  Future<void> close() async {
    _closed = true;
    if (_socket.isCompleted) {
      final socket = await _socket.future;
      await socket.close();
    }
    await _eventSignal.close();
    await _server.close(force: true);
  }
}

final class _StaticSecretProvider implements RealtimeSecretProvider {
  const _StaticSecretProvider(this.secret);

  final String secret;

  @override
  Future<String> read(SecretReference reference) async => secret;
}

final class _CallbackSecretProvider implements RealtimeSecretProvider {
  const _CallbackSecretProvider(this.callback);

  final Future<String> Function() callback;

  @override
  Future<String> read(SecretReference reference) => callback();
}

final class _TlsFailingConnector implements RealtimeWebSocketConnector {
  const _TlsFailingConnector();

  @override
  WebSocketChannel connect(
    Uri uri, {
    required Map<String, dynamic> headers,
    required Duration connectTimeout,
    required Duration pingInterval,
  }) => throw HandshakeException(
    'certificate detail ${headers['Authorization']} $uri',
  );
}

final class _HttpFailingConnector implements RealtimeWebSocketConnector {
  const _HttpFailingConnector(this.statusCode);

  final int statusCode;

  @override
  WebSocketChannel connect(
    Uri uri, {
    required Map<String, dynamic> headers,
    required Duration connectTimeout,
    required Duration pingInterval,
  }) => throw WebSocketException(
    'Connection was not upgraded, HTTP status code: $statusCode '
    '${headers['Authorization']} $uri',
  );
}
