/// drift_devのDriftTableを参考にした動的テーブル定義
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'dm_column.dart';
import 'dm_constraint.dart';

/// DMNotationから解析されたテーブル定義
/// drift_devのDriftTableクラスを参考に設計
class DMTable {
  /// テーブルの日本語名（表示用）
  final String displayName;

  /// テーブルの英語名（SQL用）
  final String sqlName;

  /// テーブルのカラム一覧
  final List<DMColumn> columns;

  /// 主キー定義
  final DMPrimaryKey primaryKey;

  /// 外部キー制約一覧
  final List<DMForeignKey> foreignKeys;

  /// テーブル レベル制約
  final List<DMTableConstraint> constraints;

  /// テーブルのコメント・説明
  final String? comment;

  /// 定義順序で並んだ全カラム（外部キーカラムを含む）
  final List<DMColumn>? _allColumnsInOrder;

  const DMTable({
    required this.displayName,
    required this.sqlName,
    required this.columns,
    required this.primaryKey,
    this.foreignKeys = const [],
    this.constraints = const [],
    this.comment,
    List<DMColumn>? allColumnsInOrder,
  }) : _allColumnsInOrder = allColumnsInOrder;

  /// 指定した名前のカラムを検索
  DMColumn? findColumn(String columnName) {
    try {
      return columns.firstWhere((col) => col.sqlName == columnName);
    } catch (e) {
      return null;
    }
  }

  /// 外部キーカラムを含む全カラム（PRIMARY KEYを含む、定義順）
  List<DMColumn> get allColumns {
    // 定義順序が利用可能な場合はそれを使用
    if (_allColumnsInOrder != null) {
      final result = <DMColumn>[];

      // 1. PRIMARY KEYカラムを最初に追加
      result.add(DMColumn(
        displayName: primaryKey.columnName, // PRIMARY KEYには日本語名がないのでSQL名を使用
        sqlName: primaryKey.columnName,
        type: DMDataType.integer, // PRIMARY KEYは通常INTEGER型
        constraints: [DMColumnConstraint.notNull], // PRIMARY KEYは常にNOT NULL
      ));

      // 2. 定義順のカラムを追加（PRIMARY KEYと重複しないようにチェック）
      for (final col in _allColumnsInOrder) {
        if (col.sqlName != primaryKey.columnName) {
          result.add(col);
        }
      }

      return result;
    }

    // フォールバック：従来の方式
    final result = <DMColumn>[];

    // 1. PRIMARY KEYカラムを最初に追加
    result.add(DMColumn(
      displayName: primaryKey.columnName, // PRIMARY KEYには日本語名がないのでSQL名を使用
      sqlName: primaryKey.columnName,
      type: DMDataType.integer, // PRIMARY KEYは通常INTEGER型
      constraints: [DMColumnConstraint.notNull], // PRIMARY KEYは常にNOT NULL
    ));

    // 2. 通常カラムを追加（PRIMARY KEYと重複しないようにチェック）
    for (final col in columns) {
      if (col.sqlName != primaryKey.columnName) {
        result.add(col);
      }
    }

    // 3. 外部キーカラムを追加（重複チェック）
    for (final fk in foreignKeys) {
      if (!result.any((col) => col.sqlName == fk.columnName)) {
        result.add(DMColumn(
          displayName: fk.displayName,
          sqlName: fk.columnName,
          type: fk.type,
          constraints: fk.constraints,
        ));
      }
    }

    return result;
  }

  /// NOT NULL制約を持つカラム
  List<DMColumn> get requiredColumns {
    return allColumns.where((col) => col.isRequired).toList();
  }

  /// UNIQUE制約を持つカラム
  List<DMColumn> get uniqueColumns {
    return allColumns.where((col) => col.isUnique).toList();
  }

  /// インデックス推奨カラム
  List<DMColumn> get indexedColumns {
    return allColumns.where((col) => col.isIndexed).toList();
  }

  /// SQLテーブル作成文を生成
  String generateCreateTableSQL() {
    final columnDefs = <String>[];

    // 主キー
    columnDefs.add(_formatPrimaryKeySQL());

    // 通常カラム
    for (final column in columns) {
      // 主キーと重複しないようにチェック
      if (column.sqlName != primaryKey.columnName) {
        columnDefs.add(_formatColumnSQL(column));
      }
    }

    // 外部キーカラム（カラム定義のみ）
    for (final fk in foreignKeys) {
      // 通常カラムと重複チェック（外部キーカラムは追加）
      if (!columns.any((col) => col.sqlName == fk.columnName) && fk.columnName != primaryKey.columnName) {
        columnDefs.add(_formatForeignKeyColumnSQL(fk));
      }
    }

    // 外部キー制約（まとめて最後に追加）
    for (final fk in foreignKeys) {
      columnDefs.add(_formatForeignKeyConstraintSQL(fk));
    }

    // テーブル作成SQL
    final sql = '''CREATE TABLE IF NOT EXISTS `$sqlName` (
  ${columnDefs.join(',\n  ')}
)''';

    // デバッグ用：カラム定義をログ出力
    if (kDebugMode) {
      print('Table $sqlName column definitions:');
      for (int i = 0; i < columnDefs.length; i++) {
        print('  [$i]: ${columnDefs[i]}');
      }
      print('Full CREATE TABLE SQL:');
      print(sql);
    }

    return sql;
  }

  /// 主キーのSQL定義を生成
  String _formatPrimaryKeySQL() {
    return '${primaryKey.columnName} ${primaryKey.sqlType} PRIMARY KEY AUTOINCREMENT';
  }

  /// カラムのSQL定義を生成
  String _formatColumnSQL(DMColumn column) {
    final constraints = <String>[];

    if (column.isRequired) constraints.add('NOT NULL');
    if (column.isUnique) constraints.add('UNIQUE');

    final constraintStr = constraints.isNotEmpty ? ' ${constraints.join(' ')}' : '';
    return '${column.sqlName} ${column.sqlType}$constraintStr';
  }

  /// 外部キーカラムのSQL定義を生成
  String _formatForeignKeyColumnSQL(DMForeignKey fk) {
    final constraints = <String>[];

    if (fk.constraints.any((c) => c == DMColumnConstraint.notNull)) {
      constraints.add('NOT NULL');
    }
    if (fk.constraints.any((c) => c == DMColumnConstraint.unique)) {
      constraints.add('UNIQUE');
    }

    final constraintStr = constraints.isNotEmpty ? ' ${constraints.join(' ')}' : '';
    return '${fk.columnName} ${fk.sqlType}$constraintStr';
  }

  /// 外部キー制約のSQL定義を生成
  String _formatForeignKeyConstraintSQL(DMForeignKey fk) {
    return 'FOREIGN KEY (${fk.columnName}) REFERENCES `${fk.referencedTable}`(${fk.referencedColumn})';
  }

  @override
  String toString() {
    return 'DMTable{displayName: $displayName, sqlName: $sqlName, columns: ${columns.length}}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DMTable && other.sqlName == sqlName;
  }

  @override
  int get hashCode => sqlName.hashCode;
}