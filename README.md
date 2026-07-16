# mistral-vibe-ralph

A **Ralph loop** that automatically improves the agentic-coding performance of
**Mistral Medium 3.5** (served locally via llama.cpp on an NVIDIA DGX Spark) as
driven by the **[Mistral Vibe CLI](https://github.com/mistralai/mistral-vibe)**.

Inspired by NVIDIA's ["harness profile" blog for Nemotron 3 Ultra][blog], but:
- the harness is **Mistral Vibe** (the agent Mistral Medium 3.5 was built for),
  not LangChain deepagents — so **no LangChain / LangSmith / cloud** required;
- steering happens through Vibe's own knobs: **`config.toml`, custom agents,
  and skills**.

[blog]: https://developer.nvidia.com/blog/create-a-langchain-deep-agents-harness-profile-for-nvidia-nemotron-3-ultra-to-improve-performance/

## How it works

```
baseline: run every task/ through Vibe TRIALS times (default 3) → majority score
loop:
  1. proposer reads failing tasks + trajectories and makes ONE change to
     vibe_profile/ (config / agent / skill)
  2. apply vibe_profile/ → ~/.vibe/, re-run all tasks (3 trials each), re-score
  3. score didn't drop?  keep + git commit + push   :   roll back the change
  4. repeat
```

Each task in `tasks/` is a self-contained agentic coding job with a
deterministic `verify.sh` (exit 0 = pass). Each task runs 3 times; a task
passes if a **majority** of trials pass (averages out model stochasticity).
Scoring is pass/total — fully local, no LLM judge, no LangSmith.

**Adaptive proposer.** The proposer is preferably headless **Claude Code**
(`claude -p`). When Claude hits its session/quota limit the loop switches to a
**local proposer** (`local_propose.py`, driven by a strong local model —
Agents-A1 on another DGX Spark), and probes Claude each round to switch back
after cooldown. The loop never stalls.

## Key finding: where the tuned "system prompt" actually lives

Mistral Vibe has **no working `system_prompt` key in `config.toml`** — the loop
tried it repeatedly and it was silently ignored (it isn't a real Vibe field,
and any key placed after a `[[table]]` header nests into that table and dies).

What Vibe *does* inject into the model's system prompt every turn is the
**`description:` frontmatter of each auto-discovered skill** in `~/.vibe/skills/`.
So the effective, always-on steering the loop converged on is:

- **`vibe_profile/skills/tool-call-protocol/SKILL.md`** — its `description`
  frontmatter is the real injected instruction (forbid plain-text tool calls,
  exactly one tool call per message, create all files via one `bash` heredoc
  call since `write_file` is disabled).
- **`vibe_profile/config.toml`** — `disabled_tools = ["write_file"]` and
  `active_model`, kept **above** the `[[providers]]` block.

Everything the proposer changes is committed under `vibe_profile/` and pushed
each round, so the tuned harness *is* the repo history.

## Layout
- `tasks/<name>/` — `prompt.txt` (given to Vibe), `verify.sh <workdir>`, optional `seed/`
- `vibe_profile/` — the tunable harness (`config.toml`, `agents/`, `skills/`) synced into `~/.vibe/`
- `scripts/` — `run_all.sh`, `score.sh`, `apply_profile.sh`
- `proposer/PROPOSER.md` — instructions for the headless Claude Code proposer
- `ralph.sh` — the loop
- `RESULTS.md` — score history (appended each iteration)

## Run
```bash
export VIBE_LOCAL_KEY=dummy          # local llama.cpp needs no real key
TRIALS=3 ./ralph.sh 30               # 30 iterations, 3 trials/task (detached for overnight)
```

## Setup
- Mistral Medium 3.5 served OpenAI-compatible (here: `http://192.168.86.29:8010/v1`, DGX Spark spark-36d1).
- `vibe` CLI installed (`uv tool install mistral-vibe`).
- `claude` CLI (Claude Code) authenticated — used as the autonomous proposer.
