/// DMNotationサンプルデータパーサー
library;

import 'results/dm_sample_data.dart';

/// サンプルデータパーサー
class DMSampleDataParser {
  /// サンプルデータ行の正規表現パターン
  static final RegExp _samplePattern = RegExp(r'^@sample\s+(\w+)\s*,\s*(.+)$');

  /// DMNotationテキストからサンプルデータを抽出・パース
  static DMSampleDataParseResult parseSampleData(String dmNotationText) {
    final errors = <String>[];
    final sampleDataList = <DMSampleData>[];

    final lines = dmNotationText.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lineNumber = i + 1;

      // サンプルデータ行かチェック
      if (!line.startsWith('@sample')) {
        continue;
      }

      // 正規表現でパターンマッチ
      final match = _samplePattern.firstMatch(line);
      if (match == null) {
        errors.add('行 $lineNumber: 無効なサンプルデータ構文: $line');
        continue;
      }

      final tableName = match.group(1)!;
      final csvValuesText = match.group(2)!;

      // CSV値をパース
      final parseResult = _parseCSVValues(csvValuesText, lineNumber);
      if (!parseResult.isSuccess) {
        errors.addAll(parseResult.errors);
        continue;
      }

      final values = parseResult.values;
      final primaryKeyValue = values.isNotEmpty ? values[0] : null;

      sampleDataList.add(DMSampleData(
        tableName: tableName,
        primaryKeyValue: primaryKeyValue,
        values: values,
        lineNumber: lineNumber,
      ));
    }

    if (errors.isNotEmpty) {
      return DMSampleDataParseResult.failure(errors);
    }

    return DMSampleDataParseResult.success(sampleDataList);
  }

  /// CSV値をパースする
  static _CSVParseResult _parseCSVValues(String csvText, int lineNumber) {
    final errors = <String>[];
    final values = <dynamic>[];

    try {
      // シンプルなCSVパース（カンマ区切り、クォート対応）
      final parsedValues = _parseCSV(csvText);

      for (final valueStr in parsedValues) {
        final value = _parseValue(valueStr.trim());
        values.add(value);
      }

      return _CSVParseResult.success(values);
    } catch (e) {
      errors.add('行 $lineNumber: CSV値の解析エラー: $e');
      return _CSVParseResult.failure(errors);
    }
  }

  /// 値を適切な型に変換
  static dynamic _parseValue(String valueStr) {
    if (valueStr.isEmpty || valueStr.toLowerCase() == 'null') {
      return null;
    }

    // クォートされた文字列
    if ((valueStr.startsWith('"') && valueStr.endsWith('"')) ||
        (valueStr.startsWith("'") && valueStr.endsWith("'"))) {
      return valueStr.substring(1, valueStr.length - 1);
    }

    // 真偽値
    if (valueStr.toLowerCase() == 'true') return true;
    if (valueStr.toLowerCase() == 'false') return false;

    // 数値（整数）
    final intValue = int.tryParse(valueStr);
    if (intValue != null) {
      return intValue;
    }

    // 数値（浮動小数点）
    final doubleValue = double.tryParse(valueStr);
    if (doubleValue != null) {
      return doubleValue;
    }

    // デフォルトは文字列として扱う
    return valueStr;
  }

  /// シンプルなCSVパース（クォート対応）
  static List<String> _parseCSV(String csvLine) {
    final result = <String>[];
    final chars = csvLine.split('');
    final buffer = StringBuffer();
    bool inQuotes = false;
    String? quoteChar;

    for (int i = 0; i < chars.length; i++) {
      final char = chars[i];

      if (!inQuotes && (char == '"' || char == "'")) {
        // クォート開始
        inQuotes = true;
        quoteChar = char;
        buffer.write(char);
      } else if (inQuotes && char == quoteChar) {
        // クォート終了
        inQuotes = false;
        quoteChar = null;
        buffer.write(char);
      } else if (!inQuotes && char == ',') {
        // カンマ区切り
        result.add(buffer.toString());
        buffer.clear();
      } else {
        // 通常文字
        buffer.write(char);
      }
    }

    // 最後の値を追加
    if (buffer.isNotEmpty) {
      result.add(buffer.toString());
    }

    return result;
  }
}

/// CSV値のパース結果
class _CSVParseResult {
  final bool isSuccess;
  final List<dynamic> values;
  final List<String> errors;

  const _CSVParseResult({
    required this.isSuccess,
    required this.values,
    required this.errors,
  });

  factory _CSVParseResult.success(List<dynamic> values) {
    return _CSVParseResult(
      isSuccess: true,
      values: values,
      errors: [],
    );
  }

  factory _CSVParseResult.failure(List<String> errors) {
    return _CSVParseResult(
      isSuccess: false,
      values: [],
      errors: errors,
    );
  }
}