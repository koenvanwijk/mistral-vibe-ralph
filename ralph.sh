#!/bin/bash
# Ralph loop for tuning Mistral Medium 3.5 via the Mistral Vibe CLI.
#
#   baseline -> N rounds of (proposer edits vibe_profile/ -> re-score ->
#               keep if score didn't drop, else roll back), commit+push each round.
#
# FALLBACK: when the headless Claude proposer becomes unavailable (quota/auth),
# after 2 consecutive failures the loop stops improving and runs the full
# deepagents 127-test eval against the local Mistral endpoint (bypassing the
# LangSmith cloud requirement with LANGSMITH_TRACING=true + a dummy key; set a
# real LANGSMITH_API_KEY in the environment to also get the LangSmith UI).
#
# Usage: ./ralph.sh [iterations]        (default 20)
REPO="$(cd "$(dirname "$0")" && pwd)"; cd "$REPO"
N="${1:-20}"
export PATH="$HOME/.local/bin:$PATH"
export VIBE_LOCAL_KEY="${VIBE_LOCAL_KEY:-dummy}"
EVALS="${DEEPAGENTS_EVALS:-$HOME/.openclaw/workspace/deepagents/libs/evals}"
MISTRAL_URL="http://192.168.86.29:8010/v1"
log(){ echo "[$(date -Is)] $*" | tee -a "$REPO/ralph.log"; }

run_eval127(){
  log "=== FALLBACK: deepagents 127-eval vs Mistral-Medium-3.5 ==="
  ( cd "$EVALS"
    export OPENAI_BASE_URL="$MISTRAL_URL"
    export OPENAI_API_KEY="dummy"
    export LANGSMITH_TRACING=true
    export LANGSMITH_API_KEY="${LANGSMITH_API_KEY:-dummy}"
    uv run --group test pytest tests/evals -v --tb=line \
      --model openai:Mistral-Medium-3.5 ) >> "$REPO/eval127.log" 2>&1
  log "=== 127-eval finished — results in eval127.log ==="
  { echo "## $(date -Is) deepagents 127-eval (fallback)"; grep -E "passed|failed|error" "$REPO/eval127.log" | tail -3; } >> "$REPO/RESULTS.md"
  git add -A && git commit -q -m "fallback: deepagents 127-eval results" && git push -q 2>/dev/null || true
}

proposer_ok(){  # returns 0 if the proposer produced a usable result
  local logf="runs/proposer_$1.log"
  timeout 900 claude -p "$(cat proposer/PROPOSER.md)" \
    --dangerously-skip-permissions --add-dir "$REPO" > "$logf" 2>&1
  local rc=$?
  [ $rc -eq 0 ] || return 1
  grep -qiE "usage limit|credit balance|rate.?limit|invalid api key|please run /login|not authenticated|quota exceeded" "$logf" && return 1
  [ -s "$logf" ] || return 1
  return 0
}

log "=== ralph start: up to $N iterations ==="
bash scripts/apply_profile.sh
bash scripts/run_all.sh | tee -a "$REPO/ralph.log"
bash scripts/score.sh
best=$(cat runs/current/SCORE_NUM.txt 2>/dev/null || echo 0)
log "baseline score=$best"
echo "## $(date -Is) baseline score=$best" >> RESULTS.md
git add -A && git commit -q -m "baseline score=$best" && git push -q 2>/dev/null || true

fails=0
for i in $(seq 1 "$N"); do
  log "--- iteration $i (best=$best) ---"
  if ! proposer_ok "$i"; then
    fails=$((fails+1))
    log "proposer unavailable (consecutive=$fails). See runs/proposer_$i.log"
    if [ "$fails" -ge 2 ]; then
      log "Claude proposer exhausted — switching to 127-eval fallback"
      run_eval127
      break
    fi
    continue
  fi
  fails=0
  prop=$(grep -m1 '^PROPOSAL:' "runs/proposer_$i.log" 2>/dev/null || echo "PROPOSAL: (none parsed)")
  log "$prop"
  bash scripts/apply_profile.sh
  bash scripts/run_all.sh | tee -a "$REPO/ralph.log"
  bash scripts/score.sh
  new=$(cat runs/current/SCORE_NUM.txt 2>/dev/null || echo 0)
  log "iteration $i score=$new (best=$best)"
  if [ "${new:-0}" -ge "${best:-0}" ]; then
    best=$new
    echo "## $(date -Is) iter $i KEEP score=$new — $prop" >> RESULTS.md
    git add -A && git commit -q -m "iter $i keep score=$new — $prop" && git push -q 2>/dev/null || true
  else
    echo "## $(date -Is) iter $i ROLLBACK score=$new<$best — $prop" >> RESULTS.md
    git checkout -- vibe_profile/ 2>/dev/null || true
    git clean -fdq vibe_profile/ 2>/dev/null || true
    git add -A && git commit -q -m "iter $i rollback (score $new<$best)" && git push -q 2>/dev/null || true
  fi
done
log "=== ralph done, best=$best ==="
