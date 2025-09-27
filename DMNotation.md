# DMNotation記法 - データモデリング仕様

DMNotationは、視覚的で直感的なデータベーステーブル設計記法です。
インデント + 関係記号でテーブル間の関係を明確に表現します。

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

- **4スペース = 1階層**
- 親テーブルの下に子テーブルをインデント
- 同一階層のテーブルは同じインデント深度

```
顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int}), 注文日時{order_date:datetime!}
   -- 注文明細{order_detail}: [明細ID{id:int}], (注文ID{order_id:int}), (商品ID{product_id:int})
      -> 商品{product}: [商品ID{id:int}], 商品名{name:string!}
-- お気に入り{favorite}: [お気に入りID{id:int}], (顧客ID{customer_id:int}), (商品ID{product_id:int})
   -> 商品{product}
```

## 8. テーブル再定義ルール

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

## 9. 完全例

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

## 10. 構文チェックリスト

**基本構文**:
- [ ] テーブル名に日本語名{english_name}形式使用
- [ ] 各テーブルに[主キー定義]が存在
- [ ] 外部キー(参照名)の参照先テーブル定義済み

**関係性**:
- [ ] 関係記号（--, ->, ??）適切に選択
- [ ] インデント階層（4スペース単位）正確
- [ ] 初出テーブル完全定義、2回目以降名前のみ

**制約・型**:
- [ ] SQLite対応型のみ使用
- [ ] 必須制約（!）適切に設定
- [ ] 参照整合性が保たれている

---

**設計思想**: 最小限の記号で最大限の表現力 + 実装の容易さを両立