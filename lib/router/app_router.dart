/// アプリケーションルーター設定
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';

/// アプリケーションルーター
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // ホーム画面（スキーマ選択・リアルタイムエディター切り替え）
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),

      // データビューアー画面
      GoRoute(
        path: '/viewer/:schemaName',
        name: 'viewer',
        builder: (context, state) {
          final schemaName = state.pathParameters['schemaName']!;
          return DataViewerPage(schemaName: schemaName);
        },
      ),
    ],
  );
});