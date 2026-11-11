import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_skills_curation/main.dart';

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
    await tester.tap(find.text('제품 사진'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('복사'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('복사'));
    // Check before the one-second snackbar is dismissed.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('복사했어요'), findsOneWidget);
    await tester.pumpAndSettle();
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
}
