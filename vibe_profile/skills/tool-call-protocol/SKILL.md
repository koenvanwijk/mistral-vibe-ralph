---
name: tool-call-protocol
description: "MANDATORY protocol for ALL tasks that create or modify files. Tools (write_file, edit, bash, read_file, ...) run ONLY when invoked through the API's structured tool-call mechanism. NEVER print a tool call as plain text in your reply: output such as <write_file>{...}</write_file> or a JSON/XML tool block in the message body is NOT executed — no file is written and the task fails, even though the reply looks correct. CRITICAL: make EXACTLY ONE tool call per assistant message — NEVER two or more in the same message. Batching several calls in one message breaks serialization: they come out as plain text and NONE of them run. Sequence strictly: one structured tool call -> wait for its tool result -> next tool call in a NEW message. For multi-file tasks, write the files one per message, one at a time. Only claim success after seeing actual tool results confirming the files exist."
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
4. For multi-file tasks, create files strictly one at a time: one tool call,
   wait for its result, then the next call in a new message, until every file
   exists.
5. Verify your work with a real tool call (e.g. `bash` running the import or
   test the task asks for), and only then report success, based on the actual
   tool output.

## Never

- Never print tool calls as plain text or inside code fences.
- Never emit more than one tool call in a single message — batched calls all
  fail silently.
- Never assume a file was written without a tool result proving it.
- Never end the turn with files still uncreated.
