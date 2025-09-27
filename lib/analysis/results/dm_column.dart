/// drift_devのDriftColumnを参考にした動的カラム定義
library;

/// DMNotationのデータ型
enum DMDataType {
  integer('INTEGER'),
  text('TEXT'),
  real('REAL'),
  datetime('INTEGER'), // Unix timestamp
  boolean('INTEGER');  // 0/1

  const DMDataType(this.sqlType);

  /// 対応するSQLite型
  final String sqlType;

  /// DMNotation記法の型名から変換
  static DMDataType? fromDMNotation(String notation) {
    switch (notation.toLowerCase()) {
      case 'int': return DMDataType.integer;
      case 'string': return DMDataType.text;
      case 'double': return DMDataType.real;
      case 'datetime': return DMDataType.datetime;
      case 'bool': return DMDataType.boolean;
      default: return null;
    }
  }

  /// Dart型として妥当かチェック
  bool isValidDartValue(dynamic value) {
    switch (this) {
      case DMDataType.integer:
        return value is int;
      case DMDataType.text:
        return value is String;
      case DMDataType.real:
        return value is double || value is num;
      case DMDataType.datetime:
        return value is DateTime || value is int;
      case DMDataType.boolean:
        return value is bool || value is int;
    }
  }

  /// DartオブジェクトをSQLite値に変換
  dynamic toSQLiteValue(dynamic value) {
    switch (this) {
      case DMDataType.datetime:
        if (value is DateTime) {
          return value.millisecondsSinceEpoch ~/ 1000;
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

  /// SQLite値をDartオブジェクトに変換
  dynamic fromSQLiteValue(dynamic value) {
    switch (this) {
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

/// カラム制約の種類
enum DMColumnConstraint {
  notNull('!'),
  unique('@'),
  indexed('*');

  const DMColumnConstraint(this.notation);

  /// DMNotation記法の記号
  final String notation;

  /// 記号からConstraintに変換
  static DMColumnConstraint? fromNotation(String notation) {
    for (final constraint in DMColumnConstraint.values) {
      if (constraint.notation == notation) {
        return constraint;
      }
    }
    return null;
  }

  /// 記号文字列から制約リストに変換
  static List<DMColumnConstraint> parseConstraints(String constraintString) {
    final constraints = <DMColumnConstraint>[];
    for (int i = 0; i < constraintString.length; i++) {
      final char = constraintString[i];
      final constraint = fromNotation(char);
      if (constraint != null) {
        constraints.add(constraint);
      }
    }
    return constraints;
  }
}

/// DMNotationから解析されたカラム定義
/// drift_devのDriftColumnクラスを参考に設計
class DMColumn {
  /// カラムの日本語名（表示用）
  final String displayName;

  /// カラムのSQL名
  final String sqlName;

  /// データ型
  final DMDataType type;

  /// カラム制約
  final List<DMColumnConstraint> constraints;

  /// カラムのコメント・説明
  final String? comment;

  const DMColumn({
    required this.displayName,
    required this.sqlName,
    required this.type,
    this.constraints = const [],
    this.comment,
  });

  /// SQLite型文字列
  String get sqlType => type.sqlType;

  /// NOT NULL制約があるか
  bool get isRequired => constraints.contains(DMColumnConstraint.notNull);

  /// UNIQUE制約があるか
  bool get isUnique => constraints.contains(DMColumnConstraint.unique);

  /// インデックス推奨か
  bool get isIndexed => constraints.contains(DMColumnConstraint.indexed);

  /// 値の型チェック
  bool isValidValue(dynamic value) {
    if (value == null) {
      return !isRequired; // NOT NULL制約チェック
    }
    return type.isValidDartValue(value);
  }

  /// Dart値をSQLite値に変換
  dynamic convertToSQLite(dynamic value) {
    return type.toSQLiteValue(value);
  }

  /// SQLite値をDart値に変換
  dynamic convertFromSQLite(dynamic value) {
    return type.fromSQLiteValue(value);
  }

  /// SQL用の制約文字列を生成
  String get sqlConstraints {
    final sqlConstraints = <String>[];

    if (isRequired) sqlConstraints.add('NOT NULL');
    if (isUnique) sqlConstraints.add('UNIQUE');

    return sqlConstraints.isEmpty ? '' : ' ${sqlConstraints.join(' ')}';
  }

  /// 完全なSQL列定義を生成
  String get sqlDefinition {
    return '$sqlName $sqlType$sqlConstraints';
  }

  @override
  String toString() {
    return 'DMColumn{displayName: $displayName, sqlName: $sqlName, type: $type}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DMColumn && other.sqlName == sqlName;
  }

  @override
  int get hashCode => sqlName.hashCode;
}