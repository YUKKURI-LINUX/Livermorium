# Livermorium
## 下記を目指して実装中


Linuxディストリビューション ビルドツール
1. 🔧 GUIインターフェース（PyGObject + GTK4）
メイン構成（タブ形式）
タブ名	機能概要
Config	Basename、ロケール、キーボード、タイムゾーン、使用するプロファイルを設定
User	ユーザー名・パスワード・自動ログイン・root無効化・所属グループを設定
Packages	パッケージ一覧をチェックボックスで表示（説明付き）＋全選択/解除ボタン付き
Flatpak	Flatpakアプリ一覧（説明付き）＋全選択/解除ボタン
Logs	実行ログのリアルタイム表示（自動スクロール）、ビルド状況を出力
その他GUI仕様

    .json ファイルによる設定読込
   　
    ユーザーは設定の編集可（保存不要：一時的）

    タブの切替、ログ自動スクロール対応

    実行順タブにはスクリプトの順序一覧を表示（番号順）

    パッケージリスト、flatpakのアプリは表計算ソフトでリストを管理
   　CSVをjsonへ変換するツールを作成する

3. 🗂 プロファイル構造
```
project-root/
├── gui/
├── profiles/
│   ├── hogehoge/
│   │   ├── config.json
│   │   ├── packages.json
│   │   ├── flatpak.json
│   │   ├── scripts/
│   │   │   ├── 10-prepare.sh
│   │   │   ├── 20-copy-config.sh
│   │   │   ├── 50-locale.sh        ← chroot内
│   │   │   ├── 60-user.sh          ← chroot内
│   │   │   ├── 70-dconf.sh         ← chroot内（GNOME設定）
│   │   │   ├── 80-after-rootfs.sh
│   │   │   └── 90-build-iso.sh
├── common/
│   ├── scripts/ （→ 各プロファイルへシンボリックリンク）
├── builder/
│   └── executor.py
└── logs/
```

4. 🧰 設定ファイル仕様（JSON）
config.json サンプル
```
{
  "basename": "hogehoge",
  "locale": "ja_JP.UTF-8",
  "keyboard": "jp",
  "timezone": "Asia/Tokyo",
  "user": {
    "name": "hogehoge",
    "password": "hogehoge",
    "autologin": true,
    "disable_root": true,
    "groups": ["wheel", "network", "video"]
  }
}
```
packages.json / flatpak.json
```
[
  { "name": "sudo", "description": "特権コマンド用", "default": true },
  { "name": "git", "description": "Gitツール", "default": true },
  ...
]
```
```
[
  [
  {
    "name": "org.mozilla.firefox",
    "description": "ウェブブラウザ Firefox",
    "default": true
  },
  {
    "name": "com.discordapp.Discord",
    "description": "ボイス＆チャット Discord",
    "default": true
  },
  {
    "name": "org.gimp.GIMP",
    "description": "画像編集ソフト GIMP",
    "default": true
  },
  {
    "name": "org.libreoffice.LibreOffice",
    "description": "オフィススイート LibreOffice",
    "default": true
  }
]

  ...
]
```

4. 🖥 ビルド処理フロー

    ベース構築

        pacstrap（Arch）

        debootstrap（Debian/Ubuntu）

        dnf --installroot（Fedora）

        zypper --root（openSUSE）

    設定ファイルコピー（10〜20番台）

    chroot環境内処理（50〜70番台）

        ロケール生成・タイムゾーン設定

        ユーザー作成・グループ追加・root無効化

        GNOME用の dconf 設定 + dconf update

        パッケージ・flatpakインストール（パーサ付き）

    rootfs追加（80番台）

        rootfs_after/ の中身を chroot環境へコピー

    ISO作成（90番台）

        grub-mkrescue, xorriso 等でISO化

5. 📜 スクリプト管理（executor.py）

    profiles/<name>/scripts/*.sh/.py を番号順で自動実行

    chroot処理中のスクリプト（50〜70）を chroot 内で実行
   （実行順が変わらないように、共通スクリプトはシンボリックリンクの名称と同じにする）

    rootfs_before/, rootfs_after/ のコピー処理あり

7. 📦 対応ディストリビューション
ディストリ	ベース	初期化方法
- Arch Linux	pacstrap	

- Debian	debootstrap	

- Ubuntu	debootstrap	

- openSUSE Tumbleweed	zypper	

- Fedora	dnf

9. 🧠 GNOMEカスタム設定対応

    /etc/dconf/profile/user 自動作成

    dconf db 用カスタムデフォルトを json/gvariant 形式で事前に定義

    dconf update をchroot内スクリプトで呼び出し（70-dconf.sh）
