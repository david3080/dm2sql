/// 動的スキーマ定義のデータ構造
/// DMNotation記法からパースされたスキーマ情報を保持
library;

/// データベース全体のスキーマ定義
class SchemaDefinition {
  final List<TableDefinition> tables;
  final List<Relationship> relationships;

  const SchemaDefinition({
    required this.tables,
    required this.relationships,
  });

  /// テーブル名でテーブル定義を検索
  TableDefinition? findTable(String tableName) {
    return tables.cast<TableDefinition?>().firstWhere(
      (table) => table!.englishName == tableName || table.japaneseName == tableName,
      orElse: () => null,
    );
  }

  /// テーブルが存在するかチェック
  bool hasTable(String tableName) {
    return findTable(tableName) != null;
  }

  /// 全てのテーブル名を取得（英語名）
  List<String> get tableNames {
    return tables.map((table) => table.englishName).toList();
  }
}

/// テーブル定義
class TableDefinition {
  final String japaneseName;     // 顧客
  final String englishName;      // customer
  final List<ColumnDefinition> columns;
  final PrimaryKeyDefinition primaryKey;
  final List<ForeignKeyDefinition> foreignKeys;

  const TableDefinition({
    required this.japaneseName,
    required this.englishName,
    required this.columns,
    required this.primaryKey,
    required this.foreignKeys,
  });

  /// カラム名でカラム定義を検索
  ColumnDefinition? findColumn(String columnName) {
    return columns.cast<ColumnDefinition?>().firstWhere(
      (column) => column!.englishName == columnName,
      orElse: () => null,
    );
  }

  /// NOT NULL制約のカラム一覧
  List<ColumnDefinition> get notNullColumns {
    return columns.where((column) => column.constraints.contains(ColumnConstraint.notNull)).toList();
  }

  /// UNIQUE制約のカラム一覧
  List<ColumnDefinition> get uniqueColumns {
    return columns.where((column) => column.constraints.contains(ColumnConstraint.unique)).toList();
  }

  /// インデックス推奨カラム一覧
  List<ColumnDefinition> get indexedColumns {
    return columns.where((column) => column.constraints.contains(ColumnConstraint.indexed)).toList();
  }

  /// CREATE TABLE文を生成
  String generateCreateTableSQL() {
    final columnDefs = <String>[];

    // 主キー
    columnDefs.add('${primaryKey.columnName} ${primaryKey.sqlType} PRIMARY KEY AUTOINCREMENT');

    // 通常カラム
    for (final column in columns) {
      if (column.englishName == primaryKey.columnName) continue; // 主キーは既に追加済み

      final constraints = <String>[];
      if (column.constraints.contains(ColumnConstraint.notNull)) {
        constraints.add('NOT NULL');
      }
      if (column.constraints.contains(ColumnConstraint.unique)) {
        constraints.add('UNIQUE');
      }

      columnDefs.add('${column.englishName} ${column.sqlType}${constraints.isNotEmpty ? ' ${constraints.join(' ')}' : ''}');
    }

    // 外部キー
    for (final fk in foreignKeys) {
      columnDefs.add('${fk.columnName} ${fk.sqlType}');
      columnDefs.add('FOREIGN KEY (${fk.columnName}) REFERENCES `${fk.referencedTable}`(${fk.referencedColumn})');
    }

    return 'CREATE TABLE IF NOT EXISTS `$englishName` (\n  ${columnDefs.join(',\n  ')}\n)';
  }
}

/// カラム定義
class ColumnDefinition {
  final String japaneseName;     // 顧客名
  final String englishName;      // name
  final DMDataType dataType;     // string
  final String sqlType;          // TEXT
  final List<ColumnConstraint> constraints; // [notNull]

  const ColumnDefinition({
    required this.japaneseName,
    required this.englishName,
    required this.dataType,
    required this.sqlType,
    required this.constraints,
  });

  /// 型チェック
  bool isValidType(dynamic value) {
    switch (dataType) {
      case DMDataType.integer:
        return value is int;
      case DMDataType.string:
        return value is String;
      case DMDataType.double:
        return value is double || value is num;
      case DMDataType.datetime:
        return value is DateTime || value is int; // Unix timestamp
      case DMDataType.boolean:
        return value is bool || value is int; // 0/1
    }
  }
}

/// 主キー定義
class PrimaryKeyDefinition {
  final String columnName;       // id
  final String sqlType;          // INTEGER

  const PrimaryKeyDefinition({
    required this.columnName,
    required this.sqlType,
  });
}

/// 外部キー定義
class ForeignKeyDefinition {
  final String columnName;       // customer_id
  final String sqlType;          // INTEGER
  final String referencedTable;  // customer
  final String referencedColumn; // id

  const ForeignKeyDefinition({
    required this.columnName,
    required this.sqlType,
    required this.referencedTable,
    required this.referencedColumn,
  });
}

/// DMNotation記法のデータ型
enum DMDataType {
  integer,   // int
  string,    // string
  double,    // double
  datetime,  // datetime
  boolean,   // bool
}

/// カラム制約
enum ColumnConstraint {
  notNull,   // !
  unique,    // @
  indexed,   // *
}

/// テーブル間の関係性
class Relationship {
  final String parentTable;
  final String childTable;
  final RelationshipType type;

  const Relationship({
    required this.parentTable,
    required this.childTable,
    required this.type,
  });
}

/// 関係性の種類
enum RelationshipType {
  cascade,      // ├─ / └─ (カスケード削除)
  reference,    // ├* / └* (参照関係)
  weakReference, // ├? / └? (弱参照)
}

/// 型マッピング定義
class DMTypeMapper {
  static const Map<String, DMDataType> _dmTypeMap = {
    'int': DMDataType.integer,
    'string': DMDataType.string,
    'double': DMDataType.double,
    'datetime': DMDataType.datetime,
    'bool': DMDataType.boolean,
  };

  static const Map<DMDataType, String> _sqlTypeMap = {
    DMDataType.integer: 'INTEGER',
    DMDataType.string: 'TEXT',
    DMDataType.double: 'REAL',
    DMDataType.datetime: 'INTEGER', // Unix timestamp
    DMDataType.boolean: 'INTEGER',  // 0/1
  };

  static const Map<String, ColumnConstraint> _constraintMap = {
    '!': ColumnConstraint.notNull,
    '@': ColumnConstraint.unique,
    '*': ColumnConstraint.indexed,
  };

  /// DMNotation型名からDMDataTypeに変換
  static DMDataType? parseDMType(String dmType) {
    return _dmTypeMap[dmType];
  }

  /// DMDataTypeからSQL型名に変換
  static String toSQLType(DMDataType dmType) {
    return _sqlTypeMap[dmType] ?? 'TEXT';
  }

  /// 制約記号からColumnConstraintに変換
  static List<ColumnConstraint> parseConstraints(String constraintString) {
    final constraints = <ColumnConstraint>[];
    for (int i = 0; i < constraintString.length; i++) {
      final char = constraintString[i];
      final constraint = _constraintMap[char];
      if (constraint != null) {
        constraints.add(constraint);
      }
    }
    return constraints;
  }

  /// DartオブジェクトからSQLite値に変換
  static dynamic toSQLiteValue(dynamic value, DMDataType type) {
    switch (type) {
      case DMDataType.datetime:
        if (value is DateTime) {
          return value.millisecondsSinceEpoch ~/ 1000; // Unix timestamp
        }
        return value;
      case DMDataType.boolean:
        if (value is bool) {
          return value ? 1 : 0;
        }
        return value;
      default:
        return value;
    }
  }

  /// SQLite値からDartオブジェクトに変換
  static dynamic fromSQLiteValue(dynamic value, DMDataType type) {
    switch (type) {
      case DMDataType.datetime:
        if (value is int) {
          return DateTime.fromMillisecondsSinceEpoch(value * 1000);
        }
        return value;
      case DMDataType.boolean:
        if (value is int) {
          return value == 1;
        }
        return value;
      default:
        return value;
    }
  }
}