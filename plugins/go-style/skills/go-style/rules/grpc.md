# go-style gRPC lens

Applies when the opted-in module requires `google.golang.org/grpc` in a
tracked `go.mod`. Distilled from a production control-plane pair (a Go
southbound adapter talking to a C++ gRPC server with leases, durable commit
outcomes and bounded state reads) and from published API precedents (gRIBI
election/persistence/acknowledgment semantics, gNMI, vendor route services).
These are transport-shape rules; they do not prescribe a domain model.
The precedent behind each rule, and the claims the review rejected, are in
`rules/grpc-references.md`.

Legend:
- **[enforced]** — mechanical (`golangci-lint` default set, `go vet`).
- **[advisory]** — reviewer judgement.

## Client construction

- **[enforced]** `grpc.NewClient` over the deprecated `grpc.DialContext`; never `grpc.WithBlock` (unsupported by `NewClient`). `staticcheck SA1019` flags both.
- **[advisory]** Transport security is an explicit, validated enum on the options struct (`mtls`, `uds`, `insecure-lab`). No zero-value default. Insecure requires a second explicit boolean; mTLS requires a principal identity. `validate()` fails closed.
- **[advisory]** One function builds the dial options (keepalive, window sizes, interceptors) so binaries cannot drift from each other.
- **[advisory]** UDS endpoints use `WithContextDialer` + `passthrough:///`; the `unix://` prefix is stripped in exactly one place.

## Deadlines, cancellation, context

- **[advisory]** Every RPC takes the caller's `ctx`; `context.Background()` only in `main` and tests. Per-operation `WithTimeout` + `defer cancel()`. A lease-bound operation derives its timeout from the lease, not from a constant.
- **[advisory]** Check `errors.Is(err, context.Canceled)` / `context.DeadlineExceeded` BEFORE `status.FromError`. A deadline on a mutation is an ambiguous outcome, not a failure.

## Keepalive and flow control

- **[advisory]** Client `keepalive.ClientParameters.Time` must exceed the server's `GRPC_ARG_HTTP2_MIN_RECV_PING_INTERVAL_WITHOUT_DATA_MS`, or the server answers GOAWAY `too_many_pings`. Document both numbers next to each other, on both sides.
- **[advisory]** `PermitWithoutStream: true` only when the server sets `GRPC_ARG_KEEPALIVE_PERMIT_WITHOUT_CALLS`.
- **[advisory]** Initial stream/connection window sizes are symmetric on both sides and stated with the payload they were sized for (e.g. paged state reads).
- **[advisory]** Keepalive detects transport health only. Ownership leases, election epochs and stale timers are protocol decisions with their own units, bounds and renewal RPC. Never derive them from keepalive.

## Errors

- **[enforced]** Discriminate with `errors.Is` / `errors.As` and `status.FromError`; never compare `err.Error()` strings (`errorlint`).
- **[advisory]** Map `codes.*` to an action-oriented class once, in one function. `InvalidArgument`, `NotFound`, `AlreadyExists`, `PermissionDenied`, `Unauthenticated`, `FailedPrecondition`, `Aborted` are permanent; `ResourceExhausted`, `Unavailable` are retryable; `DeadlineExceeded`, `Unknown` and anything unmapped are ambiguous. Unknown never downgrades to "not applied".
- **[advisory]** A fencing signal (lease, generation, epoch or incarnation mismatch) forces a repair-required class that metadata hints cannot override.
- **[advisory]** Rich error details (`errdetails.ErrorInfo`, `BadRequest`, `PreconditionFailure`, `RetryInfo`, `QuotaFailure`) are parsed on the client ONLY if the server emits them. A parser with no producer is dead code. Add a contract test that the server populates at least `ErrorInfo.Reason` on every non-OK status it owns.
- **[advisory]** Wrap with `%w` and keep the gRPC status as the cause so `status.FromError` still works after wrapping. Keep the cause out of any canonical or JSON comparison form.

## Ambiguous mutations

- **[advisory]** Every mutation carries a client-generated operation token with at least 128 bits from `crypto/rand`; the server keys durable outcomes by it.
- **[advisory]** After `DeadlineExceeded`, `Unavailable` or a connection reset on a mutation: query the durable outcome or read back. Retry only when the outcome proves "not applied". Never retry blindly.
- **[advisory]** The client transaction state machine is explicit (`begin -> committing -> confirmed | rejected | ambiguous | canceled`). No candidate edits after prepare. Cleanup is idempotent and runs on abort, close and context cancel.

## Backpressure and admission

- **[advisory]** Server admission returns `ResourceExhausted` with a `retry-after-ms` trailer; the client maps it to retryable and honours the trailer. Silent drops are a defect.
- **[advisory]** Paged or bounded reads are revision-bound; the client rejects pages whose revision moved mid-read instead of stitching them.

## Interceptors and metadata

- **[advisory]** One chained unary and one stream client interceptor provide latency/outcome telemetry, panic recovery into a typed error, and correlation-id propagation via outgoing metadata (`x-<service>-correlation-id`). Stream telemetry reports exactly once, at the first terminal event (`io.EOF`, error, send failure, panic).
- **[advisory]** A stable per-channel client label in metadata (`x-<service>-client-id`) is for isolation only. It is not identity and must never drive authorization. Identity comes from the transport (`auth_context`, X.509 SAN), never from a request field.

## Proto hygiene

- **[advisory]** `//go:generate protoc ...` sits next to the generated files with a pinned module mapping; a test pins the proto's SHA-256 so bindings cannot drift silently.
- **[advisory]** Every RPC and externally visible field documents semantics, enum-zero behaviour, idempotence and compatibility. "Version zero means unavailable" for negotiated sub-APIs.
- **[advisory]** Generated `*.pb.go` are lint-exempt (`generated: lax`) and never hand-edited.

## Testing

- **[advisory]** Fakes over mocks: a programmable in-memory server (`bufconn` or a temp UDS) that records calls, serves queued responses and panics on unexpected writes.
- **[advisory]** `go test -race -count=1 ./...` is the gate; flaky suspects run with `-count=50`. No `time.Sleep` synchronisation in tests; use channels, `t.Cleanup`, `t.TempDir`.
- **[advisory]** One negative test per error class: cancellation mid-stream, deadline on commit, server `ResourceExhausted`, rich-detail class override, fencing mismatch, stale page revision.
