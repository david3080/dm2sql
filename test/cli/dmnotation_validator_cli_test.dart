/// DMNotation CLIバリデーターのテストケース
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DMNotation CLI バリデーター', () {
    // DMNotationファイルを動的に検出
    late List<String> validDMNotationFiles;
    late List<String> errorDMNotationFiles;

    setUpAll(() async {
      final assetsDir = Directory('assets');
      final files = await assetsDir.list().toList();

      validDMNotationFiles = files
          .whereType<File>()
          .where((file) => file.path.endsWith('.dmnotation') && !file.path.contains('_error'))
          .map((file) => file.path)
          .toList();

      errorDMNotationFiles = files
          .whereType<File>()
          .where((file) => file.path.endsWith('_error.dmnotation'))
          .map((file) => file.path)
          .toList();

      print('検出された有効なDMNotationファイル: ${validDMNotationFiles.length}件');
      print('検出されたエラー入りDMNotationファイル: ${errorDMNotationFiles.length}件');
    });
    test('ヘルプオプションが正常に表示される', () async {
      final result = await Process.run('dart', [
        'bin/dmnotation_validator.dart',
        '--help'
      ]);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('DMNotation バリデーター'));
      expect(result.stdout, contains('USAGE:'));
      expect(result.stdout, contains('OPTIONS:'));
    });

    test('バリデーション成功時の終了コード', () async {
      final result = await Process.run('dart', [
        'bin/dmnotation_validator.dart',
        'assets/simple_test.dmnotation',
        '--syntax-only',
        '--no-warnings'
      ]);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('バリデーション成功'));
    });

    test('JSON出力が正しい形式で出力される', () async {
      final result = await Process.run('dart', [
        'bin/dmnotation_validator.dart',
        'assets/simple_test.dmnotation',
        '--json'
      ]);

      expect(result.stdout, contains('"file":'));
      expect(result.stdout, contains('"valid":'));
      expect(result.stdout, contains('"severity":'));
    });

    test('存在しないファイルでエラーが発生', () async {
      final result = await Process.run('dart', [
        'bin/dmnotation_validator.dart',
        'nonexistent.dmnotation'
      ]);

      expect(result.exitCode, equals(1));
      expect(result.stderr, contains('ファイルが見つかりません'));
    });

    test('不正な引数でエラーが発生', () async {
      final result = await Process.run('dart', [
        'bin/dmnotation_validator.dart',
        '--invalid-option'
      ]);

      expect(result.exitCode, equals(1));
      expect(result.stderr, contains('引数エラー'));
    });

    test('Flutter package 経由での実行', () async {
      final result = await Process.run('flutter', [
        'packages',
        'pub',
        'run',
        'dm2sql:dmnotation_validator',
        '--help'
      ]);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('DMNotation バリデーター'));
    });

    test('Dart run 経由での実行', () async {
      final result = await Process.run('dart', [
        'run',
        'dm2sql:dmnotation_validator',
        '--help'
      ]);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('DMNotation バリデーター'));
    });

    group('有効なDMNotationファイルのテスト', () {
      for (int i = 0; i < 100; i++) {  // 最大100ファイルまで対応
        test('有効ファイル ${i + 1} の構文チェック', () async {
          if (i >= validDMNotationFiles.length) return;

          final filePath = validDMNotationFiles[i];
          final fileName = filePath.split('/').last;

          final result = await Process.run('dart', [
            'bin/dmnotation_validator.dart',
            filePath,
            '--syntax-only',
            '--no-warnings'
          ]);

          expect(result.exitCode, equals(0),
              reason: '$fileName should pass syntax validation');
          expect(result.stdout, contains('バリデーション成功'),
              reason: '$fileName should show success message');
        }, skip: false);
      }
    });

    group('エラー入りDMNotationファイルのテスト', () {
      for (int i = 0; i < 100; i++) {  // 最大100ファイルまで対応
        test('エラーファイル ${i + 1} のエラー検出', () async {
          if (i >= errorDMNotationFiles.length) return;

          final filePath = errorDMNotationFiles[i];
          final fileName = filePath.split('/').last;

          final result = await Process.run('dart', [
            'bin/dmnotation_validator.dart',
            filePath,
          ]);

          expect(result.exitCode, greaterThan(0),
              reason: '$fileName should fail validation');
          expect(result.stdout, contains('バリデーション失敗'),
              reason: '$fileName should show failure message');
        }, skip: false);
      }
    });

    group('JSON出力テスト', () {
      test('全ファイルのJSON出力テスト', () async {
        for (final filePath in validDMNotationFiles.take(3)) {  // 最初の3ファイルのみテスト
          final result = await Process.run('dart', [
            'bin/dmnotation_validator.dart',
            filePath,
            '--json'
          ]);

          expect(result.stdout, contains('"file":'),
              reason: 'JSON should contain file field for $filePath');
          expect(result.stdout, contains('"valid":'),
              reason: 'JSON should contain valid field for $filePath');
          expect(result.stdout, contains('"severity":'),
              reason: 'JSON should contain severity field for $filePath');
        }
      });
    });

    group('バリデーションレベルテスト', () {
      test('複数レベルでのバリデーション', () async {
        if (validDMNotationFiles.isEmpty) return;

        final testFile = validDMNotationFiles.first;

        for (final level in ['basic', 'standard', 'strict']) {
          final result = await Process.run('dart', [
            'bin/dmnotation_validator.dart',
            testFile,
            '--level', level,
            '--no-warnings'
          ]);

          expect(result.exitCode, equals(0),
              reason: '$testFile should validate at $level level');
        }
      });
    });
  });
}