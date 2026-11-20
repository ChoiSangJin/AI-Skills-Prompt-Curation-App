import 'package:flutter_test/flutter_test.dart';
import 'package:ai_skills_curation/repo_guide.dart';

void main() {
  test('provides a Korean key-free guide by category', () {
    expect(
        koreanQuickGuide({
          'topic_category': 'Skills',
          'topics': '["agent-skills"]',
        }),
        contains('재사용 가능한 작업 절차'));
    expect(
        koreanQuickGuide({
          'topic_category': 'MCP / Agent',
          'topics': '["mcp-server"]',
        }),
        contains('외부 도구나 데이터'));
  });

  test('prefers a generated Korean summary when available', () {
    expect(
        koreanQuickGuide({
          'topic_category': 'Skills',
          'topics': '[]',
          'use_case_summary': '이 저장소의 실제 한국어 요약',
        }),
        '이 저장소의 실제 한국어 요약');
  });

  test('malformed topics safely use the category fallback', () {
    expect(
        koreanQuickGuide({
          'topic_category': 'Prompts',
          'topics': 'not-json',
        }),
        contains('프롬프트'));
  });
}
