import 'dart:convert';

/// Korean, key-free context shown before an optional Gemini deep summary.
///
/// This intentionally describes only facts that can be inferred from the
/// category and GitHub topics. It must not pretend to translate or summarize
/// repository-specific behavior that has not been inspected.
String koreanQuickGuide(Map<String, dynamic> repo) {
  final summary = repo['use_case_summary'] as String?;
  if (summary != null && summary.trim().isNotEmpty) return summary.trim();

  final category = repo['topic_category'] as String? ?? '';
  final topics = _topics(repo['topics']);
  if (category == 'Skills' || topics.any((topic) => topic.contains('skill'))) {
    return 'AI 에이전트에 재사용 가능한 작업 절차나 전문 기능을 추가하는 자료예요. 지원 도구와 설치 방법은 저장소에서 확인하세요.';
  }
  if (category == 'MCP / Agent' ||
      topics.contains('mcp-server') ||
      topics.contains('model-context-protocol')) {
    return 'AI 에이전트를 외부 도구나 데이터에 연결하는 MCP·에이전트 자료예요. 지원 클라이언트와 필요한 권한을 확인하세요.';
  }
  if (category == 'Coding Rules' ||
      topics.any((topic) => topic.contains('rules'))) {
    return '코딩 에이전트의 작업 방식과 프로젝트 규칙을 정하는 자료예요. 사용하는 에이전트의 규칙 파일 형식을 확인하세요.';
  }
  if (category == 'Prompts' ||
      topics.any((topic) => topic.contains('prompt'))) {
    return '반복해서 활용할 수 있는 프롬프트와 작성 예시를 모은 자료예요. 사용 모델과 원하는 결과 형식에 맞게 수정해 보세요.';
  }
  return 'AI 작업에 활용할 수 있는 공개 GitHub 자료예요. 상세 기능과 사용 방법은 저장소 원문에서 확인하세요.';
}

List<String> _topics(dynamic raw) {
  if (raw is List) return raw.whereType<String>().toList();
  if (raw is! String || raw.isEmpty) return const [];
  try {
    return (jsonDecode(raw) as List).whereType<String>().toList();
  } catch (_) {
    return const [];
  }
}
