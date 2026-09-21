---
name: frr-style
description: FRR coding-style checks for any local fork of FRRouting/frr. Two scopes auto-detected — strict (upstream-submit branch) runs full mechanical checks (single-commit warn, subsystem scope, DOC-block size); baseline (any other branch in the fork) runs mechanical style only so internal fork development stays disciplined without the upstream-only constraints. Invoke on demand, via pre-commit / commit-msg hooks, or before git push.
allowed-tools: Bash(bash:*), Bash(git:*), Read, Grep, Glob, Agent, mcp__context7, WebFetch
---

# frr-style

FRR style enforcement for the local fork. Applies at two levels: **strict** when a PR is about to leave your machine for the upstream maintainers, and **baseline** for the 99% of the time you are just committing code inside your fork.

Concealment rules were REMOVED in P061-S003 (design contract §17 Q4): the
skill no longer carries identity-safety/voice rules that hide authorship,
tooling or methodology — no banword scan for AI markers, no `voice.md`. The
lint is mechanical style only.

## Scopes (auto-detected)

| Scope | Triggered when | Checks active |
|---|---|---|
| **strict** | remote `upstream` → `FRRouting/frr` AND branch matches `^upstream-submit[-/]` | mechanical + single-commit warn + subsystem-scope FAIL + DOC-block size warn + NAK-profile lens |
| **baseline** | remote `upstream` → `FRRouting/frr` AND any other branch | mechanical only: `subsystem:` subject format, subject ≤72, Signed-off-by, blank line after subject, tabs-not-spaces in added .c/.h, no trailing whitespace |
| **no-op** | repo has no `upstream` → FRRouting/frr | silent exit 0 |

**Why baseline exists:** your local fork is where all FRR-style code lives, even code that is not destined for upstream. FRR indent, commit format, and Signed-off-by matter regardless of merge destination. But over-doc warn and "single-commit" discipline only make sense when the PR is about to be seen by a maintainer — so baseline skips those and lets internal work (WIP multi-commit branches, experimental DOC blocks) land without friction.

## Invocation modes

The lint script accepts three modes for three integration points:

| Flag | Use | Scope of check |
|---|---|---|
| _(default)_ | SKILL invocation / manual `/frr-style` | full range: all commits in `merge-base..HEAD` + full diff |
| `--staged` | pre-commit git hook | staged diff only; commit-msg checks skipped (msg not written yet) |
| `--commit-msg <file>` | commit-msg git hook | the message being composed; diff checks skipped |

All three modes obey the scope (strict/baseline) auto-detection.

## When to invoke

- Before `git push origin upstream-submit/...` — **required** (also auto-blocked by the PreToolUse hook).
- Before amending an existing upstream PR after a reviewer comment.
- Automatically on every `git commit` in the fork once the pre-commit and commit-msg hooks are installed (see *Installing local hooks* below).
- Manually via `/frr-style` when you want a second opinion on a pending diff.

Silently no-op if the repo has no `upstream` remote pointing to FRRouting/frr.

## Workflow

### 1. Detect scope

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if ! echo "$BRANCH" | grep -qE '^upstream-submit[-/]'; then
  echo "frr-style: branch '$BRANCH' is not an upstream-submit branch — no-op"
  exit 0
fi
```

### 2. Collect diff material

```bash
git fetch origin master --quiet 2>/dev/null || git fetch upstream master --quiet
MERGE_BASE=$(git merge-base HEAD origin/master 2>/dev/null || git merge-base HEAD upstream/master)
git diff "$MERGE_BASE"...HEAD
git log "$MERGE_BASE"..HEAD --format='%H%n%B%n---COMMIT-END---'
git diff --name-only "$MERGE_BASE"...HEAD
```

### 3. Run mechanical checks

Shell out to:

```bash
bash <skill-dir>/checks/frr-style-lint.sh
```

Capture exit code (0 = pass, 1 = warn only, 2 = fail) and full stdout.

### 4. Load maintainer profiles

Read every `*.md` under this skill's `profiles/` directory. For each profile, extract the rule list. Apply each rule against the diff and commit messages.

### 5. Load official FRR dev guide (optional, best-effort)

Prefer Context7 MCP (up-to-date, no auth):

```
mcp__context7__resolve-library-id("FRRouting")
mcp__context7__get-library-docs(id, topic="developer/workflow")
mcp__context7__get-library-docs(id, topic="developer/code-style")
```

Fallback: `WebFetch https://docs.frrouting.org/projects/dev-guide/en/latest/workflow.html`.

Pull rules like: `Signed-off-by` required, `subsystem: summary` commit format, 72-char commit subject, no tabs in new code (spaces only for indentation unless file already uses tabs), no trailing whitespace.

### 6. Emit report

Markdown format, grouped by severity. Example:

```markdown
## frr-style report: upstream-submit/ub-7-edit-reply-kind

### Mechanical checks
- PASS: single commit on branch
- PASS: commit subject matches `subsystem: summary` (lib: mgmt_msg_native: ...)
- PASS: Signed-off-by present
- FAIL: commit subject is 78 chars (FRR limit 72)

### Profile lens — donaldsharp
- WARN: DOC block in `lib/mgmt_msg_native.h` is 52 lines; `profiles/donaldsharp.md` cites #21557 NAK at 60+ lines ("stupidly over the top"). Consider reducing to ≤30 lines or splitting rationale to commit message.
- PASS: single subsystem (`lib/`)
- PASS: no duplicate PR signal

### Profile lens — choppsv1
- WARN: inline comment at `lib/libfrr.h:143` explains `listen()` semantics; `profiles/choppsv1.md` cites #21514 where they requested removal of re-documentation of stdlib calls.

### FRR dev guide
- PASS: Signed-off-by format correct
- FAIL: commit subject exceeds 72 chars
```

### 7. Decision

- Any `FAIL` → overall FAIL, return to the user with the report and refuse to recommend `git push`.
- Only `WARN` / `PASS` → overall PASS-with-warnings, user can proceed but should consider the warnings.
- All `PASS` → overall PASS.

Exit code for the skill invocation:
- 0 if overall PASS with no WARN
- 1 if WARN-only (lint tier, surfaced for scripts; hooks map 1 -> 0)
- 2 if any FAIL

## Installing local hooks (fork dev workflow)

For everyday work in the fork (not just upstream submissions), wire the
lint into git's own hook system. This gives early feedback on every commit
without any extra ceremony. The wrappers resolve the lint relative to
themselves (symlinks followed), so the skill can live in any host directory —
symlink mode is the supported install; a copied wrapper cannot find the lint
and fails open by design (the missing-lint guard), so copying is NOT
supported:

```bash
SKILL_HOOKS="<this-skill-dir>/hooks"     # wherever this skill lives on the host
mkdir -p .git/hooks
for hook in pre-commit commit-msg; do
    dst=".git/hooks/$hook"
    # Never overwrite silently: an existing hook is refused unless --force
    # is passed, and even then the replace is an explicit rm first.
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        [ "$1" = "--force" ] || { echo "refusing to overwrite $dst (use --force)" >&2; exit 1; }
        rm -- "$dst"
    fi
    ln -s "$SKILL_HOOKS/$hook" "$dst"
done
```

The wrappers in `hooks/` call `frr-style-lint.sh --staged` (pre-commit) and
`--commit-msg "$1"` (commit-msg) respectively, mapping WARN (1) to 0 so only
a FAIL blocks. They are safe on non-FRR repos (no-op via scope detection) and
keep baseline discipline automatic in the fork.

## Files in this skill

- `SKILL.md` (this file) — instructions
- `profiles/*.md` — one per maintainer; generated by the `frr-maintainer-profiler` agent
- `checks/frr-style-lint.sh` — mechanical + strict checks, dual-mode, deterministic, exit 0/1/2
- `hooks/pre-commit`, `hooks/commit-msg` — thin wrappers installed as symlinks into the fork's `.git/hooks/`

## Regenerating profiles

When a maintainer's review style appears to have shifted, or to add a new maintainer:

```
Agent({ subagent_type: "frr-maintainer-profiler", prompt: "maintainer_login: <login>" })
```

The agent overwrites `profiles/<login>.md` with a fresh sample.

## Do not

- Do not run lint on non-upstream-submit branches. Silent no-op.
- Do not block on a `WARN` — only `FAIL` blocks.
- Do not amend the user's commit automatically. Report only; user decides.
- Do not assume the dev guide is cached; fetch fresh via Context7 or WebFetch each run unless a local `./doc/developer/` exists in the current working directory.
