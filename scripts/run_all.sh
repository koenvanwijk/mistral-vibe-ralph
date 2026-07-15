#!/bin/bash
# Run every task through Vibe TRIALS times (default 3) in isolated trusted workdirs.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/.local/bin:$PATH"
export VIBE_LOCAL_KEY="${VIBE_LOCAL_KEY:-dummy}"
TRIALS="${TRIALS:-3}"
for t in "$REPO"/tasks/*/; do
  name=$(basename "$t")
  for k in $(seq 1 "$TRIALS"); do
    out="$REPO/runs/current/$name/trial$k"
    rm -rf "$out"; mkdir -p "$out"
    [ -d "$t/seed" ] && cp -a "$t/seed/." "$out/" 2>/dev/null || true
    timeout 900 vibe -p "$(cat "$t/prompt.txt")" \
      --yolo --trust --workdir "$out" --max-turns 25 --output text \
      > "$out/_vibe_stdout.txt" 2>&1
  done
  echo "ran $name x$TRIALS"
done
