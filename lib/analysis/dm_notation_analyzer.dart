/// drift_devのAnalyzerを参考にしたDMNotation解析器
library;

import 'results/dm_database.dart';
import 'results/dm_table.dart';
import 'results/dm_column.dart';
import 'results/dm_constraint.dart';

/// DMNotation記法の解析エラー
class DMAnalysisError {
  final int line;
  final int column;
  final String message;
  final DMErrorType type;

  const DMAnalysisError({
    required this.line,
    required this.column,
    required this.message,
    required this.type,
  });

  @override
  String toString() {
    return '${type.name} at line $line, column $column: $message';
  }
}

/// エラーの種類
enum DMErrorType {
  syntaxError,
  semanticError,
  referenceError,
  typeError,
}

/// 解析結果
class DMAnalysisResult {
  final bool isSuccess;
  final DMDatabase? database;
  final List<DMAnalysisError> errors;

  const DMAnalysisResult._({
    required this.isSuccess,
    this.database,
    required this.errors,
  });

  factory DMAnalysisResult.success(DMDatabase database) {
    return DMAnalysisResult._(
      isSuccess: true,
      database: database,
      errors: [],
    );
  }

  factory DMAnalysisResult.failure(List<DMAnalysisError> errors) {
    return DMAnalysisResult._(
      isSuccess: false,
      database: null,
      errors: errors,
    );
  }
}

/// DMNotation記法分析器
/// drift_devのAnalyzerパターンを参考に設計
class DMNotationAnalyzer {
  /// DMNotationテキストを解析してDMDatabaseを生成
  static DMAnalysisResult analyze(String dmNotationText, {
    String databaseName = 'dm_database',
    int version = 1,
  }) {
    try {
      final analyzer = DMNotationAnalyzer._();
      return analyzer._analyzeInternal(dmNotationText, databaseName, version);
    } catch (e) {
      return DMAnalysisResult.failure([
        DMAnalysisError(
          line: 0,
          column: 0,
          message: '予期しないエラー: $e',
          type: DMErrorType.syntaxError,
        ),
      ]);
    }
  }

  DMNotationAnalyzer._();

  /// 行の階層情報
  _LineInfo _analyzeLine(String line, int lineNumber) {
    final originalLine = line;
    final trimmedLine = line.trim();

    if (trimmedLine.isEmpty) {
      return _LineInfo(
        lineNumber: lineNumber,
        originalLine: originalLine,
        trimmedLine: trimmedLine,
        indentLevel: 0,
        isRelationship: false,
        isEmpty: true,
      );
    }

    // インデントレベル計算（2スペース = 1レベル）
    final leadingSpaces = line.length - line.trimLeft().length;
    final indentLevel = leadingSpaces ~/ 2;

    // 関係性行かどうか判定
    final isRelationship = _isRelationshipLine(trimmedLine);

    return _LineInfo(
      lineNumber: lineNumber,
      originalLine: originalLine,
      trimmedLine: trimmedLine,
      indentLevel: indentLevel,
      isRelationship: isRelationship,
      isEmpty: false,
    );
  }

  /// 内部解析処理
  DMAnalysisResult _analyzeInternal(String text, String databaseName, int version) {
    final lines = text.split('\n');
    final tables = <DMTable>[];
    final relationships = <DMRelationship>[];
    final errors = <DMAnalysisError>[];

    // 行情報解析
    final lineInfos = <_LineInfo>[];
    for (int i = 0; i < lines.length; i++) {
      lineInfos.add(_analyzeLine(lines[i], i + 1));
    }

    // 階層構造の解析
    final hierarchyResult = _analyzeHierarchy(lineInfos);
    if (!hierarchyResult.isSuccess) {
      errors.addAll(hierarchyResult.errors);
    }

    // 1回目：完全定義されたテーブルを収集
    final tableMap = <String, DMTable>{};
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || _isRelationshipLine(line)) continue;

      final tableResult = _parseTableDefinition(line, i + 1);
      if (tableResult.isSuccess && tableResult.table != null) {
        tables.add(tableResult.table!);
        tableMap[tableResult.table!.sqlName] = tableResult.table!;
      } else {
        errors.addAll(tableResult.errors);
      }
    }

    // 2回目：関係性と子テーブル処理
    String? currentParent;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // 親テーブルの検出
      if (!_isRelationshipLine(trimmedLine)) {
        final match = RegExp(r'^([^{]+)\{([^}]+)\}:').firstMatch(trimmedLine);
        if (match != null) {
          currentParent = match.group(2)!.trim();
        }
        continue;
      }

      // 関係性処理
      if (currentParent != null) {
        final relationshipResult = _parseRelationship(trimmedLine, currentParent, i + 1, tableMap);
        if (relationshipResult.isSuccess) {
          if (relationshipResult.relationship != null) {
            relationships.add(relationshipResult.relationship!);
          }
          if (relationshipResult.childTable != null && !tableMap.containsKey(relationshipResult.childTable!.sqlName)) {
            tables.add(relationshipResult.childTable!);
            tableMap[relationshipResult.childTable!.sqlName] = relationshipResult.childTable!;
          }
        } else {
          errors.addAll(relationshipResult.errors);
        }
      }
    }

    // 3回目：外部キー検証
    final validationErrors = _validateForeignKeys(tables);
    errors.addAll(validationErrors);

    if (errors.isNotEmpty) {
      return DMAnalysisResult.failure(errors);
    }

    final database = DMDatabase(
      name: databaseName,
      version: version,
      tables: tables,
      relationships: relationships,
    );

    return DMAnalysisResult.success(database);
  }

  /// 関係性行かどうか判定
  bool _isRelationshipLine(String line) {
    return line.startsWith('--') || line.startsWith('->') || line.startsWith('??');
  }

  /// テーブル定義の解析
  _TableParseResult _parseTableDefinition(String line, int lineNumber) {
    final match = RegExp(r'^([^{]+)\{([^}]+)\}:\s*(.+)$').firstMatch(line);
    if (match == null) {
      return _TableParseResult.failure([
        DMAnalysisError(
          line: lineNumber,
          column: 0,
          message: 'テーブル定義の構文が正しくありません: $line',
          type: DMErrorType.syntaxError,
        ),
      ]);
    }

    final japaneseName = match.group(1)!.trim();
    final englishName = match.group(2)!.trim();
    final columnsText = match.group(3)!.trim();

    return _parseTableColumns(japaneseName, englishName, columnsText, lineNumber);
  }

  /// テーブルカラムの解析
  _TableParseResult _parseTableColumns(String japaneseName, String englishName, String columnsText, int lineNumber) {
    final errors = <DMAnalysisError>[];
    final columns = <DMColumn>[];
    final foreignKeys = <DMForeignKey>[];
    DMPrimaryKey? primaryKey;

    final columnTexts = columnsText.split(',').map((c) => c.trim()).toList();

    for (final columnText in columnTexts) {
      if (columnText.isEmpty) continue;

      // 主キー解析
      var match = RegExp(r'^\[([^{]*)\{([^:}]+):([^}]+)\}\]$').firstMatch(columnText);
      if (match != null) {
        final columnName = match.group(2)!.trim();
        final typeAndConstraints = match.group(3)!.trim();
        final type = _extractType(typeAndConstraints);

        if (primaryKey != null) {
          errors.add(DMAnalysisError(
            line: lineNumber,
            column: 0,
            message: '主キーが複数定義されています',
            type: DMErrorType.semanticError,
          ));
        }

        primaryKey = DMPrimaryKey(
          columnName: columnName,
          sqlType: (DMDataType.fromDMNotation(type) ?? DMDataType.integer).sqlType,
        );
        continue;
      }

      // 外部キー解析
      match = RegExp(r'^\(([^{]*)\{([^:}]+):([^}]+)\}\)$').firstMatch(columnText);
      if (match != null) {
        final displayName = match.group(1)?.trim() ?? '';
        final columnName = match.group(2)!.trim();
        final typeAndConstraints = match.group(3)!.trim();
        final type = _extractType(typeAndConstraints);
        final constraints = _parseConstraints(typeAndConstraints);

        // より賢い参照テーブル推測
        String referencedTable = 'unknown';
        if (columnName.endsWith('_id')) {
          var tableName = columnName.substring(0, columnName.length - 3);

          // 特定の役割パターンをマッピング
          final roleToTable = {
            'author': 'user',
            'uploader': 'user',
            'commenter': 'user',
            'follower': 'user',
            'following': 'user',
          };

          // プレフィックス除去（from_, to_, original_, conflicting_, etc.）
          // ただし、purchase_order のような複合語は除外
          if (tableName.contains('_') && !_isCompoundWord(tableName)) {
            final parts = tableName.split('_');
            if (parts.length >= 2) {
              // 最後の部分を取得（例：from_warehouse → warehouse）
              tableName = parts.last;
            }
          }

          // 役割マッピングを適用
          referencedTable = roleToTable[tableName] ?? tableName;

          // 複合参照の処理（original_reservation → reservation）
          if (referencedTable.contains('_') && !_isCompoundWord(referencedTable)) {
            final parts = referencedTable.split('_');
            if (parts.length >= 2) {
              referencedTable = parts.last;
            }
          }
        }

        foreignKeys.add(DMForeignKey(
          columnName: columnName,
          displayName: displayName.isNotEmpty ? displayName : columnName,
          sqlType: (DMDataType.fromDMNotation(type) ?? DMDataType.integer).sqlType,
          referencedTable: referencedTable,
          referencedColumn: 'id',
          type: DMDataType.fromDMNotation(type) ?? DMDataType.integer,
          constraints: constraints,
        ));
        continue;
      }

      // 通常カラム解析
      match = RegExp(r'^(?:([^{]*))?\{([^:}]+):([^}]+)\}$').firstMatch(columnText);
      if (match != null) {
        final displayName = match.group(1)?.trim();
        final columnName = match.group(2)!.trim();
        final typeAndConstraints = match.group(3)!.trim();
        final type = _extractType(typeAndConstraints);
        final constraints = _parseConstraints(typeAndConstraints);

        columns.add(DMColumn(
          displayName: displayName ?? columnName,
          sqlName: columnName,
          type: DMDataType.fromDMNotation(type) ?? DMDataType.text,
          constraints: constraints,
        ));
      }
    }

    // デフォルト主キー
    primaryKey ??= DMPrimaryKey(columnName: 'id', sqlType: 'INTEGER');

    if (errors.isNotEmpty) {
      return _TableParseResult.failure(errors);
    }

    final table = DMTable(
      displayName: japaneseName,
      sqlName: englishName,
      columns: columns,
      primaryKey: primaryKey,
      foreignKeys: foreignKeys,
    );

    return _TableParseResult.success(table);
  }

  /// 関係性の解析
  _RelationshipParseResult _parseRelationship(String line, String parentTable, int lineNumber, Map<String, DMTable> tableMap) {
    final errors = <DMAnalysisError>[];

    // 関係性タイプの判定
    late final DMRelationshipType relType;
    late final String content;

    if (line.startsWith('--')) {
      relType = DMRelationshipType.cascade;
      content = line.substring(2).trim();
    } else if (line.startsWith('->')) {
      relType = DMRelationshipType.reference;
      content = line.substring(2).trim();
    } else if (line.startsWith('??')) {
      relType = DMRelationshipType.weak;
      content = line.substring(2).trim();
    } else {
      return _RelationshipParseResult.failure([
        DMAnalysisError(
          line: lineNumber,
          column: 0,
          message: '不明な関係性記号です: $line',
          type: DMErrorType.syntaxError,
        ),
      ]);
    }

    // 子テーブル名の抽出
    final match = RegExp(r'^([^{]+)\{([^}]+)\}').firstMatch(content);
    if (match == null) {
      return _RelationshipParseResult.failure([
        DMAnalysisError(
          line: lineNumber,
          column: 0,
          message: '子テーブル名の解析に失敗しました: $content',
          type: DMErrorType.syntaxError,
        ),
      ]);
    }

    final childTableName = match.group(2)!.trim();
    final relationship = DMRelationship(
      parentTable: parentTable,
      childTable: childTableName,
      type: relType,
    );

    // 新しい子テーブルの定義があるかチェック
    DMTable? childTable;
    if (content.contains(':')) {
      // 完全定義
      final tableResult = _parseTableDefinition(content, lineNumber);
      if (tableResult.isSuccess) {
        childTable = tableResult.table;
      } else {
        errors.addAll(tableResult.errors);
      }
    }

    if (errors.isNotEmpty) {
      return _RelationshipParseResult.failure(errors);
    }

    return _RelationshipParseResult.success(relationship, childTable);
  }

  /// 型名抽出（制約記号除去）
  String _extractType(String typeText) {
    return typeText.replaceAll(RegExp(r'[!@*]'), '');
  }

  /// 制約解析
  List<DMColumnConstraint> _parseConstraints(String typeText) {
    return DMColumnConstraint.parseConstraints(typeText);
  }

  /// 階層構造の解析
  _HierarchyAnalysisResult _analyzeHierarchy(List<_LineInfo> lineInfos) {
    final errors = <DMAnalysisError>[];
    final hierarchyNodes = <_HierarchyNode>[];
    final nodeStack = <_HierarchyNode>[];

    for (final lineInfo in lineInfos) {
      if (lineInfo.isEmpty) continue;

      // インデントレベルに基づいてスタックを調整
      while (nodeStack.isNotEmpty && nodeStack.last.indentLevel >= lineInfo.indentLevel) {
        nodeStack.removeLast();
      }

      // 新しいノードを作成
      final node = _HierarchyNode(
        lineInfo: lineInfo,
        parent: nodeStack.isNotEmpty ? nodeStack.last : null,
        children: [],
      );

      // 親ノードに子として追加
      if (nodeStack.isNotEmpty) {
        nodeStack.last.children.add(node);
      } else {
        hierarchyNodes.add(node);
      }

      // 関係性行でなければスタックに追加（次の子のために）
      if (!lineInfo.isRelationship) {
        nodeStack.add(node);
      }
    }

    return _HierarchyAnalysisResult.success(hierarchyNodes);
  }

  /// 複合語かどうかを判定
  bool _isCompoundWord(String word) {
    // 既知の複合語パターン
    final compoundWords = {
      'purchase_order',
      'order_detail',
      'stock_movement',
      'stock_taking',
      'reservation_conflict',
      'shipping_method',
      'coupon_usage',
    };

    return compoundWords.contains(word);
  }

  /// 外部キー検証
  List<DMAnalysisError> _validateForeignKeys(List<DMTable> tables) {
    final errors = <DMAnalysisError>[];
    final tableMap = {for (var t in tables) t.sqlName: t};

    for (final table in tables) {
      for (final fk in table.foreignKeys) {
        if (!tableMap.containsKey(fk.referencedTable)) {
          errors.add(DMAnalysisError(
            line: 0,
            column: 0,
            message: 'テーブル "${table.sqlName}" の外部キー "${fk.columnName}" が参照するテーブル "${fk.referencedTable}" が見つかりません',
            type: DMErrorType.referenceError,
          ));
        }
      }
    }

    return errors;
  }
}

/// テーブル解析結果
class _TableParseResult {
  final bool isSuccess;
  final DMTable? table;
  final List<DMAnalysisError> errors;

  const _TableParseResult._(this.isSuccess, this.table, this.errors);

  factory _TableParseResult.success(DMTable table) {
    return _TableParseResult._(true, table, []);
  }

  factory _TableParseResult.failure(List<DMAnalysisError> errors) {
    return _TableParseResult._(false, null, errors);
  }
}

/// 行の階層情報
class _LineInfo {
  final int lineNumber;
  final String originalLine;
  final String trimmedLine;
  final int indentLevel;
  final bool isRelationship;
  final bool isEmpty;

  const _LineInfo({
    required this.lineNumber,
    required this.originalLine,
    required this.trimmedLine,
    required this.indentLevel,
    required this.isRelationship,
    required this.isEmpty,
  });

  @override
  String toString() {
    return '_LineInfo{line: $lineNumber, indent: $indentLevel, relationship: $isRelationship, content: "$trimmedLine"}';
  }
}

/// 階層ノード
class _HierarchyNode {
  final _LineInfo lineInfo;
  final _HierarchyNode? parent;
  final List<_HierarchyNode> children;

  _HierarchyNode({
    required this.lineInfo,
    required this.parent,
    required this.children,
  });

  int get indentLevel => lineInfo.indentLevel;

  /// このノードから親を辿ってテーブル定義ノードを検索
  _HierarchyNode? findParentTableNode() {
    var current = parent;
    while (current != null) {
      if (!current.lineInfo.isRelationship && current.lineInfo.trimmedLine.contains('{') && current.lineInfo.trimmedLine.contains('}:')) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }

  @override
  String toString() {
    return '_HierarchyNode{indent: $indentLevel, line: "${lineInfo.trimmedLine}"}';
  }
}

/// 階層解析結果
class _HierarchyAnalysisResult {
  final bool isSuccess;
  final List<_HierarchyNode> nodes;
  final List<DMAnalysisError> errors;

  const _HierarchyAnalysisResult._(this.isSuccess, this.nodes, this.errors);

  factory _HierarchyAnalysisResult.success(List<_HierarchyNode> nodes) {
    return _HierarchyAnalysisResult._(true, nodes, []);
  }

  factory _HierarchyAnalysisResult.failure(List<DMAnalysisError> errors) {
    return _HierarchyAnalysisResult._(false, [], errors);
  }
}

/// 関係性解析結果
class _RelationshipParseResult {
  final bool isSuccess;
  final DMRelationship? relationship;
  final DMTable? childTable;
  final List<DMAnalysisError> errors;

  const _RelationshipParseResult._(this.isSuccess, this.relationship, this.childTable, this.errors);

  factory _RelationshipParseResult.success(DMRelationship relationship, [DMTable? childTable]) {
    return _RelationshipParseResult._(true, relationship, childTable, []);
  }

  factory _RelationshipParseResult.failure(List<DMAnalysisError> errors) {
    return _RelationshipParseResult._(false, null, null, errors);
  }
}