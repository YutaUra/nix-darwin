#!/usr/bin/env bash
# Claude Code の Nix オーバーレイを最新バージョンに更新する
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST_FILE="$ROOT_DIR/overlays/claude-code-manifest.json"
BASE_URL="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

# 現在のバージョンを取得
CURRENT=$(jq -r .version "$MANIFEST_FILE")
echo "現在: $CURRENT"

# 最新バージョンを取得
LATEST=$(curl -fsSL "$BASE_URL/latest")
echo "最新: $LATEST"

if [ "$CURRENT" = "$LATEST" ]; then
  echo "すでに最新です"
  exit 0
fi

echo "$CURRENT → $LATEST に更新します..."

curl -fsSL "$BASE_URL/$LATEST/manifest.json" --output "$MANIFEST_FILE"

echo "更新完了: claude-code $CURRENT → $LATEST"
