#!/bin/bash
# Banword scanner for Go files. Exits 1 if any pattern matches.
set -euo pipefail

GO_FILES="$1"

# RULES resolves relative to this script (symlinks followed) — the skill can
# live in any host directory (P061-S003, no hardcoded home).
SCRIPT="$BASH_SOURCE"
while [ -L "$SCRIPT" ]; do
    DIR=$(cd -P "$(dirname "$SCRIPT")" && pwd)
    NEXT=$(readlink "$SCRIPT")
    case "$NEXT" in
        /*) SCRIPT="$NEXT" ;;
        *)  SCRIPT="$DIR/$NEXT" ;;
    esac
done
SKILL_DIR=$(cd -P "$(dirname "$SCRIPT")/.." && pwd)
RULES="$SKILL_DIR/rules/banword.md"

# Import specs are not string literals in the banword sense: a module path
# such as "git.example.internal/team/mod" is the code's own identity, not a
# leak. Lines consisting solely of an (optionally aliased) import path are
# excluded from every string-literal check.
IMPORT_LINE=':[0-9]+:[[:space:]]*(import[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*[[:space:]]+)?"[^"]+"[[:space:]]*$'

check() {
    local pattern="$1"
    local msg="$2"
    local hits
    # shellcheck disable=SC2086
    # -H forces the file: prefix even for a single file so IMPORT_LINE anchors.
    hits=$(grep -nHEi "$pattern" $GO_FILES 2>/dev/null | grep -vE "$IMPORT_LINE" || true)
    if [ -n "$hits" ]; then
        echo "BANWORD: $msg"
        printf '%s\n' "$hits"
        return 1
    fi
    return 0
}

ERR=0

check '(password|passwd|secret|token|api_key)\s*(:=|=)\s*"[^"]+"' \
    "credential leak in code" || ERR=1

# Hostname leak: FQDNs under private-use TLDs inside string literals. Anchored
# to a quoted literal so Go qualified identifiers (internal.Config) never
# match. Organisation-specific domains and e-mail suffixes are NOT hardcoded
# here: declare them in the repo's own .go-style-banwords file (below).
check '"[^"]*\b[a-z0-9-]+(\.[a-z0-9-]+)*\.(internal|corp|intranet|lan)\b[^"]*"' \
    "internal hostname leaked in string literal" || ERR=1

check '🤖|Generated with Claude' \
    "AI marker in code" || ERR=1

# Repo-specific banwords: one extended regex per line, '#' comments allowed.
# Read from the repo root, or from GO_STYLE_BANWORDS_FILE when exported.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
BANWORDS_FILE="${GO_STYLE_BANWORDS_FILE:-$ROOT/.go-style-banwords}"
if [ -f "$BANWORDS_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in ''|'#'*) continue ;; esac
        check "$line" "repo banword matched: $line" || ERR=1
    done < "$BANWORDS_FILE"
fi

exit $ERR
