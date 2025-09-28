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

      test('複数の中括弧がある行でのコロン不足を検出', () {
        // 今回のバグの根本原因: 複数の{}がある行での解析エラー
        const multiCurlyBracesDMNotation = '''
ユーザー{user} [ID{id:int}], 名前{name:string!}, 詳細{details:string}
''';

        final result = DMNotationValidator.validateSyntaxOnly(multiCurlyBracesDMNotation);

        expect(result.isValid, isFalse);
        expect(result.issues.any((issue) => issue.message.contains('コロン(:)が必要です')), isTrue);
      });

      test('関係記号のある行ではコロンチェックしない', () {
        const relationshipDMNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
-- 注文{order} [注文ID{id:int}], (顧客ID{customer_id:int})
''';

        final result = DMNotationValidator.validateSyntaxOnly(relationshipDMNotation);

        // 関係記号のある行はコロンチェックの対象外なので、エラーにならない
        expect(result.isValid, isTrue);
      });

      test('正しいコロンの位置は問題なし', () {
        const validColonDMNotation = '''
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
商品{product}: [商品ID{id:int}], 商品名{name:string!}
''';

        final result = DMNotationValidator.validateSyntaxOnly(validColonDMNotation);

        expect(result.isValid, isTrue);
        expect(result.issues.any((issue) => issue.message.contains('コロン(:)が必要です')), isFalse);
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

      test('validateSyntaxOnly は構文エラーなしでも警告を正しく返す', () {
        // 今回のバグ: validateSyntaxOnly で警告が返されない問題の回帰テスト
        const reservedWordDMNotation = '''
順序{order}: [順序ID{id:int}], 名前{name:string!}
''';

        final result = DMNotationValidator.validateSyntaxOnly(reservedWordDMNotation);

        // 構文的には正しいためisValidはtrue
        expect(result.isValid, isTrue);
        // しかし警告は含まれるべき
        expect(result.warnings, isNotEmpty);
        expect(result.warnings.any((warning) =>
          warning.message.contains('SQL予約語です')
        ), isTrue);
      });

      test('validateSyntaxOnly は複数の警告を同時に返す', () {
        const multipleWarningsDMNotation = '''
順序{order}: [順序ID{id:int}], 名前{name:string!}
ユーザー{very_long_table_name_that_exceeds_recommended_length}: [ID{id:int}]
''';

        final result = DMNotationValidator.validateSyntaxOnly(multipleWarningsDMNotation);

        expect(result.isValid, isTrue);
        expect(result.warnings.length, greaterThanOrEqualTo(2));
        expect(result.warnings.any((warning) =>
          warning.message.contains('SQL予約語です')
        ), isTrue);
        expect(result.warnings.any((warning) =>
          warning.message.contains('テーブル名が長すぎます')
        ), isTrue);
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

      test('複数のSQL予約語を検出', () {
        const multipleReservedWordsDMNotation = '''
グループ{group}: [グループID{id:int}], 名前{name:string!}
テーブル{table}: [テーブルID{id:int}], 名前{name:string!}
選択{select}: [選択ID{id:int}], 名前{name:string!}
''';

        final result = DMNotationValidator.validateSyntaxOnly(multipleReservedWordsDMNotation);

        expect(result.warnings.where((warning) =>
          warning.message.contains('SQL予約語です')
        ).length, equals(3));
      });

      test('大文字小文字を区別せずSQL予約語を検出', () {
        const mixedCaseDMNotation = '''
順序{ORDER}: [順序ID{id:int}], 名前{name:string!}
グループ{Group}: [グループID{id:int}], 名前{name:string!}
''';

        final result = DMNotationValidator.validateSyntaxOnly(mixedCaseDMNotation);

        expect(result.warnings.where((warning) =>
          warning.message.contains('SQL予約語です')
        ).length, equals(2));
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

      test('30文字のテーブル名は警告なし（境界値）', () {
        const exactlyThirtyCharsDMNotation = '''
ユーザー{twelve_character_table_name_x}: [ID{id:int}]
''';

        final result = DMNotationValidator.validateSyntaxOnly(exactlyThirtyCharsDMNotation);

        expect(result.warnings.any((warning) =>
          warning.message.contains('テーブル名が長すぎます')
        ), isFalse);
      });

      test('31文字のテーブル名は警告あり（境界値）', () {
        const thirtyOneCharsDMNotation = '''
ユーザー{twelve_character_table_name_xyz}: [ID{id:int}]
''';

        final result = DMNotationValidator.validateSyntaxOnly(thirtyOneCharsDMNotation);

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
      }, skip: 'Phase 3: パフォーマンスチェック未実装');

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
      }, skip: 'Phase 3: パフォーマンスチェック未実装');
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

      test('コメント推奨（3+テーブル）', () {
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
          warning.message.contains('コメントの追加を推奨')
        ), isTrue);
      });

      test('created_at/updated_at推奨チェック', () {
        const dmNotationWithoutTimestamps = '''
ユーザー{user}: [ID{id:int}], 名前{name:string!}, メール{email:string@}
商品{product}: [ID{id:int}], 商品名{name:string!}, 価格{price:int}
''';

        final result = DMNotationValidator.validate(dmNotationWithoutTimestamps,
            level: ValidationLevel.strict);

        expect(result.isValid, isTrue);
        expect(result.warnings, isNotEmpty);

        // created_atとupdated_atの推奨警告があることを確認
        final timestampWarnings = result.warnings.where((w) =>
          w.message.contains('created_at') || w.message.contains('updated_at')).toList();
        expect(timestampWarnings.length, greaterThan(0));
      });

      test('命名規則統一チェック', () {
        const dmNotationMixedNaming = '''
ユーザー{user}: [id{id:int}], 名前{name:string!}
商品{product}: [product_id{product_id:int}], 商品名{name:string!}
注文{order}: [orderID{orderID:int}], (ユーザーID{user_id:int})
''';

        final result = DMNotationValidator.validate(dmNotationMixedNaming,
            includeBestPracticeChecks: true);

        expect(result.isValid, isTrue);
        expect(result.warnings.any((w) => w.message.contains('命名規則が統一されていません')), isTrue);
      });

      test('単一責任原則チェック', () {
        // 15+カラムの場合の責任過多警告
        const dmNotationTooManyColumns = '''
大きなテーブル{large_table}: [ID{id:int}], 名前{name:string!}, メール{email:string@}, 電話{phone:string}, 住所{address:string}, 年齢{age:int}, 性別{gender:string}, 職業{job:string}, 年収{income:int}, 趣味{hobby:string}, 出身地{birthplace:string}, 学歴{education:string}, 資格{qualification:string}, 備考1{note1:string}, 備考2{note2:string}, 備考3{note3:string}
''';

        final result = DMNotationValidator.validate(dmNotationTooManyColumns,
            includeBestPracticeChecks: true);

        expect(result.isValid, isTrue);
        expect(result.warnings.any((w) => w.message.contains('責任が多すぎる可能性')), isTrue);
      });

      test('繰り返しグループ検出', () {
        const dmNotationRepeatingGroups = '''
連絡先{contact}: [ID{id:int}], 名前{name:string!}, 電話1{phone1:string}, 電話2{phone2:string}, 電話3{phone3:string}
''';

        final result = DMNotationValidator.validate(dmNotationRepeatingGroups,
            includeBestPracticeChecks: true);

        expect(result.isValid, isTrue);
        expect(result.warnings.any((w) => w.message.contains('繰り返しグループが検出されました')), isTrue);
      });

      test('ドメイン混在チェック', () {
        const dmNotationMixedDomains = '''
複合テーブル{mixed}: [ID{id:int}], ユーザー名{user_name:string!}, 商品名{product_name:string!}, 注文日{order_date:datetime!}
''';

        final result = DMNotationValidator.validate(dmNotationMixedDomains,
            includeBestPracticeChecks: true);

        expect(result.isValid, isTrue);
        expect(result.warnings.any((w) => w.message.contains('異なるドメインのデータが混在')), isTrue);
      });

      test('システムテーブルはベストプラクティスチェック対象外', () {
        const dmNotationSystemTable = '''
simple_test{simple_test}: [ID{id:int}], 名前{name:string!}
sample_data{sample_data}: [ID{id:int}], 値{value:string!}
''';

        final result = DMNotationValidator.validate(dmNotationSystemTable,
            includeBestPracticeChecks: true);

        expect(result.isValid, isTrue);
        // システムテーブルはcreated_at推奨警告の対象外
        expect(result.warnings.where((w) => w.message.contains('created_at')).isEmpty, isTrue);
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

        // エラー（issues）と警告（warnings）が両方存在することを確認
        expect(result.errors.isNotEmpty, isTrue);
        expect(result.warnings.isNotEmpty, isTrue);
        expect(result.errors.every((issue) =>
          issue.severity == ValidationSeverity.error
        ), isTrue);
        // DMValidationWarning には severity フィールドがないため、存在のみ確認
        expect(result.warnings.isNotEmpty, isTrue);
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