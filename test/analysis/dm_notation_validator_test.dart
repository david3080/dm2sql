/// DMNotationValidator の包括的テスト
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:dm2sql/analysis/dm_notation_validator.dart';

void main() {
  group('DMNotationValidator テスト', () {
    group('構文バリデーション', () {
      test('正常な構文はバリデーション成功', () {
        const validDMNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}, メール{email:string@}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int}), 注文日時{order_date:datetime!}
''';

        final result = DMNotationValidator.validateSyntaxOnly(validDMNotation);

        expect(result.isValid, isTrue);
        expect(result.issues, isEmpty);
      });

      test('中括弧の対応エラーを検出', () {
        const invalidDMNotation = '''
顧客{customer: [顧客ID{id:int}], 顧客名{name:string!}
''';

        final result = DMNotationValidator.validateSyntaxOnly(invalidDMNotation);

        expect(result.isValid, isFalse);
        expect(result.issues, isNotEmpty);
        expect(result.issues.first.message, contains('中括弧の対応が正しくありません'));
        expect(result.issues.first.category, equals(ValidationCategory.syntax));
      });

      test('コロン不足エラーを検出', () {
        const invalidDMNotation = '''
顧客{customer} [顧客ID{id:int}], 顧客名{name:string!}
''';

        final result = DMNotationValidator.validateSyntaxOnly(invalidDMNotation);

        expect(result.isValid, isFalse);
        expect(result.issues.any((issue) => issue.message.contains('コロン(:)が必要です')), isTrue);
      });

      test('主キー記法エラーを検出', () {
        const invalidDMNotation = '''
顧客{customer}: [顧客ID], 顧客名{name:string!}
''';

        final result = DMNotationValidator.validateSyntaxOnly(invalidDMNotation);

        expect(result.isValid, isFalse);
        expect(result.issues.any((issue) => issue.message.contains('主キー定義が正しくありません')), isTrue);
      });

      test('外部キー記法エラーを検出', () {
        const invalidDMNotation = '''
注文{order}: [注文ID{id:int}], (顧客ID), 注文日時{order_date:datetime!}
''';

        final result = DMNotationValidator.validateSyntaxOnly(invalidDMNotation);

        expect(result.isValid, isFalse);
        expect(result.issues.any((issue) => issue.message.contains('外部キー定義が正しくありません')), isTrue);
      });

      test('関係性記号後の内容不足エラーを検出', () {
        const invalidDMNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
--
''';

        final result = DMNotationValidator.validateSyntaxOnly(invalidDMNotation);

        expect(result.isValid, isFalse);
        expect(result.issues.any((issue) => issue.message.contains('関係性記号の後にテーブル定義が必要です')), isTrue);
      });
    });

    group('命名規則バリデーション', () {
      test('適切な命名規則は警告なし', () {
        const validDMNotation = '''
user_profile{user_profile}: [ユーザーID{id:int}], 名前{name:string!}
''';

        final result = DMNotationValidator.validateSyntaxOnly(validDMNotation);

        expect(result.isValid, isTrue);
        expect(result.warnings, isEmpty);
      });

      test('不適切な英語名形式を警告', () {
        const invalidDMNotation = '''
顧客{Customer-Profile}: [顧客ID{id:int}], 顧客名{name:string!}
''';

        final result = DMNotationValidator.validateSyntaxOnly(invalidDMNotation);

        expect(result.issues.any((issue) =>
          issue.message.contains('小文字とアンダースコアのみ使用してください') &&
          issue.severity == ValidationSeverity.warning
        ), isTrue);
      });

      test('SQL予約語の使用を警告', () {
        const reservedWordDMNotation = '''
順序{order}: [順序ID{id:int}], 名前{name:string!}
''';

        final result = DMNotationValidator.validateSyntaxOnly(reservedWordDMNotation);

        expect(result.warnings.any((warning) =>
          warning.message.contains('SQL予約語です')
        ), isTrue);
      });

      test('長すぎるテーブル名を警告', () {
        const longNameDMNotation = '''
ユーザー{very_long_table_name_that_exceeds_recommended_length}: [ID{id:int}]
''';

        final result = DMNotationValidator.validateSyntaxOnly(longNameDMNotation);

        expect(result.warnings.any((warning) =>
          warning.message.contains('テーブル名が長すぎます')
        ), isTrue);
      });
    });

    group('インデントバリデーション', () {
      test('正しいインデントは問題なし', () {
        const validDMNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int})
    -- 注文明細{order_detail}: [明細ID{id:int}], (注文ID{order_id:int})
''';

        final result = DMNotationValidator.validateSyntaxOnly(validDMNotation);

        expect(result.isValid, isTrue);
      });

      test('不正なインデント（奇数スペース）を警告', () {
        const invalidDMNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int})
   -- 注文明細{order_detail}: [明細ID{id:int}], (注文ID{order_id:int})
''';

        final result = DMNotationValidator.validateSyntaxOnly(invalidDMNotation);

        expect(result.issues.any((issue) =>
          issue.message.contains('2スペースの倍数である必要があります')
        ), isTrue); // 奇数スペースを使用しているため
      });

      test('タブ文字の使用を警告', () {
        const tabDMNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
\t-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int})
''';

        final result = DMNotationValidator.validateSyntaxOnly(tabDMNotation);

        expect(result.issues.any((issue) =>
          issue.message.contains('タブ文字ではなくスペースを使用してください')
        ), isTrue);
      });
    });

    group('完全バリデーション', () {
      test('完全に正しいDMNotationはバリデーション成功', () {
        const validDMNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}, メール{email:string@}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int}), 注文日時{order_date:datetime!}
''';

        final result = DMNotationValidator.validate(validDMNotation);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('参照エラーを検出', () {
        const invalidDMNotation = '''
注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int}), 注文日時{order_date:datetime!}
''';

        final result = DMNotationValidator.validate(invalidDMNotation);

        expect(result.isValid, isFalse);
        expect(result.issues.any((issue) =>
          issue.message.contains('参照するテーブル') &&
          issue.category == ValidationCategory.references
        ), isTrue);
      });

      test('空のDMNotationを拒否', () {
        const emptyDMNotation = '';

        final result = DMNotationValidator.validate(emptyDMNotation);

        expect(result.isValid, isFalse);
        expect(result.issues.any((issue) =>
          issue.message.contains('テーブルが定義されていません')
        ), isTrue);
      });
    });

    group('バリデーションレベル', () {
      test('基本レベルは最小限のチェックのみ', () {
        const dmNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
''';

        final result = DMNotationValidator.validate(
          dmNotation,
          level: ValidationLevel.basic,
          includeBestPracticeChecks: false,
        );

        expect(result.isValid, isTrue);
        expect(result.warnings, isEmpty);
      });

      test('厳密レベルはベストプラクティスチェックを含む', () {
        const dmNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
''';

        final result = DMNotationValidator.validate(
          dmNotation,
          level: ValidationLevel.strict,
        );

        expect(result.warnings.any((warning) =>
          warning.message.contains('created_at')
        ), isTrue);
      });
    });

    group('パフォーマンスチェック', () {
      test('外部キーのインデックス推奨', () {
        const dmNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int})
''';

        final result = DMNotationValidator.validate(
          dmNotation,
          includePerformanceChecks: true,
        );

        expect(result.warnings.any((warning) =>
          warning.message.contains('インデックス(*)の追加を推奨')
        ), isTrue);
      });

      test('大量カラムの警告', () {
        // 21カラムのテーブルを作成
        final largeTableColumns = List.generate(21, (i) => 'カラム$i{col$i:string}').join(', ');
        final dmNotation = '''
大きなテーブル{large_table}: [ID{id:int}], $largeTableColumns
''';

        final result = DMNotationValidator.validate(
          dmNotation,
          includePerformanceChecks: true,
        );

        expect(result.warnings.any((warning) =>
          warning.message.contains('カラム数が多すぎます')
        ), isTrue);
      });
    });

    group('ベストプラクティスチェック', () {
      test('大量テーブルの警告', () {
        // 51テーブルのデータベースを作成
        final largeDatabaseTables = List.generate(51, (i) =>
          'テーブル$i{table$i}: [ID{id:int}], 名前{name:string}'
        ).join('\n');

        final result = DMNotationValidator.validate(
          largeDatabaseTables,
          includeBestPracticeChecks: true,
        );

        expect(result.warnings.any((warning) =>
          warning.message.contains('テーブル数が多すぎます')
        ), isTrue);
      });

      test('コメント不足の警告', () {
        const dmNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int})
商品{product}: [商品ID{id:int}], 商品名{name:string!}
''';

        final result = DMNotationValidator.validate(
          dmNotation,
          includeBestPracticeChecks: true,
        );

        expect(result.warnings.any((warning) =>
          warning.message.contains('コメントが不足しています')
        ), isTrue);
      });
    });

    group('エラーメッセージと提案', () {
      test('エラーには適切な提案が含まれる', () {
        const invalidDMNotation = '''
顧客{customer} [顧客ID{id:int}], 顧客名{name:string!}
''';

        final result = DMNotationValidator.validateSyntaxOnly(invalidDMNotation);

        final issue = result.issues.firstWhere((issue) =>
          issue.message.contains('コロン(:)が必要です')
        );

        expect(issue.suggestion, isNotNull);
        expect(issue.suggestion, contains('テーブル名{english_name}:'));
      });

      test('警告には改善提案が含まれる', () {
        const dmNotation = '''
順序{order}: [順序ID{id:int}], 名前{name:string!}
''';

        final result = DMNotationValidator.validateSyntaxOnly(dmNotation);

        final warning = result.warnings.firstWhere((warning) =>
          warning.message.contains('SQL予約語です')
        );

        expect(warning.suggestion, isNotNull);
        expect(warning.suggestion, contains('別の名前を推奨'));
      });
    });

    group('バリデーション結果の活用', () {
      test('重要度別のフィルタリング', () {
        const mixedDMNotation = '''
順序{order}: [順序ID{id:int}], 名前{name:string!}
注文{order2} [注文ID{id:int}]
''';

        final result = DMNotationValidator.validateSyntaxOnly(mixedDMNotation);

        expect(result.errors.isNotEmpty, isTrue);
        expect(result.warningIssues.isNotEmpty, isTrue);
        expect(result.errors.every((issue) =>
          issue.severity == ValidationSeverity.error
        ), isTrue);
        expect(result.warningIssues.every((issue) =>
          issue.severity == ValidationSeverity.warning
        ), isTrue);
      });

      test('最高重要度の判定', () {
        const errorDMNotation = '''
顧客{customer [顧客ID{id:int}], 顧客名{name:string!}
''';

        final result = DMNotationValidator.validateSyntaxOnly(errorDMNotation);

        expect(result.severity, equals(ValidationSeverity.error));
      });
    });
  });
}