#!/bin/bash

# デフォルト設定
FORCE_OVERWRITE=false # 強制上書きはデフォルトで無効

# スクリプトの使用方法を表示する関数
usage() {
  echo "使い方: $0 [-f] <シンボリックリンク元のディレクトリ> <シンボリックリンク先のディレクトリ>"
  echo "  -f : 既存のファイルやシンボリックリンクを強制的に上書きします。"
  echo "例: $0 /path/to/source_dir /path/to/destination_dir"
  echo "例 (上書きあり): $0 -f /path/to/source_dir /path/to/destination_dir"
  exit 1
}

# オプションの解析
while getopts "f" opt; do
  case $opt in
    f)
      FORCE_OVERWRITE=true
      ;;
    \?) # 不明なオプション
      usage
      ;;
  esac
done
shift $((OPTIND - 1)) # オプション解析済み引数をシフトして削除

# 残りの引数の数のチェック
if [ "$#" -ne 2 ]; then
  usage
fi

SOURCE_DIR="$1"
DEST_DIR="$2"

# シンボリックリンク元のディレクトリが存在するかチェック
if [ ! -d "$SOURCE_DIR" ]; then
  echo "エラー: シンボリックリンク元のディレクトリ '$SOURCE_DIR' が見つかりません。"
  exit 1
fi

# シンボリックリンク先のディレクトリが存在しない場合、作成するか確認
if [ ! -d "$DEST_DIR" ]; then
  read -p "シンボリックリンク先のディレクトリ '$DEST_DIR' が存在しません。作成しますか？ (y/N): " confirm
  if [[ "$confirm" =~ ^[yY]$ ]]; then
    mkdir -p "$DEST_DIR"
    if [ $? -ne 0 ]; then
      echo "エラー: ディレクトリ '$DEST_DIR' の作成に失敗しました。"
      exit 1
    fi
    echo "ディレクトリ '$DEST_DIR' を作成しました。"
  else
    echo "シンボリックリンク先のディレクトリが作成されなかったため、処理を中断します。"
    exit 1
  fi
fi

echo "--- シンボリックリンクの作成を開始します ---"
echo "元ディレクトリ: $SOURCE_DIR"
echo "先ディレクトリ: $DEST_DIR"

if $FORCE_OVERWRITE; then
  echo "既存のファイルやリンクは上書きされます。(f オプション有効)"
else
  echo "既存のファイルやリンクはスキップされます。(f オプション無効)"
fi
echo "-------------------------------------"

# find と xargs を使ってシンボリックリンクを作成
# ファイル名にスペースや特殊文字が含まれていても安全に処理できます
find "${SOURCE_DIR}" -maxdepth 1 -type f -print0 | while IFS= read -r -d $'\0' file; do
  FILENAME=$(basename "$file")
  DEST_PATH="${DEST_DIR}/${FILENAME}"

  # 既に同名のファイルやシンボリックリンクが存在するかチェック
  if [ -e "$DEST_PATH" ]; then
    if $FORCE_OVERWRITE; then # -f オプションが有効な場合
      if [ -L "$DEST_PATH" ]; then # シンボリックリンクの場合
        echo "上書き中: 既存のシンボリックリンク '$DEST_PATH' を上書きします。"
      elif [ -f "$DEST_PATH" ]; then # 通常ファイルの場合
        echo "上書き中: 既存のファイル '$DEST_PATH' を上書きします。"
      else # その他のタイプの場合 (ディレクトリなど)
        echo "スキップ: '$DEST_PATH' はファイルまたはシンボリックリンクではありません。上書きできません。"
        continue # 次のファイルへ
      fi
      # シンボリックリンクを作成（-f オプションで強制上書き）
      ln -s -f "$file" "$DEST_PATH"
      if [ $? -eq 0 ]; then
        echo "成功: $file -> $DEST_PATH"
      else
        echo "失敗: $file のシンボリックリンク作成に失敗しました。"
      fi
    else # -f オプションが無効な場合（デフォルト）
      echo "スキップ: ${DEST_PATH} が既に存在します。上書きオプション (-f) が指定されていないためスキップします。"
    fi
  else # 存在しない場合は新規作成
    echo "作成中: 新規シンボリックリンク '$DEST_PATH' を作成します。"
    ln -s "$file" "$DEST_PATH"
    if [ $? -eq 0 ]; then
      echo "成功: $file -> $DEST_PATH"
    else
      echo "失敗: $file のシンボリックリンク作成に失敗しました。"
    fi
  fi
done

echo "--- シンボリックリンクの作成が完了しました ---"