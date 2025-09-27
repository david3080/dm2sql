/// シンプルなDMNotationパーサー（正規表現ベース）
library;

import 'dynamic_schema.dart';

/// シンプルパーサー（テスト用）
class SimpleDMNotationParser {
  /// テキストをパースしてSchemaDefinitionを返す
  static ParseResult parse(String text) {
    try {
      final tables = <TableDefinition>[];
      final relationships = <Relationship>[];
      final lines = text.split('\n');
      final tableMap = <String, TableDefinition>{};

      // 1回目：完全定義されたテーブルを収集
      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;

        // 関係記号で始まる行はスキップ（2回目で処理）
        if (trimmedLine.startsWith('--') ||
            trimmedLine.startsWith('->') ||
            trimmedLine.startsWith('??')) {
          continue;
        }

        // テーブル定義のパターンマッチ
        final tableMatch = RegExp(r'^([^{]+)\{([^}]+)\}:\s*(.+)$').firstMatch(trimmedLine);
        if (tableMatch != null) {
          final japaneseName = tableMatch.group(1)!.trim();
          final englishName = tableMatch.group(2)!.trim();
          final columnsText = tableMatch.group(3)!.trim();

          final table = _parseTableDefinition(japaneseName, englishName, columnsText);
          if (table != null) {
            tables.add(table);
            tableMap[englishName] = table;
          }
        }
      }

      // 2回目：関係性と子テーブルを処理
      String? currentParent;
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;

        // 親テーブル検出
        if (!trimmedLine.startsWith('--') &&
            !trimmedLine.startsWith('->') &&
            !trimmedLine.startsWith('??') &&
            trimmedLine.contains('{') && trimmedLine.contains('}:')) {
          final tableMatch = RegExp(r'^([^{]+)\{([^}]+)\}:').firstMatch(trimmedLine);
          if (tableMatch != null) {
            currentParent = tableMatch.group(2)!.trim();
          }
        }

        // 関係性のある子テーブル処理
        if (currentParent != null) {
          RelationshipType? relType;
          String? childTableName;

          if (trimmedLine.startsWith('--')) {
            relType = RelationshipType.cascade;
            childTableName = _extractChildTableName(trimmedLine.substring(2).trim());
          } else if (trimmedLine.startsWith('->')) {
            relType = RelationshipType.reference;
            childTableName = _extractChildTableName(trimmedLine.substring(2).trim());
          } else if (trimmedLine.startsWith('??')) {
            relType = RelationshipType.weakReference;
            childTableName = _extractChildTableName(trimmedLine.substring(2).trim());
          }

          if (relType != null && childTableName != null) {
            // 子テーブルを作成または更新
            final childTable = _parseChildTable(trimmedLine, childTableName, currentParent, tableMap);
            if (childTable != null && !tableMap.containsKey(childTableName)) {
              tables.add(childTable);
              tableMap[childTableName] = childTable;
            }

            // 関係性を追加
            relationships.add(Relationship(
              parentTable: currentParent,
              childTable: childTableName,
              type: relType,
            ));
          }
        }
      }

      return ParseResult.success(SchemaDefinition(
        tables: tables,
        relationships: relationships,
      ));

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

  /// テーブル定義をパース
  static TableDefinition? _parseTableDefinition(String japaneseName, String englishName, String columnsText) {
    try {
      final columns = <ColumnDefinition>[];
      final foreignKeys = <ForeignKeyDefinition>[];
      PrimaryKeyDefinition? primaryKey;

      // カラムを分割
      final columnTexts = columnsText.split(',').map((c) => c.trim()).toList();

      for (final columnText in columnTexts) {
        if (columnText.isEmpty) continue;

        // 主キー: [カラム名{column:type}]
        var match = RegExp(r'^\[([^{]*)\{([^:}]+):([^}]+)\}\]$').firstMatch(columnText);
        if (match != null) {
          final columnName = match.group(2)!.trim();
          final typeText = match.group(3)!.trim();
          final dmType = DMTypeMapper.parseDMType(_extractType(typeText)) ?? DMDataType.integer;

          primaryKey = PrimaryKeyDefinition(
            columnName: columnName,
            sqlType: DMTypeMapper.toSQLType(dmType),
          );
          continue;
        }

        // 外部キー: (カラム名{column:type})
        match = RegExp(r'^\(([^{]*)\{([^:}]+):([^}]+)\}\)$').firstMatch(columnText);
        if (match != null) {
          final columnName = match.group(2)!.trim();
          final typeText = match.group(3)!.trim();
          final dmType = DMTypeMapper.parseDMType(_extractType(typeText)) ?? DMDataType.integer;

          final referencedTable = columnName.endsWith('_id')
              ? columnName.substring(0, columnName.length - 3)
              : 'unknown';

          foreignKeys.add(ForeignKeyDefinition(
            columnName: columnName,
            sqlType: DMTypeMapper.toSQLType(dmType),
            referencedTable: referencedTable,
            referencedColumn: 'id',
          ));
          continue;
        }

        // 通常カラム: カラム名{column:type制約} または {column:type制約}
        match = RegExp(r'^(?:([^{]*))?\{([^:}]+):([^}]+)\}$').firstMatch(columnText);
        if (match != null) {
          final japaneseColumnName = match.group(1)?.trim();
          final columnName = match.group(2)!.trim();
          final typeAndConstraints = match.group(3)!.trim();

          final dmType = DMTypeMapper.parseDMType(_extractType(typeAndConstraints)) ?? DMDataType.string;
          final constraints = _parseConstraints(typeAndConstraints);

          columns.add(ColumnDefinition(
            japaneseName: japaneseColumnName ?? columnName,
            englishName: columnName,
            dataType: dmType,
            sqlType: DMTypeMapper.toSQLType(dmType),
            constraints: constraints,
          ));
        }
      }

      return TableDefinition(
        japaneseName: japaneseName,
        englishName: englishName,
        columns: columns,
        primaryKey: primaryKey ?? PrimaryKeyDefinition(columnName: 'id', sqlType: 'INTEGER'),
        foreignKeys: foreignKeys,
      );

    } catch (e) {
      return null;
    }
  }

  /// 型名を抽出（制約記号を除去）
  static String _extractType(String typeText) {
    return typeText.replaceAll(RegExp(r'[!@*]'), '');
  }

  /// 制約を解析
  static List<ColumnConstraint> _parseConstraints(String typeText) {
    final constraints = <ColumnConstraint>[];

    if (typeText.contains('!')) {
      constraints.add(ColumnConstraint.notNull);
    }
    if (typeText.contains('@')) {
      constraints.add(ColumnConstraint.unique);
    }
    if (typeText.contains('*')) {
      constraints.add(ColumnConstraint.indexed);
    }

    return constraints;
  }

  /// 子テーブル名を抽出
  static String? _extractChildTableName(String line) {
    final match = RegExp(r'^([^{]+)\{([^}]+)\}').firstMatch(line);
    return match?.group(2)?.trim();
  }

  /// 子テーブルをパース
  static TableDefinition? _parseChildTable(String line, String childTableName, String parentTable, Map<String, TableDefinition> tableMap) {
    // 既存のテーブル定義がある場合はそれを返す
    if (tableMap.containsKey(childTableName)) {
      return tableMap[childTableName];
    }

    // 新しい子テーブルの場合、行から定義を解析
    final match = RegExp(r'^(?:--|\->|\?\?)\s*([^{]+)\{([^}]+)\}:\s*(.+)$').firstMatch(line.trim());
    if (match != null) {
      final japaneseName = match.group(1)!.trim();
      final englishName = match.group(2)!.trim();
      final columnsText = match.group(3)!.trim();

      return _parseTableDefinition(japaneseName, englishName, columnsText);
    }

    // テーブル名のみの場合（既存テーブルへの参照）
    final nameOnlyMatch = RegExp(r'^(?:--|\->|\?\?)\s*([^{]+)\{([^}]+)\}$').firstMatch(line.trim());
    if (nameOnlyMatch != null) {
      final englishName = nameOnlyMatch.group(2)!.trim();
      return tableMap[englishName]; // 既存テーブルを参照
    }

    return null;
  }
}

/// パース結果
class ParseResult {
  final bool isSuccess;
  final SchemaDefinition? schema;
  final List<ParseError> errors;

  const ParseResult._(this.isSuccess, this.schema, this.errors);

  factory ParseResult.success(SchemaDefinition schema) {
    return ParseResult._(true, schema, []);
  }

  factory ParseResult.error(List<ParseError> errors) {
    return ParseResult._(false, null, errors);
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
  String toString() => 'Line $line, Column $column: $message';
}

/// エラータイプ
enum ParseErrorType {
  syntaxError,
  semanticError,
  referenceError,
  typeError,
}