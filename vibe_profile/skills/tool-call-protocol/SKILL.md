---
name: tool-call-protocol
description: "MANDATORY protocol for ALL tasks that create or modify files. Tools (write_file, edit, bash, read_file, ...) run ONLY when invoked through the API's structured tool-call mechanism. NEVER print a tool call as plain text in your reply: output such as <write_file>{...}</write_file> or a JSON/XML tool block in the message body is NOT executed — no file is written and the task fails, even though the reply looks correct. To create or edit a file you MUST emit a real structured tool call and wait for its tool result. Only claim success after seeing actual tool results confirming the files exist."
---

# Tool-call protocol

The runtime executes a tool ONLY when it arrives as a structured tool call
(the API's tool/function-calling mechanism). Anything you write in the plain
text of your reply — including text that *looks* like a tool call, such as
`<write_file>{"file_path": ..., "content": ...}</write_file>` — is just text.
It is never parsed and never executed. No file is created.

## Steps

1. Decide which tool you need (e.g. `write_file` to create a file, `edit` to
   change one, `bash` to run a command).
2. Invoke it as a REAL structured tool call. Do NOT write the tool name,
   XML tags, or JSON arguments into your reply text.
3. Wait for the tool result. If no tool result comes back, the tool did not
   run — invoke it again correctly instead of continuing.
4. For multi-file tasks, make one real tool call per file until every file
   exists.
5. Verify your work with a real tool call (e.g. `bash` running the import or
   test the task asks for), and only then report success, based on the actual
   tool output.

## Never

- Never print tool calls as plain text or inside code fences.
- Never assume a file was written without a tool result proving it.
- Never end the turn with files still uncreated.
