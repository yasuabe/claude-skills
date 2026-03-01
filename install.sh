#!/bin/bash
# Install Claude Code skills to ~/.claude/skills/
SKILLS_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$HOME/.claude/skills"

mkdir -p "$TARGET"

for skill in "$SKILLS_DIR"/*/; do
    name=$(basename "$skill")
    cp -r "$skill" "$TARGET/$name"
    echo "Installed: $name"
done
