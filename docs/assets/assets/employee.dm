社員{employee}: [社員ID{id:int}], 社員番号{employee_number:string@}, 氏名{name:string!}, フリガナ{name_kana:string}, メール{email:string@}, 電話{phone:string}, 住所{address:string}, 誕生日{birthday:datetime}, 入社日{hire_date:datetime!}, 退職日{resignation_date:datetime}, 基本給{base_salary:int}, ステータス{status:string!}, 作成日時{created_at:datetime!}
-- 勤怠{attendance}: [勤怠ID{id:int}], (社員ID{employee_id:int}), 勤務日{work_date:datetime!}, 出勤時刻{check_in_time:datetime}, 退勤時刻{check_out_time:datetime}, 休憩時間{break_minutes:int}, 実働時間{work_minutes:int}, 残業時間{overtime_minutes:int}, 遅刻時間{late_minutes:int}, 早退時間{early_leave_minutes:int}, 勤怠種別{attendance_type:string!}, 備考{note:string}
-- 給与{salary}: [給与ID{id:int}], (社員ID{employee_id:int}), 支給年月{pay_year_month:string!}, 基本給{base_amount:int!}, 残業手当{overtime_allowance:int}, 各種手当{other_allowances:int}, 支給総額{gross_amount:int!}, 所得税{income_tax:int}, 住民税{resident_tax:int}, 社会保険料{social_insurance:int}, 控除総額{total_deductions:int!}, 差引支給額{net_amount:int!}, 支給日{pay_date:datetime}
-- 評価{evaluation}: [評価ID{id:int}], (社員ID{employee_id:int}), 評価期間開始{period_start:datetime!}, 評価期間終了{period_end:datetime!}, 総合評価{overall_rating:string!}, 業績評価{performance_rating:string}, 能力評価{skill_rating:string}, コメント{comment:string}, 評価者{evaluator:string}, 評価日{evaluation_date:datetime!}
-- 有給休暇{paid_leave}: [有給ID{id:int}], (社員ID{employee_id:int}), 付与日{granted_date:datetime!}, 付与日数{granted_days:double!}, 使用日数{used_days:double}, 残日数{remaining_days:double!}, 有効期限{expiry_date:datetime!}

部署{department}: [部署ID{id:int}], 部署名{name:string!}, 部署コード{code:string@}, 説明{description:string}, 親部署ID{parent_id:int}, 部署長{manager_id:int}, 作成日時{created_at:datetime!}
-> 社員{employee}

役職{position}: [役職ID{id:int}], 役職名{name:string!}, 役職コード{code:string@}, 説明{description:string}, 階級{rank:int}, 基本給範囲下限{min_salary:int}, 基本給範囲上限{max_salary:int}
-> 社員{employee}

プロジェクト{project}: [プロジェクトID{id:int}], プロジェクト名{name:string!}, プロジェクトコード{code:string@}, 説明{description:string}, 開始日{start_date:datetime!}, 終了予定日{planned_end_date:datetime}, 実際終了日{actual_end_date:datetime}, ステータス{status:string!}, 予算{budget:int}, プロジェクト管理者{manager_id:int}
-- プロジェクト参加{project_assignment}: [参加ID{id:int}], (プロジェクトID{project_id:int}), (社員ID{employee_id:int}), 役割{role:string}, 参加開始日{start_date:datetime!}, 参加終了日{end_date:datetime}, 稼働率{workload_rate:double}
  -> 社員{employee}

研修{training}: [研修ID{id:int}], 研修名{name:string!}, 研修種別{type:string!}, 説明{description:string}, 開催日{training_date:datetime!}, 時間{duration_hours:double}, 定員{capacity:int}, 講師{instructor:string}, 費用{cost:int}
-- 研修受講{training_attendance}: [受講ID{id:int}], (研修ID{training_id:int}), (社員ID{employee_id:int}), 出席状況{attendance_status:string!}, 成績{score:int}, 修了状況{completion_status:string}, 受講日{attendance_date:datetime}
  -> 社員{employee}

申請{request}: [申請ID{id:int}], (申請者ID{employee_id:int}), 申請種別{request_type:string!}, 申請日{request_date:datetime!}, 開始日{start_date:datetime}, 終了日{end_date:datetime}, 理由{reason:string}, ステータス{status:string!}, 承認者{approver_id:int}, 承認日{approved_date:datetime}, 却下理由{rejection_reason:string}
-> 社員{employee}

# サンプルデータ
@sample department, 1, "開発部", "DEV", "ソフトウェア開発部門", null, null, 1640995200
@sample department, 2, "営業部", "SALES", "営業部門", null, null, 1640995200
@sample department, 3, "フロントエンド課", "FRONTEND", "フロントエンド開発", 1, null, 1640995200

@sample position, 1, "部長", "MGR", "部署の責任者", 1, 800000, 1000000
@sample position, 2, "課長", "SUP", "課の責任者", 2, 600000, 800000
@sample position, 3, "主任", "LEAD", "チームリーダー", 3, 450000, 600000
@sample position, 4, "一般", "STAFF", "一般職", 4, 300000, 450000

@sample employee, 1, "EMP001", "田中太郎", "タナカタロウ", "tanaka@company.com", "090-1234-5678", "東京都渋谷区1-1-1", 631152000, 1609459200, null, 500000, "在職", 1640995200
@sample employee, 2, "EMP002", "佐藤花子", "サトウハナコ", "sato@company.com", "080-9876-5432", "大阪府大阪市北区2-2-2", 694224000, 1617235200, null, 450000, "在職", 1640995200
@sample employee, 3, "EMP003", "山田次郎", "ヤマダジロウ", "yamada@company.com", "070-5555-1234", "名古屋市中区3-3-3", 757382400, 1625097600, null, 400000, "在職", 1640995200

@sample attendance, 1, 1, 1641024000, 1641024000, 1641052800, 60, 480, 0, 0, 0, "通常出勤", null
@sample attendance, 2, 1, 1641110400, 1641110400, 1641139200, 60, 480, 30, 0, 0, "通常出勤", "軽微な残業"
@sample attendance, 3, 2, 1641024000, 1641024000, 1641052800, 60, 480, 0, 0, 0, "通常出勤", null

@sample salary, 1, 1, "2024-01", 500000, 15000, 20000, 535000, 25000, 15000, 35000, 75000, 460000, 1643673600
@sample salary, 2, 2, "2024-01", 450000, 0, 18000, 468000, 20000, 12000, 32000, 64000, 404000, 1643673600

@sample evaluation, 1, 1, 1640995200, 1648771200, "A", "優秀", "A", "目標を上回る成果を達成", "部長", 1649030400
@sample evaluation, 2, 2, 1640995200, 1648771200, "B", "良好", "B", "安定した成果を維持", "部長", 1649030400

@sample paid_leave, 1, 1, 1640995200, 20.0, 5.0, 15.0, 1672531200
@sample paid_leave, 2, 2, 1617235200, 20.0, 3.0, 17.0, 1672531200

@sample training, 1, "新人研修", "基本的なビジネスマナーと会社ルール", 1641024000, 1641110400, "開発部", "田中部長", "完了"
@sample training, 2, "技術研修", "最新技術の習得", 1641196800, 1641283200, "開発部", "佐藤課長", "進行中"

@sample training_attendance, 1, 1, 1, "出席", 85, "修了", 1641024000
@sample training_attendance, 2, 2, 2, "出席", null, "受講中", 1641196800

@sample request, 1, 1, "有給休暇", 1641369600, 1641456000, 1641456000, "私用", "承認", 2, 1641456000, null
@sample request, 2, 2, "残業申請", 1641542400, 1641542400, 1641542400, "プロジェクト対応", "承認", 1, 1641628800, null