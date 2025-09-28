/// アセットファイル読み込み機能
library;

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'main.dart' show kVerboseLogging;
import 'analysis/dm_notation_analyzer.dart';
import 'analysis/results/dm_database.dart';

/// DMNotationアセットローダー
class DMNotationAssetLoader {
  static const Map<String, String> _assetFiles = {
    'シンプルテスト': 'assets/simple_test.dm',
    'ECサイト': 'assets/ecommerce.dm',
    '在庫管理': 'assets/inventory.dm',
    '社員管理': 'assets/employee.dm',
    '備品予約': 'assets/equipment_reservation.dm',
    'ブログ': 'assets/blog.dm',
  };

  /// 利用可能なスキーマ一覧を取得
  static List<String> getAvailableSchemas() {
    return _assetFiles.keys.toList();
  }

  /// 指定したスキーマのDMNotationテキストを読み込み
  static Future<String> loadSchemaText(String schemaName) async {
    if (kDebugMode) {
      print('=== AssetLoader: スキーマ読み込み開始 ===');
      print('スキーマ名: $schemaName');
    }

    final assetPath = _assetFiles[schemaName];
    if (assetPath == null) {
      if (kDebugMode) {
        print('エラー: スキーマ "$schemaName" が見つかりません');
        print('利用可能なスキーマ: ${_assetFiles.keys.join(', ')}');
      }
      throw ArgumentError('Schema "$schemaName" not found');
    }

    if (kDebugMode) {
      print('アセットパス: $assetPath');
    }

    try {
      final content = await rootBundle.loadString(assetPath);
      if (kDebugMode) {
        print('読み込み成功: ${content.length}文字');
        print('最初の200文字: ${content.length > 200 ? content.substring(0, 200) + '...' : content}');
      }
      return content;
    } catch (e) {
      if (kDebugMode) {
        print('読み込み失敗: $e');
      }
      throw Exception('Failed to load schema "$schemaName": $e');
    }
  }

  /// 指定したスキーマをパースしてDMDatabaseを取得
  static Future<DMDatabase> loadAndParseSchema(String schemaName) async {
    if (kDebugMode && kVerboseLogging) {
      print('=== AssetLoader: スキーマ解析開始 ===');
    }

    final dmNotationText = await loadSchemaText(schemaName);

    if (kDebugMode && kVerboseLogging) {
      print('DMNotationAnalyzer.analyze() 呼び出し中...');
    }

    final analysisResult = DMNotationAnalyzer.analyze(dmNotationText, databaseName: schemaName);

    if (kDebugMode && kVerboseLogging) {
      print('解析結果: ${analysisResult.isSuccess ? '成功' : '失敗'}');
      if (analysisResult.isSuccess) {
        print('データベース名: ${analysisResult.database?.name}');
        print('テーブル数: ${analysisResult.database?.tables.length}');
        print('サンプルデータ数: ${analysisResult.database?.sampleData.length}');
      } else {
        print('エラー数: ${analysisResult.errors.length}');
        for (final error in analysisResult.errors) {
          print('  - $error');
        }
      }
    }

    if (!analysisResult.isSuccess) {
      final errorMessages = analysisResult.errors.map((e) => e.toString()).join('\\n');
      if (kDebugMode) {
        print('解析失敗のため例外をスロー');
      }
      throw Exception('Failed to analyze schema "$schemaName":\\n$errorMessages');
    }

    if (kDebugMode && kVerboseLogging) {
      print('=== AssetLoader: スキーマ解析完了 ===');
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