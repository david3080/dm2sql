/// drift_devを参考にした動的DAO実装
library;

import '../database.dart';
import '../analysis/results/dm_database.dart';
import '../analysis/results/dm_table.dart';
import '../analysis/results/dm_column.dart';

/// Drift風の動的DAO
/// drift_devのDAOパターンを参考に設計
class DynamicDAO {
  final MinimalDatabase _database;
  final DMDatabase _schema;

  DynamicDAO(this._database, this._schema);

  /// テーブル管理機能
  DynamicTableManager get tables => DynamicTableManager(_database, _schema);

  /// Drift風のselect操作
  DynamicSelectBuilder select(String tableName) {
    final table = _schema.findTable(tableName);
    if (table == null) {
      throw ArgumentError('テーブル "$tableName" が見つかりません');
    }
    return DynamicSelectBuilder(_database, table);
  }

  /// Drift風のinsert操作
  DynamicInsertBuilder into(String tableName) {
    final table = _schema.findTable(tableName);
    if (table == null) {
      throw ArgumentError('テーブル "$tableName" が見つかりません');
    }
    return DynamicInsertBuilder(_database, table);
  }

  /// Drift風のupdate操作
  DynamicUpdateBuilder update(String tableName) {
    final table = _schema.findTable(tableName);
    if (table == null) {
      throw ArgumentError('テーブル "$tableName" が見つかりません');
    }
    return DynamicUpdateBuilder(_database, table);
  }

  /// Drift風のdelete操作
  DynamicDeleteBuilder delete(String tableName) {
    final table = _schema.findTable(tableName);
    if (table == null) {
      throw ArgumentError('テーブル "$tableName" が見つかりません');
    }
    return DynamicDeleteBuilder(_database, table);
  }

  /// 生SQLの実行
  Future<List<Map<String, dynamic>>> customSelect(String sql, [List<dynamic> arguments = const []]) {
    return _database.rawQuery(sql);
  }

  /// トランザクション実行
  Future<T> transaction<T>(Future<T> Function() action) async {
    await _database.rawExecute('BEGIN TRANSACTION');
    try {
      final result = await action();
      await _database.rawExecute('COMMIT');
      return result;
    } catch (e) {
      await _database.rawExecute('ROLLBACK');
      rethrow;
    }
  }

  /// スキーマ情報を取得
  DMDatabase get schema => _schema;
}

/// テーブル管理
class DynamicTableManager {
  final MinimalDatabase _database;
  final DMDatabase _schema;

  DynamicTableManager(this._database, this._schema);

  /// スキーマからテーブルを作成
  Future<void> createTables() async {
    final statements = _schema.generateCreateStatements();
    for (final statement in statements) {
      print('Executing SQL: $statement');
      await _database.rawExecute(statement);
    }
  }

  /// テーブルを削除
  Future<void> dropTable(String tableName) async {
    await _database.rawExecute('DROP TABLE IF EXISTS `$tableName`');
  }

  /// 全テーブルを削除
  Future<void> dropAllTables() async {
    for (final table in _schema.tables) {
      await dropTable(table.sqlName);
    }
  }

  /// テーブル存在確認
  Future<bool> tableExists(String tableName) async {
    final result = await _database.rawQuery('''
      SELECT COUNT(*) as count FROM sqlite_master
      WHERE type='table' AND name='$tableName'
    ''');
    return result.first['count'] as int > 0;
  }
}

/// Drift風のSELECTビルダー
class DynamicSelectBuilder {
  final MinimalDatabase _database;
  final DMTable _table;
  final List<String> _whereClauses = [];
  final List<dynamic> _whereArgs = [];
  String? _orderBy;
  String? _groupBy;
  String? _having;
  int? _limit;
  int? _offset;

  DynamicSelectBuilder(this._database, this._table);

  /// WHERE句追加
  DynamicSelectBuilder where(String condition, [List<dynamic> args = const []]) {
    _whereClauses.add(condition);
    _whereArgs.addAll(args);
    return this;
  }

  /// カラム条件（型安全）
  DynamicSelectBuilder whereColumn(String columnName, dynamic value, {String operator = '='}) {
    final column = _table.findColumn(columnName);
    if (column == null) {
      throw ArgumentError('カラム "$columnName" がテーブル "${_table.sqlName}" に存在しません');
    }

    if (!column.isValidValue(value)) {
      throw ArgumentError('カラム "$columnName" に対して無効な値です: $value');
    }

    _whereClauses.add('$columnName $operator ?');
    _whereArgs.add(column.convertToSQLite(value));
    return this;
  }

  /// ORDER BY句
  DynamicSelectBuilder orderBy(String columnName, {bool ascending = true}) {
    final direction = ascending ? 'ASC' : 'DESC';
    _orderBy = '$columnName $direction';
    return this;
  }

  /// GROUP BY句
  DynamicSelectBuilder groupBy(String columnName) {
    _groupBy = columnName;
    return this;
  }

  /// HAVING句
  DynamicSelectBuilder having(String condition) {
    _having = condition;
    return this;
  }

  /// LIMIT句
  DynamicSelectBuilder limit(int count) {
    _limit = count;
    return this;
  }

  /// OFFSET句
  DynamicSelectBuilder offset(int count) {
    _offset = count;
    return this;
  }

  /// JOIN操作（簡易実装）
  DynamicSelectBuilder join(String otherTableName, String condition) {
    return where(condition);
  }

  /// SQL実行
  Future<List<Map<String, dynamic>>> get() async {
    final sql = _buildSelectSQL();
    final result = await _database.rawQuery(sql);

    // 型変換
    return result.map((row) {
      final convertedRow = <String, dynamic>{};
      for (final entry in row.entries) {
        final column = _table.allColumns.cast<DMColumn?>().firstWhere(
          (col) => col!.sqlName == entry.key,
          orElse: () => null,
        );
        if (column != null) {
          convertedRow[entry.key] = column.convertFromSQLite(entry.value);
        } else {
          convertedRow[entry.key] = entry.value;
        }
      }
      return convertedRow;
    }).toList();
  }

  /// リアクティブストリーム（監視）
  Stream<List<Map<String, dynamic>>> watch() {
    // 実装の簡略化：定期的にポーリング
    return Stream.periodic(const Duration(seconds: 1), (_) => get()).asyncExpand((future) => future.asStream());
  }

  /// SQL文字列生成
  String _buildSelectSQL() {
    final buffer = StringBuffer('SELECT * FROM `${_table.sqlName}`');

    if (_whereClauses.isNotEmpty) {
      buffer.write(' WHERE ');
      buffer.write(_whereClauses.join(' AND '));
    }

    if (_groupBy != null) {
      buffer.write(' GROUP BY $_groupBy');
    }

    if (_having != null) {
      buffer.write(' HAVING $_having');
    }

    if (_orderBy != null) {
      buffer.write(' ORDER BY $_orderBy');
    }

    if (_limit != null) {
      buffer.write(' LIMIT $_limit');
    }

    if (_offset != null) {
      buffer.write(' OFFSET $_offset');
    }

    return buffer.toString();
  }
}


/// INSERT操作ビルダー
class DynamicInsertBuilder {
  final MinimalDatabase _database;
  final DMTable _table;

  DynamicInsertBuilder(this._database, this._table);

  /// データ挿入
  Future<int> insert(Map<String, dynamic> data) async {
    // 型チェック
    for (final entry in data.entries) {
      final column = _table.allColumns.cast<DMColumn?>().firstWhere(
        (col) => col!.sqlName == entry.key,
        orElse: () => null,
      );
      if (column != null && !column.isValidValue(entry.value)) {
        throw ArgumentError('カラム "${entry.key}" に対して無効な値です: ${entry.value}');
      }
    }

    final columns = data.keys.toList();
    final values = data.values.map((value) {
      if (value == null) return 'NULL';
      if (value is String) {
        return "'${value.replaceAll("'", "''")}'";
      }
      if (value is bool) return value ? '1' : '0';
      return value.toString();
    }).toList();

    final sql = '''
      INSERT INTO `${_table.sqlName}` (${columns.join(', ')})
      VALUES (${values.join(', ')})
    ''';

    await _database.rawExecute(sql);

    // 挿入されたIDを取得（簡易実装）
    final result = await _database.rawQuery('SELECT last_insert_rowid() as id');
    return result.first['id'] as int;
  }

  /// 複数データ挿入
  Future<void> insertAll(List<Map<String, dynamic>> dataList) async {
    for (final data in dataList) {
      await insert(data);
    }
  }
}

/// UPDATE操作ビルダー
class DynamicUpdateBuilder {
  final MinimalDatabase _database;
  final DMTable _table;
  final List<String> _whereClauses = [];
  final List<dynamic> _whereArgs = [];

  DynamicUpdateBuilder(this._database, this._table);

  /// WHERE句追加
  DynamicUpdateBuilder where(String condition, [List<dynamic> args = const []]) {
    _whereClauses.add(condition);
    _whereArgs.addAll(args);
    return this;
  }

  /// データ更新
  Future<int> write(Map<String, dynamic> data) async {
    if (data.isEmpty) {
      throw ArgumentError('更新データが空です');
    }

    final setClauses = <String>[];
    final setValues = <dynamic>[];

    for (final entry in data.entries) {
      setClauses.add('${entry.key} = ?');
      setValues.add(entry.value);
    }

    final sql = '''
      UPDATE `${_table.sqlName}`
      SET ${setClauses.join(', ')}
      ${_whereClauses.isNotEmpty ? 'WHERE ${_whereClauses.join(' AND ')}' : ''}
    ''';

    await _database.rawExecute(sql);

    // 更新行数を返す（簡易実装）
    final result = await _database.rawQuery('SELECT changes() as count');
    return result.first['count'] as int;
  }
}

/// DELETE操作ビルダー
class DynamicDeleteBuilder {
  final MinimalDatabase _database;
  final DMTable _table;
  final List<String> _whereClauses = [];
  final List<dynamic> _whereArgs = [];

  DynamicDeleteBuilder(this._database, this._table);

  /// WHERE句追加
  DynamicDeleteBuilder where(String condition, [List<dynamic> args = const []]) {
    _whereClauses.add(condition);
    _whereArgs.addAll(args);
    return this;
  }

  /// データ削除
  Future<int> go() async {
    final sql = '''
      DELETE FROM `${_table.sqlName}`
      ${_whereClauses.isNotEmpty ? 'WHERE ${_whereClauses.join(' AND ')}' : ''}
    ''';

    await _database.rawExecute(sql);

    // 削除行数を返す（簡易実装）
    final result = await _database.rawQuery('SELECT changes() as count');
    return result.first['count'] as int;
  }
}