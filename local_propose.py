#!/usr/bin/env python3
"""Local (Claude-free) Ralph proposer.

Uses a capable LOCAL model (Agents-A1 on spark-480b) to propose ONE edit to
vibe_profile/. Constrained output protocol keeps a weaker local model reliable:

    PROPOSAL: <one line>
    TARGET: vibe_profile/<path>
    ```
    <full new file content>
    ```

Applies the edit (guarded: path must be under vibe_profile/; config.toml must
keep the infra block) and prints the PROPOSAL line. On any parse/guard failure
it prints "PROPOSAL: (local proposer no-op)" and changes nothing.
"""
import os, re, sys, glob, pathlib
from openai import OpenAI

REPO = pathlib.Path(__file__).resolve().parent
PROP_URL = os.environ.get("PROPOSER_URL", "http://192.168.86.32:8000/v1")
PROP_MODEL = os.environ.get("PROPOSER_MODEL", "Agents-A1")
INFRA = (
    'active_model = "mistral-local"\n\n'
    '[[providers]]\nname = "spark-mistral"\n'
    'api_base = "http://192.168.86.29:8010/v1"\n'
    'api_key_env_var = "VIBE_LOCAL_KEY"\napi_style = "openai"\nbackend = "generic"\n\n'
    '[[models]]\nname = "Mistral-Medium-3.5"\nprovider = "spark-mistral"\nalias = "mistral-local"\n'
)

def read(p, n=2500):
    try:
        return pathlib.Path(p).read_text()[:n]
    except Exception:
        return ""

def gather():
    ctx = ["## SCORE\n" + read(REPO / "runs/current/SCORE.txt")]
    score = read(REPO / "runs/current/SCORE.txt")
    for task in sorted(glob.glob(str(REPO / "tasks/*/"))):
        name = os.path.basename(task.rstrip("/"))
        # only include failing-ish tasks (mentioned as FAIL) to keep prompt small
        if f"FAIL {name}" not in score:
            continue
        ctx.append(f"\n## FAILING TASK {name}\nPROMPT: {read(task+'prompt.txt',400)}")
        ctx.append("VERIFY: " + read(task + "verify.sh", 500))
        traj = read(str(REPO / f"runs/current/{name}/trial1/_vibe_stdout.txt"), 1200)
        ctx.append("TRIAL1 OUTPUT (tail):\n" + traj[-1000:])
    ctx.append("\n## CURRENT vibe_profile/config.toml\n" + read(REPO / "vibe_profile/config.toml"))
    skills = glob.glob(str(REPO / "vibe_profile/skills/*/SKILL.md"))
    ctx.append("EXISTING SKILLS: " + (", ".join(os.path.basename(os.path.dirname(s)) for s in skills) or "(none)"))
    return "\n".join(ctx)

def main():
    instructions = read(REPO / "proposer/PROPOSER.md", 4000)
    protocol = (
        "\n\nOutput EXACTLY in this format and nothing else:\n"
        "PROPOSAL: <one line>\nTARGET: vibe_profile/<relative path>\n"
        "```\n<full new content of that ONE file>\n```\n"
        "If editing config.toml, keep the entire [[providers]]/[[models]]/active_model block unchanged at the top."
    )
    client = OpenAI(base_url=PROP_URL, api_key="none", timeout=1200)
    try:
        r = client.chat.completions.create(
            model=PROP_MODEL, temperature=0.4, max_tokens=4000,
            messages=[{"role": "system", "content": instructions + protocol},
                      {"role": "user", "content": gather()}])
        out = r.choices[0].message.content or ""
    except Exception as e:
        print(f"PROPOSAL: (local proposer error: {e})"); return

    prop = next((l for l in out.splitlines() if l.strip().startswith("PROPOSAL:")), "PROPOSAL: (none)")
    mt = re.search(r"TARGET:\s*(vibe_profile/[^\s`]+)", out)
    mc = re.search(r"```[a-zA-Z]*\n(.*?)```", out, re.S)
    if not (mt and mc):
        print("PROPOSAL: (local proposer no-op — unparseable)"); return
    rel = mt.group(1).strip()
    if ".." in rel or not rel.startswith("vibe_profile/"):
        print("PROPOSAL: (local proposer no-op — bad path)"); return
    content = mc.group(1)
    if rel.endswith("config.toml") and "[[providers]]" not in content:
        content = INFRA + "\n# --- tunable ---\n" + content
    dest = REPO / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(content)
    print(prop if prop.startswith("PROPOSAL:") else "PROPOSAL: " + prop)

if __name__ == "__main__":
    main()
