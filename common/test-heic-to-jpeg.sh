#!/bin/bash
# heic-to-jpeg スクリプトの振る舞いテスト
# 対象スクリプトは $1 で受け取り、DOWNLOADS_DIR / CACHE_DIR 環境変数で動作先を差し替える
set -u
SCRIPT="$1"
PASS=0; FAIL=0
assert() { # assert <説明> <条件式...>
  local desc="$1"; shift
  if "$@"; then PASS=$((PASS+1)); echo "ok: $desc"
  else FAIL=$((FAIL+1)); echo "NG: $desc"; fi
}

WORK="$(mktemp -d)"
export DOWNLOADS_DIR="$WORK/Downloads"
export CACHE_DIR="$WORK/cache"
mkdir -p "$DOWNLOADS_DIR"

SRC_JPG="$(ls /System/Library/Desktop\ Pictures/*.heic 2>/dev/null | head -1)"
if [ -n "$SRC_JPG" ]; then
  cp "$SRC_JPG" "$DOWNLOADS_DIR/photo.heic"
else
  # Desktop Pictures に heic が無い環境向け: 単色画像を生成して heic 化
  /usr/bin/sips -s format heic <(echo) "$DOWNLOADS_DIR/photo.heic" 2>/dev/null
fi
[ -s "$DOWNLOADS_DIR/photo.heic" ] || { echo "テスト用 HEIC を用意できませんでした"; exit 1; }
cp "$DOWNLOADS_DIR/photo.heic" "$DOWNLOADS_DIR/UPPER.HEIC"

# --- 1. 変換: .heic / .HEIC 両方に対し symlink と実体が生成される ---
"$SCRIPT"
assert "photo.jpeg symlink が Downloads に生成される" test -L "$DOWNLOADS_DIR/photo.jpeg"
assert "photo.jpeg の実体が cache に生成される" test -s "$CACHE_DIR/photo.jpeg"
assert "UPPER.jpeg symlink が生成される（大文字拡張子）" test -L "$DOWNLOADS_DIR/UPPER.jpeg"

# --- 2. 冪等性: 再実行しても実体が再生成されない（mtime 不変） ---
before="$(stat -f %m "$CACHE_DIR/photo.jpeg")"
sleep 1
"$SCRIPT"
after="$(stat -f %m "$CACHE_DIR/photo.jpeg")"
assert "再実行しても再変換されない" test "$before" = "$after"

# --- 3. ユーザー自身の同名 jpeg（通常ファイル）は上書きしない ---
echo "user data" > "$DOWNLOADS_DIR/mine.jpeg"
cp "$DOWNLOADS_DIR/photo.heic" "$DOWNLOADS_DIR/mine.heic"
"$SCRIPT"
assert "既存の通常ファイル jpeg は symlink に置換されない" test ! -L "$DOWNLOADS_DIR/mine.jpeg"
assert "既存 jpeg の中身が保持される" grep -q "user data" "$DOWNLOADS_DIR/mine.jpeg"

# --- 4. リンク切れ symlink は再変換で自己修復される ---
rm "$CACHE_DIR/photo.jpeg"
"$SCRIPT"
assert "実体が消えた場合は再変換される" test -s "$CACHE_DIR/photo.jpeg"
assert "修復後も symlink が有効" test -e "$DOWNLOADS_DIR/photo.jpeg"

# --- 5. GC: 元 HEIC が消えたら実体と symlink を掃除する ---
rm "$DOWNLOADS_DIR/photo.heic"
"$SCRIPT"
assert "GC: cache の実体が削除される" test ! -e "$CACHE_DIR/photo.jpeg"
assert "GC: Downloads の symlink が削除される" test ! -L "$DOWNLOADS_DIR/photo.jpeg"
assert "GC: HEIC が残る UPPER.jpeg は消えない" test -L "$DOWNLOADS_DIR/UPPER.jpeg"
assert "GC: ユーザーの通常ファイル jpeg は消えない" test -f "$DOWNLOADS_DIR/mine.jpeg"

echo "---- PASS=$PASS FAIL=$FAIL"
rm -rf "$WORK"
[ "$FAIL" -eq 0 ]
