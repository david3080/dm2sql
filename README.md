# DM2SQL - DMNotation to SQLite WASM Converter

DMNotation記法からSQLite WASMデータベースを自動構築するFlutter Webアプリケーション

## 🌟 概要

このプロジェクトは、独自のDMNotation記法（データモデリング記法）からSQLiteデータベースを自動生成し、ブラウザ上でSQLite WASM技術を使用してデータベース操作ができるWebアプリケーションです。

### 主な特徴

- 🚀 **Web専用**: Flutter Web + SQLite WASMで動作
- 📝 **DMNotation対応**: 視覚的で直感的なデータモデリング記法
- 🔧 **自動生成**: テーブル定義からSQL文を自動生成
- 🌐 **ブラウザ内DB**: WebAssemblyによる高速なデータベース処理
- 📱 **レスポンシブ**: モバイル・デスクトップ対応UI

## 🛠️ 技術スタック

- **Flutter Web**: フロントエンドフレームワーク
- **Drift ORM**: SQLiteのType-safe ORM
- **SQLite WASM**: WebAssemblyベースのSQLite
- **GitHub Pages**: 静的サイトホスティング

## 🚀 初期セットアップ

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

3. **Driftコードの生成**
```bash
dart run build_runner build
```

4. **開発サーバーの起動**
```bash
flutter run -d chrome
```

5. **本番ビルド（GitHub Pages用）**
```bash
flutter build web --base-href="/dm2sql/" --output=docs
```

## 📁 プロジェクト構造

```
dm2sql/
├── lib/
│   ├── database.dart        # Driftデータベース定義
│   ├── database.g.dart      # 自動生成コード
│   └── main.dart            # メインアプリケーション
├── web/
│   ├── .nojekyll            # Jekyll無効化
│   ├── .htaccess            # WASM MIME設定
│   ├── sqlite3.wasm         # SQLite WebAssembly
│   └── drift_worker.dart.js # Drift Web Worker
├── docs/                    # GitHub Pages配信用（自動生成）
└── pubspec.yaml             # Web専用依存関係
```

## 💾 現在のデータベース構造

### 顧客テーブル (customers)
- `id`: 主キー（自動増分）
- `name`: 顧客名（必須）
- `email`: メールアドレス（ユニーク）
- `address`: 住所（任意）
- `phone`: 電話番号（任意）
- `created_at`: 作成日時（自動設定）

### 商品テーブル (products)
- `id`: 主キー（自動増分）
- `name`: 商品名（必須）
- `description`: 商品説明（任意）
- `price`: 価格
- `stock`: 在庫数（デフォルト0）
- `created_at`: 作成日時（自動設定）

## 🎯 現在の機能

### ✅ 実装済み
- [x] Flutter Web + SQLite WASM基盤
- [x] Drift ORMによるtype-safeなDB操作
- [x] 顧客・商品データの表示
- [x] タブ形式のUI
- [x] 初期データの自動セットアップ
- [x] エラーハンドリング
- [x] GitHub Pages対応

### 🎨 UI機能
- [x] 顧客一覧表示（カード形式）
- [x] 商品一覧表示（カード形式）
- [x] ローディング表示
- [x] エラー表示・再試行機能
- [x] レスポンシブデザイン

## 🗓️ 今後の開発予定

### Phase 1: DMNotation記法パーサー
- [ ] DMNotation記法の構文解析機能
- [ ] テキストからテーブル定義への変換
- [ ] 関係性（親子・参照・弱参照）の解析
- [ ] 構文エラーの検出・報告

### Phase 2: エディター機能
- [ ] DMNotation記法のテキストエディター
- [ ] シンタックスハイライト
- [ ] リアルタイムプレビュー
- [ ] 自動補完機能

### Phase 3: SQL生成・実行
- [ ] DMNotationからCREATE TABLE文の自動生成
- [ ] インデックス・制約の自動生成
- [ ] DDL実行とテーブル作成
- [ ] 初期データの生成・投入

### Phase 4: データ操作機能
- [ ] CRUD操作UI
- [ ] データのインポート・エクスポート
- [ ] SQLクエリ実行機能
- [ ] データベーススキーマの可視化

### Phase 5: 高度な機能
- [ ] テーブル間関係の可視化
- [ ] データマイグレーション機能
- [ ] バックアップ・復元機能
- [ ] パフォーマンス分析

## 🌐 デプロイ

### GitHub Pages
本プロジェクトはGitHub Pagesで自動デプロイされます：

1. `docs`フォルダにビルド結果を出力
2. GitHubリポジトリ設定でPages source を `/docs` に設定
3. `https://yourusername.github.io/dm2sql/` でアクセス可能

### ローカル確認
```bash
# 開発モード
flutter run -d chrome

# プロダクションビルド確認
flutter build web --output=docs
cd docs && python -m http.server 8080
```

## 📚 DMNotation記法について

DMNotation記法は、視覚的で編集しやすいデータモデリング記法です。
詳細な仕様は `4_1_DMNotation.md` を参照してください。

### 基本例
```
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}, メール{email:string@}
├─注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int}), 注文日時{order_date:datetime!}
└─お気に入り{favorite}: [お気に入りID{id:int}], (顧客ID{customer_id:int}), (商品ID{product_id:int})
```

## 🤝 貢献

プロジェクトへの貢献を歓迎します：

1. フォークしてブランチを作成
2. 機能追加・バグ修正
3. テストの確認
4. プルリクエストの作成

## 📄 ライセンス

このプロジェクトは[MIT License](LICENSE)のもとで公開されています。

## 🔗 関連リンク

- [Flutter Web](https://flutter.dev/web)
- [Drift ORM](https://drift.simonbinder.eu/)
- [SQLite WASM](https://sqlite.org/wasm/)
- [GitHub Pages](https://pages.github.com/)

---

**開発者**: Claude Code Team
**最終更新**: 2025年9月27日
