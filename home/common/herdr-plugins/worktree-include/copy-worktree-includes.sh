#!/usr/bin/env bash
#
# herdr の worktree.created イベントで起動し、元リポジトリ直下の
# `.worktreeinclude` に列挙された「git-ignore 済みファイル」を新しい worktree に
# コピーする（流儀A: リポジトリローカル宣言方式）。
#
# 対象ファイルは各リポジトリの `.worktreeinclude` が決めるため、この plugin 自体は
# リポジトリ非依存の汎用ロジックとして書く。
#
# payload のキーは herdr 0.7.1 の HERDR_PLUGIN_EVENT_JSON を実測して確定した:
#   新 worktree パス   … .data.worktree.path
#   元リポジトリパス   … .data.workspace.worktree.repo_root
# （data.workspace.worktree は「元リポジトリ側」、data.worktree は「新規 worktree 側」。
#   同名 worktree キーが 2 箇所にあるので取り違えないこと。）

set -uo pipefail

log() { echo "worktree-include: $*" >&2; }

# HERDR_PLUGIN_EVENT_JSON から新 worktree パスと元リポジトリパスを取り出す。
# jq を第一候補にしつつ、jq 非搭載環境(コンテナ等)向けに python3 をフォールバックにする。
# 両方無い場合はイベントフックなので worktree 作成自体は妨げず、警告だけ残して終了する。
read_paths() {
  local json="${HERDR_PLUGIN_EVENT_JSON:-}"
  if [ -z "$json" ]; then
    log "HERDR_PLUGIN_EVENT_JSON が空のため何もしない"
    exit 0
  fi

  if command -v jq >/dev/null 2>&1; then
    new_worktree=$(printf '%s' "$json" | jq -r '.data.worktree.path // empty')
    source_repo=$(printf '%s' "$json" | jq -r '.data.workspace.worktree.repo_root // empty')
  elif command -v python3 >/dev/null 2>&1; then
    new_worktree=$(printf '%s' "$json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("data",{}).get("worktree",{}).get("path",""))')
    source_repo=$(printf '%s' "$json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("data",{}).get("workspace",{}).get("worktree",{}).get("repo_root",""))')
  else
    log "jq も python3 も見つからないため payload を解析できない。skip"
    exit 0
  fi
}

new_worktree=""
source_repo=""
read_paths

if [ -z "$new_worktree" ] || [ -z "$source_repo" ]; then
  log "worktree パス or 元リポジトリパスを取得できなかった (new='$new_worktree' src='$source_repo')。skip"
  exit 0
fi

include_file="$source_repo/.worktreeinclude"
if [ ! -f "$include_file" ]; then
  # .worktreeinclude が無いリポジトリでは何もしない（正常系）
  exit 0
fi

log "元リポジトリ $source_repo → worktree $new_worktree へ .worktreeinclude を反映"

# 各行 = コピー対象の相対パス。空行(空白のみ含む)は無視する。
# 最終行に改行が無くても読めるよう `|| [ -n "$line" ]` を付ける。
while IFS= read -r line || [ -n "$line" ]; do
  # 前後の空白を除去してから空行判定する
  trimmed="${line#"${line%%[![:space:]]*}"}"
  trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
  [ -z "$trimmed" ] && continue

  src="$source_repo/$trimmed"
  dst="$new_worktree/$trimmed"

  if [ ! -e "$src" ]; then
    log "元リポジトリに存在しないため skip: $trimmed"
    continue
  fi

  # ネストしたパス(例 config/master.key)に備えて配置先の親ディレクトリを作る。
  # cp -a で属性を保ったままコピーする。1 件失敗しても残りは続行する。
  if ! mkdir -p "$(dirname "$dst")" || ! cp -a "$src" "$dst"; then
    log "コピー失敗: $trimmed"
    continue
  fi
  log "コピー: $trimmed"
done < "$include_file"
