#!/usr/bin/env bash
# sync-from-source.sh <skills-dir> — copy go-style and frr-style from an
# upstream skills directory into plugins/*/skills/, then run the publication
# gate: the tree must contain no private hostnames, e-mails, home paths or
# organisation names. Exit 1 if the gate fails (nothing is committed here).
set -euo pipefail

SRC="${1:?usage: sync-from-source.sh <skills-dir>}"
HERE=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

for name in go-style frr-style; do
    [ -d "$SRC/$name" ] || { echo "missing $SRC/$name" >&2; exit 2; }
    dst="$HERE/plugins/$name/skills/$name"
    mkdir -p "$dst"
    rsync -a --delete --exclude '.DS_Store' "$SRC/$name/" "$dst/"
    echo "[sync] $name <- $SRC/$name"
done

# Publication gate. Extend GATE_PATTERNS via env if needed.
GATE="${GATE_PATTERNS:-[a-z0-9.-]+\.(internal|corp|intranet|lan)\b|@[a-z0-9-]+\.(com|com\.br|cloud)\b|/Users/[a-z]+|/home/[a-z]+|~/src/}"
if grep -rnEi "$GATE" "$HERE/plugins" --exclude-dir=.git \
    | grep -vE 'example\.internal|example-corp|banword-scan\.sh|grpc\.md|banword\.md|run-smokes\.sh'; then
    echo "[gate] FAIL: private identifiers found above" >&2
    exit 1
fi
echo "[gate] PASS: no private identifiers in plugins/"
