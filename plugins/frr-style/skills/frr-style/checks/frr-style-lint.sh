#!/usr/bin/env bash
# frr-style-lint.sh — FRR coding-style checks for the local fork.
#
# SCOPE (auto-detected by repo + branch):
#   strict    — upstream remote → FRRouting/frr AND branch matches ^upstream-submit[-/]
#               Full: mechanical checks + over-doc + commit-count warn
#   baseline  — upstream remote → FRRouting/frr AND any other branch
#               Mechanical only: msg hygiene, indent, trailing whitespace, SOB.
#               No DOC-block-size warn, no single-commit warn.
#   no-op     — not an FRR fork
#
# Concealment rules were REMOVED in P061-S003 (design contract §17 Q4): the
# lint no longer scans for AI/automation markers — identity-safety rules that
# hide authorship/tooling are not preserved by this workstream.
#
# INVOCATION MODES:
#   (default):              range check — diff MERGE_BASE..HEAD + all commits on branch
#   --staged:               staged diff only (for pre-commit hook); no commit-msg check
#   --commit-msg <file>:    commit message only (for commit-msg hook); no diff check
#
# Exit codes: 0 = pass · 1 = warn only · 2 = at least one fail (P059 Design
# Req 3 — reconciled with the SKILL.md contract in P061-S003).

set -u

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
      # P061-S003 fail-closed: `shift 2` with $# < 2 is a NO-OP in bash (the
      # loop used to spin forever — same trap documented on the sibling
      # lints). A commit-msg hook that cannot read its message must FAIL, not
      # skip.
      if [ $# -lt 2 ]; then
        echo "[FAIL] --commit-msg requires a file argument" >&2
        exit 2
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

# --- scope detection ---
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "[SKIP] not in a git repo"
  exit 0
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# Is this an FRR fork? upstream remote must point to FRRouting/frr.
UPSTREAM_URL=$(git remote get-url upstream 2>/dev/null || echo "")
if ! echo "$UPSTREAM_URL" | grep -qEi 'github\.com[:/]FRRouting/frr(\.git)?$'; then
  echo "[SKIP] no 'upstream' remote pointing to FRRouting/frr; not an FRR fork"
  exit 0
fi

# Strict vs baseline
if echo "$BRANCH" | grep -qE '^upstream-submit[-/]'; then
  SCOPE="strict"
else
  SCOPE="baseline"
fi

echo "[INFO] frr-style scope=$SCOPE mode=$MODE_INVOCATION branch=$BRANCH"

# --- commit-message check (applies to a single commit's full message) ---
check_commit_msg_body() {
  local body="$1"
  local short="$2"
  local subject
  subject=$(echo "$body" | head -1)
  local len=${#subject}

  if echo "$subject" | grep -qE '^[a-z][a-z0-9_,.-]*(: [a-z][a-z0-9_,.-]*)*: .+'; then
    say_pass "$short subject starts with 'subsystem: ' prefix"
  else
    say_fail "$short subject does not match 'subsystem: summary' format: '$subject'"
  fi

  if [ "$len" -le 72 ]; then
    say_pass "$short subject is $len chars (<=72)"
  else
    say_fail "$short subject is $len chars; FRR convention is <=72"
  fi

  if echo "$body" | grep -qE '^Signed-off-by: .+ <.+@.+>$'; then
    say_pass "$short has Signed-off-by trailer"
  else
    say_fail "$short is missing a 'Signed-off-by: Name <email>' trailer"
  fi

  local second
  second=$(echo "$body" | sed -n '2p')
  local line_count
  line_count=$(echo "$body" | wc -l | tr -d ' ')
  if [ "$line_count" -gt 1 ] && [ -n "$second" ]; then
    say_fail "$short missing blank line between subject and body"
  else
    say_pass "$short subject/body separator ok"
  fi
}

# --- diff checks (applies to any diff text) ---
check_diff() {
  local diff="$1"

  # Trailing whitespace on added lines
  if echo "$diff" | grep -qE '^\+.*[ 	]$'; then
    say_fail "added lines contain trailing whitespace"
  else
    say_pass "no trailing whitespace in added lines"
  fi

  # Indent-with-spaces (not tabs) in added .c/.h lines.
  # FRR uses tabs for actual indentation; spaces are only for in-line alignment
  # after a tab. Rule: any added line starting with 4+ spaces at column 1,
  # followed by a non-space non-asterisk char (to skip ` * doxygen` continuations).
  local C_DIFF
  C_DIFF=$(echo "$diff" | awk '
    /^diff --git / { inside = ($0 ~ /\.(c|h)( |$)/) ? 1 : 0; print; next }
    inside { print }
  ')
  local SPACE_INDENT_HITS
  SPACE_INDENT_HITS=$(echo "$C_DIFF" | grep -E '^\+    [^ *]' | grep -vE '^\+\+\+ ' | head -3)
  if [ -n "$SPACE_INDENT_HITS" ]; then
    say_fail "added C/H lines use space indentation instead of tabs:"
    echo "$SPACE_INDENT_HITS" | sed 's/^/    /'
  else
    say_pass "added C/H indent uses tabs (or no C/H changes)"
  fi

  if [ "$SCOPE" = "strict" ]; then
    # Over-doc warn
    local DOC_LINES
    DOC_LINES=$(echo "$diff" | awk '/^\+\/\*\*/{inblock=1} inblock && /^\+/{count++} /^\+ \*\//{inblock=0} END{print count+0}')
    if [ "$DOC_LINES" -gt 40 ]; then
      say_warn "added C doc blocks total $DOC_LINES lines; maintainers (donaldsharp #21557) NAK over-documentation around 60+ lines"
    elif [ "$DOC_LINES" -gt 0 ]; then
      say_pass "added C doc blocks: $DOC_LINES lines"
    else
      say_pass "no new C doc blocks added"
    fi
  fi
}

# --- dispatch by invocation mode ---
case "$MODE_INVOCATION" in
  commit-msg)
    # P061-S003 fail-closed: a commit-msg hook that cannot READ its message
    # must FAIL, never silently skip (the message gate is the point of the
    # hook). `-r` and not `-f`: an existing-but-unreadable file (chmod 000)
    # used to slip into the empty [SKIP] below (review P2-2).
    if [ -z "$COMMIT_MSG_FILE" ] || [ ! -r "$COMMIT_MSG_FILE" ]; then
      echo "[FAIL] --commit-msg requires a readable file path: ${COMMIT_MSG_FILE:-<missing>}" >&2
      exit 2
    fi
    # Strip git's instructional '#' comment lines
    MSG=$(grep -v '^#' "$COMMIT_MSG_FILE")
    if [ -z "$MSG" ]; then
      echo "[SKIP] empty commit message (aborted edit?)"
      exit 0
    fi
    check_commit_msg_body "$MSG" "pending"
    ;;

  staged)
    DIFF=$(git diff --cached 2>/dev/null || echo "")
    if [ -z "$DIFF" ]; then
      echo "[INFO] no staged changes"
      exit 0
    fi
    check_diff "$DIFF"
    ;;

  range)
    # Determine base. Prefer upstream/master (authoritative for FRR).
    if git rev-parse --verify upstream/master >/dev/null 2>&1; then
      BASE_REF="upstream/master"
    elif git rev-parse --verify origin/master >/dev/null 2>&1; then
      BASE_REF="origin/master"
    else
      echo "[SKIP] no upstream/master or origin/master ref found; cannot compute merge-base"
      exit 0
    fi

    MERGE_BASE=$(git merge-base HEAD "$BASE_REF" 2>/dev/null)
    if [ -z "$MERGE_BASE" ]; then
      say_fail "cannot compute merge-base with $BASE_REF"
      exit 2
    fi

    COMMIT_COUNT=$(git rev-list --count "$MERGE_BASE"..HEAD)
    if [ "$SCOPE" = "strict" ]; then
      if [ "$COMMIT_COUNT" -eq 0 ]; then
        say_warn "no commits ahead of $BASE_REF"
      elif [ "$COMMIT_COUNT" -eq 1 ]; then
        say_pass "single commit on branch"
      else
        say_warn "$COMMIT_COUNT commits on branch; FRR maintainers prefer a single cirurgical commit per upstream submission"
      fi
    fi

    # Per-commit message checks
    for SHA in $(git rev-list "$MERGE_BASE"..HEAD); do
      BODY=$(git log -1 --format=%B "$SHA")
      SHORT=$(git log -1 --format='%h' "$SHA")
      check_commit_msg_body "$BODY" "$SHORT"
    done

    # Subsystem scope — strict FAILs above 2, baseline informational
    TOUCHED=$(git diff --name-only "$MERGE_BASE"...HEAD | awk -F/ '{print $1}' | sort -u | grep -v '^$' || true)
    SUBSYS_COUNT=$(echo "$TOUCHED" | grep -c . 2>/dev/null || echo 0)
    if [ "$SUBSYS_COUNT" -le 1 ]; then
      say_pass "diff stays within a single top-level directory"
    elif [ "$SCOPE" = "strict" ]; then
      if [ "$SUBSYS_COUNT" -le 2 ]; then
        say_warn "diff crosses $SUBSYS_COUNT top-level dirs; reviewer may request split"
      else
        say_fail "diff crosses $SUBSYS_COUNT top-level dirs; likely needs to be split into separate PRs"
      fi
    else
      say_pass "diff crosses $SUBSYS_COUNT top-level dirs (baseline mode; not gated)"
    fi

    DIFF=$(git diff "$MERGE_BASE"...HEAD)
    check_diff "$DIFF"
    ;;
esac

echo
echo "----- frr-style-lint summary (scope=$SCOPE mode=$MODE_INVOCATION) -----"
echo "PASS: $PASS_COUNT  WARN: $WARN_COUNT  FAIL: $FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 2
fi
if [ "$WARN_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
