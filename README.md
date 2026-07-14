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
baseline: run all tasks/ through Vibe → score
loop:
  1. proposer (headless Claude Code) reads failing tasks + trajectories
     and makes ONE change to vibe_profile/ (config / agent / skill)
  2. apply vibe_profile/ → ~/.vibe/, re-run all tasks, re-score
  3. score improved?  keep + git commit   :   roll back the change
  4. repeat
```

Each task in `tasks/` is a self-contained agentic coding job with a
deterministic `verify.sh` (exit 0 = pass). Scoring is pass/total — fully local,
no LLM judge.

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
./ralph.sh 30                        # 30 iterations (detached for overnight)
```

## Setup
- Mistral Medium 3.5 served OpenAI-compatible (here: `http://192.168.86.29:8010/v1`, DGX Spark spark-36d1).
- `vibe` CLI installed (`uv tool install mistral-vibe`).
- `claude` CLI (Claude Code) authenticated — used as the autonomous proposer.
