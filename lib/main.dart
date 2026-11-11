import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'gemini_service.dart';
import 'summary_loading.dart';
import 'github_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}

class Store {
  static const secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true));

  // v2 keeps one cache row per feed/category and moves AI summaries into
  // their own table so refreshing the cache never discards paid summaries.
  static Future<void> _createV2(DatabaseExecutor db) async {
    await db.execute(
        'CREATE TABLE cached_repos(repo_name TEXT NOT NULL, feed TEXT NOT NULL, topic_category TEXT NOT NULL, repo_url TEXT NOT NULL, star_count INTEGER NOT NULL, original_description TEXT, language TEXT, topics TEXT, pushed_at TEXT, updated_at INTEGER NOT NULL, PRIMARY KEY(repo_name, feed, topic_category))');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS summaries(repo_name TEXT PRIMARY KEY, use_case_summary TEXT NOT NULL, target_audience TEXT NOT NULL, execution_snippet TEXT NOT NULL)');
  }

  static Future<Database> open() async =>
      openDatabase(p.join(await getDatabasesPath(), 'curation.db'), version: 2,
          onCreate: (db, _) async {
        await _createV2(db);
        await db.execute(
            'CREATE TABLE saved_prompts(id TEXT PRIMARY KEY, title TEXT NOT NULL, content TEXT NOT NULL, category TEXT NOT NULL, created_at INTEGER NOT NULL)');
      }, onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute(
              'CREATE TABLE summaries(repo_name TEXT PRIMARY KEY, use_case_summary TEXT NOT NULL, target_audience TEXT NOT NULL, execution_snippet TEXT NOT NULL)');
          await db.execute(
              'INSERT INTO summaries SELECT repo_name, use_case_summary, target_audience, execution_snippet FROM cached_repos WHERE use_case_summary IS NOT NULL');
          await db.execute('DROP TABLE cached_repos');
          await _createV2(db);
        }
      });
}

/// Relative time label such as "3시간 전" for cache freshness.
String ago(int millis, {DateTime? now}) {
  final diff = (now ?? DateTime.now())
      .difference(DateTime.fromMillisecondsSinceEpoch(millis));
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  return '${diff.inDays}일 전';
}

ThemeData appTheme() {
  const ink = Color(0xFF302D3D);
  const pink = Color(0xFFFFC7C7);
  const blush = Color(0xFFFFE2E2);
  const background = Color(0xFFF6F6F6);
  const lavender = Color(0xFF8785A2);
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    cardColor: blush,
    colorScheme: const ColorScheme.light(
        primary: lavender,
        onPrimary: Colors.black,
        secondary: pink,
        onSecondary: ink,
        surface: background,
        onSurface: ink,
        primaryContainer: blush,
        onPrimaryContainer: ink,
        secondaryContainer: pink,
        onSecondaryContainer: ink),
    appBarTheme:
        const AppBarTheme(backgroundColor: background, foregroundColor: ink),
    navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: blush, indicatorColor: pink),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: lavender, foregroundColor: Colors.black)),
    textButtonTheme:
        TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: ink)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(foregroundColor: ink)),
    inputDecorationTheme: const InputDecorationTheme(
        filled: true, fillColor: blush, border: OutlineInputBorder()),
  );
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: 'AI 모아', theme: appTheme(), home: const Home());
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int page = 0;
  int category = 0;
  Feed feed = Feed.popular;
  bool busy = false;
  String message = '';
  List<Map<String, dynamic>> repos = [];
  List<Map<String, dynamic>> saved = [];
  Map<String, dynamic>? recipe;
  final gemini = GeminiService();
  String keyStatus = '키를 등록하면 사용할 수 있는 모델을 자동으로 찾습니다.';
  final keyInput = TextEditingController();
  final task = TextEditingController();
  final categories = ['All', ...categoryNames];
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    keyInput.dispose();
    task.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = '';
    });
    try {
      await action();
    } catch (error) {
      if (mounted)
        setState(() {
          message = friendlyError(error);
        });
    } finally {
      if (mounted)
        setState(() {
          busy = false;
        });
    }
  }

  // force: the manual refresh button skips the 12-hour cache check.
  // Only the selected feed is fetched to stay within GitHub's search limit.
  Future<void> load({bool force = false}) => run(() async {
        final db = await Store.open();
        for (int i = 0; i < categoryNames.length; i++) {
          const where = 'feed = ? AND topic_category = ?';
          final args = [feed.name, categoryNames[i]];
          final cached =
              await db.query('cached_repos', where: where, whereArgs: args);
          if (!force &&
              cached.isNotEmpty &&
              cached.every((r) =>
                  DateTime.now().millisecondsSinceEpoch -
                      (r['updated_at'] as int) <
                  43200000)) continue;
          try {
            final items = await fetchTrending(i, feed: feed);
            final now = DateTime.now().millisecondsSinceEpoch;
            await db.transaction((txn) async {
              // Replace the whole category so repos that fell out of the
              // ranking do not linger and defeat the freshness check.
              await txn.delete('cached_repos', where: where, whereArgs: args);
              for (final item in items) {
                await txn.insert('cached_repos', {
                  'repo_name': item['full_name'],
                  'feed': feed.name,
                  'topic_category': categoryNames[i],
                  'repo_url': item['html_url'],
                  'star_count': item['stargazers_count'],
                  'original_description': item['description'] ?? '',
                  'language': item['language'],
                  'topics': jsonEncode(item['topics'] ?? []),
                  'pushed_at': item['pushed_at'],
                  'updated_at': now
                });
              }
            });
          } catch (error) {
            if (mounted)
              setState(() {
                message = friendlyError(error);
              });
            // Further categories would hit the same GitHub limit.
            if (error is ApiFailure &&
                (error.status == 403 || error.status == 429)) break;
          }
        }
        final rows = await db.rawQuery(
            'SELECT c.*, s.use_case_summary, s.target_audience, s.execution_snippet FROM cached_repos c LEFT JOIN summaries s ON s.repo_name = c.repo_name WHERE c.feed = ? ORDER BY c.star_count DESC',
            [feed.name]);
        final prompts =
            await db.query('saved_prompts', orderBy: 'created_at DESC');
        if (mounted)
          setState(() {
            repos = rows;
            saved = prompts;
          });
      });
  Future<void> summarize(Map<String, dynamic> repo) => run(() async {
        var result = repo;
        if (repo['use_case_summary'] == null) {
          final key = await Store.secure.read(key: 'gemini');
          if (key == null) {
            setState(() {
              page = 2;
              message = '설정에서 Gemini 키를 먼저 검증하세요.';
            });
            return;
          }
          if (!mounted) return;
          result = await withSummaryLoading(
              context, repo['repo_name'] as String, () async {
            final output = await gemini.generate(key,
                'Analyze repository metadata (do not invent installation commands): ${jsonEncode(repo)}');
            final db = await Store.open();
            await db.insert(
                'summaries', {'repo_name': repo['repo_name'], ...output},
                conflictAlgorithm: ConflictAlgorithm.replace);
            return {...repo, ...output};
          });
          // Copy only the summary fields: the same repo can appear in
          // several categories and must keep its own category row.
          repos = repos
              .map((r) => r['repo_name'] == repo['repo_name']
                  ? {
                      ...r,
                      for (final field in [
                        'use_case_summary',
                        'target_audience',
                        'execution_snippet'
                      ])
                        field: result[field]
                    }
                  : r)
              .toList();
        }
        if (!mounted) return;
        await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
                    title: Text(result['repo_name']),
                    content: SingleChildScrollView(
                        child: SelectableText(
                            '${result['use_case_summary']}\n\n${result['target_audience']}\n\n${result['execution_snippet']}')),
                    actions: [
                      TextButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                                text: result['execution_snippet']));
                          },
                          child: const Text('복사')),
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('닫기'))
                    ]));
      });
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('AI 모아')),
      bottomNavigationBar: NavigationBar(
          selectedIndex: page,
          onDestinationSelected: (v) => setState(() => page = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.explore), label: '트렌딩'),
            NavigationDestination(icon: Icon(Icons.auto_awesome), label: '생성'),
            NavigationDestination(icon: Icon(Icons.key), label: '설정')
          ]),
      body: Column(children: [
        if (busy) const LinearProgressIndicator(),
        if (message.isNotEmpty)
          Padding(padding: const EdgeInsets.all(12), child: Text(message)),
        Expanded(
            child: page == 0
                ? trending()
                : page == 1
                    ? generator()
                    : settings())
      ]));
  Widget trending() => Column(children: [
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SegmentedButton<Feed>(
                segments: const [
                  ButtonSegment(value: Feed.popular, label: Text('인기 (누적)')),
                  ButtonSegment(
                      value: Feed.rising, label: Text('급상승 (최근 30일)')),
                ],
                selected: {feed},
                onSelectionChanged: busy
                    ? null
                    : (value) {
                        setState(() => feed = value.first);
                        load();
                      })),
        Wrap(
            children: List.generate(
                categories.length,
                (i) => Padding(
                    padding: const EdgeInsets.all(4),
                    child: ChoiceChip(
                        label: Text(categories[i]),
                        selected: category == i,
                        onSelected: (_) => setState(() => category = i))))),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(
              onPressed: busy ? null : () => load(force: true),
              child: const Text('새로고침')),
          // Oldest fetch time among loaded rows tells how fresh the list is.
          if (repos.isNotEmpty)
            Text(
                '마지막 업데이트: ${ago(repos.map((r) => r['updated_at'] as int).reduce((a, b) => a < b ? a : b))}'),
        ]),
        Expanded(
            child: ListView(children: [
          if (repos.isEmpty)
            const ListTile(
                title: Text('저장된 저장소가 없습니다'),
                subtitle:
                    Text('새로고침으로 GitHub 자료를 가져오세요. Gemini 키는 필요하지 않습니다.')),
          for (final repo in visibleRepos())
            Card(
                child: ListTile(
                    title: Text(repo['repo_name']),
                    subtitle: Text(
                        '★ ${repo['star_count']} · ${repo['topic_category']}\n${repo['original_description']}'),
                    onTap: busy ? null : () => summarize(repo),
                    trailing: IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => launchUrl(Uri.parse(repo['repo_url']),
                            mode: LaunchMode.externalApplication))))
        ]))
      ]);
  // In "All" a repo matching several categories is shown only once.
  List<Map<String, dynamic>> visibleRepos() {
    final seen = <String>{};
    return repos
        .where((r) =>
            (category == 0 || r['topic_category'] == categories[category]) &&
            seen.add(r['repo_name'] as String))
        .toList();
  }

  Widget generator() => ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
            controller: task,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '어떤 작업을 하고 싶나요?')),
        FilledButton(
            onPressed: busy
                ? null
                : () => run(() async {
                      final key = await Store.secure.read(key: 'gemini');
                      if (key == null) {
                        setState(() => message = '설정에서 Gemini 키를 등록하세요.');
                        return;
                      }
                      final result = await gemini.generate(key, task.text);
                      if (mounted) setState(() => recipe = result);
                    }),
            child: const Text('추천 및 프롬프트 생성')),
        OutlinedButton(
            onPressed: () => setState(() => recipe = {
                  'use_case_summary':
                      'Flutter 화면을 작은 위젯으로 분리하고 접근성과 오류 상태를 점검하세요. 주의: API 키를 소스 코드에 넣지 마세요.',
                  'target_audience': 'Flutter 개발자',
                  'execution_snippet':
                      'Flutter 화면을 설계해 주세요. 로딩·빈 목록·오류 상태와 접근성 레이블을 포함하고 작은 위젯으로 분리하세요.'
                }),
            child: const Text('오프라인 샘플 보기')),
        if (recipe != null) ...[
          SelectableText(
              '${recipe!['use_case_summary']}\n\n${recipe!['target_audience']}\n\n${recipe!['execution_snippet']}'),
          TextButton(
              onPressed: () => Clipboard.setData(
                  ClipboardData(text: recipe!['execution_snippet'])),
              child: const Text('프롬프트 복사')),
          TextButton(
              onPressed: () => run(() async {
                    final db = await Store.open();
                    final now = DateTime.now().millisecondsSinceEpoch;
                    await db.insert('saved_prompts', {
                      'id': '$now',
                      'title': task.text.isEmpty ? '샘플' : task.text,
                      'content': recipe!['execution_snippet'],
                      'category': 'custom',
                      'created_at': now
                    });
                    final rows = await db.query('saved_prompts',
                        orderBy: 'created_at DESC');
                    if (mounted) setState(() => saved = rows);
                  }),
              child: const Text('저장'))
        ],
        const Divider(),
        const Text('저장한 프롬프트'),
        for (final item in saved)
          ListTile(
              title: Text(item['title']),
              subtitle: Text(item['content']),
              onTap: () =>
                  Clipboard.setData(ClipboardData(text: item['content'])))
      ]);
  Widget settings() => ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
            '키는 기기의 보안 저장소에 보관됩니다. Gemini 요청 시 입력 내용과 선택한 저장소 메타데이터가 Google로 전송됩니다.'),
        TextField(
            controller: keyInput,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Gemini API 키')),
        FilledButton(
            onPressed: busy
                ? null
                : () => run(() async {
                      final key = keyInput.text.trim();
                      await gemini.discover(key);
                      await Store.secure.write(key: 'gemini', value: key);
                      keyInput.clear();
                      if (mounted)
                        setState(() {
                          message = '키 확인 · 저장 완료';
                          keyStatus = '모델 목록 확인 완료. 생성 권한과 할당량은 실제 생성 시 확인합니다.';
                        });
                    }),
            child: const Text('키 확인 후 저장')),
        TextButton(
            onPressed: () => run(() async {
                  await Store.secure.delete(key: 'gemini');
                  gemini.clear();
                  keyInput.clear();
                  if (mounted)
                    setState(() {
                      message = '키 삭제됨';
                      keyStatus = '등록된 키가 없습니다.';
                    });
                }),
            child: const Text('키 삭제')),
        TextButton(
            onPressed: () => launchUrl(
                Uri.parse('https://aistudio.google.com/app/apikey'),
                mode: LaunchMode.externalApplication),
            child: const Text('Google AI Studio에서 키 발급')),
        Text(keyStatus),
        if (gemini.models.isNotEmpty)
          DropdownButton<String>(
              isExpanded: true,
              value: gemini.selectedModel,
              items: gemini.models
                  .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: busy
                  ? null
                  : (m) => setState(() => gemini.selectedModel = m)),
        const Text(
            'API 키 없이 생성 탭의 오프라인 샘플을 사용할 수 있습니다. Gemini 호출은 사용 요금이 발생할 수 있습니다.')
      ]);
}
