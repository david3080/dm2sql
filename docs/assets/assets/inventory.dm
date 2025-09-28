商品{product}: [商品ID{id:int}], 商品名{name:string!}, 商品コード{code:string@}, 型番{model_number:string}, 説明{description:string}, 単価{unit_price:int!}, 安全在庫数{safety_stock:int}, 最大在庫数{max_stock:int}, 重量{weight:double}, サイズ{size:string}, 作成日時{created_at:datetime!}
-- 在庫{stock}: [在庫ID{id:int}], (商品ID{product_id:int}), (倉庫ID{warehouse_id:int}), 現在庫数{current_qty:int!}, 引当済数量{allocated_qty:int}, 最終更新日時{last_updated:datetime!}
  -> 倉庫{warehouse}: [倉庫ID{id:int}], 倉庫名{name:string!}, 住所{address:string!}, 電話{phone:string}, 管理者名{manager_name:string}, 容量{capacity:int}, 作成日時{created_at:datetime!}
-- 入庫{inbound}: [入庫ID{id:int}], (商品ID{product_id:int}), (倉庫ID{warehouse_id:int}), (仕入先ID{supplier_id:int}), 入庫数量{quantity:int!}, 単価{unit_price:int!}, 合計金額{total_amount:int!}, 入庫日時{inbound_date:datetime!}, 作成者{created_by:string}, 備考{note:string}
  -> 倉庫{warehouse}
  -> 仕入先{supplier}: [仕入先ID{id:int}], 仕入先名{name:string!}, 連絡先{contact:string}, 住所{address:string}, 電話{phone:string}, メール{email:string@}, 支払条件{payment_terms:string}, 作成日時{created_at:datetime!}
-- 出庫{outbound}: [出庫ID{id:int}], (商品ID{product_id:int}), (倉庫ID{warehouse_id:int}), 出庫数量{quantity:int!}, 出庫理由{reason:string!}, 出庫先{destination:string}, 出庫日時{outbound_date:datetime!}, 作成者{created_by:string}, 備考{note:string}
  -> 倉庫{warehouse}
-- 棚卸{stock_taking}: [棚卸ID{id:int}], (商品ID{product_id:int}), (倉庫ID{warehouse_id:int}), 理論在庫{theoretical_qty:int!}, 実際在庫{actual_qty:int!}, 差異{difference:int!}, 棚卸日時{taking_date:datetime!}, 実施者{executor:string}, 承認者{approver:string}, ステータス{status:string!}
  -> 倉庫{warehouse}

カテゴリ{category}: [カテゴリID{id:int}], カテゴリ名{name:string!}, 説明{description:string}, 親カテゴリID{parent_id:int}
-> 商品{product}

発注{purchase_order}: [発注ID{id:int}], (仕入先ID{supplier_id:int}), 発注日{order_date:datetime!}, 希望納期{requested_delivery_date:datetime}, 合計金額{total_amount:int!}, ステータス{status:string!}, 作成者{created_by:string}, 承認者{approved_by:string}
-- 発注明細{purchase_order_detail}: [明細ID{id:int}], (発注ID{purchase_order_id:int}), (商品ID{product_id:int}), 発注数量{order_quantity:int!}, 単価{unit_price:int!}, 小計{subtotal:int!}
  -> 商品{product}
-> 仕入先{supplier}

在庫移動{stock_movement}: [移動ID{id:int}], (商品ID{product_id:int}), (移動元倉庫ID{from_warehouse_id:int}), (移動先倉庫ID{to_warehouse_id:int}), 移動数量{quantity:int!}, 移動理由{reason:string}, 移動日時{movement_date:datetime!}, 実施者{executor:string}
-> 商品{product}

# サンプルデータ
@sample warehouse, 1, "東京倉庫", "TOKYO", "東京都江東区1-1-1", "メイン倉庫", 1640995200
@sample warehouse, 2, "大阪倉庫", "OSAKA", "大阪府大阪市住之江区2-2-2", "関西地区倉庫", 1640995200

@sample supplier, 1, "TechSupply Co.", "tech@supply.com", "03-1234-5678", "東京都港区3-3-3", "IT機器サプライヤー"
@sample supplier, 2, "Office Goods Inc.", "info@officegoods.com", "06-9876-5432", "大阪府大阪市北区4-4-4", "オフィス用品サプライヤー"

@sample product, 1, "ノートパソコン", "NB001", "高性能ノートPC", 89800, 65000.0, 1640995200
@sample product, 2, "ワイヤレスマウス", "MS001", "Bluetoothマウス", 2980, 1500.0, 1640995200
@sample product, 3, "キーボード", "KB001", "メカニカルキーボード", 5980, 3200.0, 1640995200

@sample stock, 1, 1, 1, 50, 45, 5, 30, 1641024000
@sample stock, 2, 2, 1, 100, 85, 15, 50, 1641024000
@sample stock, 3, 3, 2, 30, 25, 5, 20, 1641024000

@sample purchase_order, 1, 1, 1641024000, "承認", 200000, 1641110400, "田中", 1641196800
@sample purchase_order, 2, 2, 1641110400, "発注中", 150000, 1641196800, "佐藤", null

@sample purchase_order_detail, 1, 1, 1, 10, 65000.0, 650000
@sample purchase_order_detail, 2, 2, 2, 50, 1500.0, 75000
@sample purchase_order_detail, 3, 2, 3, 25, 3200.0, 80000

@sample stock_movement, 1, 1, 1, 2, 5, "店舗補充", 1641283200, "山田"
@sample stock_movement, 2, 2, 2, 1, 10, "倉庫間移動", 1641369600, "鈴木"