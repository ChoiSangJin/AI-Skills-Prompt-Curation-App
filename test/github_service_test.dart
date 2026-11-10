import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_skills_curation/github_service.dart';
import 'package:ai_skills_curation/gemini_service.dart';

void main() {
  test('search topics independently then merge, deduplicate and sort',
      () async {
    var count = 0;
    final client = MockClient((request) async {
      final query = request.url.queryParameters['q']!;
      expect(query, isNot(contains('OR')));
      expect(query, isNot(contains('(')));
      expect(query, 'topic:${githubTopics[0][count++]} stars:>50');
      return http.Response(
          jsonEncode({
            'items': [
              {'full_name': 'a/repo', 'stargazers_count': 10},
              {'full_name': 'b/repo', 'stargazers_count': 20}
            ]
          }),
          200);
    });
    final result = await fetchTrending(0, client: client);
    expect(count, 3);
    expect(result.length, 2);
    expect(result.first['full_name'], 'b/repo');
  });
  test('empty success is reported rather than silently showing nothing',
      () async {
    await expectLater(
        fetchTrending(2,
            client:
                MockClient((_) async => http.Response('{"items":[]}', 200))),
        throwsA(isA<ApiFailure>()
            .having((e) => e.message, 'empty', contains('결과가 없습니다'))));
  });
  test('quota failure is reported when no cached or fresh data exists',
      () async {
    await expectLater(
        fetchTrending(1,
            client: MockClient((_) async => http.Response('{}', 403))),
        throwsA(isA<ApiFailure>()
            .having((e) => e.message, 'limit', contains('한도'))));
  });
}
