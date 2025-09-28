顧客{customer}: [顧客ID{id:int}], 顧客名{name:string!}, メール{email:string@}

商品{product}: [商品ID{id:int}], 商品名{name:string!}, 価格{price:int!}

注文{order}: [注文ID{id:int}], (顧客ID{customer_id:int}), 注文日時{order_date:datetime!}

# サンプルデータ
@sample customer, 1, "田中太郎", "tanaka@example.com"
@sample customer, 2, "佐藤花子", "sato@example.com"
@sample customer, 3, "山田次郎", "yamada@example.com"

@sample product, 1, "ノートパソコン", 89800
@sample product, 2, "マウス", 2980
@sample product, 3, "キーボード", 5980

@sample order, 1, 1, 1640995800
@sample order, 2, 2, 1641082200
@sample order, 3, 1, 1641168600