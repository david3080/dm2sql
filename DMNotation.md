# DMNotation記法 - データモデリング仕様

DMNotationは、視覚的で直感的なデータベーステーブル設計記法です。
インデント + 関係記号でテーブル間の関係を明確に表現します。

## 理論的背景

DMNotationは、渡辺幸三氏の「データモデル大全」で提唱された**三要素分析法**を理論的基盤としています。

- **エンティティ（実体）**: テーブル定義
- **リレーションシップ（関係）**: 関係性記号（--, ->, ??）
- **アトリビュート（属性）**: カラム定義

渡辺氏の手法を参考に、より実装しやすく明確な記法として発展させ、外部キー解決の曖昧性を排除する拡張機能を追加しています。

## 1. 基本構文

```
親テーブル{english_name}: [主キー], カラム1, カラム2, ...
-- 子テーブル{child_table}: [主キー], (外部キー), カラム, ...
   -> 参照テーブル{ref_table}: [主キー], カラム, ...
   ?? 弱参照テーブル{weak_ref}: [主キー], カラム, ...
```

## 2. テーブル定義

**構文**: `日本語名{english_name}: カラムリスト`

**例**:
```
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}, メール{email:string@}
商品{product}: [商品ID{id:int}], 商品名{name:string!}, 価格{price:int!}
```

## 3. カラム定義

### 主キー
**構文**: `[カラム名{column_name:type}]`
- 各テーブル必須1個
- 通常は `[テーブル名ID{id:int}]` パターン

**例**: `[顧客ID{id:int}]`

### 外部キー
**構文**: `(外部キー名{column_name:type})`
- 命名規則: `参照先テーブル名_id`
- 参照先テーブルは同一記法内で定義済みであること

**例**: `(顧客ID{customer_id:int})`

### 通常カラム
**構文**: `カラム名{column_name:type制約}` または `{column_name:type制約}`
- 日本語名は任意、省略可能

**例**: `顧客名{name:string!}`, `{email:string@}`

## 4. データ型

| 記法 | SQLite型 | 説明 |
|------|----------|------|
| `int` | INTEGER | 整数値 |
| `string` | TEXT | 文字列 |
| `double` | REAL | 浮動小数点数 |
| `datetime` | INTEGER | Unix timestamp |
| `bool` | INTEGER | 0/1のブール値 |

## 5. 制約記号

| 記号 | 制約 | 説明 |
|------|------|------|
| `!` | NOT NULL | 必須項目 |
| `@` | UNIQUE | 一意制約 |
| `*` | INDEX | 索引推奨 |

## 6. 関係性記号（シンプル版）

### `--` 親子関係（カスケード削除）
親レコード削除時、子レコードも自動削除される強い結合関係

```
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int}), 注文日時{order_date:datetime!}
```

### `->` 参照関係（独立性保持）
親レコード削除時、子レコードは残存する参照関係

```
注文明細{order_detail}: [明細ID{id:int}], (注文ID{order_id:int}), (商品ID{product_id:int})
-> 商品{product}: [商品ID{id:int}], 商品名{name:string!}, 価格{price:int!}
```

### `??` 弱参照（null許可）
参照先が存在しない場合もある任意参照関係

```
商品{product}: [商品ID{id:int}], 商品名{name:string!}, (カテゴリID{category_id:int})
?? カテゴリ{category}: [カテゴリID{id:int}], カテゴリ名{name:string!}
```

## 7. インデント階層ルール

### 基本ルール
- **4スペース = 1階層**
- 親テーブルの下に子テーブルをインデント
- 同一階層のテーブルは同じインデント深度

### 改良されたインデント構造ルール

#### 1. 同一インデントレベル制限

**基本原則**: 各インデントレベルに最大1つのテーブル定義のみ配置可能

**❌ 避けるべき例（親子関係が曖昧）**:
```
顧客{customer}: [ID{id:int}], 名前{name:string}
商品{product}: [ID{id:int}], 名前{name:string}  # 同じレベル
-- 注文{order}: [ID{id:int}], (顧客ID{customer_id:int}), (商品ID{product_id:int})
# 問題: orderの親はcustomerかproductか？
```

**✅ 正しい例（空行で分離）**:
```
顧客{customer}: [ID{id:int}], 名前{name:string}
-- 注文{order}: [ID{id:int}], (顧客ID{customer_id:int})

商品{product}: [ID{id:int}], 名前{name:string}  # 空行で分離
-- 在庫{stock}: [ID{id:int}], (商品ID{product_id:int})
```

#### 2. 空行による関係表現

独立したテーブルグループは空行で分離し、関係性は明示的に定義：

```
顧客{customer}: [ID{id:int}], 名前{name:string}
-- 注文{order}: [ID{id:int}], (顧客ID{customer_id:int})
   -- 注文明細{order_detail}: [ID{id:int}], (注文ID{order_id:int}), (商品ID{product_id:int})

商品{product}: [ID{id:int}], 名前{name:string}

カテゴリ{category}: [ID{id:int}], 名前{name:string}
-> 商品{product}  # 明示的参照
```

#### 3. 検証ルール

1. **インデント一意性**: 各インデントレベルに最大1つのテーブル定義
2. **親の明確性**: 関係性行は直近の上位インデントテーブルを親とする
3. **空行の意味**: 新しいテーブルグループの開始

#### 4. メリット

- **明確な関係性**: 親子関係の曖昧さが排除される
- **視覚的整理**: 空行によるグループ化で可読性向上
- **意図の明確化**: 設計者の意図が正確に表現される
- **保守性向上**: 後からの変更時も関係性が明確

```
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int}), 注文日時{order_date:datetime!}
   -- 注文明細{order_detail}: [明細ID{id:int}], (注文ID{order_id:int}), (商品ID{product_id:int})
      -> 商品{product}: [商品ID{id:int}], 商品名{name:string!}
-- お気に入り{favorite}: [お気に入りID{id:int}], (顧客ID{customer_id:int}), (商品ID{product_id:int})
   -> 商品{product}
```

## 8. 外部キー解決と@記法拡張

### 外部キー解決の優先順位

1. **階層関係（--）**: `テーブル名_id`パターンを優先割り当て
2. **明示指定（@記法）**: 指定された外部キーに確定割り当て
3. **智的解決（->）**: パターンマッチングで最適割り当て
4. **エラー検出**: 解決不可能な曖昧性を報告

### @記法による明示的外部キー指定

複数の外部キーが同じテーブルを参照する場合の曖昧性を解決するため、参照行で外部キーを明示的に指定できます。

**構文**: `-> テーブル{name@column_name}`

**使用例**:
```
ユーザー{user}: [ID{id:int}], 名前{name:string}
-- フォロー{follow}: [ID{id:int}], (フォロワーID{follower_id:int}), (フォロー先ID{following_id:int})
   -> ユーザー{user@follower_id}   # follower_idによる参照
   -> ユーザー{user@following_id}  # following_idによる参照

-- コメント{comment}: [ID{id:int}], (ユーザーID{user_id:int}), (投稿者ID{author_id:int})
   -> ユーザー{user@author_id}     # author_idによる明示的参照
   # user_idは階層関係（--）で自動割り当て
```

### ハイブリッドアプローチ

**シンプルなケース**: 智的解決に任せる
```
-> ユーザー{user}  # 自動的に適切な外部キーを推測
```

**曖昧なケース**: @記法で明示的に指定
```
-> ユーザー{user@specific_column_id}  # 明確に指定
```

**メリット**:
- 必要最小限の明示化
- 記法の冗長性を回避
- 段階的な複雑さ対応
- 完全な曖昧性排除

## 9. テーブル再定義ルール

### 初出時完全定義
初めて出現するテーブルはすべてのカラムを完全記載

```
商品{product}: [商品ID{id:int}], 商品名{name:string!}, 価格{price:int!}
```

### 2回目以降名前のみ
同一テーブルが別の関係で出現する場合は名前のみ記載

```
お気に入り{favorite}: [お気に入りID{id:int}], (顧客ID{customer_id:int}), (商品ID{product_id:int})
-> 商品{product}  # 初出定義を参照
```

## 10. 完全例

```
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}, メール{email:string@}, 住所{address:string}, 電話{phone:string}, 作成日時{created_at:datetime!}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int}), 注文日時{order_datetime:datetime!}, 合計金額{total_amount:int!}, ステータス{status:string!}
   -- 注文明細{order_detail}: [明細ID{id:int}], (注文ID{order_id:int}), (商品ID{product_id:int}), 数量{quantity:int!}, 単価{unit_price:int!}, 小計{subtotal:int!}
      -> 商品{product}: [商品ID{id:int}], 商品名{name:string!}, 説明{description:string}, 標準売価{std_price:int!}, 標準原価{std_cost:double}, 在庫数{stock_qty:int!}
-- お気に入り{favorite}: [お気に入りID{id:int}], (顧客ID{customer_id:int}), (商品ID{product_id:int}), 登録日時{registered_at:datetime!}
   -> 商品{product}

カテゴリ{category}: [カテゴリID{id:int}], カテゴリ名{name:string!}, 説明{description:string}, 表示順{sort_order:int}
-> 商品{product}

配送先{shipping_address}: [配送先ID{id:int}], (顧客ID{customer_id:int}), 配送先名{name:string!}, 郵便番号{postal_code:string}, 住所{address:string!}, 電話{phone:string}
```

## 11. 拡張記法の活用例

### 複雑な参照関係での@記法活用

```
社員{employee}: [ID{id:int}], 名前{name:string}
-- プロジェクト{project}: [ID{id:int}], 名前{name:string}, (管理者ID{manager_id:int})
   -- 参加{assignment}: [ID{id:int}], (プロジェクトID{project_id:int}), (参加者ID{participant_id:int}), (承認者ID{approver_id:int})
      -> 社員{employee@participant_id}  # 参加者
      -> 社員{employee@approver_id}     # 承認者
   -> 社員{employee@manager_id}         # プロジェクト管理者

部署{department}: [ID{id:int}], 名前{name:string}
-> 社員{employee}  # 所属関係（department_idを自動推測）
```

### 解決パターン説明

1. **階層関係**: `employee -- project` では `manager_id`が自動推測される場合
2. **明示的指定**: `assignment -> employee@participant_id`
3. **明示的指定**: `assignment -> employee@approver_id`
4. **智的解決**: `department -> employee` では `department_id`を推測

## 12. 構文チェックリスト

**基本構文**:
- [ ] テーブル名に日本語名{english_name}形式使用
- [ ] 各テーブルに[主キー定義]が存在
- [ ] 外部キー(参照名)の参照先テーブル定義済み

**関係性**:
- [ ] 関係記号（--, ->, ??）適切に選択
- [ ] インデント階層（4スペース単位）正確
- [ ] 初出テーブル完全定義、2回目以降名前のみ
- [ ] 同一インデントレベルには最大1つのテーブル定義
- [ ] 複数参照の曖昧性がある場合は@記法使用
- [ ] 空行による適切なグループ分離

**制約・型**:
- [ ] SQLite対応型のみ使用
- [ ] 必須制約（!）適切に設定
- [ ] 参照整合性が保たれている

---

## 8. サンプルデータ定義

### 基本構文
**構文**: `@sample テーブル名, 値1, 値2, 値3, ...`

- テーブル名は`{}`内の英語名を使用
- 値はテーブル定義でのカラム宣言順に記述
- CSV形式で主キーを含む全カラムの値を指定

### 例
```
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}, メール{email:string@}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int}), 注文日時{order_date:datetime!}

# サンプルデータ
@sample customer, 1, "田中太郎", "tanaka@example.com"
@sample customer, 2, "佐藤花子", "sato@example.com"
@sample order, 1, 1, 1640995800
@sample order, 2, 2, 1641082200
```

### 値の記述形式
| データ型 | 記述例 | 説明 |
|----------|--------|------|
| `int` | `123`, `0`, `-456` | 整数値 |
| `string` | `"テキスト"`, `"田中太郎"` | 文字列（カンマを含む場合はクォート必須） |
| `double` | `123.45`, `0.0` | 浮動小数点数 |
| `datetime` | `1640995800` | Unix timestamp |
| `bool` | `1`, `0`, `true`, `false` | 真偽値 |
| NULL値 | `null`, `` | NULL値または空白 |

### 投入順序と外部キー制約
- システムが依存関係を自動解析し、適切な順序でデータを投入
- 外部キー参照先が存在しない場合はバリデーションエラー
- ユーザーは任意の順序でサンプルデータを記述可能

```
# 記述順序は自由（システムが自動調整）
@sample order, 1, 1, 1640995800      # customer_id=1を参照
@sample customer, 1, "田中太郎", "tanaka@example.com"  # 後から定義でもOK
```

### バリデーション
- **カラム数チェック**: テーブル定義とサンプルデータの値数の一致
- **データ型チェック**: 各カラムのデータ型との整合性
- **制約チェック**: NOT NULL制約、UNIQUE制約の確認
- **外部キーチェック**: 参照先レコードの存在確認

## 設計思想と拡張方針

**基本思想**: 最小限の記号で最大限の表現力 + 実装の容易さを両立

**渡辺氏からの継承**:
- 視覚的で直感的なデータモデリング手法
- エンティティ、リレーションシップ、アトリビュートの三要素分析
- 現実のビジネス要件に即したモデリング思考

**dm2sql独自の拡張**:
- 外部キー曖昧性の完全排除（@記法）
- 厳密なインデント構造ルール
- SQLite/Drift ORM自動生成対応
- プログラマティックな解析とバリデーション

**進化の方向性**:
- 理論的正確性と実装の容易さの両立
- 段階的学習コスト（シンプル → 複雑）
- 設計者の意図を正確に表現する記法の追求