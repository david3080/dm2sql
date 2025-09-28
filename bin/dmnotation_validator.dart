#!/usr/bin/env dart
/// DMNotation CLIバリデーター
/// Usage: dart run dm2sql:validate [options] <file.dmnotation>
library;

import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:dm2sql/analysis/dm_notation_validator.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'ヘルプを表示します',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: '詳細な出力を表示します',
    )
    ..addFlag(
      'json',
      abbr: 'j',
      negatable: false,
      help: 'JSON形式で結果を出力します',
    )
    ..addOption(
      'level',
      abbr: 'l',
      allowed: ['basic', 'standard', 'strict'],
      defaultsTo: 'standard',
      help: 'バリデーションレベルを指定します',
    )
    ..addFlag(
      'syntax-only',
      abbr: 's',
      negatable: false,
      help: '構文チェックのみ実行します（高速）',
    )
    ..addFlag(
      'no-warnings',
      abbr: 'w',
      negatable: false,
      help: '警告を表示しません',
    )
    ..addFlag(
      'no-performance',
      negatable: false,
      help: 'パフォーマンスチェックを無効にします',
    )
    ..addFlag(
      'no-best-practices',
      negatable: false,
      help: 'ベストプラクティスチェックを無効にします',
    )
    ..addFlag(
      'color',
      defaultsTo: true,
      help: 'カラー出力を有効/無効にします',
    );

  try {
    final results = parser.parse(arguments);

    if (results['help']) {
      _printUsage(parser);
      exit(0);
    }

    if (results.rest.isEmpty) {
      stderr.writeln('エラー: DMNotationファイルを指定してください');
      _printUsage(parser);
      exit(1);
    }

    final filePath = results.rest.first;
    final file = File(filePath);

    if (!file.existsSync()) {
      stderr.writeln('エラー: ファイルが見つかりません: $filePath');
      exit(1);
    }

    // DMNotationファイルの読み込み
    final content = await file.readAsString();

    // バリデーション設定
    final level = _parseValidationLevel(results['level']);
    final syntaxOnly = results['syntax-only'];
    final includeWarnings = !results['no-warnings'];
    final includePerformance = !results['no-performance'];
    final includeBestPractices = !results['no-best-practices'];
    final useColor = results['color'] && stdout.hasTerminal;
    final verbose = results['verbose'];
    final jsonOutput = results['json'];

    // バリデーション実行
    late final DMValidationResult validationResult;

    if (syntaxOnly) {
      validationResult = DMNotationValidator.validateSyntaxOnly(content);
    } else {
      validationResult = DMNotationValidator.validate(
        content,
        level: level,
        includeWarnings: includeWarnings,
        includePerformanceChecks: includePerformance,
        includeBestPracticeChecks: includeBestPractices,
      );
    }

    // 結果出力
    if (jsonOutput) {
      _outputJson(validationResult, filePath);
    } else {
      _outputHuman(validationResult, filePath, useColor, verbose);
    }

    // 終了コード
    if (validationResult.isValid) {
      exit(0);
    } else {
      final criticalIssues = validationResult.issues
          .where((issue) => issue.severity == ValidationSeverity.critical)
          .length;
      final errorIssues = validationResult.errors.length;

      if (criticalIssues > 0) {
        exit(2); // Critical errors
      } else if (errorIssues > 0) {
        exit(1); // Errors
      } else {
        exit(0); // Only warnings
      }
    }
  } on FormatException catch (e) {
    stderr.writeln('引数エラー: ${e.message}');
    _printUsage(parser);
    exit(1);
  } catch (e, stackTrace) {
    stderr.writeln('予期しないエラーが発生しました: $e');
    if (arguments.contains('--verbose') || arguments.contains('-v')) {
      stderr.writeln('スタックトレース:\n$stackTrace');
    }
    exit(3);
  }
}

void _printUsage(ArgParser parser) {
  print('''
DMNotation バリデーター v2.0

USAGE:
    dart run dm2sql:validate [options] <file.dmnotation>

DESCRIPTION:
    DMNotation記法ファイルの構文と意味をバリデーションします。

EXAMPLES:
    # 基本的なバリデーション
    dart run dm2sql:validate schema.dmnotation

    # 厳密なバリデーション
    dart run dm2sql:validate -l strict schema.dmnotation

    # 構文のみ高速チェック
    dart run dm2sql:validate -s schema.dmnotation

    # JSON出力
    dart run dm2sql:validate -j schema.dmnotation

    # 複数ファイルのバッチ処理
    find . -name "*.dmnotation" -exec dart run dm2sql:validate {} \\;

OPTIONS:
${parser.usage}

EXIT CODES:
    0: バリデーション成功（または警告のみ）
    1: エラーが発見されました
    2: 致命的エラーが発見されました
    3: 予期しない実行エラー
''');
}

ValidationLevel _parseValidationLevel(String level) {
  switch (level) {
    case 'basic':
      return ValidationLevel.basic;
    case 'standard':
      return ValidationLevel.standard;
    case 'strict':
      return ValidationLevel.strict;
    default:
      throw FormatException('不正なバリデーションレベル: $level');
  }
}

void _outputJson(DMValidationResult result, String filePath) {
  final jsonResult = {
    'file': filePath,
    'valid': result.isValid,
    'severity': result.severity.name,
    'issues': result.issues.map((issue) => {
      'line': issue.line,
      'column': issue.column,
      'message': issue.message,
      'severity': issue.severity.name,
      'category': issue.category.name,
      'suggestion': issue.suggestion,
    }).toList(),
    'warnings': result.warnings.map((warning) => {
      'line': warning.line,
      'message': warning.message,
      'category': warning.category,
      'suggestion': warning.suggestion,
    }).toList(),
    'summary': {
      'total_issues': result.issues.length,
      'errors': result.errors.length,
      'warnings': result.warnings.length,
      'suggestions': result.issues.where((i) => i.suggestion != null).length,
    }
  };

  print(const JsonEncoder.withIndent('  ').convert(jsonResult));
}

void _outputHuman(DMValidationResult result, String filePath, bool useColor, bool verbose) {
  // ヘッダー
  final fileName = filePath.split('/').last;
  print(_colorize('📄 $fileName をバリデーション中...', AnsiColor.blue, useColor));
  print('');

  if (result.isValid) {
    print(_colorize('✅ バリデーション成功!', AnsiColor.green, useColor));

    if (verbose && result.warnings.isNotEmpty) {
      print('');
      print(_colorize('⚠️  警告 (${result.warnings.length}件):', AnsiColor.yellow, useColor));
      for (final warning in result.warnings) {
        print(_formatWarning(warning, useColor));
      }
    }
  } else {
    print(_colorize('❌ バリデーション失敗', AnsiColor.red, useColor));
    print('');

    // エラーと問題の表示
    final criticalIssues = result.issues.where((i) => i.severity == ValidationSeverity.critical);
    final errorIssues = result.errors;
    final warningIssues = result.warningIssues;

    // 致命的エラー
    if (criticalIssues.isNotEmpty) {
      print(_colorize('💥 致命的エラー (${criticalIssues.length}件):', AnsiColor.magenta, useColor));
      for (final issue in criticalIssues) {
        print(_formatIssue(issue, useColor));
      }
      print('');
    }

    // エラー
    if (errorIssues.isNotEmpty) {
      print(_colorize('🚫 エラー (${errorIssues.length}件):', AnsiColor.red, useColor));
      for (final issue in errorIssues) {
        print(_formatIssue(issue, useColor));
      }
      print('');
    }

    // 警告レベルの問題
    if (warningIssues.isNotEmpty) {
      print(_colorize('⚠️  警告 (${warningIssues.length}件):', AnsiColor.yellow, useColor));
      for (final issue in warningIssues) {
        print(_formatIssue(issue, useColor));
      }
      print('');
    }

    // 追加の警告
    if (result.warnings.isNotEmpty) {
      print(_colorize('💡 提案 (${result.warnings.length}件):', AnsiColor.cyan, useColor));
      for (final warning in result.warnings) {
        print(_formatWarning(warning, useColor));
      }
      print('');
    }
  }

  // サマリー
  _printSummary(result, useColor);
}

String _formatIssue(DMValidationIssue issue, bool useColor) {
  final location = issue.line > 0 ? '${issue.line}:${issue.column}' : '-';
  final severity = _getSeverityIcon(issue.severity);
  final category = '[${issue.category.name}]';

  final buffer = StringBuffer();
  buffer.write('  $severity ');
  buffer.write(_colorize('$location', AnsiColor.gray, useColor));
  buffer.write(' $category ${issue.message}');

  if (issue.suggestion != null) {
    buffer.write('\n      ');
    buffer.write(_colorize('💡 ${issue.suggestion}', AnsiColor.cyan, useColor));
  }

  return buffer.toString();
}

String _formatWarning(DMValidationWarning warning, bool useColor) {
  final location = warning.line > 0 ? warning.line.toString() : '-';

  final buffer = StringBuffer();
  buffer.write('  💡 ');
  buffer.write(_colorize(location, AnsiColor.gray, useColor));
  buffer.write(' [${warning.category}] ${warning.message}');

  if (warning.suggestion != null) {
    buffer.write('\n      ');
    buffer.write(_colorize('提案: ${warning.suggestion}', AnsiColor.cyan, useColor));
  }

  return buffer.toString();
}

String _getSeverityIcon(ValidationSeverity severity) {
  switch (severity) {
    case ValidationSeverity.critical:
      return '💥';
    case ValidationSeverity.error:
      return '🚫';
    case ValidationSeverity.warning:
      return '⚠️ ';
    case ValidationSeverity.info:
      return 'ℹ️ ';
    case ValidationSeverity.none:
      return '  ';
  }
}

void _printSummary(DMValidationResult result, bool useColor) {
  print(_colorize('📊 サマリー', AnsiColor.blue, useColor));
  print('─' * 40);

  final totalIssues = result.issues.length;
  final criticalCount = result.issues.where((i) => i.severity == ValidationSeverity.critical).length;
  final errorCount = result.errors.length;
  final warningCount = result.warningIssues.length + result.warnings.length;
  final suggestionCount = result.issues.where((i) => i.suggestion != null).length;

  print('問題総数: $totalIssues');
  if (criticalCount > 0) print('  💥 致命的: $criticalCount');
  if (errorCount > 0) print('  🚫 エラー: $errorCount');
  if (warningCount > 0) print('  ⚠️  警告: $warningCount');
  if (suggestionCount > 0) print('  💡 提案: $suggestionCount');

  print('');
  if (result.isValid) {
    print(_colorize('✨ バリデーション完了！', AnsiColor.green, useColor));
  } else {
    print(_colorize('🔧 修正が必要です', AnsiColor.red, useColor));
  }
}

String _colorize(String text, AnsiColor color, bool useColor) {
  if (!useColor) return text;
  return '${color.code}$text${AnsiColor.reset.code}';
}

enum AnsiColor {
  reset('\x1B[0m'),
  red('\x1B[31m'),
  green('\x1B[32m'),
  yellow('\x1B[33m'),
  blue('\x1B[34m'),
  magenta('\x1B[35m'),
  cyan('\x1B[36m'),
  gray('\x1B[90m');

  const AnsiColor(this.code);
  final String code;
}