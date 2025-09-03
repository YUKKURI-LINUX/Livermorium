# Livermorium
CLIでの実行を優先して作成しました。
Ubuntuベースのみの対応です。
GUIは追々作成します。
# 実行方法
## 1.環境構築
```
tool/ubuntu-setup.sh
```
## 2.実行
下で記載の使い方を参照して下さい。

## !実行時注意事項!
ペッケージのインストール時に
gdmかLightDMのどちらをデフォルトにするか聞いてきます。
2　を入力して先に進んで下さい。
（LightDMを指示）



# 実装できている仕様

各ディストリベースのカスタムISOを生成するビルド環境です。  
実行順序は **番号ルール（00〜99）昇順**、`prelude`（先頭必須）→ **本編** → `finalizers`（終了必須）で構成します。  
GUI からの呼び出しも想定し、**カテゴリ/グループ定義**と**実行制御**を分離しています。

- 実行計画（論理）: `profiles/<profile>/categories.json`
  - `nodes`（カテゴリ/グループ）、`prelude`、`finalizers` を定義
- 実行方式（物理）: `profiles/<profile>/execution.json`
  - chroot 実行帯 `min`/`max` のみを定義（既定 50..79）


## 1. 主要ディレクトリ

```
Livermorium/
├─ cl_main.py                # 実行オーケストレーション入口
├─ builder/
│  ├─ executor.py            # prelude→本編→finalizers を番号昇順で実行（chroot帯考慮）
│  ├─ categories.py          # categories.json の読み込み/正規化/ノード解決
│  ├─ logger.py              # 逐次ログ書き出し
│  ├─ config_loader.py       # config, package/flatpak list ロード
│  └─ …（既存）
├─ profiles/
│  └─ ubuntu/
│     ├─ scripts/            # 実スクリプト（00〜99）
│     │  ├─ 実行スクリプトを番号を付与して準備しておく
│     ├─ categories.json     # 実行論理（prelude/finalizers含む）
│     └─ execution.json      # chroot 実行帯（min/max のみ）
└─ work_build/               # 実行時に生成（logs, scripts, <basename>/tmp 等）
```

---

## 2. categories.json（定義例）

```json
{
  "nodes": {
    "base": {
      "desc": "初期準備",
      "patterns": ["05-*.sh", "10-*.sh", "30-*.sh", "40-*.sh"]
    },
    "locale": {
      "desc": "ロケール/キーボード",
      "deps": ["base"],
      "patterns": ["50-locale.sh", "52-keyboard.sh"]
    },
    "user": {
      "desc": "ユーザー・グループ",
      "deps": ["locale"],
      "patterns": ["60-user.sh"]
    },
    "packages": {
      "desc": "APT/Flatpak 導入",
      "deps": ["user"],
      "patterns": ["65-packages.sh"]
    },
    "desktop": {
      "desc": "デスクトップ設定/Calamares/サービス",
      "deps": ["packages"],
      "patterns": ["70-dconf-settings.sh", "71-calamares-install.sh", "75-enable-services.sh", "76-systemd-initramfs.sh"]
    },
    "finalize": {
      "desc": "rootfs コピー後/整備",
      "deps": ["desktop"],
      "patterns": ["80-copy-rootfs-after.sh", "81-chown-home.sh", "82-purge-hostside.sh"]
    },
    "boot": {
      "desc": "GRUB と EFI/El Torito",
      "deps": ["finalize"],
      "patterns": ["84-create-grubcfg.sh", "85-generate-eltorito.sh", "86-generate-efi.sh"]
    },
    "iso": {
      "desc": "ISO 最終生成",
      "deps": ["boot"],
      "patterns": ["90-build-iso.sh"]
    },

    "minimal": {
      "desc": "最小構成（基本 + ロケール）",
      "includes": ["base", "locale"]
    },
    "with-packages": {
      "desc": "パッケージ導入まで",
      "includes": ["minimal", "user", "packages"]
    },
    "full-desktop": {
      "desc": "フル構成（ISOまで）",
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

---

## 3. execution.json（定義例）

```json
{
  "chroot": {
    "min": 50,
    "max": 79
  }
}
```

---

## 4. 使い方

### 4.1 計画確認
```bash
sudo ./cl_main.py ubuntu --print-plan --dry-run
```

### 4.2 フル構成
```bash
sudo ./cl_main.py ubuntu -r full-desktop
```

### 4.3 パッケージ導入まで
```bash
sudo ./cl_main.py ubuntu -r with-packages
```

### 4.4 ブート処理だけ（パターン指定）
```bash
sudo ./cl_main.py ubuntu -r "85-*.sh"
```

---

## 5. コマンドラインオプション一覧

| オプション | 意味 | 例 |
|---|---|---|
| `profile` | プロファイル名（必須） | `ubuntu` |
| `-r, --run` | ノード名/パターン（カンマ区切り） | `full-desktop,85-*.sh` |
| `--allow-deprecated` | deprecated ノードを依存から許可（全体） |  |
| `--allow-deprecated-nodes` | 特定ノードだけ許可（CSV） | `old-desktop,legacy` |
| `--chroot-min` | chroot 最小番号 | `60` |
| `--chroot-max` | chroot 最大番号 | `89` |
| `--print-plan` | 実行計画を表示 |  |
| `--validate` | 計画検証のみで終了 |  |
| `--list-only` | 実行対象一覧のみで終了 |  |
| `--dry-run` | 実行せずコマンドのみログ出力 |  |
| `--continue-on-error` | エラーでも続行 |  |
| `--package-list` | 追加APTパッケージ（CSV） | `vim,htop` |
| `--flatpak-list` | 追加Flatpak（CSV） | `org.mozilla.firefox,org.gimp.GIMP` |

---

## 6. 実行ルール

- 番号昇順が絶対ルール
- prelude は常に先頭、finalizers は常に最後
- finalizers.on_failure は失敗時のみ、on_success は成功時のみ
- すべての複数指定はカンマ区切り統一

---

