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
    await tester.tap(find.text('오프라인 샘플 보기'));
    await tester.pumpAndSettle();
    expect(find.text('프롬프트 복사'), findsOneWidget);
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.obscureText, true);
    expect(find.text('키 확인 후 저장'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
