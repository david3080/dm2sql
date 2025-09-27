/// drift_devのDriftDatabaseを参考にした動的データベース定義
library;

import 'dm_table.dart';
import 'dm_constraint.dart';

/// DMNotationから解析されたデータベース全体の定義
/// drift_devのDriftDatabaseクラスを参考に設計
class DMDatabase {
  /// データベース名
  final String name;

  /// データベースのバージョン
  final int version;

  /// データベース内のテーブル一覧
  final List<DMTable> tables;

  /// データベース間の関係性一覧
  final List<DMRelationship> relationships;

  /// データベースレベルのインデックス
  final List<DMIndex> indexes;

  /// データベースのコメント・説明
  final String? comment;

  const DMDatabase({
    required this.name,
    required this.version,
    required this.tables,
    this.relationships = const [],
    this.indexes = const [],
    this.comment,
  });

  /// 指定した名前のテーブルを検索
  DMTable? findTable(String tableName) {
    try {
      return tables.firstWhere((table) => table.sqlName == tableName);
    } catch (e) {
      return null;
    }
  }

  /// テーブルが存在するかチェック
  bool hasTable(String tableName) {
    return findTable(tableName) != null;
  }

  /// 全テーブル名のリスト
  List<String> get tableNames {
    return tables.map((table) => table.sqlName).toList();
  }

  /// 依存関係順にソートされたテーブル一覧
  /// 外部キーの参照先テーブルを先に作成する順序
  List<DMTable> get tablesInDependencyOrder {
    final sorted = <DMTable>[];
    final remaining = List<DMTable>.from(tables);
    final tableMap = {for (var t in tables) t.sqlName: t};

    while (remaining.isNotEmpty) {
      final added = <DMTable>[];

      for (final table in remaining) {
        // このテーブルが依存する他のテーブル
        final dependencies = table.foreignKeys
            .map((fk) => fk.referencedTable)
            .where((ref) => tableMap.containsKey(ref))
            .toList();

        // 依存するテーブルがすべて作成済みの場合
        if (dependencies.every((dep) => sorted.any((t) => t.sqlName == dep))) {
          sorted.add(table);
          added.add(table);
        }
      }

      // 循環参照対策：進捗がない場合は残りをそのまま追加
      if (added.isEmpty && remaining.isNotEmpty) {
        sorted.addAll(remaining);
        break;
      }

      remaining.removeWhere((table) => added.contains(table));
    }

    return sorted;
  }

  /// データベース全体のCREATE文群を生成
  List<String> generateCreateStatements() {
    final statements = <String>[];

    // テーブル作成文（依存関係順）
    for (final table in tablesInDependencyOrder) {
      statements.add(table.generateCreateTableSQL());
    }

    // インデックス作成文
    for (final index in indexes) {
      statements.add(index.createIndexSQL);
    }

    // 推奨インデックス（カラムの*制約から）
    for (final table in tables) {
      for (final column in table.indexedColumns) {
        final indexName = '${table.sqlName}_${column.sqlName}_idx';
        statements.add('CREATE INDEX IF NOT EXISTS `$indexName` ON `${table.sqlName}` (${column.sqlName})');
      }
    }

    return statements;
  }

  /// 外部キー制約の検証
  List<String> validateForeignKeys() {
    final errors = <String>[];

    for (final table in tables) {
      for (final fk in table.foreignKeys) {
        final referencedTable = findTable(fk.referencedTable);
        if (referencedTable == null) {
          errors.add('テーブル "${table.sqlName}" の外部キー "${fk.columnName}" が参照するテーブル "${fk.referencedTable}" が存在しません');
          continue;
        }

        final referencedColumn = referencedTable.findColumn(fk.referencedColumn);
        if (referencedColumn == null && fk.referencedColumn != referencedTable.primaryKey.columnName) {
          errors.add('テーブル "${table.sqlName}" の外部キー "${fk.columnName}" が参照するカラム "${fk.referencedTable}.${fk.referencedColumn}" が存在しません');
        }
      }
    }

    return errors;
  }

  /// データベース情報のサマリー
  Map<String, dynamic> get summary {
    return {
      'name': name,
      'version': version,
      'tableCount': tables.length,
      'relationshipCount': relationships.length,
      'indexCount': indexes.length,
      'totalColumns': tables.fold<int>(0, (sum, table) => sum + table.allColumns.length),
      'totalForeignKeys': tables.fold<int>(0, (sum, table) => sum + table.foreignKeys.length),
    };
  }

  @override
  String toString() {
    return 'DMDatabase{name: $name, version: $version, tables: ${tables.length}}';
  }
}

/// テーブル間の関係性定義
class DMRelationship {
  /// 親テーブル名
  final String parentTable;

  /// 子テーブル名
  final String childTable;

  /// 関係性の種類
  final DMRelationshipType type;

  /// 関係性の説明
  final String? description;

  const DMRelationship({
    required this.parentTable,
    required this.childTable,
    required this.type,
    this.description,
  });

  @override
  String toString() {
    return 'DMRelationship{parent: $parentTable, child: $childTable, type: $type}';
  }
}

/// 関係性の種類（DMNotation記法対応）
enum DMRelationshipType {
  cascade('--'),    // カスケード削除
  reference('->'),  // 参照関係
  weak('??');       // 弱参照

  const DMRelationshipType(this.notation);

  /// DMNotation記法の記号
  final String notation;

  /// 記号から関係性タイプに変換
  static DMRelationshipType? fromNotation(String notation) {
    for (final type in DMRelationshipType.values) {
      if (type.notation == notation) {
        return type;
      }
    }
    return null;
  }

  /// 対応するForeignKeyAction
  DMForeignKeyAction get foreignKeyAction {
    switch (this) {
      case DMRelationshipType.cascade:
        return DMForeignKeyAction.cascade;
      case DMRelationshipType.reference:
        return DMForeignKeyAction.restrict;
      case DMRelationshipType.weak:
        return DMForeignKeyAction.setNull;
    }
  }
}