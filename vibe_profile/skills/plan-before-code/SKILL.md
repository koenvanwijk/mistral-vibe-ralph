---
name: plan-before-code
description: "MANDATORY FIRST step for any task whose prompt states several rules, edge cases, or exact-format requirements: BEFORE writing any code, restate every rule from the prompt as a numbered checklist (exact filenames, formats, ordering, tie-breaks, ignore/skip rules, 'must NOT appear' rules) and decide which line or branch of your code will handle each one — rules you never wrote down are the ones graders catch. For any large input file (log/data): NEVER read or eyeball the data to compute the answer — write ONE program that processes the ENTIRE file and implements every checklist rule, then run it. Finish with verify-before-done against the same checklist."
---

# Plan before code

Hard tasks fail not because the code is wrong but because a rule stated in
the prompt never made it into the code. The fix is mechanical: extract every
rule first, then write code against the list.

## Steps

1. Read the ENTIRE task prompt. Number every explicit requirement, one per
   line: each named file and path, each exact output format (separators,
   ordering, tie-breaks, headers or their absence, trailing whitespace), each
   rule about what to include, ignore, or exclude ("must not appear", "is
   silently ignored", "contributes nothing"), each edge case.
2. Negative/exclusion rules are the most commonly missed — list them
   explicitly and plan the exact condition in code that enforces each.
3. For large input files, compute NOTHING by hand or by reading the data in
   your context: write ONE program (single bash heredoc) that streams the
   whole file and implements every numbered rule, then execute it with a real
   tool call. Peek at a few lines only to confirm the format, never to derive
   results.
4. While implementing, tick off each numbered rule against the specific code
   branch that handles it; any rule with no matching branch means the code is
   incomplete.
5. Then follow verify-before-done: re-check every numbered item against real
   tool-call output before finishing.
