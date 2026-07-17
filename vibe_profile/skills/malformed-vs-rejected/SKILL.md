---
name: malformed-vs-rejected
description: "MANDATORY when a task defines TWO OR MORE categories of invalid input with different handling (e.g. MALFORMED lines silently ignored vs REJECTED lines recorded in an output file): implement them as two SEPARATE phases and never let one check leak into the other. Phase 1 — syntactic well-formedness on the RAW, UNMODIFIED line: never strip(), trim, lower(), or normalize whitespace before validating; a leading space, trailing space, tab, or double space makes the line malformed even though stripping would 'fix' it — only strip the newline (rstrip('\\n')), then check exact field count with line.split(' ') and exact per-field patterns. Phase 2 — semantic rules (id not present in the reference data / accounts file, insufficient balance, self-transfer) apply ONLY to lines that passed phase 1, and a semantic failure means REJECTED (it MUST appear in the rejected output), NEVER silently ignored: an id that matches the required pattern (e.g. A9999) but is missing from the accounts file is a REJECTION to record, not a malformed line to drop. Before finishing, audit your code with a real bash call: any strip()/trim before validation, or any 'is it in the lookup table' membership test inside the parse/malformed check, is a bug — fix it, re-run the whole pipeline, and re-check both output files against every category rule in the prompt."
---

# Malformed vs rejected: two phases, never merged

Specs that replay logs or records often define two distinct kinds of bad
input: lines that are *syntactically* invalid (ignore silently) and lines
that are syntactically fine but *semantically* disallowed (record as
rejected). Collapsing these into one validity check is the classic bug: the
rejected-output file silently loses entries, and normalized lines that should
have been ignored get applied.

## Rules

1. **Validate the raw line.** Remove only the trailing newline. Do NOT call
   `strip()` / `trim()` first: leading/trailing spaces and tabs are exactly
   what the malformed-line rules exist to catch. Check field count with a
   single-space split (`line.split(' ')`) so double spaces produce empty
   fields and fail; check each field against its exact grammar (operation
   word case-sensitive, id pattern, amount with no leading zeros/sign/dot).
2. **Syntax says nothing about existence.** Whether an id exists in the
   accounts/reference data is NOT part of well-formedness. Keep the parse
   function free of any lookup-table membership test.
3. **Semantic failures are recorded, not dropped.** After a line parses,
   apply the spec's rejection rules (unknown id on ANY operand, overdraft,
   self-transfer, ...). Every such failure goes to the rejected output in
   processing order.
4. **Audit before done.** `grep -n 'strip\|in accounts\|in data' yourscript`
   — a strip before validation or a membership test inside parsing means the
   two phases leaked into each other. Fix, re-run on the full input, and
   re-check both output files against every rule in the prompt (counts per
   category, exact formats, ordering, tie-breaks).
