/// DMNotation記法パーサー
/// DMNotation記法のテキストを解析してSchemaDefinitionオブジェクトに変換
library;

import 'package:petitparser/petitparser.dart';
import 'dynamic_schema.dart';

/// DMNotation記法パーサー (PetitParser版)
class DMNotationParser extends GrammarDefinition {
  /// メインパース実行
  static ParseResult parse(String dmNotationText) {
    try {
      final parser = DMNotationParser().build();
      final result = parser.parse(dmNotationText);

      if (result is Success) {
        final schema = result.value as SchemaDefinition;
        return ParseResult.success(schema);
      } else {
        return ParseResult.error([
          ParseError(
            line: result.position ~/ 100, // 簡易的な行計算
            column: result.position % 100,
            message: 'パース失敗: ${result.message}',
            errorType: ParseErrorType.syntaxError,
          )
        ]);
      }
    } catch (e) {
      return ParseResult.error([
        ParseError(
          line: 0,
          column: 0,
          message: 'パースエラー: $e',
          errorType: ParseErrorType.syntaxError,
        )
      ]);
    }
  }

  @override
  Parser start() => ref0(schema).end();

  /// スキーマ全体：最もシンプルな実装
  Parser schema() {
    // まず文字列を行ごとに分割して処理
    return any().star().flatten().map((text) {
      final tables = <TableDefinition>[];
      final lines = text.split('\n');

      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;

        // 関係記号で始まる行はスキップ（インデントされた子テーブル）
        if (trimmedLine.startsWith('--') || trimmedLine.startsWith('->') || trimmedLine.startsWith('??')) {
          continue;
        }

        // 単純なテーブル定義のみ解析
        if (trimmedLine.contains('{') && trimmedLine.contains('}:')) {
          try {
            final tableResult = ref0(fullTableDefinition).parse(trimmedLine);
            if (tableResult is Success) {
              tables.add(tableResult.value as TableDefinition);
            }
          } catch (e) {
            // パースエラーは無視して次の行へ
          }
        }
      }

      return SchemaDefinition(
        tables: tables,
        relationships: [],
      );
    });
  }


  /// 完全テーブル定義: 顧客{customer}: [主キー], カラム1, カラム2
  Parser fullTableDefinition() => (
    ref0(tableName).trim() &
    char('{') &
    ref0(identifier).trim() &
    char('}') &
    char(':').trim() &
    ref0(columnList)
  ).map((values) {
    final japaneseName = values[0] as String;
    final englishName = values[2] as String;
    final columns = values[5] as List<dynamic>;

    // 主キーとカラムを分離
    PrimaryKeyDefinition? primaryKey;
    final regularColumns = <ColumnDefinition>[];
    final foreignKeys = <ForeignKeyDefinition>[];

    for (final column in columns) {
      if (column is PrimaryKeyDefinition) {
        primaryKey = column;
      } else if (column is ForeignKeyDefinition) {
        foreignKeys.add(column);
      } else if (column is ColumnDefinition) {
        regularColumns.add(column);
      }
    }

    return TableDefinition(
      japaneseName: japaneseName,
      englishName: englishName,
      columns: regularColumns,
      primaryKey: primaryKey ?? PrimaryKeyDefinition(columnName: 'id', sqlType: 'INTEGER'),
      foreignKeys: foreignKeys,
    );
  });


  /// テーブル名（日本語可）
  Parser tableName() => (letter() | pattern('ぁ-ヿ㐀-鿿')).plus().flatten().trim();

  /// 識別子（英語のみ）
  Parser identifier() => (letter() | char('_')).seq((letter() | digit() | char('_')).star()).flatten().trim();

  /// カラムリスト: [主キー], カラム1, カラム2, ...
  Parser columnList() => ref0(columnItem).plusSeparated(char(',').trim()).map((result) => result.elements);

  /// カラム項目（主キー、外部キー、通常カラム）
  Parser columnItem() => ref0(primaryKey) | ref0(foreignKey) | ref0(regularColumn);

  /// 主キー: [主キー名{column:type}]
  Parser primaryKey() => (
    char('[') &
    ref0(columnDefinition) &
    char(']')
  ).map((values) {
    final columnDef = values[1] as Map<String, dynamic>;
    return PrimaryKeyDefinition(
      columnName: columnDef['englishName'],
      sqlType: columnDef['sqlType'],
    );
  });

  /// 外部キー: (外部キー名{column:type})
  Parser foreignKey() => (
    char('(') &
    ref0(columnDefinition) &
    char(')')
  ).map((values) {
    final columnDef = values[1] as Map<String, dynamic>;
    final columnName = columnDef['englishName'] as String;
    final referencedTable = columnName.endsWith('_id')
        ? columnName.substring(0, columnName.length - 3)
        : 'unknown';

    return ForeignKeyDefinition(
      columnName: columnName,
      sqlType: columnDef['sqlType'],
      referencedTable: referencedTable,
      referencedColumn: 'id',
    );
  });

  /// 通常カラム: カラム名{column:type制約}
  Parser regularColumn() => ref0(columnDefinition).map((columnDef) {
    return ColumnDefinition(
      japaneseName: columnDef['japaneseName'],
      englishName: columnDef['englishName'],
      dataType: columnDef['dataType'],
      sqlType: columnDef['sqlType'],
      constraints: columnDef['constraints'],
    );
  });

  /// カラム定義: 日本語名{english_name:type制約} または {english_name:type制約}
  Parser columnDefinition() => (
    (ref0(tableName) & char('{') & ref0(identifier) & char(':') & ref0(dataType) & ref0(constraints) & char('}')) |
    (char('{') & ref0(identifier) & char(':') & ref0(dataType) & ref0(constraints) & char('}'))
  ).map((values) {
    String japaneseName;
    String englishName;
    String typeInfo;
    List<ColumnConstraint> constraintList;

    if (values.length == 7) {
      // 日本語名あり: 日本語名{english_name:type制約}
      japaneseName = values[0] as String;
      englishName = values[2] as String;
      typeInfo = values[4] as String;
      constraintList = values[5] as List<ColumnConstraint>;
    } else {
      // 日本語名なし: {english_name:type制約}
      englishName = values[1] as String;
      japaneseName = englishName; // 英語名をそのまま使用
      typeInfo = values[3] as String;
      constraintList = values[4] as List<ColumnConstraint>;
    }

    final dmType = DMTypeMapper.parseDMType(typeInfo) ?? DMDataType.string;

    return {
      'japaneseName': japaneseName,
      'englishName': englishName,
      'dataType': dmType,
      'sqlType': DMTypeMapper.toSQLType(dmType),
      'constraints': constraintList,
    };
  });

  /// データ型: int, string, double, datetime, bool
  Parser dataType() => (
    string('int') |
    string('string') |
    string('double') |
    string('datetime') |
    string('bool')
  ).flatten();

  /// 制約: !, @, *
  Parser constraints() => pattern('!@*').star().map((chars) {
    return chars.map((char) {
      switch (char) {
        case '!': return ColumnConstraint.notNull;
        case '@': return ColumnConstraint.unique;
        case '*': return ColumnConstraint.indexed;
        default: return null;
      }
    }).where((c) => c != null).cast<ColumnConstraint>().toList();
  });
}

/// パース結果
class ParseResult {
  final bool isSuccess;
  final SchemaDefinition? schema;
  final List<ParseError> errors;

  const ParseResult._({
    required this.isSuccess,
    this.schema,
    required this.errors,
  });

  factory ParseResult.success(SchemaDefinition schema) {
    return ParseResult._(
      isSuccess: true,
      schema: schema,
      errors: [],
    );
  }

  factory ParseResult.error(List<ParseError> errors) {
    return ParseResult._(
      isSuccess: false,
      schema: null,
      errors: errors,
    );
  }
}

/// パースエラー
class ParseError {
  final int line;
  final int column;
  final String message;
  final ParseErrorType errorType;

  const ParseError({
    required this.line,
    required this.column,
    required this.message,
    required this.errorType,
  });

  @override
  String toString() {
    return 'Line $line, Column $column: $message';
  }
}

/// パースエラーの種類
enum ParseErrorType {
  syntaxError,        // 構文エラー
  semanticError,      // 意味論エラー
  referenceError,     // 参照エラー
  typeError,          // 型エラー
}

/// パース例外
class ParseException implements Exception {
  final String message;
  ParseException(this.message);

  @override
  String toString() => 'ParseException: $message';
}

/// DMNotation記法のサンプル（シンプル仕様準拠版）
class DMNotationSamples {
  /// ECサイトのサンプル（新仕様準拠）
  static const String ecommerceSample = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}, メール{email:string@}, 住所{address:string}, 電話{phone:string}, 作成日時{created_at:datetime!}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int}), 注文日時{order_datetime:datetime!}, 合計金額{total_amount:int!}, ステータス{status:string!}
   -- 注文明細{order_detail}: [明細ID{id:int}], (注文ID{order_id:int}), (商品ID{product_id:int}), 数量{quantity:int!}, 単価{unit_price:int!}, 小計{subtotal:int!}
      -> 商品{product}: [商品ID{id:int}], 商品名{name:string!}, 説明{description:string}, 標準売価{std_price:int!}, 標準原価{std_cost:double}, 在庫数{stock_qty:int!}
-- お気に入り{favorite}: [お気に入りID{id:int}], (顧客ID{customer_id:int}), (商品ID{product_id:int}), 登録日時{registered_at:datetime!}
   -> 商品{product}

カテゴリ{category}: [カテゴリID{id:int}], カテゴリ名{name:string!}, 説明{description:string}, 表示順{sort_order:int}
-> 商品{product}

配送先{shipping_address}: [配送先ID{id:int}], (顧客ID{customer_id:int}), 配送先名{name:string!}, 郵便番号{postal_code:string}, 住所{address:string!}, 電話{phone:string}
''';

  /// シンプルなサンプル（新仕様基本機能）
  static const String simpleSample = '''
ユーザー{user}: [ユーザーID{id:int}], ユーザー名{name:string!}, メール{email:string@}
-- 投稿{post}: [投稿ID{id:int}], (ユーザーID{user_id:int}), タイトル{title:string!}, 内容{content:string}

商品{product}: [商品ID{id:int}], 商品名{name:string!}, 価格{price:int!}, 在庫{stock:int}
?? カテゴリ{category}: [カテゴリID{id:int}], カテゴリ名{name:string!}
''';
}