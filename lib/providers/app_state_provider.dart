/// アプリケーション状態管理
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 表示モード（サンプルモデル表示 / リアルタイムエディター）
enum ViewMode {
  sampleModels('サンプルモデル'),
  realtimeEditor('リアルタイムエディター');

  const ViewMode(this.displayName);
  final String displayName;
}

/// 現在の表示モードプロバイダー
final viewModeProvider = StateProvider<ViewMode>((ref) => ViewMode.sampleModels);

/// リアルタイムエディターの状態
class RealtimeEditorState {
  final String dmNotationContent;
  final String? selectedSchemaName;
  final bool isProcessing;

  const RealtimeEditorState({
    this.dmNotationContent = '',
    this.selectedSchemaName,
    this.isProcessing = false,
  });

  RealtimeEditorState copyWith({
    String? dmNotationContent,
    String? selectedSchemaName,
    bool? isProcessing,
  }) {
    return RealtimeEditorState(
      dmNotationContent: dmNotationContent ?? this.dmNotationContent,
      selectedSchemaName: selectedSchemaName ?? this.selectedSchemaName,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

/// リアルタイムエディター状態プロバイダー
final realtimeEditorStateProvider = StateProvider<RealtimeEditorState>((ref) {
  return const RealtimeEditorState();
});