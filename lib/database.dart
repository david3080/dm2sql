import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'analysis/dm_sample_data_inserter.dart';
import 'analysis/results/dm_database.dart';
import 'asset_loader.dart';

/// 最小限のDriftデータベース
/// 自動生成に依存せず、Web WASM接続管理のみを利用
class MinimalDatabase extends GeneratedDatabase {
  MinimalDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => [];

  // 生SQL実行メソッド
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Variable>? arguments]) async {
    final result = await customSelect(sql, variables: arguments ?? []).get();
    return result.map((row) => row.data).toList();
  }

  // 生SQL実行（戻り値なし）
  Future<void> rawExecute(String sql, [List<Variable>? arguments]) async {
    await customStatement(sql, arguments ?? []);
  }

  // 挿入実行
  Future<int> rawInsert(String sql, [List<Variable>? arguments]) async {
    return await customInsert(sql, variables: arguments ?? []);
  }

  // デモ用の初期データ作成
  Future<void> setupDemoData() async {
    // 顧客テーブル作成
    await rawExecute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE,
        address TEXT,
        phone TEXT,
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // 商品テーブル作成
    await rawExecute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        price INTEGER NOT NULL,
        stock INTEGER DEFAULT 0,
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // データ存在チェック
    final customerCount = await rawQuery('SELECT COUNT(*) as count FROM customers');
    final productCount = await rawQuery('SELECT COUNT(*) as count FROM products');

    // 初期データ挿入
    if (customerCount.first['count'] == 0) {
      await rawExecute('''
        INSERT INTO customers (name, email, address, phone) VALUES
        ('山田太郎', 'yamada@example.com', '東京都渋谷区1-1-1', '090-1234-5678'),
        ('佐藤花子', 'sato@example.com', '大阪府大阪市2-2-2', '090-9876-5432'),
        ('田中次郎', 'tanaka@example.com', '名古屋市中区3-3-3', '090-5555-7777')
      ''');
    }

    if (productCount.first['count'] == 0) {
      await rawExecute('''
        INSERT INTO products (name, description, price, stock) VALUES
        ('Webカメラ', '高画質1080p対応Webカメラ', 5980, 15),
        ('ワイヤレスマウス', '静音設計のワイヤレスマウス', 2480, 25),
        ('キーボード', 'メカニカルキーボード', 8900, 8),
        ('モニタースタンド', '高さ調整可能なモニタースタンド', 3200, 12)
      ''');
    }
  }

  // デモ用データ取得
  Future<List<Map<String, dynamic>>> getAllCustomers() {
    return rawQuery('SELECT * FROM customers ORDER BY created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getAllProducts() {
    return rawQuery('SELECT * FROM products ORDER BY created_at DESC');
  }

  /// DMNotationデータベース定義からスキーマを作成
  Future<void> setupFromDMDatabase(DMDatabase dmDatabase) async {
    try {
      if (kDebugMode) {
        print('=== データベースセットアップ開始 ===');
        print('データベース名: ${dmDatabase.name}');
        print('バージョン: ${dmDatabase.version}');
      }

      // 既存のデータとテーブルをクリア（開発用）
      if (kDebugMode) {
        print('既存データクリア中...');
      }
      await DMSampleDataInserter.clearAllTables(this, dmDatabase);

      // 強制的にテーブルを削除（スキーマ変更対応）
      if (kDebugMode) {
        print('既存テーブル削除中...');
      }
      await _dropAllTables(dmDatabase);

      // テーブル作成文を依存関係順に実行
      final createStatements = dmDatabase.generateCreateStatements();
      if (kDebugMode) {
        print('テーブル作成中... (${createStatements.length}文)');
      }

      for (int i = 0; i < createStatements.length; i++) {
        final statement = createStatements[i];
        if (kDebugMode) {
          print('  SQL ${i + 1}: ${statement.length > 100 ? statement.substring(0, 100) + '...' : statement}');
        }
        await rawExecute(statement);
      }

      if (kDebugMode) {
        print('テーブル作成完了');
      }

      // サンプルデータを挿入
      if (dmDatabase.sampleData.isNotEmpty) {
        if (kDebugMode) {
          print('サンプルデータ挿入開始...');
        }
        try {
          final insertResult = await DMSampleDataInserter.insertSampleData(this, dmDatabase);

          if (!insertResult.isSuccess) {
            if (kDebugMode) {
              print('サンプルデータ挿入エラー:');
              for (final error in insertResult.errors) {
                print('  - $error');
              }
            }
            // エラーがあってもデータベース初期化は続行
          } else {
            if (kDebugMode) {
              print(insertResult.summaryMessage);
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('サンプルデータ挿入中に例外発生: $e');
            print('スタックトレース: ${StackTrace.current}');
          }
          // 例外があってもデータベース初期化は続行
        }
      } else {
        if (kDebugMode) {
          print('サンプルデータなし - スキップ');
        }
      }

      if (kDebugMode) {
        print('=== データベースセットアップ完了 ===');
      }
    } catch (e) {
      if (kDebugMode) {
        print('=== データベースセットアップ失敗 ===');
        print('エラー: $e');
        print('スタックトレース: ${StackTrace.current}');
      }
      rethrow;
    }
  }

  /// 既存テーブルを強制削除
  Future<void> _dropAllTables(DMDatabase dmDatabase) async {
    try {
      // 外部キー制約を一時的に無効化
      await customStatement('PRAGMA foreign_keys = OFF');

      // 依存関係の逆順でテーブルを削除
      final reversedTables = dmDatabase.tablesInDependencyOrder.reversed;

      for (final table in reversedTables) {
        try {
          if (kDebugMode) {
            print('  テーブル ${table.sqlName} を削除中...');
          }
          await customStatement('DROP TABLE IF EXISTS `${table.sqlName}`');
        } catch (e) {
          if (kDebugMode) {
            print('  テーブル ${table.sqlName} の削除でエラー: $e - 継続');
          }
        }
      }

      // 外部キー制約を再有効化
      await customStatement('PRAGMA foreign_keys = ON');

      if (kDebugMode) {
        print('既存テーブル削除完了');
      }
    } catch (e) {
      if (kDebugMode) {
        print('テーブル削除中にエラー: $e');
      }
    }
  }

  /// DMNotationスキーマからデータベースを初期化
  Future<void> setupFromDMNotationSchema(String schemaName) async {
    try {
      // AssetLoaderを使用してスキーマを読み込み・パース
      final dmDatabase = await DMNotationAssetLoader.loadAndParseSchema(schemaName);

      // データベーススキーマとサンプルデータをセットアップ
      await setupFromDMDatabase(dmDatabase);
    } catch (e) {
      if (kDebugMode) {
        print('DMNotationスキーマ「$schemaName」のセットアップエラー: $e');
      }
      rethrow;
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Web用の設定
    if (kIsWeb) {
      // Webプラットフォームの場合
      return DatabaseConnection.delayed(Future(() async {
        final result = await WasmDatabase.open(
          databaseName: 'dm2sql_db',
          sqlite3Uri: Uri.parse('sqlite3.wasm'),
          driftWorkerUri: Uri.parse('drift_worker.dart.js'),
        );
        return result.resolvedExecutor;
      }));
    }

    // モバイル/デスクトップ用の設定（この部分は後で実装）
    throw UnsupportedError('Native platforms not yet supported in this example');
  });
}