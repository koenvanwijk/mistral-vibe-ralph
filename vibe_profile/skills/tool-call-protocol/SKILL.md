---
name: tool-call-protocol
description: "MANDATORY protocol for ALL tasks that create or modify files. There is NO write_file tool in this environment — never call it, it does not exist and the attempt comes out as dead plain text (nothing runs, no file is written, the task fails). To create a file — ONE file or many — use exactly ONE bash tool call with quoted heredocs: cat > file.py <<'EOF' ... EOF (plus mkdir -p for directories). Modify existing files with the edit tool. Tools run ONLY when invoked through the API's structured tool-call mechanism: NEVER print a tool call, XML tags, or JSON arguments as plain text in your reply — that text is never executed. CRITICAL: make EXACTLY ONE tool call per assistant message — never two or more; batched calls serialize as plain text and NONE run. Sequence strictly: one structured tool call -> wait for its tool result -> next call in a NEW message. Only claim success after a real tool result confirms the files exist and work."
---

# Tool-call protocol

The runtime executes a tool ONLY when it arrives as a structured tool call
(the API's tool/function-calling mechanism). Anything you write in the plain
text of your reply — including text that *looks* like a tool call — is just
text. It is never parsed and never executed. No file is created.

**There is no `write_file` tool here.** Do not call it, name it, or imitate
it: any attempt becomes plain text in your reply and nothing happens. File
creation ALWAYS goes through the `bash` tool with quoted heredocs.

The other fatal mistake is BATCHING: putting two or more tool calls in the
same assistant message. The serializer cannot encode multiple calls at once —
they get concatenated into plain text and NONE of them execute. One message =
one tool call, always.

## Steps

1. Decide which tool you need: `bash` to create files or run commands,
   `edit` to change an existing file, `read_file` to inspect one.
2. Invoke it as EXACTLY ONE real structured tool call in this message. Do NOT
   write the tool name, XML tags, or JSON arguments into your reply text, and
   do NOT add a second tool call to the same message.
3. To create a file — one or several — use ONE `bash` call with `mkdir -p`
   (if directories are needed) and quoted heredocs:

       cat > fizzbuzz.py <<'PYEOF'
       def fizzbuzz(n):
           ...
       PYEOF

   For multiple files, put every file's FULL content in the SAME single bash
   call, one heredoc per file:

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

   CRITICAL — do NOT create the files empty first and fill them later. Never
   use `touch` (or an empty heredoc) to stub files you plan to fill in a
   later message — the real content must live inside the heredocs of this
   SAME bash call, so one call finishes the whole job.
4. Wait for the tool result. If no tool result comes back, the tool did not
   run — invoke it again correctly (one call, own message) instead of
   continuing.
5. Verify your work with a real tool call (e.g. `bash` running `cat`, the
   import, or the test the task asks for), and only then report success,
   based on the actual tool output.

## Never

- Never call or mention `write_file` — it does not exist in this environment.
- Never print tool calls as plain text or inside code fences.
- Never emit more than one tool call in a single message — batched calls all
  fail silently.
- Never assume a file was written without a tool result proving it.
- Never end the turn with files still uncreated.
