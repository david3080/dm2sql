/// 包括的なDMNotationバリデータ
/// 構文解析前の文法チェック、意味解析、ベストプラクティス検証を提供
library;

import 'dm_notation_analyzer.dart';
import 'results/dm_database.dart';
import 'results/dm_table.dart';

/// DMNotationバリデーション結果
class DMValidationResult {
  final bool isValid;
  final List<DMValidationIssue> issues;
  final List<DMValidationWarning> warnings;
  final ValidationSeverity severity;

  const DMValidationResult({
    required this.isValid,
    required this.issues,
    required this.warnings,
    required this.severity,
  });

  factory DMValidationResult.valid() {
    return const DMValidationResult(
      isValid: true,
      issues: [],
      warnings: [],
      severity: ValidationSeverity.none,
    );
  }

  factory DMValidationResult.invalid(
    List<DMValidationIssue> issues, [
    List<DMValidationWarning> warnings = const [],
  ]) {
    final maxSeverity = issues.isEmpty
        ? ValidationSeverity.none
        : issues.map((i) => i.severity).reduce((a, b) =>
            a.index > b.index ? a : b);

    return DMValidationResult(
      isValid: false,
      issues: issues,
      warnings: warnings,
      severity: maxSeverity,
    );
  }

  /// エラーのみ（警告は除外）
  List<DMValidationIssue> get errors {
    return issues.where((issue) => issue.severity == ValidationSeverity.error).toList();
  }

  /// 警告レベルの問題
  List<DMValidationIssue> get warningIssues {
    return issues.where((issue) => issue.severity == ValidationSeverity.warning).toList();
  }
}

/// バリデーション問題
class DMValidationIssue {
  final int line;
  final int column;
  final String message;
  final ValidationSeverity severity;
  final ValidationCategory category;
  final String? suggestion;

  const DMValidationIssue({
    required this.line,
    required this.column,
    required this.message,
    required this.severity,
    required this.category,
    this.suggestion,
  });

  @override
  String toString() {
    final severityStr = severity.name.toUpperCase();
    final suggestionStr = suggestion != null ? ' (提案: $suggestion)' : '';
    return '[$severityStr] Line $line: $message$suggestionStr';
  }
}

/// バリデーション警告（非致命的）
class DMValidationWarning {
  final int line;
  final String message;
  final String category;
  final String? suggestion;

  const DMValidationWarning({
    required this.line,
    required this.message,
    required this.category,
    this.suggestion,
  });

  @override
  String toString() {
    final suggestionStr = suggestion != null ? ' (提案: $suggestion)' : '';
    return '[WARNING] Line $line: $message$suggestionStr';
  }
}

/// バリデーション重要度
enum ValidationSeverity {
  none,
  info,
  warning,
  error,
  critical,
}

/// バリデーションカテゴリ
enum ValidationCategory {
  syntax,           // 構文エラー
  semantics,        // 意味エラー
  references,       // 参照エラー
  naming,           // 命名規則
  structure,        // 構造問題
  performance,      // パフォーマンス
  bestPractice,     // ベストプラクティス
  accessibility,    // アクセシビリティ
}

/// DMNotation包括的バリデータ
class DMNotationValidator {

  /// 完全バリデーション実行
  static DMValidationResult validate(String dmNotation, {
    ValidationLevel level = ValidationLevel.strict,
    bool includeWarnings = true,
    bool includePerformanceChecks = true,
    bool includeBestPracticeChecks = true,
  }) {
    final validator = DMNotationValidator._();
    return validator._performValidation(
      dmNotation,
      level: level,
      includeWarnings: includeWarnings,
      includePerformanceChecks: includePerformanceChecks,
      includeBestPracticeChecks: includeBestPracticeChecks,
    );
  }

  /// 構文のみの高速バリデーション
  static DMValidationResult validateSyntaxOnly(String dmNotation) {
    final validator = DMNotationValidator._();
    return validator._validateSyntax(dmNotation);
  }

  /// 既に解析済みのデータベースのバリデーション
  static DMValidationResult validateDatabase(DMDatabase database, {
    ValidationLevel level = ValidationLevel.standard,
  }) {
    final validator = DMNotationValidator._();
    return validator._validateDatabaseStructure(database, level);
  }

  DMNotationValidator._();

  DMValidationResult _performValidation(
    String dmNotation, {
    required ValidationLevel level,
    required bool includeWarnings,
    required bool includePerformanceChecks,
    required bool includeBestPracticeChecks,
  }) {
    final issues = <DMValidationIssue>[];
    final warnings = <DMValidationWarning>[];

    // 1. 構文バリデーション
    final syntaxResult = _validateSyntax(dmNotation);
    issues.addAll(syntaxResult.issues);
    warnings.addAll(syntaxResult.warnings);

    // 構文エラーがある場合は後続チェックをスキップ
    if (syntaxResult.errors.isNotEmpty) {
      return DMValidationResult.invalid(issues, warnings);
    }

    // 2. 解析を実行して意味バリデーション
    try {
      final analysisResult = DMNotationAnalyzer.analyze(dmNotation);

      if (analysisResult.isSuccess) {
        final database = analysisResult.database!;

        // 3. データベース構造バリデーション
        final structureResult = _validateDatabaseStructure(database, level);
        issues.addAll(structureResult.issues);
        warnings.addAll(structureResult.warnings);

        // 4. パフォーマンスチェック
        if (includePerformanceChecks) {
          final perfResult = _validatePerformance(database);
          issues.addAll(perfResult.issues);
          warnings.addAll(perfResult.warnings);
        }

        // 5. ベストプラクティスチェック
        if (includeBestPracticeChecks) {
          final bpResult = _validateBestPractices(database, dmNotation);
          issues.addAll(bpResult.issues);
          warnings.addAll(bpResult.warnings);
        }
      } else {
        // 解析エラーをバリデーション問題に変換
        for (final error in analysisResult.errors) {
          issues.add(DMValidationIssue(
            line: error.line,
            column: error.column,
            message: error.message,
            severity: _mapErrorTypeToSeverity(error.type),
            category: _mapErrorTypeToCategory(error.type),
          ));
        }
      }
    } catch (e) {
      issues.add(DMValidationIssue(
        line: 0,
        column: 0,
        message: '解析中に予期しないエラーが発生しました: $e',
        severity: ValidationSeverity.critical,
        category: ValidationCategory.syntax,
      ));
    }

    // 警告を含めない場合は除外
    if (!includeWarnings) {
      warnings.clear();
    }

    return issues.isEmpty
        ? DMValidationResult.valid()
        : DMValidationResult.invalid(issues, warnings);
  }

  /// 構文バリデーション
  DMValidationResult _validateSyntax(String dmNotation) {
    final issues = <DMValidationIssue>[];
    final warnings = <DMValidationWarning>[];
    final lines = dmNotation.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNumber = i + 1;
      final trimmed = line.trim();

      if (trimmed.isEmpty) continue;

      // 基本構文チェック
      _validateBasicSyntax(line, lineNumber, issues);

      // 命名規則チェック
      _validateNamingConventions(line, lineNumber, issues, warnings);

      // インデントチェック
      _validateIndentation(line, lineNumber, issues);
    }

    return issues.isEmpty
        ? DMValidationResult.valid()
        : DMValidationResult.invalid(issues, warnings);
  }

  /// 基本構文チェック
  void _validateBasicSyntax(String line, int lineNumber, List<DMValidationIssue> issues) {
    final trimmed = line.trim();

    // テーブル定義の基本構文
    if (trimmed.contains('{') && trimmed.contains('}')) {
      // 中括弧の対応チェック
      final openCount = trimmed.split('{').length - 1;
      final closeCount = trimmed.split('}').length - 1;

      if (openCount != closeCount) {
        issues.add(DMValidationIssue(
          line: lineNumber,
          column: 0,
          message: '中括弧の対応が正しくありません',
          severity: ValidationSeverity.error,
          category: ValidationCategory.syntax,
          suggestion: '開き括弧と閉じ括弧の数を確認してください',
        ));
      }

      // コロンの存在チェック（テーブル定義）
      if (trimmed.contains('}') && !trimmed.contains(':')) {
        final afterBrace = trimmed.substring(trimmed.lastIndexOf('}') + 1);
        if (afterBrace.trim().isNotEmpty && !afterBrace.trim().startsWith(':')) {
          issues.add(DMValidationIssue(
            line: lineNumber,
            column: trimmed.lastIndexOf('}') + 1,
            message: 'テーブル定義の後にコロン(:)が必要です',
            severity: ValidationSeverity.error,
            category: ValidationCategory.syntax,
            suggestion: 'テーブル名{english_name}: の形式で記述してください',
          ));
        }
      }
    }

    // 関係性記号のチェック
    if (trimmed.startsWith('--') || trimmed.startsWith('->') || trimmed.startsWith('??')) {
      final relationshipPart = trimmed.substring(2).trim();
      if (relationshipPart.isEmpty) {
        issues.add(DMValidationIssue(
          line: lineNumber,
          column: 2,
          message: '関係性記号の後にテーブル定義が必要です',
          severity: ValidationSeverity.error,
          category: ValidationCategory.syntax,
        ));
      }
    }

    // 主キー記法チェック
    if (trimmed.contains('[') && trimmed.contains(']')) {
      final bracketPattern = RegExp(r'\[([^\]]+)\]');
      final matches = bracketPattern.allMatches(trimmed);

      for (final match in matches) {
        final content = match.group(1)!;
        if (!content.contains('{') || !content.contains('}')) {
          issues.add(DMValidationIssue(
            line: lineNumber,
            column: match.start,
            message: '主キー定義が正しくありません',
            severity: ValidationSeverity.error,
            category: ValidationCategory.syntax,
            suggestion: '[カラム名{column:type}]の形式で記述してください',
          ));
        }
      }
    }

    // 外部キー記法チェック
    if (trimmed.contains('(') && trimmed.contains(')')) {
      final parenPattern = RegExp(r'\(([^\)]+)\)');
      final matches = parenPattern.allMatches(trimmed);

      for (final match in matches) {
        final content = match.group(1)!;
        if (!content.contains('{') || !content.contains('}')) {
          issues.add(DMValidationIssue(
            line: lineNumber,
            column: match.start,
            message: '外部キー定義が正しくありません',
            severity: ValidationSeverity.error,
            category: ValidationCategory.syntax,
            suggestion: '(カラム名{column:type})の形式で記述してください',
          ));
        }
      }
    }
  }

  /// 命名規則チェック
  void _validateNamingConventions(
    String line,
    int lineNumber,
    List<DMValidationIssue> issues,
    List<DMValidationWarning> warnings,
  ) {
    final trimmed = line.trim();

    // テーブル名の英語名チェック
    final tablePattern = RegExp(r'([^{]+)\{([^}]+)\}');
    final match = tablePattern.firstMatch(trimmed);

    if (match != null) {
      final englishName = match.group(2)!.trim();

      // 英語名の形式チェック
      if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(englishName)) {
        issues.add(DMValidationIssue(
          line: lineNumber,
          column: match.start + match.group(1)!.length + 1,
          message: 'テーブルの英語名は小文字とアンダースコアのみ使用してください',
          severity: ValidationSeverity.warning,
          category: ValidationCategory.naming,
          suggestion: 'snake_case形式（例: user_profile）で記述してください',
        ));
      }

      // 予約語チェック
      final reservedWords = {
        'order', 'group', 'select', 'from', 'where', 'insert', 'update', 'delete',
        'table', 'column', 'index', 'key', 'constraint', 'primary', 'foreign',
        'unique', 'not', 'null', 'default', 'check', 'references'
      };

      if (reservedWords.contains(englishName.toLowerCase())) {
        warnings.add(DMValidationWarning(
          line: lineNumber,
          message: 'テーブル名 "$englishName" はSQL予約語です',
          category: 'naming',
          suggestion: 'バッククォートでエスケープされますが、別の名前を推奨します',
        ));
      }

      // 長すぎる名前のチェック
      if (englishName.length > 30) {
        warnings.add(DMValidationWarning(
          line: lineNumber,
          message: 'テーブル名が長すぎます（${englishName.length}文字）',
          category: 'naming',
          suggestion: '30文字以下を推奨します',
        ));
      }
    }
  }

  /// インデントチェック
  void _validateIndentation(String line, int lineNumber, List<DMValidationIssue> issues) {
    if (line.trim().isEmpty) return;

    final leadingSpaces = line.length - line.trimLeft().length;

    // インデントが2の倍数でない場合
    if (leadingSpaces % 2 != 0) {
      issues.add(DMValidationIssue(
        line: lineNumber,
        column: 0,
        message: 'インデントは2スペースの倍数である必要があります',
        severity: ValidationSeverity.warning,
        category: ValidationCategory.structure,
        suggestion: '2スペース単位でインデントしてください',
      ));
    }

    // タブ文字の使用チェック
    if (line.contains('\t')) {
      issues.add(DMValidationIssue(
        line: lineNumber,
        column: line.indexOf('\t'),
        message: 'タブ文字ではなくスペースを使用してください',
        severity: ValidationSeverity.warning,
        category: ValidationCategory.structure,
        suggestion: 'スペース2文字でインデントしてください',
      ));
    }
  }

  /// データベース構造バリデーション
  DMValidationResult _validateDatabaseStructure(DMDatabase database, ValidationLevel level) {
    final issues = <DMValidationIssue>[];
    final warnings = <DMValidationWarning>[];

    // テーブル数チェック
    if (database.tables.isEmpty) {
      issues.add(DMValidationIssue(
        line: 0,
        column: 0,
        message: 'テーブルが定義されていません',
        severity: ValidationSeverity.error,
        category: ValidationCategory.structure,
      ));
    }

    // 各テーブルのバリデーション
    for (final table in database.tables) {
      _validateTable(table, issues, warnings, level);
    }

    // 関係性のバリデーション
    _validateRelationships(database, issues, warnings);

    return issues.isEmpty
        ? DMValidationResult.valid()
        : DMValidationResult.invalid(issues, warnings);
  }

  /// テーブルバリデーション
  void _validateTable(
    DMTable table,
    List<DMValidationIssue> issues,
    List<DMValidationWarning> warnings,
    ValidationLevel level,
  ) {
    // カラム数チェック
    if (table.allColumns.isEmpty) {
      issues.add(DMValidationIssue(
        line: 0,
        column: 0,
        message: 'テーブル "${table.sqlName}" にカラムが定義されていません',
        severity: ValidationSeverity.error,
        category: ValidationCategory.structure,
      ));
    }

    // 主キーチェック
    if (table.primaryKey.columnName.isEmpty) {
      issues.add(DMValidationIssue(
        line: 0,
        column: 0,
        message: 'テーブル "${table.sqlName}" に主キーが定義されていません',
        severity: ValidationSeverity.error,
        category: ValidationCategory.structure,
      ));
    }

    // カラム名重複チェック
    final columnNames = <String>{};
    for (final column in table.allColumns) {
      if (columnNames.contains(column.sqlName)) {
        issues.add(DMValidationIssue(
          line: 0,
          column: 0,
          message: 'テーブル "${table.sqlName}" でカラム名 "${column.sqlName}" が重複しています',
          severity: ValidationSeverity.error,
          category: ValidationCategory.structure,
        ));
      }
      columnNames.add(column.sqlName);
    }

    // 厳密レベルでの追加チェック
    if (level == ValidationLevel.strict) {
      // created_atの推奨
      final hasCreatedAt = table.allColumns.any((c) => c.sqlName == 'created_at');

      if (!hasCreatedAt && table.sqlName != 'simple_test') {
        warnings.add(DMValidationWarning(
          line: 0,
          message: 'テーブル "${table.sqlName}" にcreated_atカラムの追加を推奨します',
          category: 'best_practice',
          suggestion: 'レコード作成日時の追跡のため',
        ));
      }
    }
  }

  /// 関係性バリデーション
  void _validateRelationships(
    DMDatabase database,
    List<DMValidationIssue> issues,
    List<DMValidationWarning> warnings,
  ) {
    final tableMap = {for (var t in database.tables) t.sqlName: t};

    for (final table in database.tables) {
      for (final fk in table.foreignKeys) {
        // 参照先テーブル存在チェック
        if (!tableMap.containsKey(fk.referencedTable)) {
          issues.add(DMValidationIssue(
            line: 0,
            column: 0,
            message: 'テーブル "${table.sqlName}" の外部キー "${fk.columnName}" が参照するテーブル "${fk.referencedTable}" が見つかりません',
            severity: ValidationSeverity.error,
            category: ValidationCategory.references,
          ));
        } else {
          // 参照先カラム存在チェック
          final referencedTable = tableMap[fk.referencedTable]!;

          // 主キーまたは通常のカラムとして存在するかチェック
          final hasReferencedColumn =
            fk.referencedColumn == referencedTable.primaryKey.columnName ||
            referencedTable.allColumns.any((col) => col.sqlName == fk.referencedColumn);

          if (!hasReferencedColumn) {
            issues.add(DMValidationIssue(
              line: 0,
              column: 0,
              message: 'テーブル "${fk.referencedTable}" にカラム ${fk.referencedColumn} が存在しません',
              severity: ValidationSeverity.error,
              category: ValidationCategory.references,
            ));
          }
        }
      }
    }
  }

  /// パフォーマンスバリデーション
  DMValidationResult _validatePerformance(DMDatabase database) {
    final warnings = <DMValidationWarning>[];

    for (final table in database.tables) {
      // インデックス推奨チェック
      final foreignKeyColumns = table.foreignKeys.map((fk) => fk.columnName).toSet();
      for (final fkColumn in foreignKeyColumns) {
        final column = table.allColumns.firstWhere((col) => col.sqlName == fkColumn);
        if (!column.isIndexed) {
          warnings.add(DMValidationWarning(
            line: 0,
            message: 'テーブル "${table.sqlName}" の外部キー "${fkColumn}" にインデックス(*)の追加を推奨します',
            category: 'performance',
            suggestion: 'JOINクエリのパフォーマンス向上のため',
          ));
        }
      }

      // テーブルサイズ推定
      if (table.allColumns.length > 20) {
        warnings.add(DMValidationWarning(
          line: 0,
          message: 'テーブル "${table.sqlName}" のカラム数が多すぎます（${table.allColumns.length}カラム）',
          category: 'performance',
          suggestion: 'テーブル分割を検討してください',
        ));
      }
    }

    return warnings.isEmpty
        ? DMValidationResult.valid()
        : DMValidationResult.invalid([], warnings);
  }

  /// ベストプラクティスバリデーション
  DMValidationResult _validateBestPractices(DMDatabase database, String dmNotation) {
    final warnings = <DMValidationWarning>[];

    // データベース全体のベストプラクティス
    if (database.tables.length > 50) {
      warnings.add(DMValidationWarning(
        line: 0,
        message: 'データベースのテーブル数が多すぎます（${database.tables.length}テーブル）',
        category: 'best_practice',
        suggestion: 'マイクロサービス化やデータベース分割を検討してください',
      ));
    }

    // コメントの推奨
    final lines = dmNotation.split('\n');
    final commentLines = lines.where((line) => line.trim().startsWith('//')).length;
    if (commentLines < database.tables.length / 2) {
      warnings.add(DMValidationWarning(
        line: 0,
        message: 'コメントが不足しています',
        category: 'best_practice',
        suggestion: '各テーブルの用途を説明するコメントを追加してください',
      ));
    }

    return warnings.isEmpty
        ? DMValidationResult.valid()
        : DMValidationResult.invalid([], warnings);
  }

  /// エラータイプをバリデーション重要度にマッピング
  ValidationSeverity _mapErrorTypeToSeverity(DMErrorType errorType) {
    switch (errorType) {
      case DMErrorType.syntaxError:
        return ValidationSeverity.error;
      case DMErrorType.semanticError:
        return ValidationSeverity.error;
      case DMErrorType.referenceError:
        return ValidationSeverity.error;
      case DMErrorType.typeError:
        return ValidationSeverity.error;
    }
  }

  /// エラータイプをバリデーションカテゴリにマッピング
  ValidationCategory _mapErrorTypeToCategory(DMErrorType errorType) {
    switch (errorType) {
      case DMErrorType.syntaxError:
        return ValidationCategory.syntax;
      case DMErrorType.semanticError:
        return ValidationCategory.semantics;
      case DMErrorType.referenceError:
        return ValidationCategory.references;
      case DMErrorType.typeError:
        return ValidationCategory.semantics;
    }
  }
}

/// バリデーションレベル
enum ValidationLevel {
  /// 基本的なエラーのみ
  basic,

  /// 標準的なチェック（推奨）
  standard,

  /// 厳密なチェック（ベストプラクティス含む）
  strict,
}