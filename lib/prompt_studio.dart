import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PromptStudio extends StatefulWidget {
  final TextEditingController controller;
  final bool busy;
  final Map<String, dynamic>? recipe;
  final String recipeTitle;
  final bool isSample;
  final bool recipeSaved;
  final List<Map<String, dynamic>> saved;
  final Future<void> Function(String) onGenerate;
  final VoidCallback onSample;
  final Future<void> Function() onSave;
  const PromptStudio(
      {super.key,
      required this.controller,
      required this.busy,
      required this.recipe,
      required this.recipeTitle,
      required this.isSample,
      required this.recipeSaved,
      required this.saved,
      required this.onGenerate,
      required this.onSample,
      required this.onSave});
  @override
  State<PromptStudio> createState() => _PromptStudioState();
}

class _PromptStudioState extends State<PromptStudio> {
  static const ink = Color(0xFF302D3D);
  static const lavender = Color(0xFF8785A2);
  static const pink = Color(0xFFFFC7C7);
  static const blush = Color(0xFFFFE2E2);
  static const background = Color(0xFFF6F6F6);
  final resultKey = GlobalKey();
  bool generating = false;
  bool saving = false;
  bool get locked => widget.busy || generating || saving;
  static const examples = [
    (
      Icons.code_rounded,
      '개발·코딩',
      'Flutter로 회원가입 화면을 만들고 싶어요. 입력 검증, 로딩, 오류 상태를 포함한 구현 순서와 코드 작성용 프롬프트를 추천해 주세요.'
    ),
    (
      Icons.edit_note_rounded,
      '글쓰기',
      '새로 출시한 생산성 앱을 소개하는 블로그 글을 쓰고 싶어요. 독자는 직장인이고, 과장 없이 친근한 말투로 제목과 글 구조를 만드는 프롬프트를 추천해 주세요.'
    ),
    (
      Icons.palette_outlined,
      '디자인',
      '모바일 습관 관리 앱의 첫 화면을 디자인하고 싶어요. 핵심 기능, 화면 구성, 접근성을 고려한 디자인 작업용 프롬프트를 추천해 주세요.'
    ),
    (
      Icons.insights_rounded,
      '기획·분석',
      '고객 인터뷰 내용을 분석하고 싶어요. 주요 불편, 반복되는 요구, 우선순위를 근거와 함께 정리하는 분석용 프롬프트를 추천해 주세요.'
    ),
  ];

  @override
  void didUpdateWidget(covariant PromptStudio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recipe != null && !identical(widget.recipe, oldWidget.recipe))
      revealResult();
  }

  void revealResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = resultKey.currentContext;
      if (mounted && target != null) {
        Scrollable.ensureVisible(target,
            alignment: .05,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic);
      }
    });
  }

  Future<void> generate() async {
    final request = widget.controller.text.trim();
    if (locked || request.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => generating = true);
    revealResult();
    try {
      await widget.onGenerate(request);
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Future<void> copy(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('프롬프트를 복사했어요')));
  }

  Widget panel(Widget child, {Color color = Colors.white}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: lavender.withValues(alpha: .12))),
      child: child);

  Widget heading(IconData icon, String title, {Widget? trailing}) =>
      LayoutBuilder(builder: (context, constraints) {
        final stack = trailing != null &&
            (constraints.maxWidth < 260 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.4);
        final row = Row(children: [
          Icon(icon, color: lavender, size: 22),
          const SizedBox(width: 9),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: ink))),
          if (!stack && trailing != null) trailing,
        ]);
        return stack
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                row,
                const SizedBox(height: 8),
                Padding(
                    padding: const EdgeInsets.only(left: 31), child: trailing)
              ])
            : row;
      });

  Widget tag(String title) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: blush, borderRadius: BorderRadius.circular(10)),
      child: Text(title,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: ink)));

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) => ListView(
            // Retain compatibility with the pinned Flutter 3.38 CI SDK.
            // ignore: deprecated_member_use
            cacheExtent: 1000,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                          colors: [blush, Color(0xFFFFEFEF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: tag('나만의 프롬프트 스튜디오'))),
                          const SizedBox(width: 8),
                          const Icon(Icons.auto_awesome_rounded,
                              color: lavender, size: 26)
                        ]),
                        const SizedBox(height: 18),
                        const Text('어떤 일을 더 쉽게\n해내고 싶나요?',
                            style: TextStyle(
                                fontSize: 27,
                                height: 1.3,
                                fontWeight: FontWeight.w800,
                                color: ink)),
                        const SizedBox(height: 10),
                        const Text('작업을 알려주면 추천 방법과\n바로 쓸 수 있는 프롬프트를 정리해 드려요.',
                            style: TextStyle(
                                fontSize: 14, height: 1.6, color: ink)),
                      ])),
              const SizedBox(height: 18),
              panel(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading(Icons.tune_rounded, '원하는 작업'),
                    const SizedBox(height: 6),
                    const Text('예시를 골라 시작하거나 직접 적어보세요.',
                        style:
                            TextStyle(fontSize: 13, height: 1.5, color: ink)),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final example in examples)
                        ActionChip(
                            avatar: Icon(example.$1, size: 17, color: ink),
                            label: Text(example.$2),
                            backgroundColor:
                                value.text == example.$3 ? pink : background,
                            side: BorderSide(
                                color: value.text == example.$3
                                    ? pink
                                    : lavender.withValues(alpha: .18)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            onPressed: generating || saving
                                ? null
                                : () {
                                    widget.controller.value = TextEditingValue(
                                        text: example.$3,
                                        selection: TextSelection.collapsed(
                                            offset: example.$3.length));
                                  }),
                    ]),
                    const SizedBox(height: 16),
                    TextField(
                      controller: widget.controller,
                      enabled: !generating && !saving,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                          hintText:
                              '예: 회원가입 화면을 Flutter로 만들고 싶어요.\n입력 검증과 오류 상태까지 포함해 주세요.',
                          hintStyle: TextStyle(
                              color: ink.withValues(alpha: .55),
                              height: 1.6,
                              fontSize: 14),
                          filled: true,
                          fillColor: background,
                          contentPadding: const EdgeInsets.all(16),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: lavender.withValues(alpha: .18))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  const BorderSide(color: lavender, width: 2)),
                          counterStyle: TextStyle(
                              color: ink.withValues(alpha: .6), fontSize: 11)),
                    ),
                    const SizedBox(height: 4),
                    const Text('목표 · 사용할 도구 · 원하는 결과를 적으면 더 좋아요.',
                        style:
                            TextStyle(fontSize: 12, height: 1.5, color: ink)),
                    const SizedBox(height: 18),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 54),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 15),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16))),
                            onPressed: locked || value.text.trim().isEmpty
                                ? null
                                : generate,
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (generating)
                                    const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: ink))
                                  else
                                    const Icon(Icons.auto_awesome_rounded,
                                        size: 20),
                                  const SizedBox(width: 9),
                                  Flexible(
                                      child: Text(
                                          generating
                                              ? '프롬프트를 만들고 있어요'
                                              : '추천 프롬프트 만들기',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15))),
                                ]))),
                    const SizedBox(height: 8),
                    Center(
                        child: TextButton.icon(
                            onPressed: generating || saving
                                ? null
                                : () {
                                    FocusScope.of(context).unfocus();
                                    widget.onSample();
                                  },
                            icon:
                                const Icon(Icons.visibility_outlined, size: 18),
                            label: const Text('예시 먼저 보기'))),
                    const Center(
                        child: Text('API 키 없이 결과 형태를 확인할 수 있어요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12, height: 1.5, color: ink))),
                  ])),
              if (generating || widget.recipe != null) ...[
                const SizedBox(height: 18),
                KeyedSubtree(
                    key: resultKey,
                    child: generating
                        ? panel(
                            const Column(children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('내 작업에 맞는 프롬프트를 다듬고 있어요',
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                              SizedBox(height: 6),
                              Text('완성되면 이곳에 추천 결과가 나타나요.',
                                  textAlign: TextAlign.center),
                            ]),
                            color: blush)
                        : resultPanel()),
              ],
              const SizedBox(height: 26),
              heading(Icons.bookmarks_outlined, '저장한 프롬프트',
                  trailing: tag('${widget.saved.length}개')),
              const SizedBox(height: 12),
              if (widget.saved.isEmpty)
                panel(Column(children: [
                  Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                          color: blush, shape: BoxShape.circle),
                      child: const Icon(Icons.bookmark_add_outlined,
                          color: lavender, size: 26)),
                  const SizedBox(height: 12),
                  const Text('아직 저장한 프롬프트가 없어요',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ink)),
                  const SizedBox(height: 6),
                  const Text('마음에 드는 추천 결과를 저장해\n다음 작업에 다시 꺼내 쓰세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, height: 1.6, color: ink)),
                ]))
              else ...[
                for (final item in widget.saved)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                            leading: const Icon(Icons.description_outlined,
                                color: lavender),
                            title: Text(item['title'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(item['content'] as String,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            onTap: () => showSaved(item),
                            trailing: IconButton(
                                tooltip: '저장한 프롬프트 복사',
                                icon: const Icon(Icons.copy_rounded, size: 19),
                                onPressed: () =>
                                    copy(item['content'] as String)),
                          ))),
              ],
            ]),
      );

  Widget resultPanel() =>
      panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        heading(Icons.auto_awesome_rounded, '추천 결과',
            trailing: tag(widget.isSample ? '오프라인 예시' : 'AI 추천')),
        const SizedBox(height: 14),
        Text(widget.recipeTitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: ink)),
        const SizedBox(height: 18),
        const Text('추천 워크플로',
            style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
        const SizedBox(height: 7),
        SelectableText(widget.recipe!['use_case_summary'] as String,
            style: const TextStyle(height: 1.65, color: ink)),
        const SizedBox(height: 16),
        const Text('이런 분께 추천해요',
            style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
        const SizedBox(height: 7),
        SelectableText(widget.recipe!['target_audience'] as String,
            style: const TextStyle(height: 1.6, color: ink)),
        const SizedBox(height: 18),
        const Text('바로 쓸 프롬프트',
            style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
        const SizedBox(height: 9),
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: background, borderRadius: BorderRadius.circular(16)),
            child: SelectableText(widget.recipe!['execution_snippet'] as String,
                style: const TextStyle(height: 1.7, fontSize: 14, color: ink))),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 8, children: [
          FilledButton.icon(
              onPressed: () =>
                  copy(widget.recipe!['execution_snippet'] as String),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('프롬프트 복사')),
          OutlinedButton.icon(
              onPressed: locked || widget.recipeSaved
                  ? null
                  : () async {
                      setState(() => saving = true);
                      try {
                        await widget.onSave();
                      } finally {
                        if (mounted) setState(() => saving = false);
                      }
                    },
              icon: Icon(
                  widget.recipeSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_add_outlined,
                  size: 18),
              label: Text(widget.recipeSaved
                  ? '저장됨'
                  : saving
                      ? '저장 중'
                      : '저장')),
        ]),
      ]));

  void showSaved(Map<String, dynamic> item) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
        builder: (sheetContext) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['title'] as String,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              SelectableText(item['content'] as String,
                  style: const TextStyle(height: 1.7)),
              const SizedBox(height: 20),
              FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    copy(item['content'] as String);
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('프롬프트 복사')),
            ])));
  }
}
