"""RunCat Neo 向け Claude Code statusLine スクリプト。

stdin で受け取った statusLine payload から モデル名 / コンテキスト使用率 /
レートリミット使用率を抜き出し、~/.claude/runcat-usage.json へ書き出す。
標準出力にはモデル名を出すので、そのまま Claude Code のステータス行になる。

出力形式は RunCat Neo の Custom Metrics が読む JSON スキーマに準拠する。
"""

import json
import os
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

OUT = Path(
    os.environ.get(
        "RUNCAT_OUT_FILE", str(Path.home() / ".claude" / "runcat-usage.json")
    )
)


def pct(title, value):
    if value is None:
        return None
    return {
        "title": title,
        "formattedValue": f"{value:g}%",
        "normalizedValue": round(value / 100, 4),
    }


# json.load の失敗を握りつぶす理由:
# statusLine は毎ターン呼ばれるため、payload が想定外でも例外で落とすと
# ステータス行が壊れる。空 dict にフォールバックしてモデル名だけ出す。
try:
    payload = json.load(sys.stdin)
    if not isinstance(payload, dict):
        payload = {}
except Exception:
    payload = {}

model = (payload.get("model") or {}).get("display_name") or "Claude Code"
ctx = (payload.get("context_window") or {}).get("used_percentage")
rate_limits = payload.get("rate_limits") or {}
five = (rate_limits.get("five_hour") or {}).get("used_percentage")
seven = (rate_limits.get("seven_day") or {}).get("used_percentage")

snapshot = {
    "title": "Claude Code",
    "symbol": "staroflife",
    "metrics": [
        m
        for m in [
            {"title": "Model", "formattedValue": model},
            pct("Context", ctx),
            pct("5h", five),
            pct("7d", seven),
        ]
        if m is not None
    ],
    "lastUpdatedDate": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
if ctx is not None:
    snapshot["metricsBarValue"] = f"{ctx:g}%"

# 直接書かずに tempfile + os.replace する理由:
# RunCat Neo が読み込む最中に書き込むと壊れた JSON を読まれる可能性がある。
# 同一ディレクトリ内の rename は atomic なので中途半端な状態が見えない。
OUT.parent.mkdir(parents=True, exist_ok=True)
fd, tmp = tempfile.mkstemp(prefix=".runcat-", dir=str(OUT.parent))
with os.fdopen(fd, "w", encoding="utf-8") as f:
    json.dump(snapshot, f, ensure_ascii=False)
os.replace(tmp, OUT)

print(model)
