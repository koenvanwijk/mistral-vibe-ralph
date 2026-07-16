---
name: verify-before-done
description: "MANDATORY final step for EVERY multi-step or exact-format task (CLIs, reports, logs, refactors). Before your last message: re-read the ENTIRE task prompt and enumerate every explicit requirement — exact file paths, function/class names, CLI commands and flags, exact output text, ordering, persistence across runs, edge cases. Then verify EACH item with a real bash tool call: run the program end-to-end the way the prompt describes (including a second run when state must persist) and compare required output byte-for-byte — spacing, punctuation, capitalisation, blank lines and ordering all count. If any check fails, fix it and re-run the check. NEVER end the session claiming success on a requirement you did not just see pass in a real tool result."
---

# Verify before done

Graders run the exact commands in the prompt and diff output exactly. A
solution that is "basically right" but off by one character, one filename, or
one missing rerun of a stateful CLI scores zero.

## Steps

1. Re-read the full task prompt one more time. Write out (mentally or in the
   reply) a checklist: every named file, every named function/command, every
   literal output string, every ordering or persistence rule, every edge case.
2. For each checklist item, run ONE bash tool call that exercises it the same
   way a grader would: invoke the real entry point (script/CLI), not just an
   imported function, and use the prompt's own example invocations when given.
3. For stateful tasks (todo lists, logs, sessions), run the sequence TWICE in
   separate invocations to prove data persists between runs.
4. For exact-format output, print the actual output and compare it
   character-by-character against the required text — trailing whitespace,
   blank lines, and line order included. Prefer `diff <(cmd) expected.txt`
   style checks when the expected text is known.
5. If anything mismatches, fix the code and repeat the failed check. Finish
   only when every item has passed in a real tool result in this session.
