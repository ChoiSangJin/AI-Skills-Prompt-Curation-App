import 'package:flutter_test/flutter_test.dart';
import 'package:ai_skills_curation/prompt_library.dart';

void main() {
  test('every purpose has a Gemini guide and several offline examples', () {
    for (final purpose in purposes) {
      expect(purposeGuides[purpose], isNotNull);
      expect(promptLibrary.where((p) => p.purpose == purpose).length,
          greaterThanOrEqualTo(3));
    }
    expect(promptLibrary.every((p) => purposes.contains(p.purpose)), isTrue);
  });
}
