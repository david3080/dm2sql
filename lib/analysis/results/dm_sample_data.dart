/// サンプルデータクラス
library;

/// DMNotationのサンプルデータ定義
class DMSampleData {
  /// テーブル名（英語名）
  final String tableName;

  /// 主キー値（CSV最初の値）
  final dynamic primaryKeyValue;

  /// 全カラムの値リスト（主キー含む、カラム定義順）
  final List<dynamic> values;

  /// サンプルデータが定義された行番号
  final int lineNumber;

  const DMSampleData({
    required this.tableName,
    required this.primaryKeyValue,
    required this.values,
    required this.lineNumber,
  });

  /// テーブル定義と照合してMap形式に変換
  Map<String, dynamic> toColumnMap(List<String> columnNames) {
    final result = <String, dynamic>{};
    for (int i = 0; i < columnNames.length && i < values.length; i++) {
      result[columnNames[i]] = values[i];
    }
    return result;
  }

  /// 指定されたカラムの値を取得
  dynamic getValueForColumn(String columnName, List<String> columnNames) {
    final index = columnNames.indexOf(columnName);
    if (index >= 0 && index < values.length) {
      return values[index];
    }
    return null;
  }

  @override
  String toString() {
    return 'DMSampleData(table: $tableName, pk: $primaryKeyValue, values: $values)';
  }
}

/// サンプルデータのパース結果
class DMSampleDataParseResult {
  final bool isSuccess;
  final List<DMSampleData> sampleData;
  final List<String> errors;

  const DMSampleDataParseResult({
    required this.isSuccess,
    required this.sampleData,
    required this.errors,
  });

  factory DMSampleDataParseResult.success(List<DMSampleData> sampleData) {
    return DMSampleDataParseResult(
      isSuccess: true,
      sampleData: sampleData,
      errors: [],
    );
  }

  factory DMSampleDataParseResult.failure(List<String> errors) {
    return DMSampleDataParseResult(
      isSuccess: false,
      sampleData: [],
      errors: errors,
    );
  }
}