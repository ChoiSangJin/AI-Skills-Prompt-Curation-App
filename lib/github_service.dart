import 'dart:convert';
import 'package:http/http.dart' as http;
import 'gemini_service.dart';

// Search each topic separately: GitHub does not support the app's old
// parenthesized boolean topic expression. Merge and deduplicate the results.
const githubTopics = [
  ['mcp-server', 'model-context-protocol', 'agent-skills'],
  ['cursor-rules', 'claude-code', 'coding-agent'],
  ['prompt-engineering', 'awesome-prompts', 'midjourney-prompts'],
];
Uri trendingUri(int category, int topic) =>
    Uri.https('api.github.com', '/search/repositories', {
      'q': 'topic:${githubTopics[category][topic]} stars:>${[
        50,
        30,
        100
      ][category]}',
      'sort': 'stars',
      'order': 'desc',
      'per_page': '20',
    });
Future<List<dynamic>> fetchTrending(int category, {http.Client? client}) async {
  final owned = client == null;
  client ??= http.Client();
  try {
    final merged = <String, dynamic>{};
    Object? failure;
    for (var topic = 0; topic < githubTopics[category].length; topic++) {
      try {
        final response =
            await client.get(trendingUri(category, topic), headers: {
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
        final items =
            jsonDecode(utf8.decode(response.bodyBytes))['items'] as List;
        for (final item in items) {
          merged[item['full_name'] as String] = item;
        }
      } catch (error) {
        failure = error;
        if (error is ApiFailure && (error.status == 403 || error.status == 429))
          break;
      }
    }
    if (merged.isEmpty) {
      if (failure != null) throw failure;
      throw const ApiFailure('GitHub 검색 결과가 없습니다. 잠시 후 새로고침해 주세요.');
    }
    final sorted = merged.values.toList()
      ..sort((a, b) => (b['stargazers_count'] as int)
          .compareTo(a['stargazers_count'] as int));
    return sorted.take(20).toList();
  } finally {
    if (owned) client.close();
  }
}
