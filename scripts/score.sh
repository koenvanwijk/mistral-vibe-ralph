#!/bin/bash
# Score all tasks: run each verify.sh against its workdir. Pass/total.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; total=0; detail=""
for t in "$REPO"/tasks/*/; do
  name=$(basename "$t"); total=$((total+1))
  out="$REPO/runs/current/$name"
  if bash "$t/verify.sh" "$out" >/dev/null 2>&1; then
    detail="${detail}PASS ${name}\n"; pass=$((pass+1))
  else
    detail="${detail}FAIL ${name}\n"
  fi
done
{ printf "SCORE: %d/%d\n" "$pass" "$total"; printf "%b" "$detail"; } | tee "$REPO/runs/current/SCORE.txt"
echo "$pass" > "$REPO/runs/current/SCORE_NUM.txt"
