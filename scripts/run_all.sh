#!/bin/bash
# Run every task through Vibe in an isolated, trusted workdir.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/.local/bin:$PATH"
export VIBE_LOCAL_KEY="${VIBE_LOCAL_KEY:-dummy}"
mkdir -p "$REPO/runs/current"
for t in "$REPO"/tasks/*/; do
  name=$(basename "$t")
  out="$REPO/runs/current/$name"
  rm -rf "$out"; mkdir -p "$out"
  [ -d "$t/seed" ] && cp -a "$t/seed/." "$out/" 2>/dev/null || true
  timeout 900 vibe -p "$(cat "$t/prompt.txt")" \
    --yolo --trust --workdir "$out" --max-turns 25 --output text \
    > "$out/_vibe_stdout.txt" 2>&1
  echo "ran $name (exit $?)"
done
