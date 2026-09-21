# go-style NAK idioms checklist

Inspired by Pike/Cheney Go idioms + FRR C discipline translated to Go.

Legend:
- **[enforced]** — checked mechanically by `.golangci.yml` in the repo. Hook fails on violation in staged diff.
- **[advisory]** — reviewer judgement. Not mechanically enforced.

See the opted-in repo's `.golangci.yml` (next to its `go.mod`) for the enforcement
config. gRPC-specific idioms live in `rules/grpc.md` and apply when that
`go.mod` requires `google.golang.org/grpc`. Pre-commit hook runs `golangci-lint run --new-from-rev=HEAD`, so issues
pre-dating the config do not block commits that do not touch the affected file.
CI / manual `/go-style` can widen scope via `MERGE_BASE` env var.

## API surface (pkg/frrfe/)

- **[enforced]** Exported functions have godoc starting with the function name  (`revive: exported`)
- **[enforced]** `ctx context.Context` is first arg in functions (`revive: context-as-argument`)
- **[enforced]** Errors wrapped with `%w` (not `%v`) in `fmt.Errorf` when caller may need to unwrap  (`errorlint: errorf`)
- **[advisory]** Interfaces are small (≤3 methods) preferred over struct hierarchies
- **[advisory]** Avoid `interface{}` / `any` in public API without justification
- **[advisory]** Public structs use field tags consistently; document zero-value behavior (a zero value that silently means "disabled" is a trap)

## Concurrency

- **[advisory]** Goroutines have clear lifecycle owner (no goroutine leaks)
- **[advisory]** `sync.Mutex` / `RWMutex` have Lock/Unlock paired in the same lexical scope when possible
- **[advisory]** `defer mu.Unlock()` pattern preferred over manual Unlock
- **[advisory]** `sync.Once` misuse: do not call Do from inside a loop
- **[advisory]** `context.WithTimeout` / `WithCancel` have matching `cancel()` call (defer preferred)

## Error handling

- **[enforced]** `errors.Is` / `errors.As` used for typed error discrimination; not `err == sentinel` or string compare  (`errorlint: comparison`, `errorlint: asserts`)
- **[enforced]** No `return nil, nil` in functions returning `(T, error)` — use a sentinel  (`nilnil`)
- **[enforced]** Unchecked error returns flagged  (`errcheck`, standard default)
- **[enforced]** Deprecated symbol use flagged  (`staticcheck: SA1019`); the deprecation marker lands in the same change as the replacement API
- **[advisory]** Sentinel errors are package-level vars (not inline `errors.New` at call site)
- **[advisory]** Sentinels name the condition, not the actor (`ErrInvalidRequest` > `ErrClientBugSchema`)
- **[advisory]** Typed-nil guard on any function that deref pointer post-`errors.As` (a typed nil satisfies the interface but dereferences to a panic)

## Naming

- **[enforced]** Error type/var naming (`revive: error-naming`)
- **[enforced]** Error strings not capitalized (`staticcheck: ST1005`)
- **[advisory]** Package names are short, lowercase, single-word (`frrfe`, not `frr_frontend`)
- **[advisory]** Avoid `Get` / `Set` prefixes in getters (use `Name()` not `GetName()`)
- **[advisory]** Acronyms in names keep consistent case (`XMLHTTPRequest`, not `XmlHttpRequest`)

## Control flow

- **[enforced]** No empty blocks  (`revive: empty-block`, `staticcheck: SA9003`)
- **[enforced]** No superfluous else after return  (`revive: superfluous-else`)
- **[enforced]** Indent error flow (`revive: indent-error-flow`)
- **[enforced]** Unreachable code (`revive: unreachable-code`)

## Exclusions documented in `.golangci.yml`

- `_test.go` files exempt from `revive` and `errorlint` — test ergonomics prioritised.
- `cmd/*` exempt from `revive: exported` — entry points may skip godoc.
- Experimental harness directories may be exempted the same way; name them in the repo config, never in this file.
