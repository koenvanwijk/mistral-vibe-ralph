---
name: strict-validation
description: "MANDATORY when writing any validation, parsing, or is_valid_* function (emails, URLs, formats). Graders use STRICTER edge cases than the literal prompt wording, so interpret every constraint per-COMPONENT, not just on the whole string: a rule like 'must not start or end with X' also applies to each part around a delimiter — for emails, after splitting on '@', the local part AND the domain part must each be non-empty and must not start or end with '.' or '@' (so 'a@.com', '.a@b.com', 'a@b.' are ALL invalid). Before reporting success you MUST run the function with a real bash tool call against these edge cases and confirm each returns False: '' , '@y.com', 'x@', 'a@@b.com', 'a@.com', '.a@b.com', 'a@b.', 'x y@z.com' — and True for normal inputs like 'x@y.com', 'a.b@c.d.com'. If any edge case returns the wrong value, fix the function and re-test before finishing."
---

# Strict validation

Verifiers test edge cases beyond the literal prompt text. When a prompt lists
constraints for a validator, apply each structural constraint to every
component of the input, not only the whole string.

## Rules

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
