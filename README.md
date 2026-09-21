# go-skills

Claude Code skills that hold Go and FRRouting code to a mechanical, evidence-driven
style bar. Each skill is a scope-aware lint plus a review lens: it runs as a
`/skill`, as git `pre-commit` / `commit-msg` hooks, or from any directory as a
portable script that silently no-ops outside its target repositories.

| Skill | Target | What it checks |
|---|---|---|
| `go-style` | Any Go repo that opts in | gofmt, goimports, `go vet`, `golangci-lint` (default set + the repo's own `.golangci.yml`), banword scan, NAK idioms (`rules/nak.md`), gRPC lens (`rules/grpc.md`) with its precedent ledger (`rules/grpc-references.md`: gRIBI, gNMI, I2RS RFCs, vendor route APIs, papers), conventional-commit subject rules |
| `frr-style` | Local forks of `FRRouting/frr` | `subsystem: summary` subject, 72-col limit, `Signed-off-by`, tabs in `.c/.h`, trailing whitespace; strict mode on `upstream-submit/*` branches adds single-commit, subsystem-scope and DOC-block checks plus a maintainer NAK lens |

## Install

As a Claude Code plugin marketplace:

```text
/plugin marketplace add reinaldosaraiva/go-skills
/plugin install go-style@go-skills
/plugin install frr-style@go-skills
```

Or as plain skills, symlinked into `~/.claude/skills`:

```bash
git clone https://github.com/reinaldosaraiva/go-skills
go-skills/scripts/install.sh          # refuses to overwrite; --force to replace
```

Git hooks are installed per repository, never globally:

```bash
<skill-dir>/go-style/scripts/install-hooks.sh          # wrapper mode: skill edits propagate
```

`frr-style` hooks are symlinked by hand; the recipe is in its `SKILL.md`.

## Activation

`go-style` never activates by repository name. It runs only when a tracked
`go.mod` exists AND one of these opt-ins is present:

- a `.mas-style` file at the repo root containing `go-style`, or
- an `AGENTS.md` policy line `style-lens: go-style` outside fenced blocks, or
- `GO_STYLE_SCOPE=enable` in the environment.

`frr-style` activates when the repo has an `upstream` remote pointing at
`FRRouting/frr`; `upstream-submit/*` branches get the strict tier.

## Repo-side configuration

| File | Purpose |
|---|---|
| `.golangci.yml` next to `go.mod` | Enables the NAK-aligned linters (`errorlint`, `revive`, `nilnil`, `gocritic`) on top of the default set. The skill ships no config on purpose. |
| `.go-style-banwords` at the repo root | One extended regex per line (`#` comments). Organisation-specific hostnames and e-mail domains belong here, never in the skill. `GO_STYLE_BANWORDS_FILE` overrides the path. |

The built-in banword scan covers credentials assigned to string literals,
FQDNs under private-use TLDs (`.internal`, `.corp`, `.intranet`, `.lan`) in
string literals, and AI markers in source. Import paths are exempt.

## Exit codes

Every portable lint follows the same contract: `0` pass, `1` warn only,
`2` at least one fail. Hook wrappers collapse `1` to `0`, so only a FAIL
blocks a commit.

## Layout

```text
.claude-plugin/marketplace.json      marketplace manifest (two plugins)
plugins/go-style/skills/go-style/    SKILL.md, checks/, hooks/, rules/, scripts/, tests/
plugins/frr-style/skills/frr-style/  SKILL.md, checks/, hooks/, profiles/
scripts/install.sh                   symlink skills into ~/.claude/skills
scripts/sync-from-source.sh          pull from an upstream skills dir + publication gate
```

`tests/run-smokes.sh` in `go-style` plants one violation per check layer in a
temporary repo and asserts the commit fails on that exact layer.

## Provenance

Both skills are developed in a private multi-agent-system repository and
published here through `scripts/sync-from-source.sh`, which rejects any tree
containing private hostnames, e-mail domains or home paths. The `frr-style`
maintainer profiles are derived from public GitHub pull-request reviews and
cite the PR for every rule; they are internal review references and must never
be used to sign or present output as the maintainers themselves.

## License

MIT. See `LICENSE`.
