#!/bin/bash
# run-smokes.sh — end-to-end smoke tests for go-style skill hooks.
#
# Each smoke:
#   1. creates an isolated tmpdir with a minimal go module
#   2. installs the skill hooks (wrapper mode) into its .git/hooks
#   3. plants a violation matching a specific check layer
#   4. attempts a commit — expects exit != 0 AND the layer's diagnostic
#      in the output (P061-S003: cause-exact — the commit must fail on the
#      EXPECTED layer, not on any other)
#   5. cleans up
#
# Smokes:
#   A. banword-scan.sh           — credential pattern in Go source
#   B. pre-commit (errcheck)     — ignored error return (golangci-lint default set)
#   C. commit-msg                — overclaim ("perfect")
#   D. (opt) .golangci.yml       — nilnil (nil, nil) via project config
#   E. (opt) .golangci.yml       — errorlint %v-in-wrap via project config
#   F. banword negative control  — import path under .internal must NOT be flagged
#   G. .go-style-banwords        — repo-declared pattern must be flagged
#   H. banword hostname default  — FQDN under .internal in a string literal
#
# Smokes D and E require --config=PATH pointing at a .golangci.yml that
# enables revive/errorlint/nilnil (the opted-in repo's own config).
# Without --config, only A/B/C/F/G/H run.
#
# Exit 0 iff every smoke behaved as expected.

set -u

CONFIG=""
KEEP=0

for arg in "$@"; do
    case "$arg" in
        --config=*) CONFIG="${arg#--config=}" ;;
        --keep)     KEEP=1 ;;
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

# SKILL resolves from this script's own location (symlinks followed) — no
# hardcoded home (P061-S003).
SCRIPT="$BASH_SOURCE"
while [ -L "$SCRIPT" ]; do
    DIR=$(cd -P "$(dirname "$SCRIPT")" && pwd)
    NEXT=$(readlink "$SCRIPT")
    case "$NEXT" in
        /*) SCRIPT="$NEXT" ;;
        *)  SCRIPT="$DIR/$NEXT" ;;
    esac
done
SKILL=$(cd -P "$(dirname "$SCRIPT")/.." && pwd)
INSTALL="$SKILL/scripts/install-hooks.sh"

if [ ! -x "$INSTALL" ]; then
    echo "install-hooks.sh missing or not executable at $INSTALL" >&2
    exit 2
fi

PASS=0
FAIL=0
FAILED_SMOKES=()

run_smoke() {
    local name="$1"
    local setup="$2"
    local expect_exit_nonzero="$3"
    local expect_marker="${4:-}"

    local tmp
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/go-style-smoke.$name.XXXXXX")
    local smoke_log="$tmp/smoke.log"
    (
        set -e
        cd "$tmp"
        git init -q
        git config user.email smoke@example.invalid
        git config user.name "smoke"
        git config commit.gpgsign false
        "$INSTALL" --repo="$tmp" --force >/dev/null
        # Give the smoke access to $tmp and $CONFIG via env.
        CONFIG="$CONFIG" bash -c "$setup" >"$smoke_log" 2>&1
    )
    local smoke_rc=$?

    local verdict="PASS"
    if [ "$expect_exit_nonzero" -eq 1 ] && [ "$smoke_rc" -eq 0 ]; then
        verdict="FAIL"
    elif [ "$expect_exit_nonzero" -eq 0 ] && [ "$smoke_rc" -ne 0 ]; then
        verdict="FAIL"
    fi
    # Cause-exactness (P061-S003): a commit that fails for the WRONG reason
    # (marker absent) is a FAIL, same as one that does not fail at all.
    if [ "$verdict" = "PASS" ] && [ -n "$expect_marker" ] \
      && ! grep -qF "$expect_marker" "$smoke_log" 2>/dev/null; then
        verdict="FAIL"
    fi

    if [ "$verdict" = "PASS" ]; then
        PASS=$((PASS+1))
        echo "[smoke $name] PASS  (exit=$smoke_rc, expect-nonzero=$expect_exit_nonzero${expect_marker:+, marker='$expect_marker'})"
    else
        FAIL=$((FAIL+1))
        FAILED_SMOKES+=("$name")
        echo "[smoke $name] FAIL  (exit=$smoke_rc, expect-nonzero=$expect_exit_nonzero${expect_marker:+, marker='$expect_marker'})"
        echo "    tmpdir: $tmp"
        tail -10 "$smoke_log" 2>/dev/null | sed 's/^/    | /'
    fi

    if [ "$KEEP" -eq 0 ] && [ "$verdict" = "PASS" ]; then
        rm -rf "$tmp"
    fi
}

# ---- Smoke A: banword (credential) ----
run_smoke A '
cat > main.go <<EOF
package main

func main() {
    secret := "abc123_hardcoded_secret_xyz"
    _ = secret
}
EOF
# gofmt-normalize so the FAIL must come from banword, not mechanical checks.
gofmt -w main.go
git add main.go
git -c commit.gpgsign=false commit -q -m "feat(smoke): plant secret"
' 1 "BANWORD: credential leak"

# ---- Smoke B: errcheck (golangci default) ----
# Uses default golangci-lint if --config not given; if --config given, relies
# on that (default set also enables errcheck).
run_smoke B '
cat > go.mod <<EOF
module smoke
go 1.22
EOF
cat > main.go <<EOF
package main

import "os"

func main() {
    os.Remove("/tmp/nonexistent-smoke-path")
}
EOF
gofmt -w main.go
if [ -n "$CONFIG" ] && [ -f "$CONFIG" ]; then
    cp "$CONFIG" .golangci.yml
fi
git add go.mod main.go
git -c commit.gpgsign=false commit -q -m "feat(smoke): ignore os.Remove err"
' 1 "golangci-lint"

# ---- Smoke C: commit-msg overclaim ----
run_smoke C '
cat > README.md <<EOF
smoke
EOF
git add README.md
git -c commit.gpgsign=false commit -q -m "fix: perfect solution for everything"
' 1 "overclaiming in commit message"

# ---- Smoke D: nilnil (requires project .golangci.yml) ----
if [ -n "$CONFIG" ] && [ -f "$CONFIG" ]; then
    run_smoke D '
cat > go.mod <<EOF
module smoke
go 1.22
EOF
cat > main.go <<EOF
package main

// ProduceNilNil returns both nil and nil which nilnil should flag.
func ProduceNilNil() (*int, error) { return nil, nil }

func main() { _, _ = ProduceNilNil() }
EOF
gofmt -w main.go
cp "$CONFIG" .golangci.yml
git add go.mod main.go .golangci.yml
git -c commit.gpgsign=false commit -q -m "feat(smoke): plant nilnil"
' 1 "nilnil"
else
    echo "[smoke D] SKIP  (no --config)"
fi

# ---- Smoke E: errorlint %v-in-wrap (requires project .golangci.yml) ----
if [ -n "$CONFIG" ] && [ -f "$CONFIG" ]; then
    run_smoke E '
cat > go.mod <<EOF
module smoke
go 1.22
EOF
cat > main.go <<EOF
package main

import (
    "errors"
    "fmt"
)

// WrapBadly wraps err with %v which errorlint should flag.
func WrapBadly() error {
    e := errors.New("root")
    return fmt.Errorf("prefix: %v", e)
}

func main() { _ = WrapBadly() }
EOF
gofmt -w main.go
cp "$CONFIG" .golangci.yml
git add go.mod main.go .golangci.yml
git -c commit.gpgsign=false commit -q -m "feat(smoke): plant errorlint"
' 1 "errorlint"
else
    echo "[smoke E] SKIP  (no --config)"
fi

# ---- Smoke F: import path is NOT a banword hit (negative control) ----
# No go.mod on purpose: the hook skips go vet/golangci-lint (WARN) and the
# verdict must come from banword alone. The commit MUST succeed.
run_smoke F '
cat > main.go <<EOF
package main

import (
    "fmt"

    lib "example.internal/team/lib"
)

func main() { fmt.Println(lib.Name) }
EOF
gofmt -w main.go
git add main.go
git -c commit.gpgsign=false commit -q -m "feat(smoke): import path under .internal"
' 0 "[go-style] PASS"

# ---- Smoke G: repo-declared banword (.go-style-banwords) ----
run_smoke G '
printf "%s\n" "# org-specific" "@example-corp\\.com" > .go-style-banwords
cat > main.go <<EOF
package main

// contact: dev@example-corp.com
func main() {}
EOF
gofmt -w main.go
git add .go-style-banwords main.go
git -c commit.gpgsign=false commit -q -m "feat(smoke): plant repo banword"
' 1 "repo banword matched"

# ---- Smoke H: default hostname rule (FQDN under .internal in a literal) ----
run_smoke H '
cat > main.go <<EOF
package main

const endpoint = "https://api.example.internal/v1"

func main() { _ = endpoint }
EOF
gofmt -w main.go
git add main.go
git -c commit.gpgsign=false commit -q -m "feat(smoke): plant internal hostname"
' 1 "internal hostname leaked"

echo "-----"
echo "smoke summary: $PASS passed, $FAIL failed"
if [ "$FAIL" -eq 0 ]; then
    exit 0
else
    echo "failed: ${FAILED_SMOKES[*]}"
    exit 1
fi
