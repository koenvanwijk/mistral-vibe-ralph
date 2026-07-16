#!/bin/bash
# Auto-escalator: when the harness saturates, generate ONE new harder task via
# headless Claude, then VALIDATE it (reference solution passes verify; seed-only
# fails verify) before keeping it. Discards invalid tasks. Requires Claude.
REPO="$(cd "$(dirname "$0")/.." && pwd)"; cd "$REPO"
export PATH="$HOME/.local/bin:$PATH"
MAXTASKS="${MAXTASKS:-40}"
log(){ echo "[$(date -Is)] [gen] $*" | tee -a "$REPO/ralph.log"; }

n=$(ls -d tasks/*/ 2>/dev/null | wc -l)
[ "$n" -ge "$MAXTASKS" ] && { log "task cap $MAXTASKS reached — no escalation"; exit 1; }
timeout 60 claude -p "reply with exactly OK" --dangerously-skip-permissions 2>/dev/null | grep -q OK \
  || { log "Claude unavailable — skip escalation this round"; exit 1; }

for attempt in 1 2 3; do
  before=$(ls -d tasks/*/ 2>/dev/null | sort)
  timeout 900 claude -p "$(cat proposer/GEN_TASK.md)" \
    --dangerously-skip-permissions --add-dir "$REPO" > runs/gen_last.log 2>&1
  newp=$(grep -m1 '^NEWTASK:' runs/gen_last.log | sed 's/^NEWTASK:[[:space:]]*//; s:/*$::')
  [ -z "$newp" ] && newp=$(comm -13 <(echo "$before") <(ls -d tasks/*/ 2>/dev/null | sort) | head -1 | sed 's:/*$::')
  [ -z "$newp" ] || [ ! -d "$newp" ] && { log "attempt $attempt: no task dir produced"; continue; }
  if [ ! -f "$newp/prompt.txt" ] || [ ! -f "$newp/verify.sh" ]; then
    log "attempt $attempt: $newp missing prompt/verify — discard"; rm -rf "$newp"; continue
  fi
  chmod +x "$newp/verify.sh"
  wref=$(mktemp -d); wemp=$(mktemp -d)
  [ -d "$newp/seed" ] && { cp -a "$newp/seed/." "$wref/"; cp -a "$newp/seed/." "$wemp/"; }
  [ -d "$newp/_reference" ] && cp -a "$newp/_reference/." "$wref/"
  bash "$newp/verify.sh" "$wref" >/dev/null 2>&1; refok=$?
  bash "$newp/verify.sh" "$wemp" >/dev/null 2>&1; empok=$?
  rm -rf "$wref" "$wemp"
  if [ "$refok" -eq 0 ] && [ "$empok" -ne 0 ]; then
    log "VALID new task $(basename "$newp") (ref passes, seed-only fails)"
    git add -A && git commit -q -m "escalate: add harder task $(basename "$newp")" && git push -q 2>/dev/null || true
    exit 0
  fi
  log "attempt $attempt: $newp invalid (ref=$refok empty=$empok) — discard"
  rm -rf "$newp"
done
log "escalation failed after 3 attempts"
exit 1
