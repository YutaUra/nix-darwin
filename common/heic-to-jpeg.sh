#!/bin/bash
# nix モジュールに埋め込む本体ロジック（テスト用にディレクトリを環境変数で差し替え可能）
DOWNLOADS_DIR="${DOWNLOADS_DIR:-$HOME/Downloads}"
CACHE_DIR="${CACHE_DIR:-$HOME/.cache/heic-to-jpeg}"

mkdir -p "$CACHE_DIR"
shopt -s nullglob

# 変換: 対応する jpeg が無い（またはリンク切れの）HEIC のみ処理する冪等走査
for f in "$DOWNLOADS_DIR"/*.heic "$DOWNLOADS_DIR"/*.HEIC; do
  base="$(basename "${f%.*}")"
  real="$CACHE_DIR/$base.jpeg"
  link="$DOWNLOADS_DIR/$base.jpeg"

  # ユーザー自身の通常ファイル jpeg が既にある場合は触らない
  if [ -e "$link" ] && [ ! -L "$link" ]; then continue; fi
  # 有効な symlink が既にあれば変換済み（WatchPaths 再発火によるループ防止）
  if [ -L "$link" ] && [ -e "$link" ]; then continue; fi

  /usr/bin/sips -s format jpeg "$f" --out "$real" > /dev/null && ln -sf "$real" "$link"
done

# GC: 元 HEIC が消えた実体 jpeg と、cache を指す symlink を掃除する
for real in "$CACHE_DIR"/*.jpeg; do
  base="$(basename "${real%.jpeg}")"
  if [ ! -e "$DOWNLOADS_DIR/$base.heic" ] && [ ! -e "$DOWNLOADS_DIR/$base.HEIC" ]; then
    link="$DOWNLOADS_DIR/$base.jpeg"
    # 誤削除防止のため、symlink がこの cache 実体を指す場合のみ消す
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$real" ]; then
      rm -f "$link"
    fi
    rm -f "$real"
  fi
done
