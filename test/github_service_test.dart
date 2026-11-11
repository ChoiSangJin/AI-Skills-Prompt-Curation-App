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
      expect(query, 'topic:${githubTopics[0][count++]} stars:>${minStars[0]}');
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
  test('rising feed searches repos created in the last 30 days', () {
    final uri = trendingUri(0, 1,
        feed: Feed.rising, now: DateTime.utc(2026, 11, 11, 12));
    expect(uri.queryParameters['q'],
        'topic:claude-skills created:>2026-10-12 stars:>10');
    expect(uri.queryParameters['sort'], 'stars');
  });
  test('each topic keeps a share of the page against larger topics',
      () async {
    final client = MockClient((request) async {
      final topic = request.url.queryParameters['q']!.split(' ').first;
      // The first topic has 20 huge repos; the others have small ones.
      final huge = topic == 'topic:${githubTopics[0][0]}';
      return http.Response(
          jsonEncode({
            'items': [
              for (var i = 0; i < 20; i++)
                {
                  'full_name': '$topic/$i',
                  'stargazers_count': huge ? 100000 - i : 100 - i
                }
            ]
          }),
          200);
    });
    final result = await fetchTrending(0, client: client);
    expect(result.length, pageSize);
    for (final topic in githubTopics[0]) {
      final count = result
          .where((r) => (r['full_name'] as String).startsWith('topic:$topic/'))
          .length;
      expect(count, greaterThanOrEqualTo(pageSize ~/ githubTopics[0].length));
    }
  });
}
