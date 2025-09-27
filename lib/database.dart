import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

part 'database.g.dart';

// テーブル定義: 顧客テーブル
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get email => text().unique()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// テーブル定義: 商品テーブル
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  IntColumn get price => integer()();
  IntColumn get stock => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// データベースクラス
@DriftDatabase(tables: [Customers, Products])
class MyDatabase extends _$MyDatabase {
  MyDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // 顧客データの初期化
  Future<void> insertInitialCustomers() async {
    await batch((batch) {
      batch.insertAll(customers, [
        CustomersCompanion.insert(
          name: '山田太郎',
          email: 'yamada@example.com',
          address: const Value('東京都渋谷区1-1-1'),
          phone: const Value('090-1234-5678'),
        ),
        CustomersCompanion.insert(
          name: '佐藤花子',
          email: 'sato@example.com',
          address: const Value('大阪府大阪市2-2-2'),
          phone: const Value('090-9876-5432'),
        ),
        CustomersCompanion.insert(
          name: '田中次郎',
          email: 'tanaka@example.com',
          address: const Value('名古屋市中区3-3-3'),
          phone: const Value('090-5555-7777'),
        ),
      ]);
    });
  }

  // 商品データの初期化
  Future<void> insertInitialProducts() async {
    await batch((batch) {
      batch.insertAll(products, [
        ProductsCompanion.insert(
          name: 'Webカメラ',
          description: const Value('高画質1080p対応Webカメラ'),
          price: 5980,
          stock: const Value(15),
        ),
        ProductsCompanion.insert(
          name: 'ワイヤレスマウス',
          description: const Value('静音設計のワイヤレスマウス'),
          price: 2480,
          stock: const Value(25),
        ),
        ProductsCompanion.insert(
          name: 'キーボード',
          description: const Value('メカニカルキーボード'),
          price: 8900,
          stock: const Value(8),
        ),
        ProductsCompanion.insert(
          name: 'モニタースタンド',
          description: const Value('高さ調整可能なモニタースタンド'),
          price: 3200,
          stock: const Value(12),
        ),
      ]);
    });
  }

  // すべての顧客を取得
  Future<List<Customer>> getAllCustomers() {
    return select(customers).get();
  }

  // すべての商品を取得
  Future<List<Product>> getAllProducts() {
    return select(products).get();
  }

  // 初期データのセットアップ
  Future<void> setupInitialData() async {
    final customerCount = await (selectOnly(customers)..addColumns([customers.id.count()])).getSingle();
    final productCount = await (selectOnly(products)..addColumns([products.id.count()])).getSingle();

    if (customerCount.read(customers.id.count()) == 0) {
      await insertInitialCustomers();
    }

    if (productCount.read(products.id.count()) == 0) {
      await insertInitialProducts();
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