import 'dart:io';

import 'package:easy_meeting/domain/models/configuration.dart';
import 'package:easy_meeting/infrastructure/network/openai_compatible_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('network timeout is converted to a safe actionable error', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final responses = <HttpResponse>[];
    server.listen((request) => responses.add(request.response));
    addTearDown(() async {
      for (final response in responses) {
        await response.close();
      }
      await server.close(force: true);
    });

    final client = OpenAICompatibleClient(
      timeout: const Duration(milliseconds: 80),
    );
    const secret = 'private-timeout-key';
    final config = ServiceConfig(
      baseUrl: 'http://${server.address.host}:${server.port}/v1',
      apiKey: secret,
      model: 'mock-model',
    );

    try {
      await client.test(config);
      fail('request should time out');
    } on OpenAIClientException catch (error) {
      expect(error.code, 'network_error');
      expect(error.message, '请求超时，请检查网络后重试。');
      expect(error.toString(), isNot(contains(secret)));
      expect(error.toString(), isNot(contains(config.baseUrl)));
    }
  });
}
