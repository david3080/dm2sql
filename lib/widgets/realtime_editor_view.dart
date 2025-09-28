/// リアルタイムエディタービュー
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../analysis/dm_notation_validator.dart';
import '../analysis/dm_notation_analyzer.dart';
import '../analysis/results/dm_database.dart';
import '../analysis/results/dm_table.dart';
import '../analysis/results/dm_column.dart';
import '../asset_loader.dart';
import '../providers/app_state_provider.dart';
import '../main.dart';

/// リアルタイムエディタービューウィジェット
class RealtimeEditorView extends ConsumerStatefulWidget {
  const RealtimeEditorView({super.key});

  @override
  ConsumerState<RealtimeEditorView> createState() => _RealtimeEditorViewState();
}

class _RealtimeEditorViewState extends ConsumerState<RealtimeEditorView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  DMValidationResult? _validationResult;
  DMDatabase? _parsedSchema;
  String? _error;
  bool _isProcessing = false;
  List<String> _availableSchemas = [];
  String? _selectedSchemaName;
  double _splitterPosition = 0.5; // エディタとプレビューの分割位置（0.0-1.0）

  @override
  void initState() {
    super.initState();
    _loadAvailableSchemas();
    _loadDefaultSchema();

    // テキスト変更時のリアルタイム処理
    _textController.addListener(() {
      _processText(_textController.text);
    });
  }

  Future<void> _loadDefaultSchema() async {
    // デフォルトでシンプルテストスキーマを読み込み
    try {
      await _loadSchemaContent('シンプルテスト');
    } catch (e) {
      // フォールバック用のシンプルなデフォルトテキスト
      setState(() {
        _textController.text = '''[User] ユーザー
UserID*: ID
UserName: NVARCHAR(50) = ユーザー名
''';
        _selectedSchemaName = null; // エラー時は選択状態をクリア
      });
      _processText(_textController.text);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableSchemas() async {
    final schemas = DMNotationAssetLoader.getAvailableSchemas();
    setState(() {
      _availableSchemas = schemas;
    });
  }

  Future<void> _loadSchemaContent(String schemaName) async {
    try {
      final content = await DMNotationAssetLoader.loadSchemaText(schemaName);
      if (!mounted) return;

      setState(() {
        _textController.text = content;
        _selectedSchemaName = schemaName;
      });

      // Riverpodの状態も更新
      ref.read(realtimeEditorStateProvider.notifier).state =
          ref.read(realtimeEditorStateProvider).copyWith(
            dmNotationContent: content,
            selectedSchemaName: schemaName,
          );

      _processText(content);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('モデルの読み込みに失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _processText(String text) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      // バリデーション実行
      final validationResult = DMNotationValidator.validate(
        text,
        level: ValidationLevel.strict,
        includeBestPracticeChecks: true,
      );

      // スキーマ解析実行
      DMDatabase? parsedSchema;
      if (validationResult.isValid) {
        try {
          final analysisResult = DMNotationAnalyzer.analyze(text, databaseName: 'リアルタイムエディター');
          if (analysisResult.isSuccess) {
            parsedSchema = analysisResult.database;
          }
        } catch (e) {
          // パース失敗は無視（バリデーションエラーで表示される）
        }
      }

      setState(() {
        _validationResult = validationResult;
        _parsedSchema = parsedSchema;
        _isProcessing = false;
      });

      // Riverpodの状態も更新
      ref.read(realtimeEditorStateProvider.notifier).state =
          ref.read(realtimeEditorStateProvider).copyWith(
            dmNotationContent: text,
            isProcessing: false,
          );
    } catch (e) {
      setState(() {
        _error = 'エラーが発生しました: $e';
        _validationResult = null;
        _parsedSchema = null;
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final editorHeight = constraints.maxHeight * _splitterPosition;
        final previewHeight = constraints.maxHeight * (1 - _splitterPosition);

        return Column(
          children: [
            // 上部：エディター
            SizedBox(
              height: editorHeight,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'リアルタイムエディタ',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // バリデーション状態アイコン
                        if (_validationResult != null)
                          IconButton(
                            icon: Icon(
                              _validationResult!.isValid ? Icons.check_circle : Icons.error,
                              color: _validationResult!.isValid ? Colors.green : Colors.red,
                            ),
                            onPressed: () => _showValidationDialog(context),
                            tooltip: _validationResult!.isValid ? 'バリデーション成功' : 'バリデーション失敗',
                          ),
                        // データビューアーで開くボタン
                        if (_parsedSchema != null)
                          IconButton(
                            icon: const Icon(Icons.visibility),
                            onPressed: () => context.go('/viewer/リアルタイムエディター'),
                            tooltip: 'データビューアーで開く',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // サンプルモデル選択ドロップダウン
                    Row(
                      children: [
                        Text(
                          'サンプルから選択:',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text('モデルを選択'),
                            value: _selectedSchemaName,
                            items: _availableSchemas.map((schema) {
                              return DropdownMenuItem(
                                value: schema,
                                child: Text(schema),
                              );
                            }).toList(),
                            onChanged: (schemaName) {
                              if (schemaName != null) {
                                _loadSchemaContent(schemaName);
                              }
                            },
                          ),
                        ),
                        const Spacer(flex: 2),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).colorScheme.outline),
                          borderRadius: BorderRadius.circular(4),
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        child: Scrollbar(
                          controller: _horizontalScrollController,
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            child: Scrollbar(
                              controller: _verticalScrollController,
                              child: SingleChildScrollView(
                                controller: _verticalScrollController,
                                scrollDirection: Axis.vertical,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: MediaQuery.of(context).size.width - 32, // パディング分を引く
                                  ),
                                  child: IntrinsicWidth(
                                    child: TextField(
                                      controller: _textController,
                                      maxLines: null,
                                      minLines: 20,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 14,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'DMNotation記法でスキーマを入力...',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(16),
                                        filled: false,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // スプリッター（リサイズ可能な仕切り線）
            GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  final newPosition = _splitterPosition + (details.delta.dy / constraints.maxHeight);
                  _splitterPosition = newPosition.clamp(0.3, 0.7); // 30%-70%の範囲で制限（より制限的に）
                });
              },
              child: Container(
                height: 8,
                width: double.infinity,
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                child: Center(
                  child: Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),

            // 下部：プレビュー
            Container(
              height: (previewHeight - 8).clamp(100.0, double.infinity), // 最小高さ100pxを確保
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'プレビュー',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_isProcessing)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ClipRect(
                        child: _buildPreviewContent(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewContent() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_validationResult == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_validationResult!.isValid) {
      // バリデーションエラーがある場合
      return ValidationResultView(
        validationResult: _validationResult!,
        dmNotationContent: _textController.text,
      );
    }

    if (_parsedSchema == null) {
      return const Center(
        child: Text('モデルを解析中...'),
      );
    }

    // 成功時：モデルプレビューを表示
    return _buildSchemaPreview();
  }

  Widget _buildSchemaPreview() {
    final schema = _parsedSchema!;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 利用可能な高さが十分でない場合はスクロール可能なビューを使用
        if (constraints.maxHeight < 150) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // バリデーション成功メッセージ（コンパクト版）
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${schema.tables.length}個のテーブル',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // テーブル一覧（縦リスト）
                ...schema.tables.map((table) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: _buildCompactTableCard(table),
                )),
              ],
            ),
          );
        }

        // 通常サイズの場合
        return Column(
          children: [
            // バリデーション成功メッセージ
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'バリデーション成功 - ${schema.tables.length}個のテーブルが検出されました',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // テーブル一覧をGridViewで表示
            Expanded(
              child: LayoutBuilder(
                builder: (context, gridConstraints) {
                  // 画面幅に応じて列数を動的に決定（従来の倍の列数）
                  final screenWidth = gridConstraints.maxWidth;
                  int crossAxisCount = 2; // 最小2列
                  if (screenWidth > 1200) {
                    crossAxisCount = 6; // 1200px以上で6列
                  } else if (screenWidth > 800) {
                    crossAxisCount = 4; // 800px以上で4列
                  }

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 1.8, // 縦サイズを小さく（1.2 → 1.8）
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: schema.tables.length,
                    itemBuilder: (context, index) {
                      return _buildCompactGridTableCard(schema.tables[index]);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactTableCard(DMTable table) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(
              Icons.table_chart,
              color: Theme.of(context).colorScheme.primary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                table.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${table.columns.length}列',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactGridTableCard(DMTable table) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // テーブル名とアイコン
            Row(
              children: [
                Icon(
                  Icons.table_chart,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20, // 28 → 20
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    table.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20, // 22 → 20
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${table.columns.length}列',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 18, // 9 → 18（倍）
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // カラム一覧（スクロール可能）
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: table.columns.take(10).map((column) => Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Row(
                      children: [
                        Icon(
                          (table.primaryKey.columnName == column.sqlName)
                              ? Icons.key
                              : column.isRequired
                                  ? Icons.circle
                                  : Icons.circle_outlined,
                          size: 16, // 8 → 16（倍）
                          color: (table.primaryKey.columnName == column.sqlName)
                              ? Colors.amber
                              : column.isRequired
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            column.displayName,
                            style: const TextStyle(fontSize: 16), // 18 → 16
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ),

            // 追加カラムがある場合の表示
            if (table.columns.length > 10)
              Text(
                '他 ${table.columns.length - 10}列...',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 16, // 8 → 16（倍）
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard(DMTable table) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.table_chart,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  table.displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (table.comment?.isNotEmpty == true) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '(${table.comment})',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // カラム一覧
            ...table.columns.map((column) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                children: [
                  Icon(
                    (table.primaryKey.columnName == column.sqlName)
                        ? Icons.key
                        : column.isRequired
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                    size: 16,
                    color: (table.primaryKey.columnName == column.sqlName)
                        ? Colors.amber
                        : column.isRequired
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: column.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          TextSpan(
                            text: ': ${column.type.name}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          if (column.comment?.isNotEmpty == true)
                            TextSpan(
                              text: ' - ${column.comment}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showValidationDialog(BuildContext context) {
    if (_validationResult == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_validationResult!.isValid ? 'バリデーション成功' : 'バリデーション結果'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ValidationResultView(
            validationResult: _validationResult!,
            dmNotationContent: _textController.text,
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
}