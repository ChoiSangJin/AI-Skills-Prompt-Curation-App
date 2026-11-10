import 'dart:async';
import 'package:flutter/material.dart';

/// Keep the loading route separate from the eventual summary/error UI.
Future<T> withSummaryLoading<T>(BuildContext context, String repository,
    Future<T> Function() action) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('AI가 내용을 정리하고 있어요'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'AI 요약 생성 중',
              liveRegion: true,
              child: const CircularProgressIndicator(),
            ),
            const SizedBox(height: 24),
            Text(repository, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            const Text('네트워크 상태에 따라 잠시 걸릴 수 있어요.', textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
  unawaited(navigator.push(route));
  try {
    return await action();
  } finally {
    // Remove this exact route on success or error; never pop another screen.
    if (navigator.mounted && route.isActive) navigator.removeRoute(route);
  }
}
