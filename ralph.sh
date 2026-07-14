#!/bin/bash
# Ralph loop: baseline, then N rounds of (proposer edits profile → re-score →
# keep if score didn't drop, else roll back). Commits + pushes each round.
# Usage: ./ralph.sh [iterations]   (default 20)
REPO="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO"
N="${1:-20}"
export PATH="$HOME/.local/bin:$PATH"
export VIBE_LOCAL_KEY="${VIBE_LOCAL_KEY:-dummy}"
log(){ echo "[$(date -Is)] $*" | tee -a "$REPO/ralph.log"; }

log "=== ralph start: $N iterations ==="
bash scripts/apply_profile.sh
bash scripts/run_all.sh | tee -a "$REPO/ralph.log"
bash scripts/score.sh
best=$(cat runs/current/SCORE_NUM.txt)
log "baseline score=$best"
echo "## $(date -Is) baseline score=$best" >> RESULTS.md
git add -A && git commit -q -m "baseline score=$best" && git push -q 2>/dev/null || true

for i in $(seq 1 "$N"); do
  log "--- iteration $i (best=$best) ---"
  # Proposer: headless Claude Code makes ONE change to vibe_profile/
  timeout 900 claude -p "$(cat proposer/PROPOSER.md)" \
    --dangerously-skip-permissions --add-dir "$REPO" \
    > "runs/proposer_$i.log" 2>&1 || true
  prop=$(grep -m1 '^PROPOSAL:' "runs/proposer_$i.log" 2>/dev/null || echo "PROPOSAL: (none)")
  log "$prop"
  bash scripts/apply_profile.sh
  bash scripts/run_all.sh | tee -a "$REPO/ralph.log"
  bash scripts/score.sh
  new=$(cat runs/current/SCORE_NUM.txt)
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
