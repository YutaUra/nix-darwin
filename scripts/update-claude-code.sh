#!/usr/bin/env bash
# Claude Code の Nix オーバーレイを最新バージョンに更新する
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NIX_FILE="$ROOT_DIR/overlays/claude-code.nix"
LOCK_FILE="$ROOT_DIR/overlays/claude-code-package-lock.json"

# 現在のバージョンを取得
CURRENT=$(grep 'version = ' "$NIX_FILE" | head -1 | sed 's/.*"\(.*\)".*/\1/')
echo "現在: $CURRENT"

# 最新バージョンを取得
LATEST=$(curl -sS https://registry.npmjs.org/@anthropic-ai/claude-code/latest | jq -r .version)
echo "最新: $LATEST"

if [ "$CURRENT" = "$LATEST" ]; then
  echo "すでに最新です"
  exit 0
fi

echo "$CURRENT → $LATEST に更新します..."

URL="https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${LATEST}.tgz"

# 1. ソースハッシュを計算（fetchzip と同じ方式）
echo "ソースハッシュを計算中..."
BASE32=$(nix-prefetch-url --unpack "$URL" 2>/dev/null)
SRC_HASH=$(nix hash convert --to sri "sha256:$BASE32")
echo "  hash = $SRC_HASH"

# 2. package-lock.json を生成
echo "package-lock.json を生成中..."
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
curl -sL "$URL" | tar xz -C "$WORK" --strip-components=1
(cd "$WORK" && npm install --package-lock-only --ignore-scripts 2>/dev/null)
cp "$WORK/package-lock.json" "$LOCK_FILE"

# 3. npmDepsHash を計算
echo "npmDepsHash を計算中..."
if command -v prefetch-npm-deps &>/dev/null; then
  NPM_DEPS_HASH=$(prefetch-npm-deps "$LOCK_FILE" 2>/dev/null)
else
  NPM_DEPS_HASH=$(nix shell nixpkgs#prefetch-npm-deps -c prefetch-npm-deps "$LOCK_FILE" 2>/dev/null)
fi
echo "  npmDepsHash = $NPM_DEPS_HASH"

# 4. Nix ファイルを更新
perl -pi -e "s|version = \"\Q$CURRENT\E\"|version = \"$LATEST\"|" "$NIX_FILE"
perl -pi -e 's|hash = "sha256-[^"]*"|hash = "'"$SRC_HASH"'"|' "$NIX_FILE"
perl -pi -e 's|npmDepsHash = "sha256-[^"]*"|npmDepsHash = "'"$NPM_DEPS_HASH"'"|' "$NIX_FILE"

echo "更新完了: claude-code $CURRENT → $LATEST"
