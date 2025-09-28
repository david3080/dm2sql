import 'dart:math';
import 'package:flutter/material.dart';
import 'database.dart';
import 'asset_loader.dart';
import 'runtime/dynamic_dao.dart';
import 'analysis/results/dm_database.dart';
import 'analysis/results/dm_table.dart';
import 'analysis/results/dm_column.dart';

void main() {
  runApp(const DMNotationApp());
}

class DMNotationApp extends StatelessWidget {
  const DMNotationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DM2SQL - 動的スキーマ生成デモ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SchemaSelectionPage(),
    );
  }
}

class SchemaSelectionPage extends StatefulWidget {
  const SchemaSelectionPage({super.key});

  @override
  State<SchemaSelectionPage> createState() => _SchemaSelectionPageState();
}

class _SchemaSelectionPageState extends State<SchemaSelectionPage> {
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
      setState(() {
        isLoading = true;
        error = null;
      });

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('DM2SQL - スキーマ選択'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                        onPressed: _loadSchemaInfos,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'テスト用データモデルを選択してください',
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
                                        Icon(Icons.table_chart, size: 16, color: Colors.grey[600]),
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
                                onTap: () => _navigateToDataViewer(schemaName),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadSchemaInfos,
        tooltip: 'スキーマ情報を再読み込み',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Color _getSchemaColor(String schemaName) {
    const colors = {
      'ECサイト': Colors.orange,
      '在庫管理': Colors.green,
      '社員管理': Colors.blue,
      '備品予約': Colors.purple,
      'ブログ': Colors.teal,
    };
    return colors[schemaName] ?? Colors.grey;
  }

  IconData _getSchemaIcon(String schemaName) {
    const icons = {
      'ECサイト': Icons.shopping_cart,
      '在庫管理': Icons.inventory_2,
      '社員管理': Icons.people,
      '備品予約': Icons.event_available,
      'ブログ': Icons.article,
    };
    return icons[schemaName] ?? Icons.schema;
  }

  void _navigateToDataViewer(String schemaName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DataViewerPage(schemaName: schemaName),
      ),
    );
  }
}

class DataViewerPage extends StatefulWidget {
  final String schemaName;

  const DataViewerPage({super.key, required this.schemaName});

  @override
  State<DataViewerPage> createState() => _DataViewerPageState();
}

class _DataViewerPageState extends State<DataViewerPage> {
  late MinimalDatabase database;
  late DynamicDAO dao;
  Map<String, List<Map<String, dynamic>>> tablesData = {};
  bool isLoading = true;
  String? error;
  DMDatabase? schema;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // データベース初期化
      database = MinimalDatabase();

      // スキーマ読み込み・パース
      schema = await DMNotationAssetLoader.loadAndParseSchema(widget.schemaName);

      // DAO初期化
      dao = DynamicDAO(database, schema!);

      // 既存テーブルをクリア
      await dao.tables.dropAllTables();

      // テーブル作成
      await dao.tables.createTables();

      // サンプルデータ挿入
      await _insertSampleData();

      // データ読み込み
      await _loadTablesData();

    } catch (e) {
      print('データベースの初期化エラー: $e');
      setState(() {
        error = 'データベースの初期化に失敗しました: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _loadTablesData() async {
    try {
      final data = <String, List<Map<String, dynamic>>>{};

      // 各テーブルのデータを読み込み
      for (final table in schema!.tables) {
        final tableData = await dao.select(table.sqlName).get();
        data[table.sqlName] = tableData;
      }

      setState(() {
        tablesData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'データの読み込みに失敗しました: $e';
        isLoading = false;
      });
    }
  }

  /// サンプルデータ挿入
  Future<void> _insertSampleData() async {
    for (final table in schema!.tablesInDependencyOrder) {
      final sampleCount = _getSampleCount(table.sqlName);

      for (int i = 1; i <= sampleCount; i++) {
        final data = _generateSampleRecord(table, i);
        await dao.into(table.sqlName).insert(data);
      }
    }
  }

  /// テーブルごとのサンプルデータ件数を決定
  int _getSampleCount(String tableName) {
    const counts = {
      'customer': 5, 'user': 5, 'employee': 8,
      'product': 10, 'equipment': 6,
      'category': 4, 'department': 3, 'position': 4,
      'order': 8, 'post': 12, 'reservation': 6,
      'comment': 15, 'review': 8,
    };

    for (final key in counts.keys) {
      if (tableName.contains(key)) {
        return counts[key]!;
      }
    }

    return 3; // デフォルト
  }

  /// サンプルレコード生成
  Map<String, dynamic> _generateSampleRecord(DMTable table, int index) {
    final record = <String, dynamic>{};
    final random = Random();

    // 通常カラムの値を生成
    for (final column in table.allColumns) {
      // 主キーはスキップ（AUTOINCREMENT）
      if (column.sqlName == table.primaryKey.columnName) continue;

      // 外部キーの処理
      bool isForeignKey = false;
      for (final fk in table.foreignKeys) {
        if (column.sqlName == fk.columnName) {
          // 簡易的な外部キー値生成（1-3の範囲）
          record[column.sqlName] = random.nextInt(3) + 1;
          isForeignKey = true;
          break;
        }
      }

      if (!isForeignKey) {
        record[column.sqlName] = _generateSampleValue(column, table.sqlName, index, random);
      }
    }

    return record;
  }

  /// カラムのサンプル値生成
  dynamic _generateSampleValue(DMColumn column, String tableName, int index, Random random) {
    final columnName = column.sqlName;

    // 特定のカラム名に基づく値生成
    if (columnName.contains('name')) {
      return _generateName(tableName, index);
    } else if (columnName.contains('email')) {
      return 'user$index@example.com';
    } else if (columnName.contains('phone')) {
      return '090-${random.nextInt(9000) + 1000}-${random.nextInt(9000) + 1000}';
    } else if (columnName.contains('address')) {
      return '東京都渋谷区$index-$index-$index';
    } else if (columnName.contains('title')) {
      return 'サンプルタイトル $index';
    } else if (columnName.contains('content') || columnName.contains('description')) {
      return 'これはサンプルの内容です。テスト用のデータとして作成されました。($index)';
    } else if (columnName.contains('password')) {
      return 'password$index';
    } else if (columnName.contains('status')) {
      return ['active', 'inactive', 'pending'].elementAt(random.nextInt(3));
    }

    // データ型に基づく値生成
    switch (column.type) {
      case DMDataType.integer:
        if (columnName.contains('price') || columnName.contains('amount') || columnName.contains('cost')) {
          return random.nextInt(50000) + 1000;
        } else if (columnName.contains('count') || columnName.contains('quantity')) {
          return random.nextInt(100) + 1;
        } else {
          return random.nextInt(1000) + 1;
        }

      case DMDataType.text:
        return 'sample_${columnName}_$index';

      case DMDataType.real:
        return (random.nextDouble() * 1000).roundToDouble();

      case DMDataType.datetime:
        final now = DateTime.now();
        final offset = random.nextInt(365 * 24 * 60 * 60); // 1年以内
        return now.subtract(Duration(seconds: offset)).millisecondsSinceEpoch ~/ 1000;

      case DMDataType.boolean:
        return random.nextBool() ? 1 : 0;
    }
  }

  /// 名前の生成
  String _generateName(String tableName, int index) {
    if (tableName.contains('customer') || tableName.contains('user')) {
      const names = ['田中太郎', '佐藤花子', '鈴木次郎', '高橋美咲', '伊藤健太'];
      return names[index % names.length];
    } else if (tableName.contains('product')) {
      const products = ['高性能ノートPC', 'ワイヤレスマウス', 'メカニカルキーボード', '4Kモニター', 'Webカメラ'];
      return products[index % products.length];
    } else if (tableName.contains('category')) {
      const categories = ['電子機器', '事務用品', '家具', '消耗品'];
      return categories[index % categories.length];
    } else {
      return '${tableName}_アイテム_$index';
    }
  }

  @override
  void dispose() {
    database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.schemaName} - データビューア'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showAdvancedDemoDialog,
            tooltip: '高度な機能デモ',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTablesData,
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          error!,
                          style: const TextStyle(fontSize: 16, color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initializeAndLoadData,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : tablesData.isEmpty
                  ? const Center(child: Text('テーブルデータがありません'))
                  : DefaultTabController(
                      length: tablesData.length,
                      child: Column(
                        children: [
                          TabBar(
                            isScrollable: true,
                            tabs: tablesData.keys
                                .map((tableName) => Tab(text: tableName))
                                .toList(),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: tablesData.entries
                                  .map((entry) => _buildTableView(entry.key, entry.value))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildTableView(String tableName, List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_chart, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '$tableName テーブルにデータがありません',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final record = data[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(
              '$tableName #${record['id'] ?? index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _getRecordSummary(record),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: record.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _formatValue(entry.value),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getRecordSummary(Map<String, dynamic> record) {
    // nameカラムがあればそれを使用
    if (record.containsKey('name')) {
      return record['name']?.toString() ?? '';
    }

    // titleカラムがあればそれを使用
    if (record.containsKey('title')) {
      return record['title']?.toString() ?? '';
    }

    // 最初のstring型のカラムを使用
    for (final entry in record.entries) {
      if (entry.key != 'id' && entry.value is String && entry.value.toString().isNotEmpty) {
        return entry.value.toString();
      }
    }

    return 'ID: ${record['id'] ?? '不明'}';
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'NULL';
    if (value is String && value.isEmpty) return '(空文字)';
    return value.toString();
  }

  /// 高度な機能のデモダイアログ
  void _showAdvancedDemoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('高度な機能デモ'),
        content: const Text('DynamicDAOの高度な機能をデモンストレーションします。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdvancedDemoPage(
                    dao: dao,
                    schema: schema!,
                  ),
                ),
              );
            },
            child: const Text('デモを開始'),
          ),
        ],
      ),
    );
  }
}

/// 高度な機能デモページ
class AdvancedDemoPage extends StatefulWidget {
  final DynamicDAO dao;
  final DMDatabase schema;

  const AdvancedDemoPage({
    super.key,
    required this.dao,
    required this.schema,
  });

  @override
  State<AdvancedDemoPage> createState() => _AdvancedDemoPageState();
}

class _AdvancedDemoPageState extends State<AdvancedDemoPage> {
  final List<DemoResult> _results = [];
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('高度な機能デモ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DynamicDAO 高度機能デモ',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'JOIN操作、トランザクション、型安全操作などの高度な機能をデモンストレーションします。',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _isRunning ? null : _runJoinDemo,
                      child: const Text('JOIN操作デモ'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isRunning ? null : _runTransactionDemo,
                      child: const Text('トランザクションデモ'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isRunning ? null : _runTypeSafetyDemo,
                      child: const Text('型安全性デモ'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _results.isEmpty ? null : _clearResults,
                  child: const Text('結果をクリア'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Text(
                      'デモボタンを押して機能をテストしてください',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          title: Text(
                            result.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(result.description),
                          leading: Icon(
                            result.isSuccess ? Icons.check_circle : Icons.error,
                            color: result.isSuccess ? Colors.green : Colors.red,
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SQL:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      result.sql,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    '結果:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      result.result,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// JOIN操作のデモ
  Future<void> _runJoinDemo() async {
    setState(() => _isRunning = true);

    try {
      // 顧客と注文のJOIN（ECサイトスキーマの場合）
      if (widget.schema.hasTable('customer') && widget.schema.hasTable('order')) {
        const sql = '''
          SELECT
            c.name as customer_name,
            COUNT(o.id) as order_count,
            COALESCE(SUM(o.total_amount), 0) as total_spent
          FROM customer c
          LEFT JOIN `order` o ON c.id = o.customer_id
          GROUP BY c.id, c.name
          ORDER BY total_spent DESC
        ''';

        final result = await widget.dao.customSelect(sql);

        _addResult(DemoResult(
          title: 'JOIN操作: 顧客別注文統計',
          description: '顧客と注文テーブルをJOINして統計を取得',
          sql: sql,
          result: _formatJoinResult(result),
          isSuccess: true,
        ));
      }
      // ブログスキーマの場合
      else if (widget.schema.hasTable('user') && widget.schema.hasTable('post')) {
        const sql = '''
          SELECT
            u.username,
            u.display_name,
            COUNT(p.id) as post_count,
            MAX(p.published_at) as latest_post
          FROM user u
          LEFT JOIN post p ON u.id = p.author_id
          GROUP BY u.id, u.username, u.display_name
          HAVING post_count > 0
          ORDER BY post_count DESC
        ''';

        final result = await widget.dao.customSelect(sql);

        _addResult(DemoResult(
          title: 'JOIN操作: ユーザー別投稿統計',
          description: 'ユーザーと投稿テーブルをJOINして統計を取得',
          sql: sql,
          result: _formatJoinResult(result),
          isSuccess: true,
        ));
      }
      // 在庫管理スキーマの場合
      else if (widget.schema.hasTable('product') && widget.schema.hasTable('stock')) {
        const sql = '''
          SELECT
            p.name as product_name,
            w.name as warehouse_name,
            s.current_qty,
            s.allocated_qty,
            (s.current_qty - s.allocated_qty) as available_qty
          FROM product p
          JOIN stock s ON p.id = s.product_id
          JOIN warehouse w ON s.warehouse_id = w.id
          WHERE s.current_qty > 0
          ORDER BY available_qty DESC
        ''';

        final result = await widget.dao.customSelect(sql);

        _addResult(DemoResult(
          title: 'JOIN操作: 商品在庫状況',
          description: '商品、在庫、倉庫テーブルをJOINして在庫状況を取得',
          sql: sql,
          result: _formatJoinResult(result),
          isSuccess: true,
        ));
      }
    } catch (e) {
      _addResult(DemoResult(
        title: 'JOIN操作',
        description: 'JOIN操作でエラーが発生しました',
        sql: 'N/A',
        result: 'エラー: $e',
        isSuccess: false,
      ));
    } finally {
      setState(() => _isRunning = false);
    }
  }

  /// トランザクションのデモ
  Future<void> _runTransactionDemo() async {
    setState(() => _isRunning = true);

    try {
      final result = await widget.dao.transaction(() async {
        final operations = <String>[];

        // 顧客スキーマの場合
        if (widget.schema.hasTable('customer')) {
          // 新規顧客を追加
          final customerId = await widget.dao.into('customer').insert({
            'name': 'トランザクションテスト顧客',
            'email': 'transaction@test.com',
          });
          operations.add('顧客追加: ID=$customerId');

          // 注文テーブルがある場合は注文も追加
          if (widget.schema.hasTable('order')) {
            final orderId = await widget.dao.into('order').insert({
              'customer_id': customerId,
              'order_datetime': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'total_amount': 5000,
              'status': 'pending',
            });
            operations.add('注文追加: ID=$orderId');
          }
        }
        // ブログスキーマの場合
        else if (widget.schema.hasTable('user')) {
          // 新規ユーザーを追加
          final userId = await widget.dao.into('user').insert({
            'username': 'tx_test_user',
            'display_name': 'トランザクションテストユーザー',
            'email': 'txtest@example.com',
            'password': 'password123',
            'status': 'active',
          });
          operations.add('ユーザー追加: ID=$userId');

          // 投稿も追加
          if (widget.schema.hasTable('post')) {
            final postId = await widget.dao.into('post').insert({
              'author_id': userId,
              'title': 'トランザクションテスト投稿',
              'content': 'これはトランザクションのテスト投稿です。',
              'status': 'published',
              'published_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            });
            operations.add('投稿追加: ID=$postId');
          }
        }

        return operations;
      });

      _addResult(DemoResult(
        title: 'トランザクション操作',
        description: '複数のテーブルへの挿入をトランザクション内で実行',
        sql: 'BEGIN; [複数のINSERT文]; COMMIT;',
        result: '成功した操作:\n${result.join('\n')}',
        isSuccess: true,
      ));
    } catch (e) {
      _addResult(DemoResult(
        title: 'トランザクション操作',
        description: 'トランザクション実行でエラーが発生（ロールバック済み）',
        sql: 'BEGIN; [複数のINSERT文]; ROLLBACK;',
        result: 'エラー: $e',
        isSuccess: false,
      ));
    } finally {
      setState(() => _isRunning = false);
    }
  }

  /// 型安全性のデモ
  Future<void> _runTypeSafetyDemo() async {
    setState(() => _isRunning = true);

    try {
      final testResults = <String>[];

      // 最初のテーブルで型安全性をテスト
      final firstTable = widget.schema.tables.first;
      final builder = widget.dao.select(firstTable.sqlName);

      // 型安全なWHERE句のテスト
      for (final column in firstTable.allColumns) {
        try {
          switch (column.type) {
            case DMDataType.integer:
              builder.whereColumn(column.sqlName, 1);
              testResults.add('✅ ${column.sqlName} (integer): 型チェック成功');
              break;
            case DMDataType.text:
              builder.whereColumn(column.sqlName, 'test');
              testResults.add('✅ ${column.sqlName} (text): 型チェック成功');
              break;
            case DMDataType.boolean:
              builder.whereColumn(column.sqlName, true);
              testResults.add('✅ ${column.sqlName} (boolean): 型チェック成功');
              break;
            case DMDataType.datetime:
              builder.whereColumn(column.sqlName, DateTime.now());
              testResults.add('✅ ${column.sqlName} (datetime): 型チェック成功');
              break;
            case DMDataType.real:
              builder.whereColumn(column.sqlName, 1.5);
              testResults.add('✅ ${column.sqlName} (real): 型チェック成功');
              break;
          }
        } catch (e) {
          testResults.add('❌ ${column.sqlName}: エラー - $e');
        }
      }

      // 型エラーのテスト
      try {
        final intColumn = firstTable.allColumns.firstWhere(
          (col) => col.type == DMDataType.integer,
          orElse: () => firstTable.allColumns.first,
        );
        builder.whereColumn(intColumn.sqlName, 'invalid_type');
        testResults.add('❌ 型エラーテスト: 例外が発生すべきでしたが成功してしまいました');
      } catch (e) {
        testResults.add('✅ 型エラーテスト: 正しく例外が発生しました - ${e.toString().substring(0, 50)}...');
      }

      _addResult(DemoResult(
        title: '型安全性テスト',
        description: 'DynamicDAOの実行時型チェック機能をテスト',
        sql: 'SELECT * FROM ${firstTable.sqlName} WHERE [various type conditions]',
        result: testResults.join('\n'),
        isSuccess: true,
      ));
    } catch (e) {
      _addResult(DemoResult(
        title: '型安全性テスト',
        description: '型安全性テストでエラーが発生しました',
        sql: 'N/A',
        result: 'エラー: $e',
        isSuccess: false,
      ));
    } finally {
      setState(() => _isRunning = false);
    }
  }

  String _formatJoinResult(List<Map<String, dynamic>> result) {
    if (result.isEmpty) return '結果なし';

    final buffer = StringBuffer();
    for (int i = 0; i < result.length; i++) {
      final row = result[i];
      buffer.writeln('行 ${i + 1}:');
      for (final entry in row.entries) {
        buffer.writeln('  ${entry.key}: ${entry.value}');
      }
    }
    return buffer.toString();
  }

  void _addResult(DemoResult result) {
    setState(() {
      _results.add(result);
    });
  }

  void _clearResults() {
    setState(() {
      _results.clear();
    });
  }
}

/// デモ結果を保持するクラス
class DemoResult {
  final String title;
  final String description;
  final String sql;
  final String result;
  final bool isSuccess;

  const DemoResult({
    required this.title,
    required this.description,
    required this.sql,
    required this.result,
    required this.isSuccess,
  });
}