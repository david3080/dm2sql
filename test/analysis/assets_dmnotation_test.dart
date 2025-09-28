/// assets配下の全DMNotationファイルの包括的テスト
/// インデント構造解析の実用性を検証
library;

import 'package:flutter_test/flutter_test.dart';
import '../../lib/analysis/dm_notation_analyzer.dart';
import '../../lib/analysis/results/dm_database.dart';
import 'dart:io';

void main() {
  group('Assets DMNotation Files テスト', () {
    late Map<String, String> dmNotationFiles;

    setUpAll(() async {
      // assets配下の全.dmnotationファイルを読み込み
      dmNotationFiles = {
        'simple_test': await File('assets/simple_test.dmnotation').readAsString(),
        'ecommerce': await File('assets/ecommerce.dmnotation').readAsString(),
        'inventory': await File('assets/inventory.dmnotation').readAsString(),
        'employee': await File('assets/employee.dmnotation').readAsString(),
        'equipment_reservation': await File('assets/equipment_reservation.dmnotation').readAsString(),
        'blog': await File('assets/blog.dmnotation').readAsString(),
      };
    });

    test('simple_test.dmnotation の解析', () {
      final result = DMNotationAnalyzer.analyze(dmNotationFiles['simple_test']!);

      expect(result.isSuccess, isTrue);
      expect(result.database, isNotNull);

      final db = result.database!;
      expect(db.tables.length, equals(3)); // customer, product, order

      // テーブル存在確認
      final tableNames = db.tables.map((t) => t.sqlName).toSet();
      expect(tableNames, containsAll(['customer', 'product', 'order']));

      // 外部キー確認
      final orderTable = db.tables.firstWhere((t) => t.sqlName == 'order');
      expect(orderTable.foreignKeys.length, equals(1));
      expect(orderTable.foreignKeys.first.columnName, equals('customer_id'));
      expect(orderTable.foreignKeys.first.referencedTable, equals('customer'));
    });

    test('ecommerce.dmnotation の解析 - 複雑な階層構造', () {
      final result = DMNotationAnalyzer.analyze(dmNotationFiles['ecommerce']!);

      expect(result.isSuccess, isTrue);
      expect(result.database, isNotNull);

      final db = result.database!;

      // 主要テーブルの存在確認
      final tableNames = db.tables.map((t) => t.sqlName).toSet();
      expect(tableNames, containsAll([
        'customer', 'order', 'order_detail', 'product', 'category', 'brand',
        'favorite', 'cart', 'review', 'coupon', 'coupon_usage', 'shipping_method'
      ]));

      // 階層関係の確認
      expect(db.relationships.isNotEmpty, isTrue);

      // customer -> order の関係
      final customerOrderRel = db.relationships.where(
        (r) => r.parentTable == 'customer' && r.childTable == 'order'
      );
      expect(customerOrderRel.isNotEmpty, isTrue);
      expect(customerOrderRel.first.type, equals(DMRelationshipType.cascade));

      // order -> order_detail の関係
      final orderDetailRel = db.relationships.where(
        (r) => r.parentTable == 'order' && r.childTable == 'order_detail'
      );
      expect(orderDetailRel.isNotEmpty, isTrue);
      expect(orderDetailRel.first.type, equals(DMRelationshipType.cascade));

      // 外部キー解決の確認
      final orderDetailTable = db.tables.firstWhere((t) => t.sqlName == 'order_detail');
      final orderIdFk = orderDetailTable.foreignKeys.firstWhere((fk) => fk.columnName == 'order_id');
      expect(orderIdFk.referencedTable, equals('order'));

      final productIdFk = orderDetailTable.foreignKeys.firstWhere((fk) => fk.columnName == 'product_id');
      expect(productIdFk.referencedTable, equals('product'));
    });

    test('inventory.dmnotation の解析 - from_warehouse_id 外部キー推測', () {
      final result = DMNotationAnalyzer.analyze(dmNotationFiles['inventory']!);

      expect(result.isSuccess, isTrue);
      expect(result.database, isNotNull);

      final db = result.database!;

      // stock_movement テーブルの確認
      final stockMovementTable = db.tables.firstWhere((t) => t.sqlName == 'stock_movement');

      // 複合外部キーの解決確認
      final fromWarehouseIdFk = stockMovementTable.foreignKeys.firstWhere(
        (fk) => fk.columnName == 'from_warehouse_id'
      );
      expect(fromWarehouseIdFk.referencedTable, equals('warehouse'));

      final toWarehouseIdFk = stockMovementTable.foreignKeys.firstWhere(
        (fk) => fk.columnName == 'to_warehouse_id'
      );
      expect(toWarehouseIdFk.referencedTable, equals('warehouse'));

      // purchase_order_detail の複合語テーブル名確認
      final purchaseOrderDetailTable = db.tables.firstWhere((t) => t.sqlName == 'purchase_order_detail');
      final purchaseOrderIdFk = purchaseOrderDetailTable.foreignKeys.firstWhere(
        (fk) => fk.columnName == 'purchase_order_id'
      );
      expect(purchaseOrderIdFk.referencedTable, equals('purchase_order'));
    });

    test('employee.dmnotation の解析 - 深い階層構造', () {
      final result = DMNotationAnalyzer.analyze(dmNotationFiles['employee']!);

      expect(result.isSuccess, isTrue);
      expect(result.database, isNotNull);

      final db = result.database!;

      // 主要テーブルの存在確認
      final tableNames = db.tables.map((t) => t.sqlName).toSet();
      expect(tableNames, containsAll([
        'employee', 'attendance', 'salary', 'evaluation', 'paid_leave',
        'department', 'position', 'project', 'project_assignment',
        'training', 'training_attendance', 'request'
      ]));

      // 階層関係の確認：employee -> attendance
      final employeeAttendanceRel = db.relationships.where(
        (r) => r.parentTable == 'employee' && r.childTable == 'attendance'
      );
      expect(employeeAttendanceRel.isNotEmpty, isTrue);

      // 階層関係の確認：project -> project_assignment
      final projectAssignmentRel = db.relationships.where(
        (r) => r.parentTable == 'project' && r.childTable == 'project_assignment'
      );
      expect(projectAssignmentRel.isNotEmpty, isTrue);

      // 外部キー解決の確認
      final attendanceTable = db.tables.firstWhere((t) => t.sqlName == 'attendance');
      final employeeIdFk = attendanceTable.foreignKeys.firstWhere((fk) => fk.columnName == 'employee_id');
      expect(employeeIdFk.referencedTable, equals('employee'));
    });

    test('equipment_reservation.dmnotation の解析 - 多重ネスト', () {
      final result = DMNotationAnalyzer.analyze(dmNotationFiles['equipment_reservation']!);

      expect(result.isSuccess, isTrue);
      expect(result.database, isNotNull);

      final db = result.database!;

      // 主要テーブルの存在確認
      final tableNames = db.tables.map((t) => t.sqlName).toSet();
      expect(tableNames, containsAll([
        'equipment', 'reservation', 'user', 'usage_history', 'maintenance',
        'category', 'location', 'notification', 'reservation_conflict',
        'usage_rule', 'holiday'
      ]));

      // 階層関係の確認：equipment -> reservation
      final equipmentReservationRel = db.relationships.where(
        (r) => r.parentTable == 'equipment' && r.childTable == 'reservation'
      );
      expect(equipmentReservationRel.isNotEmpty, isTrue);

      // 参照関係の確認：reservation -> user
      final reservationUserRel = db.relationships.where(
        (r) => r.parentTable == 'reservation' && r.childTable == 'user'
      );
      expect(reservationUserRel.isNotEmpty, isTrue);
      expect(reservationUserRel.first.type, equals(DMRelationshipType.reference));

      // 外部キー解決の確認
      final reservationTable = db.tables.firstWhere((t) => t.sqlName == 'reservation');
      final equipmentIdFk = reservationTable.foreignKeys.firstWhere((fk) => fk.columnName == 'equipment_id');
      expect(equipmentIdFk.referencedTable, equals('equipment'));

      final userIdFk = reservationTable.foreignKeys.firstWhere((fk) => fk.columnName == 'user_id');
      expect(userIdFk.referencedTable, equals('user'));
    });

    test('blog.dmnotation の解析 - 弱参照と複雑な関係', () {
      final result = DMNotationAnalyzer.analyze(dmNotationFiles['blog']!);

      expect(result.isSuccess, isTrue);
      expect(result.database, isNotNull);

      final db = result.database!;

      // 主要テーブルの存在確認
      final tableNames = db.tables.map((t) => t.sqlName).toSet();
      expect(tableNames, containsAll([
        'user', 'post', 'comment', 'like', 'follow', 'category', 'tag',
        'post_tag', 'media', 'site_setting', 'contact', 'newsletter',
        'newsletter_subscription', 'access_log'
      ]));

      // 階層関係の確認：user -> post
      final userPostRel = db.relationships.where(
        (r) => r.parentTable == 'user' && r.childTable == 'post'
      );
      expect(userPostRel.isNotEmpty, isTrue);

      // 深い階層：post -> comment
      final postCommentRel = db.relationships.where(
        (r) => r.parentTable == 'post' && r.childTable == 'comment'
      );
      expect(postCommentRel.isNotEmpty, isTrue);

      // 弱参照の確認：access_log ??-> user
      final weakRefRel = db.relationships.where(
        (r) => r.parentTable == 'access_log' && r.childTable == 'user'
      );
      expect(weakRefRel.isNotEmpty, isTrue);
      expect(weakRefRel.first.type, equals(DMRelationshipType.weak));

      // author_id の役割マッピング確認
      final postTable = db.tables.firstWhere((t) => t.sqlName == 'post');
      final authorIdFk = postTable.foreignKeys.firstWhere((fk) => fk.columnName == 'author_id');
      expect(authorIdFk.referencedTable, equals('user')); // author -> user のマッピング

      // コメントの入れ子構造確認
      final commentTable = db.tables.firstWhere((t) => t.sqlName == 'comment');
      final commenterIdFk = commentTable.foreignKeys.firstWhere((fk) => fk.columnName == 'commenter_id');
      expect(commenterIdFk.referencedTable, equals('user')); // commenter -> user のマッピング
    });

    test('全スキーマの総合的な検証', () {
      for (final entry in dmNotationFiles.entries) {
        final result = DMNotationAnalyzer.analyze(entry.value);

        expect(result.isSuccess, isTrue, reason: '${entry.key}.dmnotation の解析が失敗しました');
        expect(result.database, isNotNull, reason: '${entry.key}.dmnotation のデータベースがnullです');
        expect(result.database!.tables.isNotEmpty, isTrue, reason: '${entry.key}.dmnotation にテーブルがありません');

        // エラーレポート
        if (!result.isSuccess) {
          print('=== ${entry.key}.dmnotation エラー ===');
          for (final error in result.errors) {
            print('行 ${error.line}: ${error.message}');
          }
        }
      }
    });

    test('パフォーマンステスト - 大規模スキーマの解析速度', () {
      final stopwatch = Stopwatch()..start();

      for (final entry in dmNotationFiles.entries) {
        final result = DMNotationAnalyzer.analyze(entry.value);
        expect(result.isSuccess, isTrue);
      }

      stopwatch.stop();

      // 全スキーマの解析が1秒以内に完了することを確認
      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
        reason: '解析時間が長すぎます: ${stopwatch.elapsedMilliseconds}ms');

      print('全スキーマ解析時間: ${stopwatch.elapsedMilliseconds}ms');
    });

    test('SQL生成の検証', () {
      for (final entry in dmNotationFiles.entries) {
        final result = DMNotationAnalyzer.analyze(entry.value);
        expect(result.isSuccess, isTrue);

        final db = result.database!;

        // 各テーブルのSQL生成が正常に動作することを確認
        for (final table in db.tables) {
          expect(() => table.generateCreateTableSQL(), returnsNormally,
            reason: '${entry.key}のテーブル ${table.sqlName} のSQL生成でエラー');

          final sql = table.generateCreateTableSQL();
          expect(sql.contains('CREATE TABLE'), isTrue);
          expect(sql.contains(table.sqlName), isTrue);
        }
      }
    });
  });
}