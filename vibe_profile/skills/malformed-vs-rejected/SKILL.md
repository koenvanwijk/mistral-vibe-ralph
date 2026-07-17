---
name: malformed-vs-rejected
description: "NEVER call .strip() on a data line. MANDATORY whenever a task validates lines/records against exact whitespace-sensitive formatting rules (e.g. MALFORMED silently ignored vs REJECTED recorded in an output file). The one fatal bug: line.strip() before validation 'repairs' a line whose only defect is a leading/trailing space, so a malformed line gets APPLIED and a balance is silently wrong. STEP 1 — before writing any code, COMMIT by writing this exact sentence in your reply: I will not call strip() on any data line; I will validate each RAW line, removing only the trailing newline with rstrip, using one anchored re.fullmatch. STEP 2 — copy this shape: `line = raw.rstrip('\\n')` then `m = re.fullmatch(r'(DEPOSIT|WITHDRAW) A\\d{4} [1-9]\\d*|TRANSFER A\\d{4} A\\d{4} [1-9]\\d*', line)` (adapt the grammar to the spec); no match means MALFORMED, silently ignored — fullmatch on the un-stripped line is what catches a trailing space, leading space, tab, or double space. STEP 3 — a line that MATCHES but names an id missing from the reference data, overdraws a balance, or self-transfers is REJECTED and MUST be recorded in the rejected output in processing order — never dropped as malformed; keep membership tests OUT of the parse step. STEP 4 — after writing the script, run `grep -n strip your_script.py` in bash: any hit other than rstrip('\\n') means fix and re-run before finishing. Then re-check both output files against every rule (exact format, ordering, tie-breaks)."
---

# Malformed vs rejected: one regex, two phases, two audits

Specs that replay logs define two distinct kinds of bad input: lines that are
*syntactically* invalid (ignore silently) and lines that are syntactically
fine but *semantically* disallowed (record as rejected). Two classic bugs:

1. Calling `strip()` before validating — this "repairs" lines whose only
   defect is a leading/trailing space, so a malformed line gets APPLIED and
   one balance ends up silently wrong.
2. Testing `id in accounts` inside the parse step — this makes
   unknown-account lines vanish as malformed instead of being RECORDED as
   rejected.

## Phase 1 — syntax via one anchored fullmatch on the raw line

Copy this shape (adapt the grammar to the spec):

```python
for lineno, raw in enumerate(f, 1):
    line = raw.rstrip('\n')          # ONLY the newline — nothing else, ever
    m = re.fullmatch(
        r'(DEPOSIT|WITHDRAW) (A\d{4}) ([1-9]\d*)'
        r'|TRANSFER (A\d{4}) (A\d{4}) ([1-9]\d*)', line)
    if m is None:
        continue                     # MALFORMED: silently ignored
```

`re.fullmatch` on the un-stripped line automatically fails trailing spaces,
leading spaces, tabs, double spaces, lowercase ops, wrong field counts,
leading-zero or signed or decimal amounts, and bad id shapes — with zero
per-case code. Do not write `line.strip()` anywhere; it is the bug.

## Phase 2 — semantics, only for matched lines, always recorded

Unknown id in the reference data (on ANY operand), insufficient balance,
self-transfer: these are REJECTIONS. Append `(filename, lineno, op)` to the
rejected list — never `continue` past them silently. Existence in the
accounts file is NOT part of well-formedness.

## Two audits before you finish (real bash calls)

1. `grep -n strip your_script.py` — every hit must be `rstrip('\n')`.
2. `grep -nP '\t|  |^ | $' txns/*.log` — these are the planted whitespace
   traps; verify each listed line was ignored: not applied to any balance
   and absent from the rejected output.

Then re-run the pipeline end to end and re-check both output files against
every rule in the prompt: per-category counts, exact line format, ordering,
tie-breaks, and the final formatting (e.g. cents → dollars with two
decimals).
