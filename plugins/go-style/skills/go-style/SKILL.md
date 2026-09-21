---
name: go-style
description: Go coding-style checks (mechanical + banword + NAK lens + gRPC lens) activated by explicit opt-in (.mas-style file, AGENTS.md policy, or GO_STYLE_SCOPE=enable) in any Go repo. Baseline-only — no strict scope. Invoke manually, via checks/go-style-lint.sh (3 modes, scope-aware, silent no-op without opt-in), via pre-commit/commit-msg hooks, or before git push.
allowed-tools: Bash(bash:*), Bash(git:*), Read, Grep, Glob, Agent
---

# go-style

Go style enforcement for any Go repository that **opts in** — mechanical
checks (gofmt/goimports/go vet/golangci-lint), a banword scan, and a NAK lens.
Runs on every commit via local git hooks in a repo that installed them, and on
demand from anywhere through the scope-aware lint. No dual scope — an opted-in
repo gets the same checks on every branch.

## Why opt-in, not detection

Every Go repo has a `go.mod`, so "declares Go" carries no signal — activation
cannot be dependency-based like `fastapi-style` / `django-style`. Early
versions matched repositories by hardcoded identity (remote URL / module path
naming specific repos), which (a) hardcoded repository names into the
mechanism and (b) could compile-check someone else's similarly-named code in
`--staged` mode. P061 removed name-based identity: activation is now explicit
opt-in only, gated on the repo actually being Go.

## Scope detection (`checks/go-style-lint.sh` — P061-S003)

| Scope | Triggered when | Behaviour |
|---|---|---|
| **baseline** | a tracked `go.mod` exists AND any opt-in signal: `.mas-style` at the repo root names `go-style`, an `AGENTS.md` policy line `style-lens: go-style` (outside fenced blocks), or `GO_STYLE_SCOPE=enable` is exported | full checks |
| **no-op** | no opt-in, or no tracked `go.mod` | silent exit 0 |

`go.mod` discovery uses `git ls-files '*go.mod'`, so a module nested at any
depth is found. A stray export in a **non-Go** repo still no-ops, and a repo
whose name merely resembles an old target never activates by name. Use
`GO_STYLE_DEBUG=1` to see why a run no-op'd.

Opting a repo in means adding a `.mas-style` file with `go-style` (or a
`style-lens: go-style` policy line in AGENTS.md) — no lint edits are needed,
and no repository name is ever hardcoded in the mechanism. The `.mas-style`
format is one lens name per line (the selector reads it the same way).

## Portable invocation (3 modes, exit 0/1/2)

Exit codes: `0` pass · `1` warn only · `2` at least one fail. The `1` tier is
genuinely reachable — advisory WARNs that the delegated hooks print while
exiting 0 (a `TODO` with no issue ref, "no go.mod found for staged files") are
surfaced by the lint as WARN. The hook wrappers collapse `1 -> 0`, so a WARN
still never blocks a commit.

```bash
bash <skill-dir>/checks/go-style-lint.sh              # range: gofmt + banword over merge-base...HEAD
bash <skill-dir>/checks/go-style-lint.sh --staged     # staged files: mechanical + banword (delegates to hooks/pre-commit)
bash <skill-dir>/checks/go-style-lint.sh --commit-msg .git/COMMIT_EDITMSG
```

The lint **delegates** to `hooks/pre-commit`, `hooks/commit-msg` and
`hooks/banword-scan.sh` rather than reimplementing them, so there is exactly
one copy of each check. Those hooks are unchanged by the lint's existence: a
repo with the wrappers already installed behaves exactly as before. The hooks
predate the P059 exit contract and exit `1` on FAIL; the lint maps any non-zero
delegate exit to `2`.

Commit-message evidence is the opted-in repo's **own history**
(`git log --format=%s` → `feat:` / `fix:` / `docs:` / `style:` / `test:` /
`ci:`), which is exactly the type set `hooks/commit-msg` already enforces —
there is no third-party maintainer profile for Go, unlike the fastapi/django
skills.

## Toolchain (pinned)

| Tool | Version | Install | Why |
|---|---|---|---|
| gofmt | built-in Go | `go` distribution | Fast gate, zero config |
| goimports | latest | `go install golang.org/x/tools/cmd/goimports@latest` | Superset of gofmt + import management |
| golangci-lint | v2.11.4 | binary installer pinned | Covers errcheck, govet, staticcheck, ineffassign, unused via default set |

## Invocation modes

| Flag | Use | Scope |
|---|---|---|
| _(default)_ | SKILL invocation / manual `/go-style` | full diff since merge-base |
| `--staged` | pre-commit hook | staged files only |
| `--commit-msg <file>` | commit-msg hook | message file only |

## When to invoke

- Automatically on every `git commit` in an opted-in repo via pre-commit + commit-msg hooks
- Manually via `/go-style` when you want a second opinion on a pending diff
- Before `git push` to `origin` (feature branches)

## Workflow

### 1. Detect Go files

```bash
GO_FILES=$(git diff --name-only --diff-filter=ACM "$MERGE_BASE"...HEAD | grep '\.go$' || true)
[[ -z "$GO_FILES" ]] && exit 0
```

### 2. Run mechanical checks

```bash
gofmt -l $GO_FILES
goimports -l $GO_FILES
go vet ./...
golangci-lint run --new-from-rev="$MERGE_BASE" ./...
```

Any non-zero exit → FAIL.

### 3. Run banword scan

Shell out to rules file:

```bash
bash <skill-dir>/hooks/banword-scan.sh "$GO_FILES"
```

The scanner ships only generic patterns (credentials, private-use TLDs in
string literals, AI markers). Organisation-specific domains or e-mail
suffixes go in a `.go-style-banwords` file at the opted-in repo's root (one
extended regex per line) or in the file named by `GO_STYLE_BANWORDS_FILE`.
Import paths are exempt from the string-literal checks.

### 4. Run NAK lens

Read `rules/nak.md`, apply each rule against the diff. Report PASS/WARN/FAIL per rule.

### 4b. Run gRPC lens (when applicable)

If any tracked `go.mod` in the diff's module requires `google.golang.org/grpc`,
also read `rules/grpc.md` and apply it to the changed files: client
construction, deadlines, keepalive/lease separation, error-class mapping,
ambiguous-mutation handling, backpressure, interceptors, proto hygiene, tests.

### 5. Emit report

Markdown format, grouped by severity:

```markdown
## go-style report: feature/poc-frrfe-bgpdlite

### Mechanical checks
- PASS: gofmt clean
- PASS: goimports clean
- PASS: go vet clean
- PASS: golangci-lint default set clean

### Banword scan
- PASS: no credential leakage
- PASS: no AI markers in code
- PASS: no internal hostnames leaked

### NAK lens
- PASS: godoc on exports
- WARN: `internal/bgpdlite/config.go:42` — ctx not first arg in I/O function `DialBackend`
```

### 6. Decision

- Any FAIL → overall FAIL. Fix and re-commit.
- Only WARN/PASS → overall PASS-with-warnings. Proceed but consider fixing WARNs.
- All PASS → overall PASS.

Exit code (skill-level report):
- 0 if PASS (with or without WARN)
- 2 if any FAIL

`checks/go-style-lint.sh` is finer-grained: it reports WARN as exit `1` (see
"Portable invocation" above), and the hook wrappers collapse `1 -> 0`.

## Files in this skill

- `SKILL.md` (this file) — instructions
- `checks/go-style-lint.sh` — scope-aware portable entry point, 3 modes, exit 0/1/2 (delegates to the hooks below)
- `rules/banword.md` — banword list with regex patterns
- `rules/nak.md` — NAK idioms checklist for Go (enforced vs advisory)
- `rules/grpc.md` — gRPC lens: transport-shape rules for modules that require `google.golang.org/grpc`
- `rules/grpc-references.md` — precedents (gRIBI, gNMI, I2RS RFCs, vendor route APIs, papers) behind each gRPC rule, plus rejected claims
- `hooks/pre-commit` — mechanical + banword inline; delegated to by repo wrapper
- `hooks/commit-msg` — overclaiming + conventional commit scan
- `hooks/banword-scan.sh` — grep-based scanner invoked by pre-commit
- `scripts/install-hooks.sh` — installs wrappers / copies / symlinks into a repo
- `tests/run-smokes.sh` — end-to-end regression harness (5 smokes A-E)

## Repo-side config

The skill does not ship a `.golangci.yml`. Each opted-in repo keeps its own
file alongside `go.mod`, enabling the NAK-aligned linters (`errorlint`,
`revive`, `nilnil`, `gocritic`) on top of the default set. Rules flagged
**[enforced]** in `rules/nak.md` correspond to checks active in that config.
Rules flagged **[advisory]** remain reviewer judgement.

## Installing hooks into a repo

```bash
<skill-dir>/scripts/install-hooks.sh              # current repo, wrapper mode
<skill-dir>/scripts/install-hooks.sh --mode=copy  # or symlink
```

Wrappers (default) call the skill hook via `exec`, so edits to the skill
propagate immediately. Copy mode is frozen until re-installed. An existing
hook is never overwritten silently: the installer refuses unless `--force` is
passed (wrapper mode refreshes its own marked wrapper silently).

## Running the smoke harness

```bash
<skill-dir>/tests/run-smokes.sh                        # A/B/C only
<skill-dir>/tests/run-smokes.sh --config=/path/to/.golangci.yml  # + D/E
```

Each smoke isolates a tmpdir, installs the wrapper hooks, plants one violation,
and asserts the commit fails on the expected layer — the layer's own
diagnostic must appear in the output (cause-exact, not just a non-zero exit).

## Do not

- Do not skip checks on any branch. All branches get the same bar.
- Do not block on WARN — only FAIL blocks.
- Do not amend the user's commit automatically. Report only.
- Do not assume tools are in PATH. Check `$(go env GOPATH)/bin` and `/usr/local/go/bin`.
