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
    final errors = <DMAnalysisError>[];

    // Phase 1: 行情報解析
    final lineInfos = <_LineInfo>[];
    final lines = text.split('\n');
    for (int i = 0; i < lines.length; i++) {
      lineInfos.add(_analyzeLine(lines[i], i + 1));
    }

    // Phase 2: 階層構造構築
    final hierarchyResult = _analyzeHierarchy(lineInfos);
    if (!hierarchyResult.isSuccess) {
      errors.addAll(hierarchyResult.errors);
      return DMAnalysisResult.failure(errors);
    }

    // Phase 3: テーブル定義抽出（階層構造から）
    final tableExtractionResult = _extractTablesFromHierarchy(hierarchyResult.nodes);
    errors.addAll(tableExtractionResult.errors);
    final tables = tableExtractionResult.tables;
    final tableMap = {for (var t in tables) t.sqlName: t};

    // Phase 4: 関係性抽出（階層構造から）
    final relationshipResult = _extractRelationshipsFromHierarchy(hierarchyResult.nodes);
    errors.addAll(relationshipResult.errors);
    final relationships = relationshipResult.relationships;

    // Phase 5: 外部キー解決（階層情報活用）
    final foreignKeyResult = _resolveForeignKeysWithHierarchy(tables, relationships);
    errors.addAll(foreignKeyResult.errors);

    // Phase 6: 最終検証
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

      // 関係性行の場合は特別な処理
      if (lineInfo.isRelationship) {
        // 適切な親ノードを検索
        _HierarchyNode? parentNode;

        // インデントレベルに基づいて親を決定
        if (lineInfo.indentLevel > 0) {
          // インデントされている関係性行：より小さいインデントレベルのノードを探す
          for (int i = nodeStack.length - 1; i >= 0; i--) {
            final stackNode = nodeStack[i];
            if (stackNode.indentLevel < lineInfo.indentLevel) {
              parentNode = stackNode;
              break;
            }
          }
        } else {
          // ルートレベルの関係性行：直前のテーブル定義を親とする
          for (int i = hierarchyNodes.length - 1; i >= 0; i--) {
            final rootNode = hierarchyNodes[i];
            if (rootNode.isTableDefinition) {
              parentNode = rootNode;
              break;
            }
          }
        }

        final node = _HierarchyNode(
          lineInfo: lineInfo,
          parent: parentNode,
          children: [],
        );

        if (parentNode != null) {
          parentNode.children.add(node);
        } else {
          hierarchyNodes.add(node);
        }

        // 関係性行もスタックに追加（子の関係性行の親になる可能性がある）
        nodeStack.add(node);
      } else {
        // テーブル定義行の場合は既存のロジック
        while (nodeStack.isNotEmpty && nodeStack.last.indentLevel >= lineInfo.indentLevel) {
          nodeStack.removeLast();
        }

        final node = _HierarchyNode(
          lineInfo: lineInfo,
          parent: nodeStack.isNotEmpty ? nodeStack.last : null,
          children: [],
        );

        if (nodeStack.isNotEmpty) {
          nodeStack.last.children.add(node);
        } else {
          hierarchyNodes.add(node);
        }

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

  /// 階層構造からテーブル定義を抽出
  _TableExtractionResult _extractTablesFromHierarchy(List<_HierarchyNode> hierarchyNodes) {
    final tables = <DMTable>[];
    final errors = <DMAnalysisError>[];

    void processNode(_HierarchyNode node) {
      if (node.isTableDefinition) {
        final tableResult = _parseTableDefinition(node.lineInfo.trimmedLine, node.lineInfo.lineNumber);
        if (tableResult.isSuccess && tableResult.table != null) {
          tables.add(tableResult.table!);
        } else {
          errors.addAll(tableResult.errors);
        }
      } else if (node.lineInfo.isRelationship) {
        // 関係性行にテーブル定義が含まれているかチェック
        final content = _extractRelationshipContent(node.lineInfo.trimmedLine);
        if (content.contains(':')) {
          // テーブル定義を含む関係性行
          final tableResult = _parseTableDefinition(content, node.lineInfo.lineNumber);
          if (tableResult.isSuccess && tableResult.table != null) {
            tables.add(tableResult.table!);
          } else {
            errors.addAll(tableResult.errors);
          }
        }
      }

      for (final child in node.children) {
        processNode(child);
      }
    }

    for (final rootNode in hierarchyNodes) {
      processNode(rootNode);
    }

    return _TableExtractionResult.mixed(tables, errors);
  }

  /// 階層構造から関係性を抽出
  _RelationshipExtractionResult _extractRelationshipsFromHierarchy(List<_HierarchyNode> hierarchyNodes) {
    final relationships = <DMRelationship>[];
    final errors = <DMAnalysisError>[];

    void processNode(_HierarchyNode node) {
      if (node.lineInfo.isRelationship) {
        final relationshipType = node.relationshipType;

        if (relationshipType != null) {
          // 関係性行から子テーブル名を抽出
          final content = _extractRelationshipContent(node.lineInfo.trimmedLine);
          final match = RegExp(r'\{([^}]+)\}').firstMatch(content);
          if (match != null) {
            final childTableName = match.group(1)!.trim();

            // 親テーブル名を決定
            String? parentTableName;

            // 階層を考慮した親テーブル名の決定
            _HierarchyNode? parentNode = node.parent;

            // 親ノードから適切なテーブル名を取得
            while (parentNode != null) {
              if (parentNode.isTableDefinition) {
                parentTableName = parentNode.tableName;
                break;
              } else if (parentNode.lineInfo.isRelationship) {
                // 親も関係性行の場合、その関係性行から子テーブル名を取得
                final parentContent = _extractRelationshipContent(parentNode.lineInfo.trimmedLine);
                final parentMatch = RegExp(r'\{([^}]+)\}').firstMatch(parentContent);
                if (parentMatch != null) {
                  parentTableName = parentMatch.group(1)!.trim();
                  break;
                }
              }
              parentNode = parentNode.parent;
            }

            // 親が見つからない場合（ルートレベル）、直前のテーブル定義を探す
            if (parentTableName == null) {
              for (int i = hierarchyNodes.length - 1; i >= 0; i--) {
                final rootNode = hierarchyNodes[i];
                if (rootNode.isTableDefinition) {
                  parentTableName = rootNode.tableName;
                  break;
                }
              }
            }

            if (parentTableName != null) {
              relationships.add(DMRelationship(
                parentTable: parentTableName,
                childTable: childTableName,
                type: relationshipType,
              ));
            } else {
              errors.add(DMAnalysisError(
                line: node.lineInfo.lineNumber,
                column: 0,
                message: '関係性行の親テーブルが見つかりません: ${node.lineInfo.trimmedLine}',
                type: DMErrorType.semanticError,
              ));
            }
          } else {
            errors.add(DMAnalysisError(
              line: node.lineInfo.lineNumber,
              column: 0,
              message: '関係性行から子テーブル名を抽出できませんでした: ${node.lineInfo.trimmedLine}',
              type: DMErrorType.syntaxError,
            ));
          }
        }
      }

      for (final child in node.children) {
        processNode(child);
      }
    }

    for (final rootNode in hierarchyNodes) {
      processNode(rootNode);
    }

    return _RelationshipExtractionResult.mixed(relationships, errors);
  }

  /// 関係性行からコンテンツ部分を抽出
  String _extractRelationshipContent(String line) {
    if (line.startsWith('--')) return line.substring(2).trim();
    if (line.startsWith('->')) return line.substring(2).trim();
    if (line.startsWith('??')) return line.substring(2).trim();
    return line;
  }

  /// 階層情報を活用して外部キーを解決
  _ForeignKeyResolutionResult _resolveForeignKeysWithHierarchy(List<DMTable> tables, List<DMRelationship> relationships) {
    final errors = <DMAnalysisError>[];
    final relationshipMap = <String, List<DMRelationship>>{};

    // 関係性をマップに整理
    for (final rel in relationships) {
      relationshipMap.putIfAbsent(rel.childTable, () => []).add(rel);
    }

    // 各テーブルの外部キーを解決
    for (final table in tables) {
      for (final fk in table.foreignKeys) {
        bool resolved = false;

        // 1. 階層関係から参照先を特定
        final parentRelations = relationshipMap[table.sqlName] ?? [];
        for (final relation in parentRelations) {
          if (relation.type == DMRelationshipType.cascade && fk.columnName.contains(relation.parentTable)) {
            fk.referencedTable = relation.parentTable;
            resolved = true;
            break;
          }
        }

        if (resolved) continue;

        // 2. 明示的参照関係から特定
        for (final relation in relationships) {
          if (relation.type == DMRelationshipType.reference &&
              relation.childTable == table.sqlName &&
              fk.columnName.contains(relation.parentTable)) {
            fk.referencedTable = relation.parentTable;
            resolved = true;
            break;
          }
        }

        if (resolved) continue;

        // 3. フォールバック: 既存の推測ロジック
        final inferredTable = _inferTableFromColumnName(fk.columnName);
        if (inferredTable != 'unknown') {
          fk.referencedTable = inferredTable;
        }
      }
    }

    return _ForeignKeyResolutionResult.success();
  }

  /// カラム名から参照テーブルを推測（既存ロジック改良版）
  String _inferTableFromColumnName(String columnName) {
    if (!columnName.endsWith('_id')) return 'unknown';

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
        tableName = parts.last;
      }
    }

    // 役割マッピングを適用
    final mappedTable = roleToTable[tableName] ?? tableName;

    // 複合参照の処理（original_reservation → reservation）
    if (mappedTable.contains('_') && !_isCompoundWord(mappedTable)) {
      final parts = mappedTable.split('_');
      if (parts.length >= 2) {
        return parts.last;
      }
    }

    return mappedTable;
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
      if (current.isTableDefinition) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }

  /// このノードがテーブル定義ノードかどうか
  bool get isTableDefinition {
    return !lineInfo.isRelationship &&
           lineInfo.trimmedLine.contains('{') &&
           lineInfo.trimmedLine.contains('}:');
  }

  /// このノードのテーブル名を取得（テーブル定義ノードの場合）
  String? get tableName {
    if (!isTableDefinition) return null;
    final match = RegExp(r'\{([^}]+)\}:').firstMatch(lineInfo.trimmedLine);
    return match?.group(1)?.trim();
  }

  /// このノードの関係性タイプを取得（関係性ノードの場合）
  DMRelationshipType? get relationshipType {
    if (!lineInfo.isRelationship) return null;
    final line = lineInfo.trimmedLine;
    if (line.startsWith('--')) return DMRelationshipType.cascade;
    if (line.startsWith('->')) return DMRelationshipType.reference;
    if (line.startsWith('??')) return DMRelationshipType.weak;
    return null;
  }

  /// 全ての子孫ノードを深さ優先で取得
  List<_HierarchyNode> getAllDescendants() {
    final descendants = <_HierarchyNode>[];
    for (final child in children) {
      descendants.add(child);
      descendants.addAll(child.getAllDescendants());
    }
    return descendants;
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

/// テーブル抽出結果
class _TableExtractionResult {
  final List<DMTable> tables;
  final List<DMAnalysisError> errors;

  const _TableExtractionResult._(this.tables, this.errors);

  factory _TableExtractionResult.success(List<DMTable> tables) {
    return _TableExtractionResult._(tables, []);
  }

  factory _TableExtractionResult.failure(List<DMAnalysisError> errors) {
    return _TableExtractionResult._([], errors);
  }

  factory _TableExtractionResult.mixed(List<DMTable> tables, List<DMAnalysisError> errors) {
    return _TableExtractionResult._(tables, errors);
  }
}

/// 関係性抽出結果
class _RelationshipExtractionResult {
  final List<DMRelationship> relationships;
  final List<DMAnalysisError> errors;

  const _RelationshipExtractionResult._(this.relationships, this.errors);

  factory _RelationshipExtractionResult.success(List<DMRelationship> relationships) {
    return _RelationshipExtractionResult._(relationships, []);
  }

  factory _RelationshipExtractionResult.failure(List<DMAnalysisError> errors) {
    return _RelationshipExtractionResult._([], errors);
  }

  factory _RelationshipExtractionResult.mixed(List<DMRelationship> relationships, List<DMAnalysisError> errors) {
    return _RelationshipExtractionResult._(relationships, errors);
  }
}

/// 外部キー解決結果
class _ForeignKeyResolutionResult {
  final List<DMAnalysisError> errors;

  const _ForeignKeyResolutionResult._(this.errors);

  factory _ForeignKeyResolutionResult.success() {
    return _ForeignKeyResolutionResult._([]);
  }

  factory _ForeignKeyResolutionResult.failure(List<DMAnalysisError> errors) {
    return _ForeignKeyResolutionResult._(errors);
  }
}