---
name: malformed-vs-rejected
description: "MANDATORY whenever a task validates lines/records against exact formatting rules, especially with two invalid categories (MALFORMED silently ignored vs REJECTED recorded in an output file). Phase 1 — syntax, decided by ONE anchored regex on the RAW line: `line = raw.rstrip('\\n')` then `m = re.fullmatch(r'(DEPOSIT|WITHDRAW) A\\d{4} [1-9]\\d*|TRANSFER A\\d{4} A\\d{4} [1-9]\\d*', line)`; no match means MALFORMED, silently ignored. Copy this shape exactly: fullmatch on the un-stripped line is what catches a trailing space, leading space, tab, or double space — the word strip()/trim() must NOT appear anywhere in your program except rstrip('\\n'), because stripping 'repairs' malformed lines and silently corrupts balances. Phase 2 — semantics, ONLY for lines that matched: an account id that fits the pattern but is missing from the accounts data, an overdraft, or a self-transfer means REJECTED and MUST be recorded in the rejected output in processing order — never dropped as malformed; keep every lookup-table membership test OUT of the parse function. Before finishing, run BOTH audits in bash: (a) `grep -n strip your_script.py` — anything except rstrip('\\n') is a bug; (b) `grep -nP '\\t|  |^ | $' txns/*.log` lists the whitespace-trap lines — confirm each one was IGNORED (appears in neither output nor any balance). Then re-run the whole pipeline and re-check both output files against every rule (counts per category, exact format, ordering, tie-breaks)."
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
