import 'dart:convert';
import 'package:http/http.dart' as http;
import 'gemini_service.dart';

// Category names shown in the app, aligned with githubTopics/minStars.
// Skills has its own category so it is not buried under larger MCP topics.
const categoryNames = ['Skills', 'MCP / Agent', 'Coding Rules', 'Prompts'];

// Search each topic separately: GitHub does not support the app's old
// parenthesized boolean topic expression. Merge and deduplicate the results.
const githubTopics = [
  ['agent-skills', 'claude-skills', 'claude-code-skills'],
  ['mcp-server', 'model-context-protocol'],
  ['cursor-rules', 'claude-code', 'coding-agent'],
  ['prompt-engineering', 'awesome-prompts', 'midjourney-prompts'],
];
const minStars = [30, 50, 30, 100];

/// popular: all-time stars. rising: repos created in the last 30 days.
enum Feed { popular, rising }

const risingDays = 30;
const risingMinStars = 10;
const pageSize = 20;

Uri trendingUri(int category, int topic,
    {Feed feed = Feed.popular, DateTime? now}) {
  final name = githubTopics[category][topic];
  final since = (now ?? DateTime.now())
      .toUtc()
      .subtract(const Duration(days: risingDays))
      .toIso8601String()
      .substring(0, 10);
  return Uri.https('api.github.com', '/search/repositories', {
    'q': feed == Feed.popular
        ? 'topic:$name stars:>${minStars[category]}'
        : 'topic:$name created:>$since stars:>$risingMinStars',
    'sort': 'stars',
    'order': 'desc',
    'per_page': '$pageSize',
  });
}

int _byStars(dynamic a, dynamic b) =>
    (b['stargazers_count'] as int).compareTo(a['stargazers_count'] as int);

Future<List<dynamic>> fetchTrending(int category,
    {Feed feed = Feed.popular, http.Client? client, DateTime? now}) async {
  final owned = client == null;
  client ??= http.Client();
  try {
    final perTopic = <List<dynamic>>[];
    Object? failure;
    for (var topic = 0; topic < githubTopics[category].length; topic++) {
      try {
        final response = await client.get(
            trendingUri(category, topic, feed: feed, now: now),
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'AI-Moa',
            }).timeout(const Duration(seconds: 20));
        if (response.statusCode == 403 || response.statusCode == 429) {
          throw ApiFailure(
              'GitHub 검색 사용 한도 또는 접근 제한입니다. 잠시 후 다시 시도해 주세요. 저장된 자료가 있으면 표시합니다.',
              response.statusCode);
        }
        if (response.statusCode != 200)
          throw ApiFailure(
              'GitHub 검색에 실패했습니다 (${response.statusCode}). 잠시 후 다시 시도해 주세요.');
        perTopic.add(
            (jsonDecode(utf8.decode(response.bodyBytes))['items'] as List)
              ..sort(_byStars));
      } catch (error) {
        failure = error;
        if (error is ApiFailure && (error.status == 403 || error.status == 429))
          break;
      }
    }
    // Guarantee each topic a share of the page so small topics are not
    // crowded out by huge ones, then fill the remaining slots by stars.
    final picked = <String, dynamic>{};
    final quota = pageSize ~/ githubTopics[category].length;
    for (final items in perTopic) {
      for (final item in items.take(quota)) {
        picked.putIfAbsent(item['full_name'] as String, () => item);
      }
    }
    for (final item in perTopic.expand((items) => items).toList()
      ..sort(_byStars)) {
      if (picked.length >= pageSize) break;
      picked.putIfAbsent(item['full_name'] as String, () => item);
    }
    if (picked.isEmpty) {
      if (failure != null) throw failure;
      throw const ApiFailure('GitHub 검색 결과가 없습니다. 잠시 후 새로고침해 주세요.');
    }
    return picked.values.toList()..sort(_byStars);
  } finally {
    if (owned) client.close();
  }
}
