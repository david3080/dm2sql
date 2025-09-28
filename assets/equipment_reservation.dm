備品{equipment}: [備品ID{id:int}], 備品名{name:string!}, 備品コード{code:string@}, 型番{model_number:string}, メーカー{manufacturer:string}, 説明{description:string}, 購入日{purchase_date:datetime}, 購入価格{purchase_price:int}, 保証期限{warranty_expiry:datetime}, 設置場所{location:string}, ステータス{status:string!}, 作成日時{created_at:datetime!}
-- 予約{reservation}: [予約ID{id:int}], (備品ID{equipment_id:int}), (利用者ID{user_id:int}), 予約開始日時{start_datetime:datetime!}, 予約終了日時{end_datetime:datetime!}, 利用目的{purpose:string!}, 備考{note:string}, 予約ステータス{status:string!}, 予約日時{reserved_at:datetime!}, 承認者{approved_by:int}, 承認日時{approved_at:datetime}
  -> 利用者{user}: [利用者ID{id:int}], 利用者名{name:string!}, 社員番号{employee_number:string@}, メール{email:string@}, 電話{phone:string}, 部署名{department:string}, 役職{position:string}, 作成日時{created_at:datetime!}
-- 利用履歴{usage_history}: [履歴ID{id:int}], (備品ID{equipment_id:int}), (利用者ID{user_id:int}), 実際開始日時{actual_start_datetime:datetime!}, 実際終了日時{actual_end_datetime:datetime}, 利用状況{usage_status:string!}, 問題報告{issue_report:string}, 返却確認者{return_confirmed_by:int}, 返却確認日時{return_confirmed_at:datetime}
  -> 利用者{user}
-- 保守{maintenance}: [保守ID{id:int}], (備品ID{equipment_id:int}), 保守種別{maintenance_type:string!}, 実施日{maintenance_date:datetime!}, 実施者{maintainer:string}, 内容{description:string!}, 費用{cost:int}, 次回保守予定日{next_maintenance_date:datetime}, ステータス{status:string!}

カテゴリ{category}: [カテゴリID{id:int}], カテゴリ名{name:string!}, 説明{description:string}, 親カテゴリID{parent_id:int}
-> 備品{equipment}

場所{location}: [場所ID{id:int}], 場所名{name:string!}, 建物{building:string}, フロア{floor:string}, 詳細位置{detail_location:string}, 収容人数{capacity:int}, 設備{facilities:string}
-> 備品{equipment}

通知{notification}: [通知ID{id:int}], (利用者ID{user_id:int}), 通知タイトル{title:string!}, 通知内容{message:string!}, 通知種別{type:string!}, 送信日時{sent_at:datetime!}, 既読フラグ{is_read:bool}, 既読日時{read_at:datetime}
-> 利用者{user}

予約競合{reservation_conflict}: [競合ID{id:int}], (元予約ID{original_reservation_id:int}), (競合予約ID{conflicting_reservation_id:int}), 競合検出日時{detected_at:datetime!}, 解決ステータス{resolution_status:string!}, 解決方法{resolution_method:string}, 解決日時{resolved_at:datetime}
-> 予約{reservation}

利用ルール{usage_rule}: [ルールID{id:int}], (カテゴリID{category_id:int}), ルール名{name:string!}, ルール内容{content:string!}, 最大予約時間{max_reservation_hours:int}, 事前予約期間{advance_booking_days:int}, キャンセル期限{cancellation_deadline_hours:int}, 作成日時{created_at:datetime!}
-> カテゴリ{category}

休日設定{holiday}: [休日ID{id:int}], 休日名{name:string!}, 休日日付{holiday_date:datetime!}, 休日種別{type:string!}, 繰り返しフラグ{is_recurring:bool}, 説明{description:string}

# サンプルデータ
@sample category, 1, "会議室", "会議用の部屋", null
@sample category, 2, "PC機器", "パソコン関連機器", null
@sample category, 3, "プロジェクター", "プレゼン用機器", null

@sample user, 1, "田中太郎", "EMP001", "tanaka@company.com", "090-1234-5678", "開発部", "エンジニア", 1640995200
@sample user, 2, "佐藤花子", "EMP002", "sato@company.com", "090-2345-6789", "営業部", "営業", 1641000000
@sample user, 3, "山田次郎", "EMP003", "yamada@company.com", "090-3456-7890", "総務部", "総務", 1641005000

@sample equipment, 1, "会議室A", "MTG-A", "RoomA-2023", "会議室メーカー", "メイン会議室", 1609459200, 500000, 1735689600, "4F会議室", "利用可", 1640995200
@sample equipment, 2, "ノートパソコン #1", "NB-001", "NB-2023-001", "PCメーカー", "開発用ノートPC", 1609459200, 89000, 1735689600, "機器室", "利用可", 1640995200
@sample equipment, 3, "プロジェクター #1", "PROJ-001", "PROJ-2023-001", "映像機器メーカー", "HD対応プロジェクター", 1609459200, 120000, 1735689600, "機器室", "利用可", 1640995200

@sample reservation, 1, 1, 1, 1641024000, 1641027600, "定例会議", "週次定例", "承認", 1641000000, 1, 1641001000
@sample reservation, 2, 2, 2, 1641110400, 1641117600, "開発作業", "客先常駐用", "承認", 1641081600, 2, 1641082000
@sample reservation, 3, 3, 3, 1641196800, 1641200400, "プレゼン準備", "新商品発表", "予約中", 1641168000, null, null

@sample usage_history, 1, 1, 1, 1641024000, 1641027600, "正常使用", null, 1, 1641027700
@sample usage_history, 2, 2, 2, 1641110400, 1641117600, "正常使用", null, 2, 1641117700

@sample maintenance, 1, 1, "定期清掃", 1641369600, "清掃業者", "月次清掃", 5000, 1643875200, "完了"
@sample maintenance, 2, 2, "バッテリー交換", 1641456000, "PC修理業者", "バッテリー劣化のため交換", 15000, 1643961600, "完了"

@sample holiday, 1, "元日", 1641020400, "祝日", true, "年始の祝日"
@sample holiday, 2, "成人の日", 1641873600, "祝日", true, "成人の日"