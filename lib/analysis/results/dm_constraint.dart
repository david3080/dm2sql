/// drift_devの制約クラスを参考にした制約定義
library;

import 'dm_column.dart';

/// 主キー定義
class DMPrimaryKey {
  /// 主キーカラム名
  final String columnName;

  /// 主キーのSQL型
  final String sqlType;

  /// 自動増分するか
  final bool autoIncrement;

  const DMPrimaryKey({
    required this.columnName,
    required this.sqlType,
    this.autoIncrement = true,
  });

  /// SQL定義文字列
  String get sqlDefinition {
    final autoInc = autoIncrement ? ' AUTOINCREMENT' : '';
    return '$columnName $sqlType PRIMARY KEY$autoInc';
  }

  @override
  String toString() {
    return 'DMPrimaryKey{columnName: $columnName, sqlType: $sqlType}';
  }
}

/// 外部キー定義
class DMForeignKey {
  /// 外部キーカラム名
  final String columnName;

  /// 外部キーの表示名
  final String displayName;

  /// 外部キーのSQL型
  final String sqlType;

  /// 参照先テーブル名（解析中に更新される可能性があるためmutable）
  String referencedTable;

  /// 参照先カラム名
  final String referencedColumn;

  /// カスケード動作
  final DMForeignKeyAction onDelete;

  /// カスケード動作
  final DMForeignKeyAction onUpdate;

  /// データ型
  final DMDataType type;

  /// 制約
  final List<DMColumnConstraint> constraints;

  DMForeignKey({
    required this.columnName,
    required this.displayName,
    required this.sqlType,
    required this.referencedTable,
    required this.referencedColumn,
    required this.type,
    this.constraints = const [],
    this.onDelete = DMForeignKeyAction.noAction,
    this.onUpdate = DMForeignKeyAction.noAction,
  });

  /// SQL制約定義文字列
  String get sqlConstraintDefinition {
    final onDeleteClause = onDelete != DMForeignKeyAction.noAction
        ? ' ON DELETE ${onDelete.sqlKeyword}'
        : '';
    final onUpdateClause = onUpdate != DMForeignKeyAction.noAction
        ? ' ON UPDATE ${onUpdate.sqlKeyword}'
        : '';

    return 'FOREIGN KEY ($columnName) REFERENCES `$referencedTable`($referencedColumn)$onDeleteClause$onUpdateClause';
  }

  @override
  String toString() {
    return 'DMForeignKey{columnName: $columnName, referencedTable: $referencedTable}';
  }
}

/// 外部キーのカスケード動作
enum DMForeignKeyAction {
  noAction('NO ACTION'),
  restrict('RESTRICT'),
  cascade('CASCADE'),
  setNull('SET NULL'),
  setDefault('SET DEFAULT');

  const DMForeignKeyAction(this.sqlKeyword);

  final String sqlKeyword;
}

/// テーブルレベル制約の基底クラス
sealed class DMTableConstraint {
  const DMTableConstraint();

  /// SQL制約定義文字列
  String get sqlDefinition;
}

/// UNIQUE制約（複数カラム）
class DMUniqueConstraint extends DMTableConstraint {
  /// UNIQUE制約対象のカラム名リスト
  final List<String> columnNames;

  /// 制約名（任意）
  final String? constraintName;

  const DMUniqueConstraint({
    required this.columnNames,
    this.constraintName,
  });

  @override
  String get sqlDefinition {
    final name = constraintName != null ? 'CONSTRAINT $constraintName ' : '';
    final columns = columnNames.join(', ');
    return '${name}UNIQUE ($columns)';
  }

  @override
  String toString() {
    return 'DMUniqueConstraint{columnNames: $columnNames}';
  }
}

/// CHECK制約
class DMCheckConstraint extends DMTableConstraint {
  /// CHECK式
  final String expression;

  /// 制約名（任意）
  final String? constraintName;

  const DMCheckConstraint({
    required this.expression,
    this.constraintName,
  });

  @override
  String get sqlDefinition {
    final name = constraintName != null ? 'CONSTRAINT $constraintName ' : '';
    return '${name}CHECK ($expression)';
  }

  @override
  String toString() {
    return 'DMCheckConstraint{expression: $expression}';
  }
}

/// INDEX定義（テーブル作成後）
class DMIndex {
  /// インデックス名
  final String indexName;

  /// 対象テーブル名
  final String tableName;

  /// インデックス対象カラム
  final List<String> columnNames;

  /// ユニークインデックスか
  final bool isUnique;

  const DMIndex({
    required this.indexName,
    required this.tableName,
    required this.columnNames,
    this.isUnique = false,
  });

  /// CREATE INDEX文を生成
  String get createIndexSQL {
    final unique = isUnique ? 'UNIQUE ' : '';
    final columns = columnNames.join(', ');
    return 'CREATE ${unique}INDEX IF NOT EXISTS `$indexName` ON `$tableName` ($columns)';
  }

  @override
  String toString() {
    return 'DMIndex{indexName: $indexName, tableName: $tableName, columnNames: $columnNames}';
  }
}