顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}, メール{email:string@}, パスワード{password:string!}, 住所{address:string}, 電話{phone:string}, 誕生日{birthday:datetime}, 作成日時{created_at:datetime!}, 更新日時{updated_at:datetime!}
-- 注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int}), 注文日時{order_datetime:datetime!}, 配送先住所{shipping_address:string!}, 配送先電話{shipping_phone:string}, 小計{subtotal:int!}, 送料{shipping_fee:int}, 税額{tax_amount:int}, 合計金額{total_amount:int!}, ステータス{status:string!}, 作成日時{created_at:datetime!}
  -- 注文明細{order_detail}: [明細ID{id:int}], (注文ID{order_id:int}), (商品ID{product_id:int}), 数量{quantity:int!}, 注文時単価{unit_price:int!}, 小計{subtotal:int!}
    -> 商品{product}: [商品ID{id:int}], 商品名{name:string!}, 商品説明{description:string}, 標準売価{std_price:int!}, 標準原価{std_cost:double}, 在庫数{stock_qty:int!}, 重量{weight:double}, サイズ{size:string}, 画像URL{image_url:string}, ステータス{status:string!}, 作成日時{created_at:datetime!}
-- お気に入り{favorite}: [お気に入りID{id:int}], (顧客ID{customer_id:int}), (商品ID{product_id:int}), 登録日時{registered_at:datetime!}
  -> 商品{product}
-- カート{cart}: [カートID{id:int}], (顧客ID{customer_id:int}), (商品ID{product_id:int}), 数量{quantity:int!}, 追加日時{added_at:datetime!}
  -> 商品{product}
-- レビュー{review}: [レビューID{id:int}], (顧客ID{customer_id:int}), (商品ID{product_id:int}), 評価{rating:int!}, コメント{comment:string}, 投稿日時{posted_at:datetime!}
  -> 商品{product}

カテゴリ{category}: [カテゴリID{id:int}], カテゴリ名{name:string!}, 説明{description:string}, 表示順{sort_order:int}, 親カテゴリID{parent_id:int}, 作成日時{created_at:datetime!}
-> 商品{product}

ブランド{brand}: [ブランドID{id:int}], ブランド名{name:string!}, 説明{description:string}, ロゴURL{logo_url:string}, 公式サイト{website:string}
-> 商品{product}

クーポン{coupon}: [クーポンID{id:int}], クーポン名{name:string!}, 割引タイプ{discount_type:string!}, 割引値{discount_value:int!}, 最低利用金額{min_amount:int}, 利用開始日{start_date:datetime!}, 利用終了日{end_date:datetime!}, 利用回数制限{usage_limit:int}, 現在利用回数{usage_count:int}, ステータス{status:string!}
-- クーポン利用{coupon_usage}: [利用ID{id:int}], (クーポンID{coupon_id:int}), (注文ID{order_id:int}), 割引金額{discount_amount:int!}, 利用日時{used_at:datetime!}
  -> 注文{order}

配送方法{shipping_method}: [配送方法ID{id:int}], 配送方法名{name:string!}, 基本料金{base_fee:int!}, 重量単価{weight_fee:double}, 説明{description:string}
-> 注文{order}

# サンプルデータ
@sample customer, 1, "田中太郎", "tanaka@example.com", "password123", "東京都渋谷区1-1-1", "090-1234-5678", 631152000, 1640995200, 1640995200
@sample customer, 2, "佐藤花子", "sato@example.com", "pass456", "大阪府大阪市北区2-2-2", "080-9876-5432", 694224000, 1641081600, 1641081600

@sample category, 1, "電子機器", "パソコンやスマートフォンなど", 1, null, 1640995200
@sample category, 2, "PC周辺機器", "マウス、キーボードなど", 2, 1, 1640995200

@sample brand, 1, "TechCorp", "高品質な電子機器メーカー", "https://example.com/logo1.png", "https://techcorp.com"
@sample brand, 2, "DevTools", "開発者向けツールメーカー", "https://example.com/logo2.png", "https://devtools.com"

@sample product, 1, "ノートパソコン", "高性能なノートパソコン", 89800, 65000.0, 10, 2.1, "35cm x 25cm x 2cm", "https://example.com/laptop.jpg", "販売中", 1640995200
@sample product, 2, "ワイヤレスマウス", "使いやすいワイヤレスマウス", 2980, 1500.0, 50, 0.1, "10cm x 6cm x 3cm", "https://example.com/mouse.jpg", "販売中", 1640995200
@sample product, 3, "メカニカルキーボード", "タイピングが快適なキーボード", 5980, 3200.0, 25, 0.8, "45cm x 15cm x 4cm", "https://example.com/keyboard.jpg", "販売中", 1640995200

@sample shipping_method, 1, "通常配送", 500, 0.0, "3-5営業日でお届け"
@sample shipping_method, 2, "お急ぎ便", 800, 0.0, "1-2営業日でお届け"

@sample order, 1, 1, 1641052800, "東京都渋谷区1-1-1", "090-1234-5678", 92780, 500, 9278, 102558, "配送完了", 1641052800
@sample order, 2, 2, 1641139200, "大阪府大阪市北区2-2-2", "080-9876-5432", 8960, 500, 896, 10356, "処理中", 1641139200

@sample order_detail, 1, 1, 1, 1, 89800, 89800
@sample order_detail, 2, 1, 2, 1, 2980, 2980
@sample order_detail, 3, 2, 3, 1, 5980, 5980
@sample order_detail, 4, 2, 2, 1, 2980, 2980

@sample favorite, 1, 1, 3, 1641052800
@sample favorite, 2, 2, 1, 1641139200

@sample cart, 1, 1, 2, 1, 1641225600
@sample cart, 2, 2, 3, 2, 1641225600

@sample review, 1, 1, 1, 5, "とても使いやすいです！", 1641398400
@sample review, 2, 1, 2, 4, "コンパクトで良い", 1641484800
@sample review, 3, 2, 3, 5, "打鍵感が最高です", 1641571200

@sample coupon, 1, "新規会員特典", "固定額", 1000, 5000, 1640995200, 1672531200, 1, 0, "有効"
@sample coupon, 2, "リピーター割引", "割合", 10, 10000, 1640995200, 1672531200, null, 5, "有効"

@sample coupon_usage, 1, 1, 1, 1000, 1641052800