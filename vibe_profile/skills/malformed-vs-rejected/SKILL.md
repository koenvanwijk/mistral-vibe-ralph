---
name: malformed-vs-rejected
description: "MANDATORY whenever a task replays/validates log lines against exact formatting rules (MALFORMED silently ignored vs REJECTED recorded). The session has a HARD TIME LIMIT: your FIRST tool call must be ONE bash heredoc that writes the complete processing script AND runs it, so both output files exist on disk within minutes — files written early still count if time runs out; verify only AFTER they exist. NEVER cat/print the data logs into the conversation (they are thousands of lines; the script reads them, you don't). The two fatal bugs, both observed: (1) NEVER call .strip() on a data line — validate the RAW line with one anchored re.fullmatch after removing only the trailing newline via rstrip('\\n'); (2) a positive-integer AMOUNT with no leading zeros is EXACTLY the regex [1-9]\\d* — writing 0*[1-9]\\d* silently accepts leading-zero amounts like 0500, which are MALFORMED, and corrupts one balance. Before writing code, COMMIT by writing this exact sentence in your reply: I will validate each raw line (rstrip newline only, never strip) with one re.fullmatch, and my amount pattern is [1-9]\\d* with no 0* prefix. Recipe: `line = raw.rstrip('\\n')` then `m = re.fullmatch(r'(DEPOSIT|WITHDRAW) A\\d{4} [1-9]\\d*|TRANSFER A\\d{4} A\\d{4} [1-9]\\d*', line)` (adapt grammar to the spec); no match = MALFORMED, silently ignored. A line that MATCHES but names an unknown id, overdraws (equal to balance is allowed), or self-transfers is REJECTED and MUST be recorded in processing order — keep membership tests OUT of the parse step. After the files exist, audit fast: `grep -nE \"strip|0\\*\" script.py` — any strip other than rstrip('\\n') or any 0* in a pattern means fix and re-run ONCE. Then stop; do not re-read the logs."
---

# Malformed vs rejected: script first, one fullmatch, fast audit

## Rule 0 — beat the clock

These sessions are killed at a hard wall-clock limit. Output files already
written to disk still count after the kill; analysis in your head does not.
Therefore:

- Your FIRST tool call writes the complete script (one bash heredoc) and runs
  it, producing both output files immediately.
- NEVER cat, head -100, or otherwise print the transaction logs into the
  conversation. They are thousands of lines; ingesting them burns the whole
  time budget. `head -3 txns/*.log` at most, only if genuinely unsure of the
  format — the prompt already tells you the grammar.
- Verify AFTER the files exist, briefly. Never before.

## Rule 1 — syntax via one anchored fullmatch on the raw line

```python
for lineno, raw in enumerate(f, 1):
    line = raw.rstrip('\n')          # ONLY the newline — nothing else, ever
    m = re.fullmatch(
        r'(DEPOSIT|WITHDRAW) (A\d{4}) ([1-9]\d*)'
        r'|TRANSFER (A\d{4}) (A\d{4}) ([1-9]\d*)', line)
    if m is None:
        continue                     # MALFORMED: silently ignored
```

Two fatal bugs this exact recipe prevents — both have actually happened:

1. `line.strip()` before validating "repairs" a line whose only defect is a
   leading/trailing space, so a malformed line gets APPLIED. Only
   `rstrip('\n')`, ever.
2. Writing the amount as `0*[1-9]\d*` accepts leading-zero amounts like
   `0500`, which the spec calls MALFORMED. The amount pattern is EXACTLY
   `[1-9]\d*` — no `0*` prefix, no sign, no decimal.

`re.fullmatch` on the un-stripped line then fails trailing/leading spaces,
tabs, double spaces, lowercase ops, wrong field counts, and bad id shapes
with zero per-case code.

## Rule 2 — semantics, only for matched lines, always recorded

Unknown id in the reference data (on ANY operand), insufficient balance
(spending the exact balance is ALLOWED — reject only when amount > balance),
self-transfer: these are REJECTIONS. Append `(filename, lineno, op)` to the
rejected list — never `continue` past them silently. Existence in the
accounts file is NOT part of well-formedness.

## Rule 3 — one fast audit, then stop

After both output files exist:

1. `grep -nE "strip|0\*" script.py` — every strip hit must be
   `rstrip('\n')`; any `0*` inside a regex is the leading-zero bug. Fix and
   re-run once if either appears.
2. Re-check the two output files against the prompt's format rules from the
   script's own output (ordering, tie-breaks, `$%.2f` from integer cents,
   no trailing spaces) — do NOT re-read the logs to double-check totals.
