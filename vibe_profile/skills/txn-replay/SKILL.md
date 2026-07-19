---
name: txn-replay
description: "MANDATORY when a task replays a write-ahead log / WAL with transactions (BEGIN/COMMIT/ROLLBACK) against a snapshot key-value store. You emit ~2 tokens/sec and die at 15 min: NO plan, NO prose, NO comments (plan-before-code does NOT apply). FIRST tool call = ONE bash heredoc that writes a dense python script (<=60 lines) replaying every file and writing ALL output files, then runs it in the SAME call. Semantics: re.fullmatch the RAW line after rstrip('\\n') only, never .strip(); VALUE regex (0|[1-9]\\d*) — 0 valid, leading zeros/signs not; DEL takes KEY ONLY (2 fields, no VALUE); lowercase commit/rollback is MALFORMED; open txn = commands act on a dict COPY, rejection checked against that COPY; rejections stay recorded even if the txn rolls back; BEGIN in a txn and COMMIT/ROLLBACK outside one are REJECTED not malformed; a txn open at end of input is discarded, NOT counted as rolled_back; SET never rejects; SUB equal to current value applies (leaves 0). Then ONE cheap check (head outputs) and stop."
---

# Transactional WAL replay: dense script first, zero prose

## Rule 0 — you are token-starved

The backing model emits ~2 tokens/second and the session is killed at a hard
15-minute wall clock. A 200-token paragraph costs ~1.5 minutes; a commented
150-line script costs more time than the whole session has. Files already on
disk still count after the kill; words do not. Therefore:

- Do NOT write a plan, a checklist, or any explanation. The script is the plan.
- Do NOT explore beyond at most one `ls`. The prompt fully specifies the
  grammar and semantics — reading the logs teaches nothing and burns minutes.
- Write the script DENSE: no comments, no blank-line padding, short names
  (`kv`, `txn`, `mal`, `rej`), 60 lines or fewer.
- ONE bash heredoc that writes the script AND runs it (`cat > r.py <<'EOF'
  ... EOF
  python3 r.py`) so all output files exist after your first tool call.

## Rule 1 — validation

Validate the RAW line with `re.fullmatch` after `rstrip('\n')` ONLY — never
`.strip()` (it repairs whitespace-defective lines). Field counts differ per
command — do NOT fold DEL into the 3-field pattern. Use exactly these:

```python
p3 = re.compile(r'(SET|ADD|SUB) ([a-z]{2,10}) (0|[1-9]\d*)')  # 3 fields
p2 = re.compile(r'DEL ([a-z]{2,10})')                          # DEL has NO VALUE
p1 = re.compile(r'(BEGIN|COMMIT|ROLLBACK)')
```

`0` is valid; `00`/`070`/`+5`/`-5`/`1.5` are malformed. Command words are
matched case-sensitively; a lowercase `commit` is MALFORMED, not a commit.
Malformed lines are counted and skipped — they never appear in the rejected
list.

## Rule 2 — transaction semantics (the graders' favorite traps)

- Open txn = commands act on a private `dict(kv)` COPY; COMMIT swaps the copy
  in; ROLLBACK discards it. No nesting. Track open-ness with `txn is not None`
  (an empty working copy is falsy — plain `if txn:` corrupts state).
- Rejection (existence, overdraft/underflow) is checked against the COPY while
  a txn is open, the committed store otherwise.
- A rejection is recorded at processing time and STAYS recorded even if the
  surrounding txn is later rolled back or never committed.
- BEGIN inside an open txn, and COMMIT/ROLLBACK with no open txn, are
  REJECTED (well-formed but recorded), not malformed.
- A txn still open after the last line of the last file is discarded and does
  NOT increment the rolled_back counter.
- SET never rejects (creates the key). SUB of exactly the current value is
  applied and leaves 0; only SUB greater than the value rejects.

## Rule 3 — finish cheaply

After the run: at most ONE more tool call (`head` the output files) to confirm
they exist and look sane, then stop. No re-reading the prompt, no byte-by-byte
audit essay — the clock is still running.
