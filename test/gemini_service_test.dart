import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_skills_curation/gemini_service.dart';

Map<String, dynamic> model(String name, {String method = 'generateContent'}) =>
    {
      'name': 'models/$name',
      'supportedGenerationMethods': [method]
    };
void main() {
  test(
      'key verification discovers paginated supported models without generating',
      () async {
    var calls = 0;
    final service = GeminiService(client: MockClient((request) async {
      calls++;
      expect(request.method, 'GET');
      expect(request.headers['x-goog-api-key'], 'private-key');
      expect(request.url.queryParameters.containsKey('key'), false);
      if (calls == 1)
        return http.Response(
            jsonEncode({
              'models': [model('gemini-pro'), model('gemini-image')],
              'nextPageToken': 'next'
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      expect(request.url.queryParameters['pageToken'], 'next');
      return http.Response(
          jsonEncode({
            'models': [
              model('gemini-current-flash'),
              model('gemini-embed', method: 'embedContent')
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    expect(await service.discover(' private-key '),
        ['gemini-current-flash', 'gemini-pro']);
    expect(service.selectedModel, 'gemini-current-flash');
    expect(calls, 2);
  });
  test('generation uses discovered model and returns only schema fields',
      () async {
    final service = GeminiService(client: MockClient((request) async {
      if (request.method == 'GET')
        return http.Response(
            jsonEncode({
              'models': [model('gemini-current-flash')]
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      expect(request.url.path,
          '/v1beta/models/gemini-current-flash:generateContent');
      expect(jsonDecode(request.body)['generationConfig']['responseMimeType'],
          'application/json');
      return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'use_case_summary': '목적',
                        'target_audience': '개발자',
                        'execution_snippet': '프롬프트',
                        'extra': 'ignored'
                      })
                    }
                  ]
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    expect(await service.generate('key', 'task'), {
      'use_case_summary': '목적',
      'target_audience': '개발자',
      'execution_snippet': '프롬프트'
    });
  });
  for (final status in [400, 401, 403, 404, 429, 503]) {
    test('$status has actionable sanitized feedback with no automatic retry',
        () async {
      var requests = 0;
      final service = GeminiService(client: MockClient((_) async {
        requests++;
        return http.Response('sensitive-provider-response', status);
      }));
      await expectLater(
          service.discover('key'),
          throwsA(isA<ApiFailure>()
              .having((e) => e.message, 'status', contains('$status'))
              .having(
                  (e) => e.message, 'redacted', isNot(contains('sensitive')))));
      expect(requests, 1);
    });
  }
  test('empty key and input make no network request', () async {
    final service = GeminiService(
        client: MockClient((_) async => throw StateError('must not send')));
    await expectLater(service.discover(' '), throwsA(isA<ApiFailure>()));
    await expectLater(service.generate('key', ' '), throwsA(isA<ApiFailure>()));
  });
  test('empty model list is actionable', () async {
    final service = GeminiService(
        client: MockClient((_) async => http.Response('{"models":[]}', 200)));
    await expectLater(service.discover('key'), throwsA(isA<ApiFailure>()));
  });
}
