ユーザー{user}: [ユーザーID{id:int}], ユーザー名{username:string@}, 表示名{display_name:string!}, メール{email:string@}, パスワード{password:string!}, プロフィール画像{profile_image:string}, 自己紹介{bio:string}, ウェブサイト{website:string}, 登録日時{created_at:datetime!}, 最終ログイン{last_login:datetime}, ステータス{status:string!}
-- 投稿{post}: [投稿ID{id:int}], (著者ID{author_id:int}), タイトル{title:string!}, スラッグ{slug:string@}, 内容{content:string!}, 抜粋{excerpt:string}, アイキャッチ画像{featured_image:string}, 公開ステータス{status:string!}, 投稿日時{published_at:datetime}, 作成日時{created_at:datetime!}, 更新日時{updated_at:datetime!}, 閲覧数{view_count:int}, いいね数{like_count:int}
  -- コメント{comment}: [コメントID{id:int}], (投稿ID{post_id:int}), (コメント者ID{commenter_id:int}), 内容{content:string!}, 承認ステータス{status:string!}, 投稿日時{created_at:datetime!}, 更新日時{updated_at:datetime}, 親コメントID{parent_id:int}
    -> ユーザー{user}
  -- いいね{like}: [いいねID{id:int}], (投稿ID{post_id:int}), (ユーザーID{user_id:int}), いいね日時{created_at:datetime!}
    -> ユーザー{user}
-- フォロー{follow}: [フォローID{id:int}], (フォロワーID{follower_id:int}), (フォロー先ID{following_id:int}), フォロー日時{created_at:datetime!}
  -> ユーザー{user}

カテゴリ{category}: [カテゴリID{id:int}], カテゴリ名{name:string!}, スラッグ{slug:string@}, 説明{description:string}, 親カテゴリID{parent_id:int}, 表示順{sort_order:int}, 投稿数{post_count:int}
-> 投稿{post}

タグ{tag}: [タグID{id:int}], タグ名{name:string!}, スラッグ{slug:string@}, 説明{description:string}, 使用回数{usage_count:int}
-- 投稿タグ{post_tag}: [投稿タグID{id:int}], (投稿ID{post_id:int}), (タグID{tag_id:int}), 追加日時{created_at:datetime!}
  -> 投稿{post}

メディア{media}: [メディアID{id:int}], (アップロード者ID{uploader_id:int}), ファイル名{filename:string!}, 元ファイル名{original_filename:string!}, ファイルパス{file_path:string!}, ファイルサイズ{file_size:int!}, MIMEタイプ{mime_type:string!}, 幅{width:int}, 高さ{height:int}, 説明{description:string}, アップロード日時{created_at:datetime!}
-> ユーザー{user}
-> 投稿{post}

サイト設定{site_setting}: [設定ID{id:int}], 設定キー{setting_key:string@}, 設定値{setting_value:string}, 設定名{setting_name:string!}, 説明{description:string}, 更新日時{updated_at:datetime!}

お問い合わせ{contact}: [お問い合わせID{id:int}], 名前{name:string!}, メール{email:string!}, 件名{subject:string!}, 内容{message:string!}, ステータス{status:string!}, 送信日時{created_at:datetime!}, 返信日時{replied_at:datetime}, 返信内容{reply_message:string}

メールマガジン{newsletter}: [メールマガジンID{id:int}], タイトル{title:string!}, 内容{content:string!}, 送信予定日時{scheduled_at:datetime}, 送信日時{sent_at:datetime}, 送信数{sent_count:int}, 開封数{open_count:int}, クリック数{click_count:int}, ステータス{status:string!}
-- メールマガジン購読{newsletter_subscription}: [購読ID{id:int}], (メールマガジンID{newsletter_id:int}), メール{email:string!}, 購読日時{subscribed_at:datetime!}, 購読解除日時{unsubscribed_at:datetime}, ステータス{status:string!}

アクセスログ{access_log}: [ログID{id:int}], IPアドレス{ip_address:string!}, ユーザーエージェント{user_agent:string}, リファラー{referer:string}, 訪問URL{url:string!}, (ユーザーID{user_id:int}), 訪問日時{created_at:datetime!}
?? ユーザー{user}

# サンプルデータ
@sample user, 1, "admin", "管理者", "admin@example.com", "password123", "https://example.com/avatar1.jpg", "ブログ管理者です", "https://admin-blog.com", 1640995200, 1641081600, "アクティブ"
@sample user, 2, "writer1", "田中太郎", "tanaka@example.com", "pass456", "https://example.com/avatar2.jpg", "技術ライターです", "https://tanaka-tech.com", 1641000000, 1641082000, "アクティブ"
@sample user, 3, "reader1", "佐藤花子", "sato@example.com", "pass789", null, "読書が好きです", null, 1641005000, 1641083000, "アクティブ"

@sample category, 1, "技術", "tech", "プログラミングや開発に関する記事", null, 1, 5
@sample category, 2, "ライフスタイル", "lifestyle", "日常生活に関する記事", null, 2, 3
@sample category, 3, "フロントエンド", "frontend", "WebフロントエンドA技術", 1, 1, 2

@sample tag, 1, "Flutter", "flutter", "Googleのモバイルアプリ開発フレームワーク", 3
@sample tag, 2, "Dart", "dart", "Dartプログラミング言語", 2
@sample tag, 3, "Web開発", "web-dev", "Web開発全般", 5

@sample post, 1, 1, "FlutterでWebアプリを作ろう", "flutter-web-app", "FlutterでWebアプリを作成する方法を解説します。", "FlutterでWebアプリ開発の基本", "https://example.com/flutter-post.jpg", "公開", 1641000000, 1640995200, 1641000000, 150, 25
@sample post, 2, 2, "Dartの基礎知識", "dart-basics", "Dart言語の基本的な文法について説明します。", "Dartの基本的な使い方", "https://example.com/dart-post.jpg", "公開", 1641010000, 1641005000, 1641010000, 89, 12
@sample post, 3, 1, "効率的なコーディング方法", "efficient-coding", "プロダクティブなコーディングのコツを紹介します。", "コーディング効率化", null, "下書き", null, 1641015000, 1641016000, 0, 0

@sample comment, 1, 1, 3, "とても参考になりました！", "承認", 1641020000, null, null
@sample comment, 2, 1, 2, "詳しい解説ありがとうございます。", "承認", 1641025000, null, null
@sample comment, 3, 2, 3, "Dartは学習しやすい言語ですね。", "承認", 1641030000, null, null

@sample like, 1, 1, 2, 1641022000
@sample like, 2, 1, 3, 1641023000
@sample like, 3, 2, 3, 1641032000

@sample follow, 1, 2, 1, 1641000000
@sample follow, 2, 3, 1, 1641005000
@sample follow, 3, 3, 2, 1641010000

@sample post_tag, 1, 1, 1, 1641000000
@sample post_tag, 2, 1, 3, 1641000000
@sample post_tag, 3, 2, 2, 1641010000

@sample media, 1, 1, "flutter-logo.png", "flutter-logo.png", "/uploads/2024/01/flutter-logo.png", 25600, "image/png", 512, 512, "Flutterのロゴ画像", 1640995200
@sample media, 2, 2, "dart-code.jpg", "sample-code.jpg", "/uploads/2024/01/dart-code.jpg", 156800, "image/jpeg", 1024, 768, "Dartコードのサンプル", 1641005000

@sample site_setting, 1, "site_title", "Tech Blog", "サイトタイトル", "ブログのタイトル設定", 1640995200
@sample site_setting, 2, "site_description", "技術について書くブログです", "サイト説明", "ブログの説明文", 1640995200
@sample site_setting, 3, "posts_per_page", "10", "1ページあたりの投稿数", "一覧ページの表示件数", 1640995200

@sample contact, 1, "山田太郎", "yamada@example.com", "お問い合わせ", "記事について質問があります。", "未対応", 1641040000, null, null
@sample contact, 2, "鈴木花子", "suzuki@example.com", "広告掲載について", "広告掲載の件でご相談があります。", "対応済み", 1641050000, 1641060000, "詳細をメールでお送りいたします。"

@sample newsletter, 1, "週刊Tech News", "今週の技術ニュースをお届けします。", 1641090000, 1641090000, 150, 75, 12, "送信済み"

@sample newsletter_subscription, 1, 1, "newsletter-user1@example.com", 1641000000, null, "購読中"
@sample newsletter_subscription, 2, 1, "newsletter-user2@example.com", 1641010000, null, "購読中"

@sample access_log, 1, "192.168.1.100", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", "https://google.com", "/posts/flutter-web-app", 2, 1641080000
@sample access_log, 2, "192.168.1.101", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", "https://twitter.com", "/posts/dart-basics", null, 1641085000