// Built-in prompt examples that work without a Gemini key.

/// Purposes shown as chips in the generator tab.
const purposes = ['코딩', '이미지 생성', '글쓰기', '리서치'];

/// Output-format guidance sent to Gemini for each purpose.
const purposeGuides = {
  '코딩':
      'Purpose: coding. Write execution_snippet as a prompt to paste into a coding agent such as Claude Code or Cursor, with context, constraints and acceptance criteria.',
  '이미지 생성':
      'Purpose: image generation. Write execution_snippet as an English Midjourney/Stable Diffusion prompt covering subject, style, lighting, composition and camera, ending with parameters such as --ar 16:9.',
  '글쓰기':
      'Purpose: writing. Write execution_snippet as a prompt specifying audience, tone, length and structure.',
  '리서치':
      'Purpose: research. Write execution_snippet as a prompt asking for sourced findings, comparisons and open questions.',
};

class LibraryPrompt {
  final String purpose;
  final String title;
  final String content;
  const LibraryPrompt(this.purpose, this.title, this.content);
}

const promptLibrary = [
  LibraryPrompt('코딩', '코드 리뷰 요청',
      '아래 코드를 리뷰해 주세요. 버그 가능성, 보안 문제, 성능 문제를 심각도 순으로 나열하고 각 항목마다 문제 위치, 이유, 수정 코드를 보여 주세요. 스타일 지적은 마지막에 따로 모아 주세요.\n\n```\n[코드 붙여넣기]\n```'),
  LibraryPrompt('코딩', '버그 재현 후 수정',
      '다음 버그를 수정해 주세요: [증상]. 먼저 버그를 재현하는 실패 테스트를 작성하고, 원인을 설명한 뒤, 테스트가 통과하도록 최소한으로 수정해 주세요. 관련 없는 코드는 바꾸지 마세요.'),
  LibraryPrompt('코딩', 'CLAUDE.md / 코딩 규칙 작성',
      '이 저장소를 분석해서 AI 코딩 에이전트용 규칙 파일을 작성해 주세요. 빌드·테스트 명령, 폴더 구조, 코드 스타일, 절대 하면 안 되는 작업을 짧은 항목으로 정리하고, 추측한 내용은 "확인 필요"로 표시해 주세요.'),
  LibraryPrompt('이미지 생성', '제품 사진',
      'Studio product photo of [product] on a matte pastel pink pedestal, soft diffused key light from the left, subtle reflection, minimal background, shallow depth of field, 85mm lens, high detail, commercial photography --ar 4:5 --style raw'),
  LibraryPrompt('이미지 생성', '앱 아이콘',
      'Minimal flat app icon of [subject], rounded square, bold simple shapes, two-color palette lavender and pink, centered, no text, soft gradient, vector style, high contrast --ar 1:1'),
  LibraryPrompt('이미지 생성', '일러스트 배경',
      'Cozy isometric illustration of [scene], warm evening light, soft pastel colors, clean lines, small details, gentle shadows, digital art, wide composition --ar 16:9'),
  LibraryPrompt('글쓰기', 'SNS 소개글',
      '[주제]를 소개하는 SNS 게시물을 3가지 버전으로 작성해 주세요. 독자는 [대상], 각 버전은 300자 이내, 첫 문장은 호기심을 끄는 질문으로 시작하고, 해시태그는 3개 이하로 붙여 주세요.'),
  LibraryPrompt('글쓰기', '문서 요약',
      '아래 글을 바쁜 독자용으로 요약해 주세요. 핵심 결론 한 문장, 근거 3개, 실행할 일 목록 순서로 정리하고 원문에 없는 내용은 추가하지 마세요.\n\n[글 붙여넣기]'),
  LibraryPrompt('글쓰기', '이메일 다듬기',
      '아래 이메일 초안을 [정중한/간결한] 톤으로 다듬어 주세요. 요청 사항과 기한이 첫 문단에 드러나게 하고, 수정한 이유를 마지막에 짧게 알려 주세요.\n\n[초안 붙여넣기]'),
  LibraryPrompt('리서치', '도구 비교',
      '[도구 A]와 [도구 B]를 [용도] 기준으로 비교해 주세요. 가격, 학습 난이도, 장단점, 추천 상황을 표로 정리하고, 확인이 필요한 최신 정보는 따로 표시해 주세요.'),
  LibraryPrompt('리서치', '주제 빠르게 파악',
      '[주제]를 처음 접하는 사람에게 설명해 주세요. 핵심 개념 5개, 자주 하는 오해, 더 공부할 자료 유형을 순서대로 알려 주고, 불확실한 부분은 그렇다고 말해 주세요.'),
  LibraryPrompt('리서치', 'GitHub 저장소 평가',
      '이 GitHub 저장소를 도입해도 될지 평가해 주세요: [URL]. 유지보수 활발도, 라이선스, 문서 품질, 보안 위험, 대안을 확인하고 도입/보류 의견을 근거와 함께 주세요.'),
];
