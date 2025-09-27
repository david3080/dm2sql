/// 動的テーブル操作とサンプルデータ生成
library;
import 'dart:math';
import 'database.dart';
import 'dynamic_schema.dart';

/// 動的テーブル管理クラス
class DynamicTableManager {
  final MinimalDatabase database;

  DynamicTableManager(this.database);

  /// スキーマからテーブルを動的作成
  Future<void> createTablesFromSchema(SchemaDefinition schema) async {
    // 依存関係順にテーブルを作成
    final sortedTables = _sortTablesByDependency(schema.tables);

    for (final table in sortedTables) {
      final createSQL = table.generateCreateTableSQL();
      // デバッグ用出力
      // print('Creating table: ${table.englishName}');
      // print('SQL: $createSQL');

      try {
        await database.rawExecute(createSQL);
        // print('✅ Table ${table.englishName} created successfully');
      } catch (e) {
        // print('❌ Error creating table ${table.englishName}: $e');
        rethrow;
      }
    }
  }

  /// テーブルにサンプルデータを挿入
  Future<void> insertSampleData(SchemaDefinition schema) async {
    final sortedTables = _sortTablesByDependency(schema.tables);

    for (final table in sortedTables) {
      await _insertSampleDataForTable(table);
    }
  }

  /// 依存関係順にテーブルをソート（外部キーの参照先を先に作成）
  List<TableDefinition> _sortTablesByDependency(List<TableDefinition> tables) {
    final sorted = <TableDefinition>[];
    final remaining = List<TableDefinition>.from(tables);
    final tableMap = {for (var t in tables) t.englishName: t};

    while (remaining.isNotEmpty) {
      final added = <TableDefinition>[];

      for (final table in remaining) {
        final dependencies = table.foreignKeys
            .map((fk) => fk.referencedTable)
            .where((ref) => tableMap.containsKey(ref))
            .toList();

        // 依存するテーブルがすべて作成済みの場合
        if (dependencies.every((dep) => sorted.any((t) => t.englishName == dep))) {
          sorted.add(table);
          added.add(table);
        }
      }

      if (added.isEmpty && remaining.isNotEmpty) {
        // 循環参照がある場合、残りをそのまま追加
        sorted.addAll(remaining);
        break;
      }

      remaining.removeWhere((table) => added.contains(table));
    }

    return sorted;
  }

  /// 特定テーブルのサンプルデータ挿入
  Future<void> _insertSampleDataForTable(TableDefinition table) async {
    final sampleCount = _getSampleCount(table.englishName);

    for (int i = 1; i <= sampleCount; i++) {
      final data = await _generateSampleRecord(table, i);

      final columns = data.keys.toList();

      // 値を直接SQLに埋め込む（パラメータを使わない）
      final valueStrings = data.values.map((value) {
        if (value == null) {
          return 'NULL';
        } else if (value is String) {
          // 文字列の場合、シングルクォートでエスケープ
          final escaped = value.replaceAll("'", "''");
          return "'$escaped'";
        } else if (value is int || value is double) {
          return value.toString();
        } else if (value is bool) {
          return value ? '1' : '0';
        } else {
          // その他の型は文字列として処理
          final escaped = value.toString().replaceAll("'", "''");
          return "'$escaped'";
        }
      }).toList();

      final insertSQL = '''
        INSERT INTO `${table.englishName}` (${columns.join(', ')})
        VALUES (${valueStrings.join(', ')})
      ''';

      try {
        // パラメータなしでSQL実行
        await database.rawExecute(insertSQL);
      } catch (e) {
        // print('❌ Error inserting data into ${table.englishName}: $e');
      }
    }

    // print('✅ Inserted $sampleCount sample records into ${table.englishName}');
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
  Future<Map<String, dynamic>> _generateSampleRecord(TableDefinition table, int index) async {
    final record = <String, dynamic>{};
    final random = Random();

    // 主キーは通常AUTOINCREMENTなので挿入しない
    // 外部キーの値を取得
    final foreignKeyValues = <String, int>{};
    for (final fk in table.foreignKeys) {
      final refValue = await _getRandomReferenceValue(fk.referencedTable);
      if (refValue != null) {
        foreignKeyValues[fk.columnName] = refValue;
      }
    }

    // 通常カラムの値を生成
    for (final column in table.columns) {
      if (foreignKeyValues.containsKey(column.englishName)) {
        record[column.englishName] = foreignKeyValues[column.englishName];
      } else {
        record[column.englishName] = _generateSampleValue(column, table.englishName, index, random);
      }
    }

    // 外部キーカラムを追加
    for (final fk in table.foreignKeys) {
      if (foreignKeyValues.containsKey(fk.columnName)) {
        record[fk.columnName] = foreignKeyValues[fk.columnName];
      }
    }

    return record;
  }

  /// ランダムな参照値を取得
  Future<int?> _getRandomReferenceValue(String referencedTable) async {
    try {
      final result = await database.rawQuery('SELECT id FROM `$referencedTable` ORDER BY RANDOM() LIMIT 1');
      if (result.isNotEmpty) {
        return result.first['id'] as int;
      }
    } catch (e) {
      // テーブルが存在しない場合は無視
    }
    return null;
  }

  /// カラムのサンプル値生成
  dynamic _generateSampleValue(ColumnDefinition column, String tableName, int index, Random random) {
    final columnName = column.englishName;

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
    switch (column.dataType) {
      case DMDataType.integer:
        if (columnName.contains('price') || columnName.contains('amount') || columnName.contains('cost')) {
          return random.nextInt(50000) + 1000;
        } else if (columnName.contains('count') || columnName.contains('quantity')) {
          return random.nextInt(100) + 1;
        } else {
          return random.nextInt(1000) + 1;
        }

      case DMDataType.string:
        return 'sample_${columnName}_$index';

      case DMDataType.double:
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

  /// 全テーブルのデータを取得
  Future<Map<String, List<Map<String, dynamic>>>> getAllTablesData() async {
    final result = <String, List<Map<String, dynamic>>>{};

    // すべてのテーブル名を取得
    final tables = await database.rawQuery('''
      SELECT name FROM sqlite_master
      WHERE type='table' AND name NOT LIKE 'sqlite_%'
      ORDER BY name
    ''');

    for (final table in tables) {
      final tableName = table['name'] as String;
      try {
        final data = await database.rawQuery('SELECT * FROM `$tableName` LIMIT 100');
        result[tableName] = data;
      } catch (e) {
        // print('Error fetching data from $tableName: $e');
        result[tableName] = [];
      }
    }

    return result;
  }

  /// データベースをクリア
  Future<void> clearDatabase() async {
    final tables = await database.rawQuery('''
      SELECT name FROM sqlite_master
      WHERE type='table' AND name NOT LIKE 'sqlite_%'
    ''');

    for (final table in tables) {
      final tableName = table['name'] as String;
      await database.rawExecute('DROP TABLE IF EXISTS `$tableName`');
    }

    // print('✅ Database cleared');
  }
}