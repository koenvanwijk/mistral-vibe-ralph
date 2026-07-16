#!/bin/bash
# Ralph loop for tuning Mistral Medium 3.5 via the Mistral Vibe CLI.
#
#   baseline -> N rounds of (proposer edits vibe_profile/ -> re-score (3 trials/task)
#               -> keep if score didn't drop, else roll back), commit+push each round.
#
# ADAPTIVE PROPOSER: prefer headless Claude Code. When Claude hits its session/
# quota limit, switch to the LOCAL proposer (Agents-A1 on spark-480b via
# local_propose.py). While on the local proposer, probe Claude each round and
# switch back as soon as its quota has cooled down. The loop never stalls.
#
# Usage: ./ralph.sh [iterations]        (default 30)
REPO="$(cd "$(dirname "$0")" && pwd)"; cd "$REPO"
N="${1:-30}"
export PATH="$HOME/.local/bin:$PATH"
export VIBE_LOCAL_KEY="${VIBE_LOCAL_KEY:-dummy}"
export TRIALS="${TRIALS:-3}"
PROP_PY="${PROP_PY:-$HOME/.openclaw/workspace/agents-a1-repro/.venv/bin/python}"
log(){ echo "[$(date -Is)] $*" | tee -a "$REPO/ralph.log"; }

claude_up(){ timeout 90 claude -p "reply with exactly OK" --dangerously-skip-permissions 2>/dev/null | grep -q OK; }

propose_claude(){  # $1=iter ; returns 0 ok, 1 quota/failure
  local logf="runs/proposer_$1.log"
  timeout 900 claude -p "$(cat proposer/PROPOSER.md)" \
    --dangerously-skip-permissions --add-dir "$REPO" > "$logf" 2>&1
  local rc=$?
  grep -qiE "session limit|usage limit|credit balance|rate.?limit|invalid api key|please run /login|quota" "$logf" && return 1
  [ $rc -eq 0 ] && [ -s "$logf" ]
}

propose_local(){  # $1=iter ; uses Agents-A1
  "$PROP_PY" local_propose.py > "runs/proposer_$1.log" 2>&1 || echo "PROPOSAL: (local error)" >> "runs/proposer_$1.log"
}

commit(){ git add -A && git commit -q -m "$1" && git push -q 2>/dev/null || true; }

log "=== ralph start: up to $N iterations, TRIALS=$TRIALS ==="
bash scripts/apply_profile.sh
bash scripts/run_all.sh | tee -a "$REPO/ralph.log"
bash scripts/score.sh
best=$(cat runs/current/SCORE_NUM.txt 2>/dev/null || echo 0)
log "baseline score=$best"
echo "## $(date -Is) baseline score=$best" >> RESULTS.md
commit "baseline score=$best"

mode=claude
for i in $(seq 1 "$N"); do
  # try to recover Claude when running local
  if [ "$mode" = local ] && claude_up; then mode=claude; log "Claude quota recovered -> back to Claude"; fi

  if [ "$mode" = claude ]; then
    if propose_claude "$i"; then :; else
      mode=local; log "Claude exhausted -> switching to LOCAL proposer (Agents-A1)"
      propose_local "$i"
    fi
  else
    propose_local "$i"
  fi
  prop=$(grep -m1 '^PROPOSAL:' "runs/proposer_$i.log" 2>/dev/null || echo "PROPOSAL: (none)")
  log "--- iter $i [$mode] $prop"

  bash scripts/apply_profile.sh
  bash scripts/run_all.sh | tee -a "$REPO/ralph.log"
  bash scripts/score.sh
  new=$(cat runs/current/SCORE_NUM.txt 2>/dev/null || echo 0)
  log "iter $i score=$new (best=$best)"
  if [ "${new:-0}" -ge "${best:-0}" ]; then
    best=$new
    echo "## $(date -Is) iter $i [$mode] KEEP score=$new — $prop" >> RESULTS.md
    commit "iter $i [$mode] keep score=$new — $prop"
  else
    echo "## $(date -Is) iter $i [$mode] ROLLBACK score=$new<$best — $prop" >> RESULTS.md
    git checkout -- vibe_profile/ 2>/dev/null || true
    git clean -fdq vibe_profile/ 2>/dev/null || true
    commit "iter $i [$mode] rollback (score $new<$best)"
  fi

  # Auto-escalate: when the harness is saturated (all tasks pass) for 2 rounds,
  # generate a harder task and re-baseline so there is always headroom to tune.
  ntasks=$(ls -d tasks/*/ 2>/dev/null | wc -l)
  if [ "${new:-0}" -eq "$ntasks" ]; then sat=$((sat+1)); else sat=0; fi
  if [ "$sat" -ge 2 ]; then
    log "saturated ($new/$ntasks) x$sat — escalating with a harder task"
    if bash scripts/gen_task.sh; then
      sat=0
      bash scripts/apply_profile.sh
      bash scripts/run_all.sh | tee -a "$REPO/ralph.log"
      bash scripts/score.sh
      best=$(cat runs/current/SCORE_NUM.txt 2>/dev/null || echo 0)
      nt=$(ls -d tasks/*/ 2>/dev/null | wc -l)
      log "re-baseline after escalation: best=$best/$nt"
      echo "## $(date -Is) re-baseline after escalation: $best/$nt tasks" >> RESULTS.md
      commit "re-baseline after escalation: best=$best/$nt"
    fi
  fi
done
log "=== ralph done, best=$best ==="
