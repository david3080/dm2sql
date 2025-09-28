/// DMNotationAnalyzerのテストケース
/// インデント構造解析の検証
import 'package:flutter_test/flutter_test.dart';
import '../../lib/analysis/dm_notation_analyzer.dart';
import '../../lib/analysis/results/dm_database.dart';
import '../../lib/analysis/results/dm_table.dart';

void main() {
  group('DMNotationAnalyzer インデント構造解析テスト', () {
    test('シンプルな階層構造の解析', () {
      const dmNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}, メール{email:string@}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int}), 注文日時{order_date:datetime!}
   -- 注文明細{order_detail}: [明細ID{id:int}], (注文ID{order_id:int}), (商品ID{product_id:int})

商品{product}: [商品ID{id:int}], 商品名{name:string!}, 価格{price:int!}
''';

      final result = DMNotationAnalyzer.analyze(dmNotation);

      expect(result.isSuccess, isTrue);
      expect(result.database, isNotNull);

      final db = result.database!;
      expect(db.tables.length, equals(4)); // customer, order, order_detail, product

      // 階層関係の検証
      expect(db.relationships.length, equals(2));

      // customer -> order の関係
      final customerOrderRel = db.relationships.firstWhere(
        (r) => r.parentTable == 'customer' && r.childTable == 'order'
      );
      expect(customerOrderRel.type, equals(DMRelationshipType.cascade));

      // order -> order_detail の関係
      final orderDetailRel = db.relationships.firstWhere(
        (r) => r.parentTable == 'order' && r.childTable == 'order_detail'
      );
      expect(orderDetailRel.type, equals(DMRelationshipType.cascade));

      // 外部キーの解決確認
      final orderTable = db.tables.firstWhere((t) => t.sqlName == 'order');
      final customerIdFk = orderTable.foreignKeys.firstWhere((fk) => fk.columnName == 'customer_id');
      expect(customerIdFk.referencedTable, equals('customer'));

      final orderDetailTable = db.tables.firstWhere((t) => t.sqlName == 'order_detail');
      final orderIdFk = orderDetailTable.foreignKeys.firstWhere((fk) => fk.columnName == 'order_id');
      expect(orderIdFk.referencedTable, equals('order'));
    });

    test('複雑な階層構造とクロス参照の解析', () {
      const dmNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int}), 注文日時{order_date:datetime!}
   -- 注文明細{order_detail}: [明細ID{id:int}], (注文ID{order_id:int}), (商品ID{product_id:int})
      -> 商品{product}: [商品ID{id:int}], 商品名{name:string!}, 価格{price:int!}

カテゴリ{category}: [カテゴリID{id:int}], カテゴリ名{name:string!}
-> 商品{product}
''';

      final result = DMNotationAnalyzer.analyze(dmNotation);

      expect(result.isSuccess, isTrue);
      expect(result.database, isNotNull);

      final db = result.database!;
      expect(db.tables.length, equals(5)); // customer, order, order_detail, product, category

      // 関係性の検証
      expect(db.relationships.length, equals(4));

      // カテゴリから商品への参照関係
      final categoryProductRel = db.relationships.where(
        (r) => r.parentTable == 'category' && r.childTable == 'product'
      );
      expect(categoryProductRel.isNotEmpty, isTrue);
      expect(categoryProductRel.first.type, equals(DMRelationshipType.reference));

      // 注文明細から商品への参照関係
      final orderDetailProductRel = db.relationships.where(
        (r) => r.parentTable == 'order_detail' && r.childTable == 'product'
      );
      expect(orderDetailProductRel.isNotEmpty, isTrue);
      expect(orderDetailProductRel.first.type, equals(DMRelationshipType.reference));
    });

    test('エラーケース：親テーブルのない関係性', () {
      const dmNotation = '''
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int})
''';

      final result = DMNotationAnalyzer.analyze(dmNotation);

      expect(result.isSuccess, isFalse);
      expect(result.errors.isNotEmpty, isTrue);
      expect(result.errors.first.type, equals(DMErrorType.semanticError));
      expect(result.errors.first.message, contains('親テーブルが見つかりません'));
    });

    test('インデントレベルの一貫性チェック', () {
      const dmNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int})
      -- 注文明細{order_detail}: [明細ID{id:int}], (注文ID{order_id:int})  // 4スペース（正しくは2スペース）
''';

      final result = DMNotationAnalyzer.analyze(dmNotation);

      // インデントエラーがあっても解析は成功するが、階層が正しく認識される
      expect(result.isSuccess, isTrue);

      final db = result.database!;
      final orderDetailTable = db.tables.firstWhere((t) => t.sqlName == 'order_detail');
      final orderIdFk = orderDetailTable.foreignKeys.firstWhere((fk) => fk.columnName == 'order_id');
      expect(orderIdFk.referencedTable, equals('order'));
    });

    test('推測ロジックのフォールバック', () {
      const dmNotation = '''
商品{product}: [商品ID{id:int}], 商品名{name:string!}

レビュー{review}: [レビューID{id:int}], (商品ID{product_id:int}), (投稿者ID{author_id:int})
''';

      final result = DMNotationAnalyzer.analyze(dmNotation);

      expect(result.isSuccess, isTrue);

      final db = result.database!;
      final reviewTable = db.tables.firstWhere((t) => t.sqlName == 'review');

      // product_id は推測で product を参照
      final productIdFk = reviewTable.foreignKeys.firstWhere((fk) => fk.columnName == 'product_id');
      expect(productIdFk.referencedTable, equals('product'));

      // author_id は推測で user を参照（role mapping）
      final authorIdFk = reviewTable.foreignKeys.firstWhere((fk) => fk.columnName == 'author_id');
      expect(authorIdFk.referencedTable, equals('user'));
    });

    test('複合語の外部キー推測', () {
      const dmNotation = '''
発注書{purchase_order}: [発注書ID{id:int}], 発注日{order_date:datetime!}

在庫移動{stock_movement}: [移動ID{id:int}], (発注書ID{purchase_order_id:int}), (移動元倉庫ID{from_warehouse_id:int})

倉庫{warehouse}: [倉庫ID{id:int}], 倉庫名{name:string!}
''';

      final result = DMNotationAnalyzer.analyze(dmNotation);

      expect(result.isSuccess, isTrue);

      final db = result.database!;
      final stockMovementTable = db.tables.firstWhere((t) => t.sqlName == 'stock_movement');

      // purchase_order_id は複合語として認識されて purchase_order を参照
      final purchaseOrderIdFk = stockMovementTable.foreignKeys.firstWhere((fk) => fk.columnName == 'purchase_order_id');
      expect(purchaseOrderIdFk.referencedTable, equals('purchase_order'));

      // from_warehouse_id は from プレフィックスを除去して warehouse を参照
      final fromWarehouseIdFk = stockMovementTable.foreignKeys.firstWhere((fk) => fk.columnName == 'from_warehouse_id');
      expect(fromWarehouseIdFk.referencedTable, equals('warehouse'));
    });
  });
}