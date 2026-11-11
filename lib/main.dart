import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'gemini_service.dart';
import 'summary_loading.dart';
import 'github_service.dart';
import 'prompt_studio.dart';
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
  static Future<Database> open() async =>
      openDatabase(p.join(await getDatabasesPath(), 'curation.db'), version: 1,
          onCreate: (db, _) async {
        await db.execute(
            'CREATE TABLE cached_repos(repo_name TEXT PRIMARY KEY, repo_url TEXT NOT NULL, star_count INTEGER NOT NULL, original_description TEXT, topic_category TEXT NOT NULL, use_case_summary TEXT, target_audience TEXT, execution_snippet TEXT, updated_at INTEGER NOT NULL)');
        await db.execute(
            'CREATE TABLE saved_prompts(id TEXT PRIMARY KEY, title TEXT NOT NULL, content TEXT NOT NULL, category TEXT NOT NULL, created_at INTEGER NOT NULL)');
      });
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
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI 모아',
      theme: appTheme(),
      home: const Home());
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int page = 0;
  int category = 0;
  bool busy = false;
  String message = '';
  List<Map<String, dynamic>> repos = [];
  List<Map<String, dynamic>> saved = [];
  Map<String, dynamic>? recipe;
  String recipeTitle = '';
  bool recipeIsSample = false;
  bool recipeSaved = false;
  final gemini = GeminiService();
  String keyStatus = '키를 등록하면 사용할 수 있는 모델을 자동으로 찾습니다.';
  final keyInput = TextEditingController();
  final task = TextEditingController();
  final categories = ['All', 'MCP / Agent', 'Coding Rules', 'Prompts'];
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

  Future<void> load() => run(() async {
        final db = await Store.open();
        for (int i = 0; i < 3; i++) {
          final cached = await db.query('cached_repos',
              where: 'topic_category = ?', whereArgs: [categories[i + 1]]);
          if (cached.isNotEmpty &&
              cached.every((r) =>
                  DateTime.now().millisecondsSinceEpoch -
                      (r['updated_at'] as int) <
                  43200000)) continue;
          try {
            final items = await fetchTrending(i);
            await db.transaction((txn) async {
              for (final item in items) {
                final old = await txn.query('cached_repos',
                    where: 'repo_name = ?', whereArgs: [item['full_name']]);
                await txn.insert(
                    'cached_repos',
                    {
                      ...(old.isEmpty ? <String, Object?>{} : old.first),
                      'repo_name': item['full_name'],
                      'repo_url': item['html_url'],
                      'star_count': item['stargazers_count'],
                      'original_description': item['description'] ?? '',
                      'topic_category': categories[i + 1],
                      'updated_at': DateTime.now().millisecondsSinceEpoch
                    },
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
            });
          } catch (error) {
            if (mounted)
              setState(() {
                message = friendlyError(error);
              });
          }
        }
        final rows = await db.query('cached_repos', orderBy: 'star_count DESC');
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
            await db.update('cached_repos', output,
                where: 'repo_name = ?', whereArgs: [repo['repo_name']]);
            return {...repo, ...output};
          });
          repos = repos
              .map((r) => r['repo_name'] == repo['repo_name'] ? result : r)
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
        Wrap(
            children: List.generate(
                4,
                (i) => Padding(
                    padding: const EdgeInsets.all(4),
                    child: ChoiceChip(
                        label: Text(categories[i]),
                        selected: category == i,
                        onSelected: (_) => setState(() => category = i))))),
        TextButton(onPressed: busy ? null : load, child: const Text('새로고침')),
        Expanded(
            child: ListView(children: [
          if (repos.isEmpty)
            const ListTile(
                title: Text('저장된 저장소가 없습니다'),
                subtitle:
                    Text('새로고침으로 GitHub 자료를 가져오세요. Gemini 키는 필요하지 않습니다.')),
          for (final repo in repos.where((r) =>
              category == 0 || r['topic_category'] == categories[category]))
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
  Widget generator() => PromptStudio(
        controller: task,
        busy: busy,
        recipe: recipe,
        recipeTitle: recipeTitle,
        isSample: recipeIsSample,
        recipeSaved: recipeSaved,
        saved: saved,
        onGenerate: (request) => run(() async {
          final key = await Store.secure.read(key: 'gemini');
          if (key == null) {
            if (mounted) setState(() => message = '설정에서 Gemini 키를 등록하세요.');
            return;
          }
          final result = await gemini.generate(key, request);
          if (mounted)
            setState(() {
              recipe = result;
              recipeTitle = request;
              recipeIsSample = false;
              recipeSaved = false;
            });
        }),
        onSample: () => setState(() {
          recipe = {
            'use_case_summary':
                '화면을 작은 위젯으로 나누고, 로딩·빈 목록·오류 상태를 먼저 설계하세요. 주의: 사용자 입력과 API 키를 코드에 직접 넣지 마세요.',
            'target_audience': 'Flutter 앱을 처음 설계하거나 화면 구조를 개선하려는 개발자',
            'execution_snippet':
                '당신은 Flutter UI 개발자입니다.\n\n목표: 접근성이 좋은 모바일 회원가입 화면을 설계해 주세요.\n\n요구 사항:\n1. 입력 필드, 검증, 제출 버튼을 작은 위젯으로 분리합니다.\n2. 로딩·성공·오류 상태와 안내 문구를 포함합니다.\n3. 큰 글씨와 좁은 화면에서도 읽기 쉽게 구성합니다.\n\n출력: 화면 구조 → 구현 순서 → 위젯 코드 → 점검 목록 순서로 작성해 주세요.',
          };
          recipeTitle = 'Flutter 회원가입 화면 설계';
          recipeIsSample = true;
          recipeSaved = false;
        }),
        onSave: () => run(() async {
          if (recipe == null || recipeSaved) return;
          final savingRecipe = recipe!;
          final savingTitle = recipeTitle;
          final savingSample = recipeIsSample;
          final db = await Store.open();
          final now = DateTime.now().millisecondsSinceEpoch;
          await db.insert('saved_prompts', {
            'id': '$now',
            'title': savingTitle,
            'content': savingRecipe['execution_snippet'],
            'category': savingSample ? 'sample' : 'custom',
            'created_at': now,
          });
          final rows =
              await db.query('saved_prompts', orderBy: 'created_at DESC');
          if (mounted) {
            setState(() {
              saved = rows;
              if (identical(recipe, savingRecipe)) recipeSaved = true;
            });
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('프롬프트를 저장했어요')));
          }
        }),
      );
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
