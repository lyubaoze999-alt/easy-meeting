import 'dart:io';

import 'package:dio/dio.dart';

import '../../domain/models/configuration.dart';

typedef ServiceApiKeyProvider = Future<String> Function(String reference);

class OpenAIClientException implements Exception {
  const OpenAIClientException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => message;
}

class OpenAICompatibleClient {
  OpenAICompatibleClient({
    Dio? dio,
    this.timeout = const Duration(minutes: 3),
    this.apiKeyProvider,
  }) : _dio = dio ?? Dio();
  final Dio _dio;
  final Duration timeout;
  final ServiceApiKeyProvider? apiKeyProvider;

  Future<Map<String, Object?>> postJson(
    String path,
    Map<String, Object?> body,
    ServiceConfig config,
  ) async {
    final response = await _request(
      path,
      config,
      data: body,
      contentType: Headers.jsonContentType,
    );
    if (response.data is! Map) {
      throw const OpenAIClientException('invalid_response', '服务返回了无法识别的数据。');
    }
    return Map<String, Object?>.from(response.data as Map);
  }

  Future<Map<String, Object?>> postAudio(
    String path,
    File audio,
    ServiceConfig config,
  ) async {
    final response = await _request(
      path,
      config,
      data: FormData.fromMap({
        'model': config.model,
        'file': await MultipartFile.fromFile(
          audio.path,
          filename: audio.uri.pathSegments.last,
          contentType: DioMediaType('audio', 'wav'),
        ),
      }),
      contentType: 'multipart/form-data',
    );
    if (response.data is! Map) {
      throw const OpenAIClientException('invalid_response', '转写服务返回了无法识别的数据。');
    }
    return Map<String, Object?>.from(response.data as Map);
  }

  Future<void> test(ServiceConfig config) async {
    await _request('models', config, method: 'GET');
  }

  Future<Response<Object?>> _request(
    String path,
    ServiceConfig config, {
    Object? data,
    String method = 'POST',
    String? contentType,
  }) async {
    if (!config.isConfigured) {
      throw const OpenAIClientException('missing_configuration', '服务配置不完整。');
    }
    final apiKey = config.apiKey.trim().isNotEmpty
        ? config.apiKey.trim()
        : await apiKeyProvider?.call(config.secretReference) ?? '';
    if (apiKey.isEmpty) {
      throw const OpenAIClientException('missing_api_key', '服务密钥不可用。');
    }
    try {
      return await _dio.request<Object?>(
        _join(config.baseUrl, path),
        data: data,
        options: Options(
          method: method,
          contentType: contentType,
          headers: {'Authorization': 'Bearer $apiKey'},
          connectTimeout: timeout,
          receiveTimeout: timeout,
          sendTimeout: timeout,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final code = status == null ? 'network_error' : 'http_$status';
      final message = switch (status) {
        401 || 403 => '鉴权失败，请检查密钥。',
        404 => '接口地址不正确或不兼容 OpenAI 协议。',
        429 => '请求过于频繁或额度不足，请稍后重试。',
        _
            when error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.receiveTimeout ||
                error.type == DioExceptionType.sendTimeout =>
          '请求超时，请检查网络后重试。',
        _ => '服务请求失败，请检查网络和服务配置。',
      };
      throw OpenAIClientException(code, message);
    }
  }

  static String _join(String baseUrl, String path) {
    final base = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final suffix = path.replaceFirst(RegExp(r'^/+'), '');
    return '$base/$suffix';
  }
}
