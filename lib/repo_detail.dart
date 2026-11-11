import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'gemini_service.dart';

/// Relative time label such as "3시간 전" for cache freshness.
String ago(int millis, {DateTime? now}) {
  final diff = (now ?? DateTime.now())
      .difference(DateTime.fromMillisecondsSinceEpoch(millis));
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  return '${diff.inDays}일 전';
}

/// Repository details that work without a Gemini key; the AI summary is an
/// optional action on this page instead of a requirement for opening it.
class RepoDetail extends StatefulWidget {
  final Map<String, dynamic> repo;

  /// Returns the summary fields; throws ApiFailure with a user message.
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> repo)
      summarize;
  const RepoDetail({super.key, required this.repo, required this.summarize});
  @override
  State<RepoDetail> createState() => _RepoDetailState();
}

class _RepoDetailState extends State<RepoDetail> {
  late Map<String, dynamic> repo = widget.repo;
  bool busy = false;
  String error = '';

  void copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('복사했어요'), duration: Duration(seconds: 1)));
  }

  Future<void> summarize() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final output = await widget.summarize(repo);
      if (mounted) setState(() => repo = {...repo, ...output});
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topics = (jsonDecode(repo['topics'] as String? ?? '[]') as List)
        .cast<String>();
    final pushed = DateTime.tryParse(repo['pushed_at'] as String? ?? '');
    final hasSummary = repo['use_case_summary'] != null;
    return Scaffold(
        appBar: AppBar(title: Text(repo['repo_name'])),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(repo['original_description'] as String? ?? ''),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 4, children: [
            Chip(label: Text('★ ${repo['star_count']}')),
            Chip(label: Text(repo['topic_category'])),
            if (repo['language'] != null) Chip(label: Text(repo['language'])),
            if (pushed != null)
              Chip(
                  label: Text(
                      '최근 업데이트 ${ago(pushed.millisecondsSinceEpoch)}')),
          ]),
          if (topics.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('토픽: ${topics.join(', ')}'),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('GitHub에서 열기'),
              onPressed: () => launchUrl(Uri.parse(repo['repo_url']),
                  mode: LaunchMode.externalApplication)),
          const Divider(height: 32),
          if (hasSummary) ...[
            const Text('AI 요약', style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(
                '${repo['use_case_summary']}\n\n${repo['target_audience']}'),
            const SizedBox(height: 12),
            const Text('실행 예시', style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(repo['execution_snippet']),
            TextButton(
                onPressed: () => copy(repo['execution_snippet']),
                child: const Text('복사')),
          ] else
            OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('AI 요약 보기 (Gemini 키 필요)'),
                onPressed: busy ? null : summarize),
          if (error.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8), child: Text(error)),
        ]));
  }
}
