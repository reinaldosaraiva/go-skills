#!/bin/bash
# install-hooks.sh — install go-style hooks into a target repo.
#
# Three modes:
#   --mode=wrapper  (default) — writes thin shim that exec's the skill hook.
#                                Fix in skill propagates without reinstall.
#   --mode=copy              — copies hook file (historical default; frozen).
#   --mode=symlink           — creates symlink to skill hook file.
#
# The skill hooks live wherever this script lives (self-resolved, symlinks
# followed — no hardcoded home, P061-S003); wrappers bake the resolved path
# at install time.
#
# Overwrite policy: an existing hook is NEVER overwritten silently — the
# install refuses unless --force is passed (wrapper mode refreshes its own
# marked wrapper silently; symlink mode re-points only when it already points
# at this hook).
#
# Usage:
#   install-hooks.sh [--mode=wrapper|copy|symlink] [--repo=PATH] [--force]
#
# Defaults:
#   repo = current git repo (git rev-parse --show-toplevel)
#   mode = wrapper

set -euo pipefail

MODE="wrapper"
REPO=""
FORCE=0

for arg in "$@"; do
    case "$arg" in
        --mode=*) MODE="${arg#--mode=}" ;;
        --repo=*) REPO="${arg#--repo=}" ;;
        --force)  FORCE=1 ;;
        -h|--help)
            sed -n '1,30p' "$0" | tail -n +2
            exit 0
            ;;
        *)
            echo "unknown arg: $arg" >&2
            exit 2
            ;;
    esac
done

case "$MODE" in
    wrapper|copy|symlink) ;;
    *) echo "invalid --mode: $MODE (expected wrapper|copy|symlink)" >&2; exit 2 ;;
esac

if [ -z "$REPO" ]; then
    REPO=$(git rev-parse --show-toplevel 2>/dev/null || true)
    if [ -z "$REPO" ]; then
        echo "no --repo given and cwd is not inside a git repo" >&2
        exit 2
    fi
fi

if [ ! -d "$REPO/.git" ] && [ ! -f "$REPO/.git" ]; then
    echo "not a git repo: $REPO" >&2
    exit 2
fi

# Worktrees have a .git file pointing at the real hooks dir. Honour
# git's own resolution via --git-path instead of hardcoding .git/hooks.
HOOKS_DIR=$(git -C "$REPO" rev-parse --git-path hooks 2>/dev/null)
if [ -z "$HOOKS_DIR" ]; then
    echo "failed to resolve hooks dir for $REPO" >&2
    exit 2
fi
# rev-parse returns a relative path when run inside the worktree; normalize.
case "$HOOKS_DIR" in
    /*) : ;;
    *)  HOOKS_DIR="$REPO/$HOOKS_DIR" ;;
esac

# The skill's hooks live next to this script (self-resolved, symlinks
# followed) — no hardcoded home anywhere (P061-S003).
SCRIPT="$BASH_SOURCE"
while [ -L "$SCRIPT" ]; do
    DIR=$(cd -P "$(dirname "$SCRIPT")" && pwd)
    NEXT=$(readlink "$SCRIPT")
    case "$NEXT" in
        /*) SCRIPT="$NEXT" ;;
        *)  SCRIPT="$DIR/$NEXT" ;;
    esac
done
SKILL_HOOKS=$(cd -P "$(dirname "$SCRIPT")/../hooks" && pwd)

mkdir -p "$HOOKS_DIR"

install_one() {
    local name="$1"
    local src="$SKILL_HOOKS/$name"
    local dst="$HOOKS_DIR/$name"

    if [ ! -f "$src" ]; then
        echo "skill hook missing: $src" >&2
        return 1
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        if [ "$FORCE" -eq 1 ]; then
            :
        elif [ "$MODE" = "wrapper" ] && grep -q 'go-style:wrapper-v1' "$dst" 2>/dev/null; then
            :   # idempotent wrapper refresh — overwrite silently (documented)
        elif [ "$MODE" = "symlink" ] && [ -L "$dst" ] \
          && [ "$(readlink "$dst" 2>/dev/null)" = "$src" ]; then
            :   # idempotent symlink — already points at this hook
        else
            echo "refusing to overwrite $dst (use --force)" >&2
            return 1
        fi
    fi

    case "$MODE" in
        wrapper)
            cat > "$dst" <<WRAPPER
#!/bin/bash
# go-style:wrapper-v1 — delegates to $SKILL_HOOKS/$name
# Regenerate via:  $0
set -e
SKILL_HOOK="$SKILL_HOOKS/$name"
if [ ! -x "\$SKILL_HOOK" ]; then
    echo "[go-style wrapper] WARN: skill hook missing at \$SKILL_HOOK — allowing commit" >&2
    exit 0
fi
exec "\$SKILL_HOOK" "\$@"
WRAPPER
            chmod +x "$dst"
            ;;
        copy)
            cp "$src" "$dst"
            chmod +x "$dst"
            ;;
        symlink)
            # Reached only with --force or an idempotent match above — the
            # replace is an explicit rm, never a silent -f overwrite.
            rm -f -- "$dst"
            ln -s "$src" "$dst"
            ;;
    esac

    echo "[install-hooks] $name -> $MODE ($dst)"
}

install_one pre-commit
install_one commit-msg

echo "[install-hooks] done. repo=$REPO mode=$MODE"
