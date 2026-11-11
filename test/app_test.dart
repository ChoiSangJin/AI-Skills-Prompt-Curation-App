import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_skills_curation/main.dart';
import 'package:ai_skills_curation/repo_detail.dart';
import 'package:ai_skills_curation/gemini_service.dart';

void main() {
  testWidgets(
      'offline sample remains usable without a key and settings are masked',
      (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
    expect(find.text('AI 모아'), findsOneWidget);
    await tester.tap(find.text('생성'));
    await tester.pumpAndSettle();
    // Built-in examples work without a key and follow the purpose chip.
    await tester.tap(find.text('이미지 생성'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('예시 먼저 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('예시 먼저 보기'));
    await tester.pumpAndSettle();
    expect(find.text('오프라인 예시'), findsOneWidget);
    expect(find.text('프롬프트 복사'), findsOneWidget);
    await tester.tap(find.text('보관함'));
    await tester.pumpAndSettle();
    expect(find.text('트렌딩 카드의 북마크 버튼으로 저장하세요.'), findsOneWidget);
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.obscureText, true);
    expect(find.text('키 확인 후 저장'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('cache freshness label uses relative Korean time', () {
    final now = DateTime(2026, 1, 1, 12);
    int before(Duration d) => now.subtract(d).millisecondsSinceEpoch;
    expect(ago(before(const Duration(seconds: 10)), now: now), '방금 전');
    expect(ago(before(const Duration(minutes: 5)), now: now), '5분 전');
    expect(ago(before(const Duration(hours: 3)), now: now), '3시간 전');
    expect(ago(before(const Duration(days: 2)), now: now), '2일 전');
  });
  testWidgets('repo detail opens without a key and shows summary errors',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: RepoDetail(
            repo: const {
          'repo_name': 'a/repo',
          'repo_url': 'https://github.com/a/repo',
          'star_count': 42,
          'original_description': '설명',
          'topic_category': 'Skills',
          'language': 'Python',
          'topics': '["agent-skills"]',
          'pushed_at': '2026-01-01T00:00:00Z',
        },
            bookmarked: false,
            toggleBookmark: (_) async => true,
            summarize: (_) async =>
                throw const ApiFailure('설정 탭에서 Gemini 키를 먼저 등록해 주세요.'))));
    expect(find.text('★ 42'), findsOneWidget);
    expect(compact(450532), '450.5k');
    expect(compact(1000), '1k');
    expect(compact(1250000), '1.3M');
    expect(find.text('토픽: agent-skills'), findsOneWidget);
    await tester.tap(find.text('AI 요약 보기 (Gemini 키 필요)'));
    await tester.pumpAndSettle();
    expect(find.text('설정 탭에서 Gemini 키를 먼저 등록해 주세요.'), findsOneWidget);
    await tester.tap(find.byTooltip('북마크'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });
}
