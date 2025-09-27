/// アセットファイル読み込み機能
library;

import 'package:flutter/services.dart';
import 'analysis/dm_notation_analyzer.dart';
import 'analysis/results/dm_database.dart';

/// DMNotationアセットローダー
class DMNotationAssetLoader {
  static const Map<String, String> _assetFiles = {
    'シンプルテスト': 'assets/simple_test.dmnotation',
    'ECサイト': 'assets/ecommerce.dmnotation',
    '在庫管理': 'assets/inventory.dmnotation',
    '社員管理': 'assets/employee.dmnotation',
    '備品予約': 'assets/equipment_reservation.dmnotation',
    'ブログ': 'assets/blog.dmnotation',
  };

  /// 利用可能なスキーマ一覧を取得
  static List<String> getAvailableSchemas() {
    return _assetFiles.keys.toList();
  }

  /// 指定したスキーマのDMNotationテキストを読み込み
  static Future<String> loadSchemaText(String schemaName) async {
    final assetPath = _assetFiles[schemaName];
    if (assetPath == null) {
      throw ArgumentError('Schema "$schemaName" not found');
    }

    try {
      return await rootBundle.loadString(assetPath);
    } catch (e) {
      throw Exception('Failed to load schema "$schemaName": $e');
    }
  }

  /// 指定したスキーマをパースしてDMDatabaseを取得
  static Future<DMDatabase> loadAndParseSchema(String schemaName) async {
    final dmNotationText = await loadSchemaText(schemaName);
    final analysisResult = DMNotationAnalyzer.analyze(dmNotationText, databaseName: schemaName);

    if (!analysisResult.isSuccess) {
      final errorMessages = analysisResult.errors.map((e) => e.toString()).join('\\n');
      throw Exception('Failed to analyze schema "$schemaName":\\n$errorMessages');
    }

    return analysisResult.database!;
  }

  /// 全スキーマを読み込み・パース
  static Future<Map<String, DMDatabase>> loadAllSchemas() async {
    final schemas = <String, DMDatabase>{};

    for (final schemaName in _assetFiles.keys) {
      try {
        schemas[schemaName] = await loadAndParseSchema(schemaName);
      } catch (e) {
        // エラーログを出力して継続
        // print('Warning: Failed to load schema "$schemaName": $e');
      }
    }

    return schemas;
  }

  /// スキーマの簡易情報を取得
  static Future<Map<String, SchemaInfo>> getSchemaInfos() async {
    final infos = <String, SchemaInfo>{};

    for (final schemaName in _assetFiles.keys) {
      try {
        final database = await loadAndParseSchema(schemaName);
        infos[schemaName] = SchemaInfo(
          name: schemaName,
          tableCount: database.tables.length,
          relationshipCount: database.relationships.length,
          description: _getSchemaDescription(schemaName),
        );
      } catch (e) {
        infos[schemaName] = SchemaInfo(
          name: schemaName,
          tableCount: 0,
          relationshipCount: 0,
          description: 'パースエラー: $e',
        );
      }
    }

    return infos;
  }

  /// スキーマの説明テキストを取得
  static String _getSchemaDescription(String schemaName) {
    const descriptions = {
      'シンプルテスト': 'パーサーテスト用のシンプルなテーブル定義',
      'ECサイト': '顧客・注文・商品・レビューなど電子商取引システムの完全なデータモデル',
      '在庫管理': '商品・倉庫・入出庫・棚卸など在庫管理システムのデータモデル',
      '社員管理': '社員・勤怠・給与・評価など人事管理システムのデータモデル',
      '備品予約': '備品・予約・利用履歴など施設管理システムのデータモデル',
      'ブログ': 'ユーザー・投稿・コメント・タグなどCMSのデータモデル',
    };

    return descriptions[schemaName] ?? '詳細なデータモデル';
  }
}

/// スキーマ情報クラス
class SchemaInfo {
  final String name;
  final int tableCount;
  final int relationshipCount;
  final String description;

  const SchemaInfo({
    required this.name,
    required this.tableCount,
    required this.relationshipCount,
    required this.description,
  });
}