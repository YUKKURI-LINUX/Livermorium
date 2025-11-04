English ver: [README.md](./README.md)

# Livermorium

Livermorium はカスタムされたLinuxディストリビューションを作成するツールです。様々なディストリビューションのサポートを目指していますが、現在は**Ubuntu ベースのシステムのみに対応**しています。

## 実行方法

### 1. インストール

```bash
./install.py
```

実行後、アプリケーションメニューにエントリが追加されます。

CLI版については、後述の「利用例」セクションを参照してください。

## 仕様

本システムは、様々なLinuxディストリビューションをベースとしたカスタム ISO を生成するためのビルドツールです。

スクリプトは以下の順に、通し番号の若いものから実行されます。:
`prelude` (常に最初に実行)→ メインコンテンツ → `finalizers` (常に最後に実行)

GUI版の実行順は以下のファイルにより定義されます。

  * `profiles/<profile>/categories.json`
      * `nodes` (カテゴリ/グループ)、`prelude`、`finalizers` を定義します。
  * `profiles/<profile>/execution.json`
      * 現状、chrootで実行されるスクリプトの範囲 (`min`/`max`)のみを定義します (デフォルトは 50〜79)。

-----

## ディレクトリ構造

```
Livermorium/
├─ cl_main.py                # CLI版 (実行可能)
├─ builder/
│  ├─ executor.py            # スクリプト実行処理の定義
│  ├─ categories.py          # categories.jsonのロード処理の定義
│  ├─ logger.py              # ロガー定義
│  ├─ config_loader.py       # 設定、パッケージ/Flatpak リストの読み込みの定義
│  └─ … (etc.)
├─ profiles/
│  └─ ubuntu/
│     ├─ scripts/            # スクリプトの実体 (00〜99)
│     │  ├─ (executorにより実行されるスクリプトは、すべて名前の先頭に連番が振られている必要があります。)
│     ├─ categories.json     # カテゴリ定義ファイル (prelude/finalizers を含む)
│     └─ execution.json      # 実行設定定義ファイル (min/max のみ)
└─ work_build/               # 作業ディレクトリ (ログ、スクリプト、<basename>/tmp など) (実行時に生成)
```

-----

## `categories.json` (定義例)

```json
{
  "nodes": {
    "base": {
      "desc": "初期準備",
      "patterns": ["05-*.sh", "10-*.sh", "30-*.sh", "40-*.sh"]
    },
    "locale": {
      "desc": "ロケール / キーボード設定",
      "deps": ["base"],
      "patterns": ["50-locale.sh", "52-keyboard.sh"]
    },
    "user": {
      "desc": "ユーザーとグループのセットアップ",
      "deps": ["locale"],
      "patterns": ["60-user.sh"]
    },
    "packages": {
      "desc": "APT/Flatpak のインストール",
      "deps": ["user"],
      "patterns": ["65-packages.sh"]
    },
    "desktop": {
      "desc": "デスクトップ設定 / Calamares / サービス",
      "deps": ["packages"],
      "patterns": ["70-dconf-settings.sh", "71-calamares-install.sh", "75-enable-services.sh", "76-systemd-initramfs.sh"]
    },
    "finalize": {
      "desc": "ルートファイルシステムコピー後 / クリーンアップ",
      "deps": ["desktop"],
      "patterns": ["80-copy-rootfs-after.sh", "81-chown-home.sh", "82-purge-hostside.sh"]
    },
    "boot": {
      "desc": "GRUB および EFI/El Torito の生成",
      "deps": ["finalize"],
      "patterns": ["84-create-grubcfg.sh", "85-generate-eltorito.sh", "86-generate-efi.sh"]
    },
    "iso": {
      "desc": "最終 ISO の生成",
      "deps": ["boot"],
      "patterns": ["90-build-iso.sh"]
    },

    "minimal": {
      "desc": "最小限のセットアップ (base + locale)",
      "includes": ["base", "locale"]
    },
    "with-packages": {
      "desc": "パッケージインストールまで",
      "includes": ["minimal", "user", "packages"]
    },
    "full-desktop": {
      "desc": "完全な構成 (ISO まで)",
      "includes": ["with-packages", "desktop", "finalize", "boot", "iso"]
    }
  },

  "prelude": {
    "always_first": ["00-*.sh", "00-*.py"]
  },

  "finalizers": {
    "always": ["99-*.sh"],
    "on_failure": [],
    "on_success": []
  }
}
```

-----

## 3. `execution.json` (定義例)

```json
{
  "chroot": {
    "min": 50,
    "max": 79
  }
}
```

-----

## 4. 利用例 (CLI版)

### 4.1 プランの確認

```bash
sudo ./cl_main.py ubuntu --print-plan --dry-run
```

### 4.2 実行 (フル)

```bash
sudo ./cl_main.py ubuntu -r full-desktop
```

### 4.3 実行 (パッケージインストール)

```bash
sudo ./cl_main.py ubuntu -r with-packages
```

### 4.4 パターン実行 (ブートローダー関連)

```bash
sudo ./cl_main.py ubuntu -r "85-*.sh"
```

-----

## 5. コマンドラインオプション

| オプション | 意味 | 例 |
|---|---|---|
| `profile` | プロファイル名 (必須) | `ubuntu` |
| `-r, --run` | ノード名/パターン (カンマ区切り) | `full-desktop,85-*.sh` |
| `--allow-deprecated` | 非推奨ノードからの依存関係を許可 (グローバル) | `(no additional options)` |
| `--allow-deprecated-nodes` | 特定のノードのみを許可 (カンマ区切り) | `old-desktop,legacy` |
| `--chroot-min` | chroot 内の最小スクリプト番号 | `60` |
| `--chroot-max` | chroot 内の最大スクリプト番号 | `89` |
| `--print-plan` | プランを表示 |　`(no additional options)` |
| `--validate` | プランの検証のみを行い終了 | `(no additional options)` |
| `--list-only` | ターゲットリストの表示 | `(no additional options)` |
| `--dry-run` | 一切の変更を加えず実行 | `(no additional options)` |
| `--continue-on-error`| エラーが発生しても実行を続行する | `(no additional options)` |
| `--package-list` | 追加の APT パッケージ (カンマ区切り) | `vim,htop` |
| `--flatpak-list` | 追加の Flatpak アプリケーション (カンマ区切り) | `org.mozilla.firefox,org.gimp.GIMP` |

-----

## 6. 実行ルールについて

  * **昇順の数値順** (00, 01, 02, ...)に実行されます。
  * `prelude` は常に処理開始時、`finalizers` は常に処理終了時に実行されます。
  * `finalizers.on_failure` は失敗時のみ、`finalizers.on_success` は成功時のみ実行されます。
  * 複数パターンの指定はすべて**カンマ区切り**で行う必要があります。