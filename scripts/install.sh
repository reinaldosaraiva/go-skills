#!/usr/bin/env bash
# install.sh — symlink every skill in this repo into ~/.claude/skills.
# Alternative to the plugin marketplace path (see README). Refuses to
# overwrite an existing entry unless --force is passed.
set -euo pipefail

FORCE=0
DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        --dest=*) DEST="${arg#--dest=}" ;;
        -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
        *) echo "unknown arg: $arg" >&2; exit 2 ;;
    esac
done

HERE=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$DEST"
for skill in "$HERE"/plugins/*/skills/*; do
    name=$(basename "$skill")
    dst="$DEST/$name"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        if [ "$FORCE" -eq 1 ]; then rm -rf -- "$dst"; else
            echo "refusing to overwrite $dst (use --force)" >&2; exit 1; fi
    fi
    ln -s "$skill" "$dst"
    echo "[install] $name -> $dst"
done
echo "[install] done. Git hooks: plugins/go-style/skills/go-style/scripts/install-hooks.sh (go-style); see frr-style/SKILL.md for frr-style hooks."
