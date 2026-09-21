#!/usr/bin/env bash
# go-style-lint.sh — portable, scope-aware entry point for the go-style checks.
#
# WHY THIS EXISTS (P059-S004). The go-style checks predate this script and are
# installed PER REPO by scripts/install-hooks.sh, so they carried no scope
# detection: whatever repo had the wrapper installed ran them. That works for a
# single target repo but cannot be invoked safely from anywhere, and it
# cannot cover a second target without installing into it.
#
# This script adds the missing layer WITHOUT touching hooks/pre-commit or
# hooks/commit-msg: those stay byte-identical, so every repo that already has
# the wrappers installed keeps its exact behaviour (anti-regression, P059-S004
# Required Outcome 5). After scope detection passes, this script DELEGATES to
# them — one implementation of the checks, never a second copy.
#
# SCOPE (opt-in — P061-S003):
#   Go has no equivalent of "declares fastapi/django as a direct dependency":
#   EVERY Go repo has a go.mod, so dependency presence carries no signal, and
#   hardcoded repository identity (P059-S004) was removed by the P061 freeze
#   (§17 Q4). Activation is EXPLICIT OPT-IN only:
#     - a `.mas-style` file at the repo root naming go-style, or
#     - an AGENTS.md policy line `style-lens: go-style` (outside fenced
#       blocks), or
#     - GO_STYLE_SCOPE=enable in the environment.
#   Every opt-in is GATED on a real Go signal (a tracked go.mod exists) — a
#   stray export in a non-Go repo still no-ops. A repo whose NAME resembles
#   an old target never activates by name.
#
# INVOCATION MODES (same contract as frr-style/fastapi-style/django-style — P059 §12):
#   (default):            range check — mechanical + banword over MERGE_BASE...HEAD
#   --staged:             staged files only (pre-commit path)
#   --commit-msg <file>:  commit message only (commit-msg path)
#
# EXIT CODES (P059 Design Req 3): 0 = pass · 1 = warn only · 2 = at least one fail.
# The delegated hooks predate that contract and exit 1 on FAIL, so this script
# MAPS a non-zero delegate exit to 2 (fail). Hooks keep their own exit codes.
#
# Debug the scope decision with GO_STYLE_DEBUG=1 (no-op is silent otherwise).

set -u

# SKILL_DIR resolves from this script's own location (symlinks followed), so
# the delegated hooks are found wherever the skill lives — no hardcoded home
# (P061-S003).
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

# --- parse flags ---
MODE_INVOCATION="range"
COMMIT_MSG_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --staged)
      MODE_INVOCATION="staged"
      shift
      ;;
    --commit-msg)
      # S002 Z1: `shift 2` with $# < 2 is a NO-OP in bash, so guard first.
      if [ $# -lt 2 ]; then
        echo "[SKIP] --commit-msg requires a file argument" >&2
        exit 0
      fi
      MODE_INVOCATION="commit-msg"
      COMMIT_MSG_FILE="$2"
      shift 2
      ;;
    *)
      echo "[SKIP] unknown arg '$1'"
      exit 0
      ;;
  esac
done

# --- counters / helpers ---
FAIL_COUNT=0
WARN_COUNT=0
PASS_COUNT=0
say_pass() { echo "[PASS] $*"; PASS_COUNT=$((PASS_COUNT+1)); }
say_warn() { echo "[WARN] $*"; WARN_COUNT=$((WARN_COUNT+1)); }
say_fail() { echo "[FAIL] $*"; FAIL_COUNT=$((FAIL_COUNT+1)); }
debug()    { [ "${GO_STYLE_DEBUG:-0}" = "1" ] && echo "[DEBUG] $*" || true; }

# S003 L9: every terminal path that counted a verdict prints the summary.
finish() {
  echo
  echo "----- go-style-lint summary (scope=$SCOPE mode=$MODE_INVOCATION) -----"
  echo "PASS: $PASS_COUNT  WARN: $WARN_COUNT  FAIL: $FAIL_COUNT"
  if [ "$FAIL_COUNT" -gt 0 ]; then exit 2; fi
  if [ "$WARN_COUNT" -gt 0 ]; then exit 1; fi
  exit 0
}

# S003 Y10/L10: a missing delegate must never block a commit — report and pass.
# zai P1-1 (S004): if a verdict was ALREADY counted when the delegate turns out
# to be missing, exiting 0 here would discard a real FAIL (false pass) and skip
# the summary. Route through finish() in that case; the callers also require
# their delegates BEFORE emitting any verdict.
require_delegate() {
  if [ ! -f "$1" ]; then
    echo "[SKIP] go-style delegate not found: $1"
    if [ $((FAIL_COUNT + WARN_COUNT + PASS_COUNT)) -gt 0 ]; then finish; fi
    exit 0
  fi
}

# --- scope detection (opt-in identity — P061-S003) ---
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  debug "not in a git repo"
  exit 0
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

# Go signal for the opt-in gate: the repo actually has a TRACKED go.mod.
# `git ls-files` instead of a depth-limited glob: Go modules nest arbitrarily
# and a depth-limited scan went silent in the past (P059-S003 finding G-mono).
# Tracked files only — no vendored or ignored trees.
GOMODS=$(git -C "$ROOT" ls-files '*go.mod' 2>/dev/null)
HAS_GOMOD=0
[ -n "$GOMODS" ] && HAS_GOMOD=1

OPT_IN=0
OPT_IN_EVIDENCE=""

# signal 1: `.mas-style` at the repo root names go-style (token-exact).
if [ -f "$ROOT/.mas-style" ] \
  && grep -qE '(^|[[:space:]])go-style([[:space:]]|$)' "$ROOT/.mas-style" 2>/dev/null; then
  OPT_IN=1
  OPT_IN_EVIDENCE=".mas-style"
  debug ".mas-style names go-style"
fi

# signal 2: AGENTS.md policy line `style-lens: go-style` (outside fenced
# blocks — documentation quoting the key is not policy, same doctrine as the
# portable selector; fences are detected with leading whitespace stripped,
# matching the selector's `stripped.startswith`).
if [ "$OPT_IN" -eq 0 ] && [ -f "$ROOT/AGENTS.md" ]; then
  IN_FENCE=0
  while IFS= read -r LINE; do
    LINE_TRIM="${LINE#"${LINE%%[![:space:]]*}"}"
    case "$LINE_TRIM" in
      '```'*) if [ "$IN_FENCE" -eq 0 ]; then IN_FENCE=1; else IN_FENCE=0; fi; continue ;;
    esac
    [ "$IN_FENCE" -eq 1 ] && continue
    if printf '%s' "$LINE" | grep -qiE '^[[:space:]]*style-lens[[:space:]]*:[[:space:]]*go-style([[:space:]]|$)'; then
      OPT_IN=1
      OPT_IN_EVIDENCE="AGENTS.md"
      debug "AGENTS.md policy names go-style"
      break
    fi
  done < "$ROOT/AGENTS.md"
fi

if [ "$OPT_IN" = "1" ] && [ "$HAS_GOMOD" = "1" ]; then
  SCOPE="baseline"   # go-style has no strict tier (P059 §17 Q1)
elif [ "${GO_STYLE_SCOPE:-}" = "enable" ] && [ "$HAS_GOMOD" = "1" ]; then
  SCOPE="baseline"   # documented env hatch, gated on a real Go signal
  debug "GO_STYLE_SCOPE=enable honored (tracked go.mod present)"
else
  debug "no go-style opt-in (or no tracked go.mod); no-op"
  exit 0
fi

echo "[INFO] go-style scope=$SCOPE mode=$MODE_INVOCATION branch=$BRANCH${OPT_IN_EVIDENCE:+ opt-in=$OPT_IN_EVIDENCE}"

# --- dispatch by invocation mode ---
case "$MODE_INVOCATION" in
  commit-msg)
    if [ -z "$COMMIT_MSG_FILE" ] || [ ! -f "$COMMIT_MSG_FILE" ]; then
      echo "[SKIP] --commit-msg requires a readable file path"
      exit 0
    fi
    # Conventional-commit + overclaim + length checks live in hooks/commit-msg.
    # Evidence for the convention is the opted-in repo's OWN history (no
    # third-party maintainer profile exists for Go): `git log --format=%s`
    # shows feat:/fix:/docs:/style:/test:/ci: subjects, which is exactly the
    # type set that hook already enforces.
    require_delegate "$SKILL_DIR/hooks/commit-msg"
    DELEGATE_OUT=$(bash "$SKILL_DIR/hooks/commit-msg" "$COMMIT_MSG_FILE" 2>&1)
    DELEGATE_RC=$?
    printf '%s\n' "$DELEGATE_OUT"
    if [ "$DELEGATE_RC" -ne 0 ]; then
      say_fail "commit message rejected by the go-style message rules (see above)"
    elif printf '%s' "$DELEGATE_OUT" | grep -q 'WARN:'; then
      # zai LOW-6/LOW-2 (S004): the hook prints advisory WARNs (e.g. TODO with
      # no issue ref) but exits 0; surfacing them here makes exit 1 reachable
      # instead of dead code, and hooks still map 1 -> 0 so nothing blocks.
      say_warn "commit message has advisory warnings (see above)"
    else
      say_pass "commit message satisfies the go-style message rules"
    fi
    ;;

  staged)
    # zai P1-3 (S004): `git diff` without -C emits paths relative to the CWD, so
    # invoking from a subdirectory silently mis-resolved every path (the whole
    # point of this script is being callable from anywhere). Root-relative here,
    # and the delegate runs FROM the root because it assumes cwd == repo root.
    STAGED_GO=$(git -C "$ROOT" diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep '\.go$' || true)
    if [ -z "$STAGED_GO" ]; then
      echo "[INFO] no staged Go files"
      exit 0
    fi
    require_delegate "$SKILL_DIR/hooks/pre-commit"
    DELEGATE_OUT=$(cd "$ROOT" && bash "$SKILL_DIR/hooks/pre-commit" 2>&1)
    DELEGATE_RC=$?
    printf '%s\n' "$DELEGATE_OUT"
    if [ "$DELEGATE_RC" -ne 0 ]; then
      say_fail "staged Go files rejected by mechanical/banword checks (see above)"
    elif printf '%s' "$DELEGATE_OUT" | grep -q 'WARN:'; then
      say_warn "staged Go files pass with advisory warnings (see above)"
    else
      say_pass "staged Go files pass mechanical + banword checks"
    fi
    ;;

  range)
    BASE_REF=""
    for CANDIDATE in upstream/main upstream/master origin/main origin/master; do
      if git rev-parse --verify "$CANDIDATE" >/dev/null 2>&1; then
        BASE_REF="$CANDIDATE"
        break
      fi
    done
    if [ -z "$BASE_REF" ]; then
      echo "[SKIP] no upstream/origin main|master ref found; cannot compute merge-base"
      exit 0
    fi
    MERGE_BASE=$(git merge-base HEAD "$BASE_REF" 2>/dev/null)
    if [ -z "$MERGE_BASE" ]; then
      say_fail "cannot compute merge-base with $BASE_REF"
      finish
    fi

    # Root-relative (zai P1-3) and delegate required BEFORE any verdict (P1-1).
    require_delegate "$SKILL_DIR/hooks/banword-scan.sh"
    RANGE_GO=$(git -C "$ROOT" diff --name-only --diff-filter=ACM "$MERGE_BASE"...HEAD 2>/dev/null | grep '\.go$' || true)
    if [ -z "$RANGE_GO" ]; then
      echo "[INFO] no Go files changed since $BASE_REF"
      exit 0
    fi

    # gofmt over the changed files that still exist in the worktree.
    EXISTING=""
    for f in $RANGE_GO; do [ -f "$ROOT/$f" ] && EXISTING="$EXISTING $ROOT/$f"; done
    if [ -z "$EXISTING" ]; then
      echo "[INFO] every changed Go file was deleted in the range; nothing to format-check"
    elif ! command -v gofmt >/dev/null 2>&1; then
      # zai P1-4 (S004): a missing binary is a SKIP, never a silent PASS.
      echo "[SKIP] gofmt not found in PATH; format check not run"
    else
      # shellcheck disable=SC2086
      UNFORMATTED=$(gofmt -l $EXISTING 2>/dev/null)
      GOFMT_RC=$?
      if [ "$GOFMT_RC" -ne 0 ]; then
        # zai P1-4: a parse error makes gofmt exit non-zero WITHOUT listing the
        # file — reading the empty list as "clean" was a false pass. The range
        # mode has no `go vet` behind it to catch the syntax error later.
        say_fail "gofmt could not parse the changed files (exit $GOFMT_RC) — syntax error in the range"
      elif [ -n "$UNFORMATTED" ]; then
        say_fail "gofmt pending on:"
        printf '%s\n' "$UNFORMATTED" | sed 's/^/    /'
      else
        say_pass "gofmt clean over the range"
      fi
    fi

    # Banword scan over the same file set (paths relative to the repo root, as
    # the scanner expects from the pre-commit path).
    if (cd "$ROOT" && bash "$SKILL_DIR/hooks/banword-scan.sh" "$RANGE_GO"); then
      say_pass "banword scan clean over the range"
    else
      say_fail "banword scan rejected the range (see above)"
    fi

    # zai LOW-3 (S004): name every check the range mode does NOT run, so the
    # weaker coverage is explicit rather than implied.
    echo "[INFO] range mode runs gofmt + banword only; goimports, go vet and golangci-lint are per-module and run by --staged (or run them directly for a full-module sweep)"
    ;;
esac

finish
