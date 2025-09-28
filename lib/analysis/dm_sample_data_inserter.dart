/// サンプルデータインサーター
library;

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../main.dart' show kVerboseLogging;
import 'results/dm_database.dart';
import 'results/dm_table.dart';
import 'results/dm_column.dart';
import 'results/dm_sample_data.dart';

/// サンプルデータの挿入処理を担当するクラス
class DMSampleDataInserter {
  /// データベースにサンプルデータを挿入
  static Future<DMSampleDataInsertResult> insertSampleData(
    GeneratedDatabase database,
    DMDatabase dmDatabase,
  ) async {
    final errors = <String>[];
    final insertedCount = <String, int>{};

    if (kDebugMode && kVerboseLogging) {
      print('=== サンプルデータ挿入開始 ===');
      print('データベース: ${dmDatabase.name}');
      print('総サンプルデータ数: ${dmDatabase.sampleData.length}');
      print('総テーブル数: ${dmDatabase.tables.length}');
    }

    try {
      // 依存関係順にテーブルをソート
      final sortedTables = dmDatabase.tablesInDependencyOrder;

      if (kDebugMode && kVerboseLogging) {
        print('テーブル処理順序: ${sortedTables.map((t) => t.sqlName).join(' -> ')}');
      }

      // 各テーブルのサンプルデータを依存関係順に挿入
      for (final table in sortedTables) {
        final tableSampleData = dmDatabase.sampleData
            .where((sample) => sample.tableName == table.sqlName)
            .toList();

        if (tableSampleData.isEmpty) {
          if (kDebugMode) {
            print('テーブル ${table.sqlName}: サンプルデータなし - スキップ');
          }
          continue;
        }

        if (kDebugMode) {
          print('テーブル ${table.sqlName}: ${tableSampleData.length}件のサンプルデータを処理中...');
        }

        // テーブル内のサンプルデータを主キー順にソート
        tableSampleData.sort((a, b) {
          final aKey = a.primaryKeyValue;
          final bKey = b.primaryKeyValue;

          if (aKey is int && bKey is int) {
            return aKey.compareTo(bKey);
          }
          return aKey.toString().compareTo(bKey.toString());
        });

        // このテーブルのサンプルデータを挿入
        final result = await _insertTableSampleData(
          database,
          table,
          tableSampleData,
        );

        if (result.hasErrors) {
          if (kDebugMode) {
            print('テーブル ${table.sqlName}: ${result.errors.length}件のエラー');
            for (final error in result.errors) {
              print('  ERROR: $error');
            }
          }
          errors.addAll(result.errors);
        } else {
          insertedCount[table.sqlName] = result.insertedCount;
          if (kDebugMode) {
            print('テーブル ${table.sqlName}: ${result.insertedCount}件挿入完了');
          }
        }
      }

      if (errors.isNotEmpty) {
        if (kDebugMode) {
          print('=== サンプルデータ挿入結果: 失敗 ===');
          print('総エラー数: ${errors.length}');
          print('挿入成功テーブル数: ${insertedCount.length}');
        }
        return DMSampleDataInsertResult.failure(errors);
      }

      if (kDebugMode) {
        print('=== サンプルデータ挿入結果: 成功 ===');
        print('処理テーブル数: ${insertedCount.length}');
        print('総挿入レコード数: ${insertedCount.values.fold<int>(0, (sum, count) => sum + count)}');
        for (final entry in insertedCount.entries) {
          print('  ${entry.key}: ${entry.value}件');
        }
      }

      return DMSampleDataInsertResult.success(insertedCount);
    } catch (e) {
      final errorMsg = 'サンプルデータ挿入中にエラーが発生しました: $e';
      if (kDebugMode) {
        print('=== サンプルデータ挿入結果: 例外エラー ===');
        print(errorMsg);
      }
      errors.add(errorMsg);
      return DMSampleDataInsertResult.failure(errors);
    }
  }

  /// 単一テーブルのサンプルデータを挿入
  static Future<_TableInsertResult> _insertTableSampleData(
    GeneratedDatabase database,
    DMTable table,
    List<DMSampleData> sampleDataList,
  ) async {
    final errors = <String>[];
    int insertedCount = 0;

    // カラム名リストを取得（定義順、PRIMARY KEYを含む）
    final columnNames = table.allColumns.map((col) => col.sqlName).toList();

    if (kDebugMode && kVerboseLogging) {
      print('  ${table.sqlName}テーブル詳細:');
      print('    カラム数: ${columnNames.length}');
      print('    カラム名: ${columnNames.join(', ')}');
      print('    サンプルデータ行数: ${sampleDataList.length}');
    }

    for (final sampleData in sampleDataList) {
      try {
        if (kDebugMode && kVerboseLogging) {
          print('    行 ${sampleData.lineNumber}: 値 ${sampleData.values}');
        }

        // カラム値のマップを作成
        final values = sampleData.toColumnMap(columnNames);

        if (kDebugMode && kVerboseLogging) {
          print('      マップ作成後: $values');
        }

        // 足りないカラムはNULLで補完
        for (final columnName in columnNames) {
          if (!values.containsKey(columnName)) {
            values[columnName] = null;
          }
        }

        if (kDebugMode && kVerboseLogging) {
          print('      NULL補完後: $values');
        }

        // データ型検証
        final validationErrors = _validateDataTypes(table, values, sampleData.lineNumber);
        if (validationErrors.isNotEmpty) {
          if (kDebugMode) {
            print('      データ型検証エラー: $validationErrors');
          }
          errors.addAll(validationErrors);
          continue;
        }

        // INSERT文を実行（Driftの生SQL実行）
        final insertColumnNames = values.keys.toList();
        final columnValues = values.values.toList();
        final placeholders = List.filled(columnValues.length, '?').join(', ');

        final sql = 'INSERT OR REPLACE INTO `${table.sqlName}` (${insertColumnNames.map((c) => '`$c`').join(', ')}) VALUES ($placeholders)';

        if (kDebugMode && kVerboseLogging) {
          print('      SQL: $sql');
          print('      値: $columnValues');
        }

        await database.customInsert(sql, variables: columnValues.map((v) => Variable(v)).toList());

        insertedCount++;
        if (kDebugMode) {
          print('      ✓ 挿入成功');
        }
      } catch (e) {
        final errorMsg = '行 ${sampleData.lineNumber}: テーブル「${table.sqlName}」への挿入エラー: $e';
        if (kDebugMode) {
          print('      ✗ $errorMsg');
        }
        errors.add(errorMsg);
      }
    }

    return _TableInsertResult(
      insertedCount: insertedCount,
      errors: errors,
    );
  }

  /// データ型の検証
  static List<String> _validateDataTypes(
    DMTable table,
    Map<String, dynamic> values,
    int lineNumber,
  ) {
    final errors = <String>[];

    if (kDebugMode && kVerboseLogging) {
      print('        データ型検証開始:');
    }

    for (final column in table.allColumns) {
      final value = values[column.sqlName];

      if (kDebugMode) {
        print('          ${column.sqlName}: $value (型: ${column.type.name}, 必須: ${column.isRequired})');
      }

      // NOT NULL制約チェック
      if (column.isRequired && (value == null || value.toString().isEmpty)) {
        final error = '行 $lineNumber: カラム「${column.sqlName}」はNULL不可です';
        if (kDebugMode) {
          print('            ✗ $error');
        }
        errors.add(error);
        continue;
      }

      // データ型チェック
      if (value != null && !_isValidDataType(value, column.type)) {
        final error = '行 $lineNumber: カラム「${column.sqlName}」の値「$value」が型「${column.type.name}」に適合しません';
        if (kDebugMode) {
          print('            ✗ $error');
        }
        errors.add(error);
      } else if (kDebugMode) {
        print('            ✓ OK');
      }
    }

    return errors;
  }

  /// データ型の適合性チェック
  static bool _isValidDataType(dynamic value, DMDataType dataType) {
    if (value == null) return true;

    switch (dataType) {
      case DMDataType.integer:
        return value is int ||
               (value is String && int.tryParse(value) != null);

      case DMDataType.real:
        return value is double || value is int ||
               (value is String && double.tryParse(value) != null);

      case DMDataType.text:
        return true; // 任意の値を文字列として扱える

      case DMDataType.boolean:
        return value is bool ||
               (value is String &&
                ['true', 'false', '1', '0'].contains(value.toLowerCase()));

      case DMDataType.datetime:
        if (value is int) return true; // UNIX timestamp
        if (value is String) {
          // ISO 8601フォーマットや他の日付フォーマットの簡易チェック
          return DateTime.tryParse(value) != null ||
                 int.tryParse(value) != null; // UNIX timestamp as string
        }
        return value is DateTime;
    }
  }

  /// データベースの既存データをクリア（開発用）
  static Future<void> clearAllTables(
    GeneratedDatabase database,
    DMDatabase dmDatabase,
  ) async {
    if (kDebugMode) {
      print('既存テーブルデータのクリア開始...');
    }

    // 外部キー制約を一時的に無効化
    await database.customStatement('PRAGMA foreign_keys = OFF');

    try {
      // 依存関係の逆順でデータを削除
      final reversedTables = dmDatabase.tablesInDependencyOrder.reversed;

      for (final table in reversedTables) {
        try {
          // テーブルが存在するかチェック
          final tableExists = await _tableExists(database, table.sqlName);

          if (tableExists) {
            if (kDebugMode) {
              print('  テーブル ${table.sqlName} のデータを削除中...');
            }
            await database.customStatement('DELETE FROM `${table.sqlName}`');
          } else {
            if (kDebugMode) {
              print('  テーブル ${table.sqlName} は存在しません - スキップ');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('  テーブル ${table.sqlName} の削除でエラー: $e - 継続');
          }
          // エラーがあっても継続
        }
      }
    } finally {
      // 外部キー制約を再有効化
      await database.customStatement('PRAGMA foreign_keys = ON');

      if (kDebugMode) {
        print('既存テーブルデータのクリア完了');
      }
    }
  }

  /// テーブルが存在するかチェック
  static Future<bool> _tableExists(GeneratedDatabase database, String tableName) async {
    try {
      final result = await database.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        variables: [Variable.withString(tableName)],
      ).get();

      return result.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('テーブル存在チェックエラー: $e');
      }
      return false;
    }
  }
}

/// テーブル単位の挿入結果
class _TableInsertResult {
  final int insertedCount;
  final List<String> errors;

  const _TableInsertResult({
    required this.insertedCount,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
}

/// サンプルデータ挿入結果
class DMSampleDataInsertResult {
  final bool isSuccess;
  final Map<String, int> insertedCounts;
  final List<String> errors;

  const DMSampleDataInsertResult({
    required this.isSuccess,
    required this.insertedCounts,
    required this.errors,
  });

  factory DMSampleDataInsertResult.success(Map<String, int> insertedCounts) {
    return DMSampleDataInsertResult(
      isSuccess: true,
      insertedCounts: insertedCounts,
      errors: [],
    );
  }

  factory DMSampleDataInsertResult.failure(List<String> errors) {
    return DMSampleDataInsertResult(
      isSuccess: false,
      insertedCounts: {},
      errors: errors,
    );
  }

  /// 挿入されたレコード総数
  int get totalInsertedCount {
    return insertedCounts.values.fold<int>(0, (sum, count) => sum + count);
  }

  /// 結果のサマリーメッセージ
  String get summaryMessage {
    if (!isSuccess) {
      return 'サンプルデータの挿入に失敗しました (${errors.length} エラー)';
    }

    final tableCount = insertedCounts.length;
    final recordCount = totalInsertedCount;
    return 'サンプルデータを正常に挿入しました ($tableCount テーブル, $recordCount レコード)';
  }

  @override
  String toString() {
    return 'DMSampleDataInsertResult{success: $isSuccess, tables: ${insertedCounts.length}, records: $totalInsertedCount}';
  }
}