#!/bin/bash
# Sync the tunable vibe_profile/ into ~/.vibe/ (config, agents, skills).
# NOTE: ~/.vibe is treated as owned by this experiment.
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p ~/.vibe
cp "$REPO/vibe_profile/config.toml" ~/.vibe/config.toml
rm -rf ~/.vibe/agents ~/.vibe/skills
mkdir -p ~/.vibe/agents ~/.vibe/skills
[ -d "$REPO/vibe_profile/agents" ] && cp -a "$REPO/vibe_profile/agents/." ~/.vibe/agents/ 2>/dev/null || true
[ -d "$REPO/vibe_profile/skills" ] && cp -a "$REPO/vibe_profile/skills/." ~/.vibe/skills/ 2>/dev/null || true
