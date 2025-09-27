# DM2SQL - DMNotation to SQLite WASM Converter

DMNotation記法からSQLite WASMデータベースを自動構築するFlutter Webアプリケーション

## 🌟 概要

このプロジェクトは、独自のDMNotation記法（データモデリング記法）からSQLiteデータベースを自動生成し、ブラウザ上でSQLite WASM技術を使用してデータベース操作ができるWebアプリケーションです。

### 主な特徴

- 🚀 **Web専用**: Flutter Web + SQLite WASMで動作
- 📝 **DMNotation対応**: 視覚的で直感的なデータモデリング記法
- 🔧 **動的スキーマ**: ビルド不要でスキーマを動的生成・変更
- 🎯 **drift_dev風DAO**: 実行時にDrift風の流暢APIを自動生成
- 🌐 **ブラウザ内DB**: WebAssemblyによる高速なデータベース処理
- 📱 **レスポンシブ**: モバイル・デスクトップ対応UI
- 📊 **6つのサンプルスキーマ**: ECサイト、在庫管理、社員管理など

## 🛠️ 技術スタック

- **Flutter Web**: フロントエンドフレームワーク
- **Drift ORM**: 最小限利用（WASM接続管理のみ）
- **SQLite WASM**: WebAssemblyベースのSQLite
- **動的スキーマ**: 実行時テーブル生成・DAO作成
- **GitHub Pages**: 静的サイトホスティング

## 🏗️ アーキテクチャ設計

### drift_dev風動的アーキテクチャ

本プロジェクトでは、**drift_devのクラス設計パターンを参考にした動的アーキテクチャ**を採用しています。

```
DMNotation記法
      ↓
[DMNotationAnalyzer] ← 2段階解析（テーブル→関係性）
      ↓
Analysis Results ← dm_table.dart, dm_column.dart, dm_constraint.dart
      ↓
[DynamicDAO] ← Drift風の流暢API (select, into, update, delete)
      ↓
SQLite WASM実行
```

### 実装済みコンポーネント

#### Analysis Layer (分析層)
- `analysis/dm_notation_analyzer.dart`: DMNotation構文解析
- `analysis/results/dm_database.dart`: データベース定義
- `analysis/results/dm_table.dart`: テーブル定義・SQL生成
- `analysis/results/dm_column.dart`: カラム定義・型システム
- `analysis/results/dm_constraint.dart`: 制約定義

#### Runtime Layer (実行時層)
- `runtime/dynamic_dao.dart`: Drift風のDAO・クエリビルダー
- `database.dart`: 最小限のDrift統合

#### Assets & UI
- `asset_loader.dart`: 6つのサンプルスキーマ管理
- `main.dart`: Flutter Web UI

### 設計原則

- **分析と実行の分離**: drift_devのAnalyzer/Writerパターンを参考
- **実行時型安全**: 動的型変換・バリデーション
- **流暢API**: `dao.select('table').where(...).get()`
- **スキーマファースト**: DMNotationから直接DB構築

## 🚀 セットアップ

### 前提条件

- Flutter SDK 3.24以上
- Chrome/Firefoxなどモダンブラウザ（WASM対応）

### セットアップ手順

1. **リポジトリのクローン**
```bash
git clone <repository-url>
cd dm2sql
```

2. **依存関係のインストール**
```bash
flutter pub get
```

3. **開発サーバーの起動**
```bash
flutter run -d chrome
```

4. **本番ビルド（GitHub Pages用）**
```bash
flutter build web --base-href="/dm2sql/" --output=docs
```

## 📁 プロジェクト構造

```
dm2sql/
├── lib/
│   ├── analysis/                    # 分析層（drift_dev風）
│   │   ├── dm_notation_analyzer.dart  # DMNotation解析エンジン
│   │   └── results/                 # 解析結果定義
│   │       ├── dm_database.dart     # データベース定義
│   │       ├── dm_table.dart        # テーブル定義・SQL生成
│   │       ├── dm_column.dart       # カラム定義・型システム
│   │       └── dm_constraint.dart   # 制約定義
│   ├── runtime/                     # 実行時層
│   │   └── dynamic_dao.dart         # Drift風動的DAO
│   ├── database.dart                # 最小限Drift統合
│   ├── asset_loader.dart            # サンプルスキーマ管理
│   └── main.dart                    # Flutter Web UI
├── assets/                          # DMNotationサンプルファイル
│   ├── simple_test.dmnotation       # テスト用シンプルスキーマ
│   ├── ecommerce.dmnotation         # ECサイトスキーマ
│   ├── inventory.dmnotation         # 在庫管理スキーマ
│   ├── employee.dmnotation          # 社員管理スキーマ
│   ├── equipment_reservation.dmnotation # 備品予約スキーマ
│   └── blog.dmnotation              # ブログスキーマ
├── web/
│   ├── .nojekyll                    # Jekyll無効化
│   ├── .htaccess                    # WASM MIME設定
│   ├── sqlite3.wasm                 # SQLite WebAssembly
│   └── drift_worker.dart.js         # Drift Web Worker
└── docs/                            # GitHub Pages配信用（自動生成）
```

## 🎯 実装済み機能

### ✅ コア機能

- [x] **DMNotation解析**: 2段階解析（テーブル→関係性）
- [x] **動的スキーマ生成**: 実行時CREATE TABLE文生成
- [x] **型安全システム**: 実行時型変換・バリデーション
- [x] **外部キー対応**: 推測ロジック付き参照解析
- [x] **Drift風DAO**: `select`, `into`, `update`, `delete`ビルダー
- [x] **6つのサンプルスキーマ**: ECサイト〜ブログまで

### ✅ データ型対応

- [x] **基本型**: `integer`, `text`, `real`, `datetime`, `boolean`
- [x] **制約**: `NOT NULL(!)`、`UNIQUE(@)`、`INDEX(*)`
- [x] **主キー**: `[カラム{name:type}]`記法
- [x] **外部キー**: `(カラム{name:type})`記法

### ✅ UI機能

- [x] **スキーマ選択**: 6つのサンプルスキーマ切り替え
- [x] **テーブル一覧**: 動的生成されたテーブル表示
- [x] **データ表示**: 各テーブルのサンプルデータ表示
- [x] **エラーハンドリング**: 詳細なエラーメッセージ表示
- [x] **レスポンシブUI**: Material Design 3対応

### ✅ 技術的成果

- [x] **SQLite予約語対応**: バッククォートエスケープ
- [x] **複合外部キー**: 複数外部キーのSQL生成
- [x] **依存関係順序**: テーブル作成の正しい順序
- [x] **推測ロジック**: `from_warehouse_id` → `warehouse`

## 📊 サンプルスキーマ

### 1. シンプルテスト
パーサーテスト用の基本的なテーブル定義

### 2. ECサイト
```dmnotation
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}, メール{email:string@}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int}), 注文日時{order_datetime:datetime!}
   -- 注文明細{order_detail}: [明細ID{id:int}], (注文ID{order_id:int}), (商品ID{product_id:int})
```

### 3. 在庫管理
商品・倉庫・入出庫・棚卸などの完全な在庫管理システム

### 4. 社員管理
社員・勤怠・給与・評価などの人事管理システム

### 5. 備品予約
備品・予約・利用履歴などの施設管理システム

### 6. ブログ
ユーザー・投稿・コメント・タグなどのCMSシステム

## 🗓️ 今後の改善計画

### Phase 1: インデント構造解析の完全実装 🚧
- [ ] 正しい階層構造解析
- [ ] 推測ロジックの削除
- [ ] パフォーマンス向上

### Phase 2: UI/UX の改善
- [ ] リアルタイムプレビュー機能
- [ ] ER図の可視化
- [ ] DMNotation構文エラーの行番号表示
- [ ] テーブルデータの直接編集

### Phase 3: SQL機能の拡張
- [ ] 複雑なクエリ対応（JOIN, GROUP BY）
- [ ] インデックス管理UI
- [ ] スキーママイグレーション
- [ ] SQLログ表示

### Phase 4: DMNotation記法の拡張
- [ ] 明示的外部キー定義: `{customer_id:int->customer.id}`
- [ ] CHECK制約、DEFAULT値
- [ ] JSON、BLOB、ENUM型対応
- [ ] カスタムバリデーター

### Phase 5: 開発者向け機能
- [ ] パフォーマンス分析
- [ ] Dartコード生成
- [ ] テストデータ生成
- [ ] プラグインシステム

## 🌐 デプロイ

### GitHub Pages
本プロジェクトはGitHub Pagesで自動デプロイされます：

1. `docs`フォルダにビルド結果を出力
2. GitHubリポジトリ設定でPages sourceを`/docs`に設定
3. `https://yourusername.github.io/dm2sql/`でアクセス可能

### ローカル確認
```bash
# 開発モード
flutter run -d chrome

# プロダクションビルド確認
flutter build web --output=docs
cd docs && python -m http.server 8080
```

## 📚 DMNotation記法

DMNotation記法は、視覚的で編集しやすい独自のデータモデリング記法です。

### 基本構文

```dmnotation
テーブル名{table_name}: [主キー{id:int}], カラム{column:type制約}, ...
-- 子テーブル{child}: [ID{id:int}], (外部キー{parent_id:int}), データ{data:string}
   -> 参照テーブル{reference}: [ID{id:int}], 名前{name:string}
```

### 制約記号
- `!`: NOT NULL制約
- `@`: UNIQUE制約
- `*`: INDEX推奨

### 関係記号
- `--`: カスケード削除
- `->`: 参照関係
- `??`: 弱参照

### 複雑な例
```dmnotation
在庫移動{stock_movement}: [移動ID{id:int}], (移動元倉庫ID{from_warehouse_id:int}), (移動先倉庫ID{to_warehouse_id:int})
-> 商品{product}: [商品ID{id:int}], 商品名{name:string!}
```

## 🔧 技術的詳細

### 推測ロジック
現在の実装では、外部キー参照先を以下のロジックで推測：

1. **プレフィックス除去**: `from_warehouse_id` → `warehouse`
2. **役割マッピング**: `author_id` → `user`
3. **複合語保持**: `purchase_order_id` → `purchase_order`

### SQL生成の特徴
- SQLite予約語の自動エスケープ
- 依存関係順でのテーブル作成
- 外部キー制約の正しい配置

## 📄 ライセンス

このプロジェクトは[MIT License](LICENSE)のもとで公開されています。

## 🔗 関連リンク

- [Flutter Web](https://flutter.dev/web)
- [Drift ORM](https://drift.simonbinder.eu/)
- [SQLite WASM](https://sqlite.org/wasm/)
- [GitHub Pages](https://pages.github.com/)

---

**開発者**: Masanobu Takagi
**最終更新**: 2025年9月27日
**バージョン**: v2.0 - drift_dev風アーキテクチャ完全実装