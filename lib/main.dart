import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'database.dart';
import 'asset_loader.dart';
import 'analysis/results/dm_database.dart';
import 'analysis/dm_notation_validator.dart';
import 'providers/app_state_provider.dart';
import 'router/app_router.dart';
import 'widgets/realtime_editor_view.dart';

// アプリ全体のログレベル制御
const bool kVerboseLogging = false; // falseで最小ログモード

void main() {
  runApp(const ProviderScope(child: DMNotationApp()));
}

class DMNotationApp extends ConsumerWidget {
  const DMNotationApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'DM2SQL - 動的DAO生成デモ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// ホーム画面（メイン画面）
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(viewModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DM2SQL - 動的DAO生成デモ',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              '独自のデータモデル表記からDAOとデータベース定義を自動生成・自動初期化します。',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
        toolbarHeight: 80,
        actions: [
          // 表示モード切り替えトグル
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: Center(
              child: ToggleSwitch(
                minWidth: 100.0,
                minHeight: 40.0,
                cornerRadius: 8.0,
                activeBgColors: [
                  [Theme.of(context).colorScheme.primary],
                  [Theme.of(context).colorScheme.secondary],
                ],
                activeFgColor: Colors.white,
                inactiveBgColor: Colors.grey[300],
                inactiveFgColor: Colors.grey[700],
                initialLabelIndex: ViewMode.values.indexOf(viewMode),
                totalSwitches: ViewMode.values.length,
                labels: const ['サンプル\nモデル', 'リアルタイム\nエディタ'],
                fontSize: 12.0,
                radiusStyle: false,
                multiLineText: true,
                centerText: true,
                onToggle: (index) {
                  if (index != null) {
                    ref.read(viewModeProvider.notifier).state =
                        ViewMode.values[index];
                  }
                },
              ),
            ),
          ),
        ],
      ),
      body: viewMode == ViewMode.sampleModels
          ? const SampleModelsView()
          : const RealtimeEditorView(),
    );
  }
}

/// サンプルモデル表示ビュー
class SampleModelsView extends ConsumerStatefulWidget {
  const SampleModelsView({super.key});

  @override
  ConsumerState<SampleModelsView> createState() => _SampleModelsViewState();
}

class _SampleModelsViewState extends ConsumerState<SampleModelsView> {
  Map<String, SchemaInfo> schemaInfos = {};
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadSchemaInfos();
  }

  Future<void> _loadSchemaInfos() async {
    try {
      final infos = await DMNotationAssetLoader.getSchemaInfos();
      setState(() {
        schemaInfos = infos;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'スキーマ情報の読み込みに失敗しました: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              error!,
              style: const TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSchemaInfos,
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'サンプルデータモデルを選択してください',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'DMNotation記法からSQLiteテーブルを動的生成し、サンプルデータを挿入します。',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: schemaInfos.length,
              itemBuilder: (context, index) {
                final entry = schemaInfos.entries.elementAt(index);
                final schemaName = entry.key;
                final info = entry.value;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getSchemaColor(schemaName),
                      child: Icon(
                        _getSchemaIcon(schemaName),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      schemaName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(info.description),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.table_chart,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text('${info.tableCount}テーブル'),
                            const SizedBox(width: 16),
                            Icon(Icons.link, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text('${info.relationshipCount}関係'),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    isThreeLine: true,
                    onTap: () {
                      if (kDebugMode) {
                        print('=== スキーマカードがクリックされました ===');
                        print('スキーマ名: $schemaName');
                        print('遷移先: /viewer/$schemaName');
                      }
                      context.go('/viewer/$schemaName');
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getSchemaColor(String schemaName) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[schemaName.hashCode % colors.length];
  }

  IconData _getSchemaIcon(String schemaName) {
    switch (schemaName) {
      case 'ECサイト':
        return Icons.shopping_cart;
      case '在庫管理':
        return Icons.inventory;
      case '社員管理':
        return Icons.people;
      case '備品予約':
        return Icons.event_available;
      case 'ブログ':
        return Icons.article;
      default:
        return Icons.table_chart;
    }
  }
}

/// データビューアー画面
class DataViewerPage extends StatefulWidget {
  final String schemaName;

  const DataViewerPage({super.key, required this.schemaName});

  @override
  State<DataViewerPage> createState() => _DataViewerPageState();
}

class _DataViewerPageState extends State<DataViewerPage> {
  MinimalDatabase? database;
  DMDatabase? schema;
  bool isLoading = true;
  String? error;
  List<String> tableNames = [];
  String? selectedTable;
  List<Map<String, dynamic>> tableData = [];
  int? _hoveredIndex;
  DMValidationResult? validationResult;
  String? dmNotationContent;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('=== DataViewerPage初期化開始 ===');
      print('スキーマ名: ${widget.schemaName}');
    }
    _loadAndInitializeDatabase();
  }

  Future<void> _loadAndInitializeDatabase() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // DMNotationファイルを読み込み
      if (widget.schemaName == 'リアルタイムエディター') {
        // リアルタイムエディターからの場合、現在のテキストを使用
        // この実装では、暫定的にシンプルテストスキーマを使用
        dmNotationContent = await DMNotationAssetLoader.loadSchemaText(
          'シンプルテスト',
        );
      } else {
        dmNotationContent = await DMNotationAssetLoader.loadSchemaText(
          widget.schemaName,
        );
      }

      // バリデーション実行
      validationResult = DMNotationValidator.validate(
        dmNotationContent!,
        level: ValidationLevel.strict,
        includeBestPracticeChecks: true,
      );

      // データベーススキーマを解析・生成
      schema = await DMNotationAssetLoader.loadAndParseSchema(
        widget.schemaName == 'リアルタイムエディター' ? 'シンプルテスト' : widget.schemaName,
      );

      // データベースを初期化
      database = MinimalDatabase();

      // テーブル名一覧を取得
      tableNames = schema!.tables.map((table) => table.sqlName).toList();

      // テーブル作成とサンプルデータ挿入を実行
      await database!.setupFromDMDatabase(schema!);

      setState(() {
        isLoading = false;
      });

      // 最初のテーブルを自動選択
      if (tableNames.isNotEmpty) {
        _selectTable(tableNames.first);
      }
    } catch (e) {
      setState(() {
        error = 'データベース初期化に失敗しました: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _selectTable(String tableName) async {
    try {
      // SQLiteの予約語対策としてテーブル名をバッククォートで囲む
      final data = await database!.rawQuery('SELECT * FROM `$tableName`');
      setState(() {
        selectedTable = tableName;
        tableData = data;
      });
    } catch (e) {
      setState(() {
        error = 'テーブルデータの読み込みに失敗しました: $e';
      });
    }
  }

  Color _getValidationColor() {
    if (validationResult == null) return Colors.grey;
    return validationResult!.isValid ? Colors.green : Colors.red;
  }

  IconData _getValidationIcon() {
    if (validationResult == null) return Icons.help;
    return validationResult!.isValid ? Icons.check_circle : Icons.error;
  }

  String _getValidationTooltip() {
    if (validationResult == null) return 'バリデーション未実行';
    return validationResult!.isValid ? 'バリデーション成功' : 'バリデーション失敗';
  }

  void _showValidationDialog() {
    if (validationResult == null || dmNotationContent == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(validationResult!.isValid ? 'バリデーション成功' : 'バリデーション結果'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ValidationResultView(
            validationResult: validationResult!,
            dmNotationContent: dmNotationContent!,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.schemaName} - データビューアー'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
          tooltip: 'ホームに戻る',
        ),
        actions: [
          IconButton(
            icon: Icon(_getValidationIcon(), color: _getValidationColor()),
            onPressed: _showValidationDialog,
            tooltip: _getValidationTooltip(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAndInitializeDatabase,
            tooltip: 'データを再読み込み',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAndInitializeDatabase,
                    child: const Text('再試行'),
                  ),
                ],
              ),
            )
          : Row(
              children: [
                // 左側：テーブル一覧
                Container(
                  width: 250,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.table_chart,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'テーブル一覧',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: tableNames.length,
                          itemBuilder: (context, index) {
                            final tableName = tableNames[index];
                            final isSelected = tableName == selectedTable;

                            return Container(
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : null,
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.table_rows,
                                  color: isSelected
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer
                                      : null,
                                ),
                                title: Text(
                                  tableName,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer
                                        : null,
                                  ),
                                ),
                                onTap: () => _selectTable(tableName),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // 右側：テーブルデータ
                Expanded(
                  child: selectedTable == null
                      ? const Center(
                          child: Text(
                            'テーブルを選択してください',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        )
                      : _buildTableView(),
                ),
              ],
            ),
    );
  }

  Widget _buildTableView() {
    if (tableData.isEmpty) {
      return const Center(
        child: Text(
          'データがありません',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    final columns = tableData.first.keys.toList();

    return Column(
      children: [
        // ヘッダー
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.table_rows,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '$selectedTable (${tableData.length}件)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  // 今後のCRUD機能実装予定地
                },
                icon: const Icon(Icons.add),
                label: const Text('追加'),
              ),
            ],
          ),
        ),

        // データテーブル
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                columns: columns
                    .map(
                      (column) => DataColumn(
                        label: Text(
                          column,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                    .toList(),
                rows: tableData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;

                  return DataRow(
                    color: WidgetStateProperty.resolveWith((states) {
                      if (_hoveredIndex == index) {
                        return Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1);
                      }
                      return null;
                    }),
                    cells: columns
                        .map(
                          (column) =>
                              DataCell(Text(row[column]?.toString() ?? '')),
                        )
                        .toList(),
                    onSelectChanged: (_) {
                      setState(() {
                        _hoveredIndex = _hoveredIndex == index ? null : index;
                      });
                    },
                  );
                }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// バリデーション結果表示ウィジェット
class ValidationResultView extends StatelessWidget {
  final DMValidationResult validationResult;
  final String dmNotationContent;

  const ValidationResultView({
    super.key,
    required this.validationResult,
    required this.dmNotationContent,
  });

  @override
  Widget build(BuildContext context) {
    final lines = dmNotationContent.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 概要
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                validationResult.isValid ? Icons.check_circle : Icons.error,
                color: validationResult.isValid ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      validationResult.isValid ? 'バリデーション成功' : 'バリデーション失敗',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: validationResult.isValid
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'エラー: ${validationResult.errors.length}件, 警告: ${validationResult.warnings.length}件',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // エラー・警告一覧
        Expanded(
          child: ListView(
            children: [
              if (validationResult.errors.isNotEmpty) ...[
                Text(
                  '🚫 エラー (${validationResult.errors.length}件)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...validationResult.errors.map(
                  (error) => _buildIssueCard(context, error, true, lines),
                ),
                const SizedBox(height: 16),
              ],

              if (validationResult.warnings.isNotEmpty) ...[
                Text(
                  '⚠️ 警告 (${validationResult.warnings.length}件)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...validationResult.warnings.map(
                  (warning) => _buildWarningCard(context, warning, lines),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIssueCard(
    BuildContext context,
    DMValidationIssue issue,
    bool isError,
    List<String> lines,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isError
          ? Colors.red.withValues(alpha: 0.05)
          : Colors.orange.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isError ? Icons.error : Icons.warning,
                  size: 16,
                  color: isError ? Colors.red : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  '行 ${issue.line}${issue.column > 0 ? ':${issue.column}' : ''}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '[${issue.category.name}]',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(issue.message, style: Theme.of(context).textTheme.bodyMedium),
            if (issue.suggestion != null) ...[
              const SizedBox(height: 4),
              Text(
                '💡 ${issue.suggestion}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (issue.line > 0 && issue.line <= lines.length) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${issue.line}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        lines[issue.line - 1],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard(
    BuildContext context,
    DMValidationWarning warning,
    List<String> lines,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.orange.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  '行 ${warning.line}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '[${warning.category}]',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              warning.message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (warning.suggestion != null) ...[
              const SizedBox(height: 4),
              Text(
                '💡 ${warning.suggestion}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (warning.line > 0 && warning.line <= lines.length) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${warning.line}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        lines[warning.line - 1],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
