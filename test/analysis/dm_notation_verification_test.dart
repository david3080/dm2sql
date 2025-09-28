/// DMNotationAnalyzerの動作検証テスト
/// debug_test.dartとtest_indent_rules.dartを統合
library dm_notation_verification_test;

import '../../lib/analysis/dm_notation_analyzer.dart';

void main() {
  print('=== DMNotationAnalyzer動作検証テスト ===\n');

  // 基本的なデバッグ・動作確認
  testBasicDebugVerification();

  // インデントルール検証
  testSameIndentMultipleTables();
  testCorrectHierarchy();
  testBlankLineRelationships();
  testProblematicCases();

  // 行解析の詳細確認
  testLineAnalysisDetails();
}

void testBasicDebugVerification() {
  print('【テスト1】基本的なデバッグ・動作確認');

  const dmNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}, メール{email:string@}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int}), 注文日時{order_date:datetime!}
   -- 注文明細{order_detail}: [明細ID{id:int}], (注文ID{order_id:int}), (商品ID{product_id:int})

商品{product}: [商品ID{id:int}], 商品名{name:string!}, 価格{price:int!}
''';

  // 行解析の詳細表示
  final lines = dmNotation.split('\n');
  print('=== 行解析 ===');
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;

    final leadingSpaces = line.length - line.trimLeft().length;
    final indentLevel = leadingSpaces ~/ 4;
    final isRelationship = line.trim().startsWith('--') ||
                          line.trim().startsWith('->') ||
                          line.trim().startsWith('??');

    print('行 ${i+1}: インデント=$indentLevel, 関係性=$isRelationship, 内容="${line.trim()}"');
  }

  print('\n=== 期待される関係性 ===');
  print('- customer (レベル0) -> order (レベル0, --関係性)');
  print('- order (レベル0, --関係性) -> order_detail (レベル1, --関係性)');

  print('\n=== 解析結果 ===');
  final result = DMNotationAnalyzer.analyze(dmNotation);

  print('解析結果: ${result.isSuccess}');
  print('エラー数: ${result.errors.length}');

  if (!result.isSuccess) {
    for (final error in result.errors) {
      print('エラー: $error');
    }
  } else {
    final db = result.database!;
    print('テーブル数: ${db.tables.length}');
    print('関係性数: ${db.relationships.length}');

    for (final table in db.tables) {
      print('テーブル: ${table.sqlName}');
      for (final fk in table.foreignKeys) {
        print('  外部キー: ${fk.columnName} -> ${fk.referencedTable}');
      }
    }

    for (final rel in db.relationships) {
      print('関係性: ${rel.parentTable} -${rel.type}-> ${rel.childTable}');
    }
  }
  print('');
}

void testSameIndentMultipleTables() {
  print('【テスト2】同じインデントレベルに複数のテーブル定義');

  const dmNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int})
-- お気に入り{favorite}: [お気に入りID{id:int}], (顧客ID{customer_id:int})
-- レビュー{review}: [レビューID{id:int}], (顧客ID{customer_id:int})
''';

  final result = DMNotationAnalyzer.analyze(dmNotation);
  print('解析結果: ${result.isSuccess}');

  if (result.isSuccess) {
    final db = result.database!;
    print('テーブル数: ${db.tables.length}');
    print('関係性数: ${db.relationships.length}');

    for (final rel in db.relationships) {
      print('  関係性: ${rel.parentTable} -${rel.type}-> ${rel.childTable}');
    }
  }
  print('');
}

void testCorrectHierarchy() {
  print('【テスト3】正しい階層構造（空行で分離）');

  const dmNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int})
   -- 注文明細{order_detail}: [明細ID{id:int}], (注文ID{order_id:int})

商品{product}: [商品ID{id:int}], 商品名{name:string!}
-- 在庫{stock}: [在庫ID{id:int}], (商品ID{product_id:int})
''';

  final result = DMNotationAnalyzer.analyze(dmNotation);
  print('解析結果: ${result.isSuccess}');

  if (result.isSuccess) {
    final db = result.database!;
    print('テーブル数: ${db.tables.length}');
    print('関係性数: ${db.relationships.length}');

    for (final rel in db.relationships) {
      print('  関係性: ${rel.parentTable} -${rel.type}-> ${rel.childTable}');
    }
  }
  print('');
}

void testBlankLineRelationships() {
  print('【テスト4】空行による関係表現');

  const dmNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int})

商品{product}: [商品ID{id:int}], 商品名{name:string!}

カテゴリ{category}: [カテゴリID{id:int}], カテゴリ名{name:string!}
-> 商品{product}
''';

  final result = DMNotationAnalyzer.analyze(dmNotation);
  print('解析結果: ${result.isSuccess}');

  if (result.isSuccess) {
    final db = result.database!;
    print('テーブル数: ${db.tables.length}');
    print('関係性数: ${db.relationships.length}');

    for (final rel in db.relationships) {
      print('  関係性: ${rel.parentTable} -${rel.type}-> ${rel.childTable}');
    }
  }
  print('');
}

void testProblematicCases() {
  print('【テスト5】問題のあるケース - 同じインデントに兄弟テーブル');

  const dmNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
商品{product}: [商品ID{id:int}], 商品名{name:string!}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int}), (商品ID{product_id:int})
''';

  final result = DMNotationAnalyzer.analyze(dmNotation);
  print('解析結果: ${result.isSuccess}');

  if (result.isSuccess) {
    final db = result.database!;
    print('テーブル数: ${db.tables.length}');
    print('関係性数: ${db.relationships.length}');

    for (final rel in db.relationships) {
      print('  関係性: ${rel.parentTable} -${rel.type}-> ${rel.childTable}');
    }

    // 問題：orderの親はcustomerかproductか？
    print('【問題】orderの親テーブルは何？');
    final orderRel = db.relationships.where((r) => r.childTable == 'order').toList();
    for (final rel in orderRel) {
      print('  orderの親: ${rel.parentTable}');
    }
  }
  print('');
}

void testLineAnalysisDetails() {
  print('【テスト6】行解析の詳細確認');

  const dmNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int})
   -- 注文明細{order_detail}: [明細ID{id:int}], (注文ID{order_id:int})
''';

  final lines = dmNotation.split('\n');
  print('=== 詳細行解析 ===');

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;

    final leadingSpaces = line.length - line.trimLeft().length;
    final indentLevel = leadingSpaces ~/ 4; // 4スペース = 1階層
    final isRelationship = line.trim().startsWith('--') ||
                          line.trim().startsWith('->') ||
                          line.trim().startsWith('??');

    print('行 ${i+1}: インデント=$indentLevel, 関係性=$isRelationship, 内容="${line.trim()}"');
  }

  print('\n=== 最終解析結果 ===');
  final result = DMNotationAnalyzer.analyze(dmNotation);
  print('解析成功: ${result.isSuccess}');

  if (result.isSuccess) {
    final db = result.database!;
    print('テーブル数: ${db.tables.length}');
    print('関係性数: ${db.relationships.length}');

    for (final rel in db.relationships) {
      print('  関係性: ${rel.parentTable} -${rel.type}-> ${rel.childTable}');
    }
  } else {
    for (final error in result.errors) {
      print('エラー: $error');
    }
  }
  print('');
}