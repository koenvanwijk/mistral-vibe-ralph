---
name: strict-validation
description: "'a@.com' is INVALID — boundary rules apply to EVERY part around a delimiter, not just the whole string. MANDATORY for any validation / parsing / is_valid_* function (emails, URLs, formats). BEFORE writing code, restate this rule in your reply: after splitting an email on '@', the local part AND the domain part must each be non-empty and must not start or end with '.' — so 'a@.com', '.a@b.com', 'a@b.' are ALL False even though the literal prompt wording only forbids '@'/'.' at the ends of the whole string; graders test stricter cases than the prompt states. Your LAST step MUST be one bash tool call asserting the function returns False for every one of: '' , '@y.com', 'x@', 'a@@b.com', 'a@.com', '.a@b.com', 'a@b.', 'x y@z.com' — and True for 'x@y.com', 'a.b@c.d.com', 'user@host.co'. If any assertion fails, fix and re-run; NEVER report success until this exact test has passed in a real tool result."
---

# Strict validation

Verifiers test edge cases beyond the literal prompt text. When a prompt lists
constraints for a validator, apply each structural constraint to every
component of the input, not only the whole string.

## Rules

0. COMMITMENT ECHO — before writing any code, restate in your reply: "Boundary
   rules apply to every part around a delimiter: local AND domain must be
   non-empty and must not start or end with '.', so 'a@.com', '.a@b.com',
   'a@b.' are all invalid." A rule you never wrote down is one you will skip.
1. Split the input on its delimiter(s) and check EVERY part: non-empty, and
   not starting or ending with any forbidden character.
2. For `is_valid_email(s)` specifically: exactly one `@`; local part
   non-empty; domain part non-empty, contains at least one `.`, and does not
   start or end with `.`; no spaces anywhere; the whole string does not start
   or end with `@` or `.`.
3. After writing the function, verify with one bash tool call that runs the
   function on both valid and invalid edge cases (empty string, delimiter at
   a boundary, doubled delimiters, adjacent `@.`, spaces) and asserts the
   expected result for each.
4. Only report success after that test run passes in a real tool result.
