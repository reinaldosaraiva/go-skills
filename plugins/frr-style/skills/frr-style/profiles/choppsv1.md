---
login: choppsv1
generated_at: 2026-04-18T13:50:00Z
sample_size_reviews: 20
sample_size_authored: 0
sources: [gh search prs (reviewed-by), gh api pulls/comments, gh api pulls/reviews, gh api issues/comments]
---

# Maintainer profile: choppsv1

Sampled 20 recent PRs reviewed by `choppsv1` on FRRouting/frr (2026-04-18). Focus area: mgmtd, YANG/northbound, topotests, libyang compat. Every rule cites ≥1 PR as evidence.

## NAK triggers

- **Don't re-document the standard library or FRR internals a reader can infer from the call site.** Evidence: [#21514](https://github.com/FRRouting/frr/pull/21514#issuecomment-4264044507) — verbatim: *"Id remove the comment, we'd just be re-documenting the listen call. We should expect people to know what the args to the function do."*
- **Don't over-engineer when a direct, minimal approach exists.** Evidence: [#21051](https://github.com/FRRouting/frr/pull/21051#pullrequestreview-3960757341) — verbatim: *"This feels a little over-engineered, will come back with suggested simplification."* and [#21051 top-level](https://github.com/FRRouting/frr/pull/21051#issuecomment-4119422611) — *"This seems too complex."* followed by a simpler proposal.
- **Don't chase a moving upstream API if the churn is large and the existing code works.** Evidence: [#21459](https://github.com/FRRouting/frr/pull/21459#issuecomment-4189968514) — verbatim: *"The amount of changes in the PR is really not OK in any case."* and *"'once, twice, ... bitten'. if there's a small change we can make to stay compatible with libyang v5 then fine, otherwise let's switch autoconf over to 'v4 and v5 not supported' and leave our code alone for now."* — quoted from [#21459](https://github.com/FRRouting/frr/pull/21459#issuecomment-4190061921).
- **Don't duplicate output functions (one with JSON, one without) — it causes drift.** Evidence: [#21232](https://github.com/FRRouting/frr/pull/21232#discussion_r2953517382) — (paraphrased) `choppsv1`'s concern is referenced by `donaldsharp` in the same thread about drift bugs; `choppsv1` is aligned on keeping a single output path (cross-reference from his review style elsewhere).
- **Don't add CLI params in the `no` form just to be ignored — reject them so users learn the real semantics.** Evidence: [#21296](https://github.com/FRRouting/frr/pull/21296#discussion_r3073202095) — verbatim: *"I know there are some CLI commands that ignore extra parameters even if they differ. But here we have new config being added so you aren't going to break anyone by not accepting the extra ignored paramter, so I think you should."*
- **Don't silently change YANG list keys without accounting for NBC (non-backward-compat).** Evidence: [#21296](https://github.com/FRRouting/frr/pull/21296#discussion_r3073260624) — verbatim: *"This is NBC. I don't have any good suggestions for how to handle the transition from old to new here. If we change this it's going to break anyone that is using direct YANG to configure FRR."*
- **Don't model YANG keys on non-unique attributes (distance/metric aren't unique identifiers of a path).** Evidence: [#21296](https://github.com/FRRouting/frr/pull/21296#discussion_r3097553149) — verbatim: *"Assuming it is I do not understand why distance is a key of the path-list, it should not be."*
- **Don't export linux-kernel-specific constraints into a YANG module that must run on other OSes.** Evidence: [#21252](https://github.com/FRRouting/frr/pull/21252#discussion_r3047695154) — verbatim: *"The constraint was removed from the module b/c it was wrong. The byte sized table-id is a very old linux kernel limitation (v2 era), and in any case, the YANG module is not for Linux its for FRR and any OS it runs on, so linux constraints are inappropriate for the model."*

## Commit message preferences

- Sample too thin — 0 authored PRs sampled here (his authored PRs were not in the top-20 slice chosen). Any inference would be speculation.
- Pattern observed in his review feedback: he cares more about correctness of content than format; he does not nit commit-msg formatting in reviews in this sample.

## Documentation / comment tolerance

- **Tolerates dev-guide links over prose.** Evidence: [#21065](https://github.com/FRRouting/frr/pull/21065#issuecomment-4044632431) — verbatim: *"Ok well the op-state has been there for quite a while and is documented in https://docs.frrouting.org/projects/dev-guide/en/latest/northbound/operational-data-rpcs-and-notifications.html"* — preference: point at the canonical doc, don't restate it in the PR.
- **Rejects inline comments that re-explain standard-library call semantics** (see #21514 NAK above).
- **Tolerates dev-notes when the change is non-obvious.** Evidence: [#21065](https://github.com/FRRouting/frr/pull/21065#discussion_r2961762568) — (paraphrased) he explains when a dev-note would *actually* be valuable: only when behavior that was previously documented/restricted is changing. For additive features that developers expect, dev-notes are noise.

## Granularity preference

- **Discrete, focused PRs over omnibus changes.** Evidence: [#21459](https://github.com/FRRouting/frr/pull/21459#pullrequestreview-4062690197) — verbatim: *"These are extensive changes that remove otherwise useful, and efficient code."* — he held a large PR until scope was justified.
- **Moves meta-discussions out of the PR.** Evidence: [#21065](https://github.com/FRRouting/frr/pull/21065#issuecomment-4044632431) — verbatim: *"In any case I think this discussion should move somewhere other than this PR comment section :)"* — prefers to keep PR threads on the diff.

## Review-style signatures

- **Engaging and conversational, uses emoticons `:)`.** Evidence: [#21514](https://github.com/FRRouting/frr/pull/21514#issuecomment-4261894808) — *"Cry 'Havoc!' ... :)"*; also [#21065](https://github.com/FRRouting/frr/pull/21065#issuecomment-4044632431) — *":)"*.
- **Exhaustive-by-example when asking for semantic clarity.** Evidence: [#21296](https://github.com/FRRouting/frr/pull/21296#discussion_r3076005076) — he dumped a 3×9 matrix of `no ip route ...` combinations asking which would delete the route. This is the pattern: ask the author to fill in a truth table rather than describe behavior in prose.
- **Will tag a specific reviewer when the issue is in their wheelhouse.** Evidence: [#20311](https://github.com/FRRouting/frr/pull/20311#pullrequestreview-3601100978) — *"@eqvinox any way to have the CLI parser deal with this?"*
- **Uses Mergify commands to orchestrate backports directly in the PR.** Evidence: [#20862](https://github.com/FRRouting/frr/pull/20862#issuecomment-3954571362) — *"https://github.com/Mergifyio backport stable/10.5 stable/10.4 stable/10.3"*.
- **Flags style nits specifically around tabs vs spaces + tab size.** Evidence: [#18217](https://github.com/FRRouting/frr/pull/18217#discussion_r1980802420) — verbatim: *"That's b/c you're not looking at tabs vs spaces, and you probably have a non-std tab size of 4... The lines above use spaces only, just match that. When editing FRR code you're goign to want your tab size to be 8."*

## Positive signals

- **"LGTM" short and sweet when the diff is clearly scoped.** Evidence: [#20226](https://github.com/FRRouting/frr/pull/20226#pullrequestreview-3558751260) and [#21252](https://github.com/FRRouting/frr/pull/21252#pullrequestreview-4070223827) — *"LGTM, includes a few changes from me as well, in case @donaldsharp you want to review them."*
- **Will approve in the same review where he leaves small inline nits if the author's direction is right.** Evidence: [#20862](https://github.com/FRRouting/frr/pull/20862) — multiple COMMENTED reviews + approval after trivial fixes landed.
- **Accepts "it matches other FRR code" as justification when the convention is consistent.** Evidence: [#21065](https://github.com/FRRouting/frr/pull/21065#discussion_r2936818424) — he did not push back when the author replied *"This matches other code in zebra, so I am not going to make this change."*

## Unknowns / low signal

- **Commit message format preferences** — authored PRs not in the sample. Cannot assert anything beyond "no explicit nits on commit msg format in reviewed sample."
- **Attitude toward Signed-off-by / Fixes: trailers** — not observed in this sample.
- **DOC block line limits** — no explicit numerical ceiling observed; the only DOC-block NAK was via scope (re-documenting stdlib), not line count.
- **CI flakiness tolerance** — not observed in sample.
- **Tabs vs spaces beyond the one #18217 comment** — thin signal.

## Operating notes for a contributor

1. Expect **engaging, conversational reviews** — respond in the same tone, not defensively.
2. When he asks for a truth-table or combinatorics, **fill the table**, don't describe in prose.
3. If an inline comment explains something a reader can infer from the code, **remove it** before he asks.
4. Route YANG/mgmtd/northbound PRs through him; expect **deep semantic scrutiny of list keys and NBC implications**.
5. Keep PR threads on the diff; take design debates to the dev-list or docs.
6. If he says "over-engineered", the correct response is a **concrete smaller alternative**, not a defense of the original.
