# Livermorium システム概要（日本語訳）

## Livermorium（リバーモリウム）

Livermorium は、**GUI および CLI の両方から実行可能なカスタムディストリビューション作成システム**です。様々なディストリビューションベースのサポートを目指していますが、**現在のところは Ubuntu ベースのシステムのみに対応**しています。

## 実行方法

### 1\. 環境セットアップ

```bash
./install.py
```

### 2\. GUI 実行

アプリケーションは、環境に **アイコンが追加されているため**、直接起動できます。

### 3\. CLI 実行

コマンドラインでの使用法については、後述の「利用例」セクションを参照してください。

## 実装仕様

本システムは、様々なディストリビューションベースの**カスタム ISO を生成するためのビルド環境**です。

実行順序は、`prelude`（常に最初に実行）→ **メインコンテンツ** → `finalizers`（常に最後に実行）という\*\*昇順の数値ルール（00〜99）\*\*に厳密に従います。

GUI 実行をサポートするため、実行計画を**カテゴリ/グループ定義**と**実行制御**に分けています。

  * **実行計画（論理）**：`profiles/<profile>/categories.json`
      * `nodes`（カテゴリ/グループ）、`prelude`、`finalizers` を定義します。
  * **実行方法（物理）**：`profiles/<profile>/execution.json`
      * chroot 実行範囲（`min`/`max`）のみを定義します（デフォルトは 50〜79）。

-----

## 1\. 主要ディレクトリ

```
Livermorium/
├─ cl_main.py                # コマンドラインによるオーケストレーションのエントリーポイント
├─ builder/
│  ├─ executor.py            # prelude→メイン→finalizers を数値順に実行（chroot 範囲を考慮）
│  ├─ categories.py          # categories.json の読み込み/正規化/ノード解決
│  ├─ logger.py              # シーケンシャルなログ書き込み
│  ├─ config_loader.py       # 設定、パッケージ/Flatpak リストの読み込み
│  └─ …（既存ファイル）
├─ profiles/
│  └─ ubuntu/
│     ├─ scripts/            # 実際のスクリプト群（00〜99）
│     │  ├─ 実行するスクリプトは数値プレフィックスを付けて準備する必要があります
│     ├─ categories.json     # 実行ロジック（prelude/finalizers を含む）
│     └─ execution.json      # chroot 実行範囲（min/max のみ）
└─ work_build/               # 実行中に生成される作業ディレクトリ（ログ、スクリプト、<basename>/tmp など）
```

-----

## 2\. `categories.json`（定義例）

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
      "desc": "最小限のセットアップ（base + locale）",
      "includes": ["base", "locale"]
    },
    "with-packages": {
      "desc": "パッケージインストールまで",
      "includes": ["minimal", "user", "packages"]
    },
    "full-desktop": {
      "desc": "完全な構成（ISO まで）",
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

## 3\. `execution.json`（定義例）

```json
{
  "chroot": {
    "min": 50,
    "max": 79
  }
}
```

-----

## 4\. 利用例

### 4.1 計画の確認

```bash
sudo ./cl_main.py ubuntu --print-plan --dry-run
```

### 4.2 完全な構成の実行

```bash
sudo ./cl_main.py ubuntu -r full-desktop
```

### 4.3 パッケージインストールまでの実行

```bash
sudo ./cl_main.py ubuntu -r with-packages
```

### 4.4 ブート処理のみの実行（パターン指定）

```bash
sudo ./cl_main.py ubuntu -r "85-*.sh"
```

-----

## 5\. コマンドラインオプション一覧

| オプション | 意味 | 例 |
|---|---|---|
| `profile` | プロファイル名（必須） | `ubuntu` |
| `-r, --run` | ノード名/パターン（カンマ区切り） | `full-desktop,85-*.sh` |
| `--allow-deprecated` | 非推奨ノードからの依存関係を許可（グローバル） | |
| `--allow-deprecated-nodes` | 特定のノードのみを許可（カンマ区切り） | `old-desktop,legacy` |
| `--chroot-min` | chroot 内の最小スクリプト番号 | `60` |
| `--chroot-max` | chroot 内の最大スクリプト番号 | `89` |
| `--print-plan` | 実行計画を表示 | |
| `--validate` | 計画の検証のみを行い終了 | |
| `--list-only` | 実行対象をリスト表示して終了 | |
| `--dry-run` | コマンドをログに記録するだけで実行しない | |
| `--continue-on-error`| エラーが発生しても実行を続行する | |
| `--package-list` | 追加の APT パッケージ（カンマ区切り） | `vim,htop` |
| `--flatpak-list` | 追加の Flatpak アプリケーション（カンマ区切り） | `org.mozilla.firefox,org.gimp.GIMP` |

-----

## 6\. 実行ルール

  * **昇順の数値順**が絶対的なルールです。
  * `prelude` は常に開始時、`finalizers` は常に終了時に実行されます。
  * `finalizers.on_failure` は失敗時のみ、`finalizers.on_success` は成功時のみ実行されます。
  * 複数の指定はすべて**カンマ区切り**で行う必要があります。