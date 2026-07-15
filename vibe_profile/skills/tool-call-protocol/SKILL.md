---
name: tool-call-protocol
description: "MANDATORY protocol for ALL tasks that create or modify files. Tools (write_file, edit, bash, read_file, ...) run ONLY when invoked through the API's structured tool-call mechanism. NEVER print a tool call as plain text in your reply: output such as <write_file>{...}</write_file> or a JSON/XML tool block in the message body is NOT executed — no file is written and the task fails, even though the reply looks correct. CRITICAL: make EXACTLY ONE tool call per assistant message — NEVER two or more in the same message. Batching several calls in one message breaks serialization: they come out as plain text and NONE of them run. Sequence strictly: one structured tool call -> wait for its tool result -> next tool call in a NEW message. For any task needing 2+ files, do NOT emit multiple write_file calls; instead create ALL the files in ONE single bash tool call using mkdir -p and quoted heredocs (cat > f <<'EOF' ... EOF) so only one tool call is ever needed. Only claim success after seeing actual tool results confirming the files exist."
---

# Tool-call protocol

The runtime executes a tool ONLY when it arrives as a structured tool call
(the API's tool/function-calling mechanism). Anything you write in the plain
text of your reply — including text that *looks* like a tool call, such as
`<write_file>{"file_path": ..., "content": ...}</write_file>` — is just text.
It is never parsed and never executed. No file is created.

The other fatal mistake is BATCHING: putting two or more tool calls in the
same assistant message. The serializer cannot encode multiple calls at once —
they get concatenated into plain text (e.g.
`<write_file[ARGS]{...}<write_file[ARGS]{...}<bash[ARGS]{...}`) and NONE of
them execute. One message = one tool call, always.

## Steps

1. Decide which tool you need (e.g. `write_file` to create a file, `edit` to
   change one, `bash` to run a command).
2. Invoke it as EXACTLY ONE real structured tool call in this message. Do NOT
   write the tool name, XML tags, or JSON arguments into your reply text, and
   do NOT add a second tool call to the same message.
3. Wait for the tool result. If no tool result comes back, the tool did not
   run — invoke it again correctly (one call, own message) instead of
   continuing.
4. For any task that needs 2 OR MORE files, do NOT emit several `write_file`
   calls — that is exactly the batching that fails. Instead create every file
   in ONE single `bash` tool call using `mkdir -p` and quoted heredocs, e.g.:

       mkdir -p calc
       cat > calc/__init__.py <<'PYEOF'
       from .ops import add, mul
       PYEOF
       cat > calc/ops.py <<'PYEOF'
       def add(a, b):
           return a + b
       def mul(a, b):
           return a * b
       PYEOF

   One structured `bash` call builds the whole package at once, so you never
   need more than one tool call in a message.

   CRITICAL — do NOT create the files empty first and fill them later. The
   file CONTENT must be inside the heredocs in this SAME bash call. This split
   is the #1 cause of failure:

       # WRONG — creates empty files, then a second call to add content.
       # The second call serializes as plain text and never runs, so the
       # files stay EMPTY and every import fails:
       mkdir -p calc && touch calc/__init__.py calc/ops.py   # call 1
       write_file calc/ops.py ...                             # call 2 -> DEAD

       # RIGHT — content lives in the heredocs, so ONE bash call finishes
       # the whole task and no second call is ever needed:
       mkdir -p calc
       cat > calc/__init__.py <<'PYEOF'
       from .ops import add, mul
       PYEOF
       cat > calc/ops.py <<'PYEOF'
       def add(a, b):
           return a + b
       def mul(a, b):
           return a * b
       PYEOF

   Never use `touch` (or an empty heredoc) to stub files you plan to fill in a
   later message — write the real content the first time.
5. Verify your work with a real tool call (e.g. `bash` running the import or
   test the task asks for), and only then report success, based on the actual
   tool output.

## Never

- Never print tool calls as plain text or inside code fences.
- Never emit more than one tool call in a single message — batched calls all
  fail silently.
- Never assume a file was written without a tool result proving it.
- Never end the turn with files still uncreated.
