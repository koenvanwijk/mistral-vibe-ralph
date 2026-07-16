# You generate ONE new, HARDER agentic-coding eval task for the Ralph loop.

The harness has saturated (the model now passes all current tasks). Create a
new task that is **harder than every existing task** in `tasks/`, so the loop
has fresh headroom to tune against.

## First
List `tasks/` and skim a few `prompt.txt` files to gauge current difficulty.
Make the new task meaningfully harder along one axis: longer horizon (more
tool-call steps), larger files to read, trickier exact-output spec, subtle
edge cases, multi-file state, or iterative run-fix-rerun.

## Create exactly this, and nothing outside it
A new directory `tasks/NN_shortname/` (NN = next zero-padded number after the
highest existing) containing:
- `prompt.txt` — the instruction given to the agent (self-contained; the agent
  works in a fresh directory containing only your `seed/` files, if any).
- `verify.sh` — takes `$1` = the agent's workdir, exits 0 ONLY if the task was
  done correctly, non-zero otherwise. Must be DETERMINISTIC and strict. No
  network. Use python3/grep/etc.
- `seed/` (optional) — input files the agent starts with (copied into its workdir).
- `_reference/` — the exact file(s) a CORRECT agent would produce (used only to
  validate your task; never shown to the agent). `verify.sh` MUST pass when run
  against a dir containing `seed/` + `_reference/`, and MUST fail against a dir
  containing only `seed/`.

Do NOT modify anything outside the new `tasks/NN_shortname/` directory.

## Output
Print exactly one line: `NEWTASK: tasks/NN_shortname`
