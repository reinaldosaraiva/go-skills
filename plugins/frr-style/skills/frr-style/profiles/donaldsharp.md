---
login: donaldsharp
generated_at: 2026-04-18T00:00:00Z
sample_size_reviews: 26
sample_size_authored: 15
sources: [gh search prs, gh api pulls/comments, gh api pulls/reviews, gh api issues/comments, gh api pulls/commits]
---

# Reviewer profile: donaldsharp

Donald Sharp is an NVIDIA FRR maintainer focused on zebra, bgpd, nexthop/RIB, watchfrr, and broader core infrastructure. His reviews are blunt, evidence-first, and heavily architectural — he pushes back hard on duplicated code paths, platform-leaky abstractions, and changes where the commit message does not justify the behavior change. Tone is direct and occasionally salty; he explicitly quotes the word "NAK" when he is rejecting an approach and expects authors to defend the design, not just the code.

## NAK triggers

- **Do not submit a patch directly against a non-master branch.** NAK reason: fix must land on master first and be backported.
  - Evidence: PR #18550 `NAK - We do not accept commits directly into non-master branches. It must be fixed there first.` — https://github.com/FRRouting/frr/pull/18550
- **Do not add configuration validation that rejects partial/out-of-order config entered by a human operator** (list-name references, etc.). FRR must tolerate forward references and return `DENY` for missing prefix-lists/access-lists.
  - Evidence: PR #21516 `This is a straight up NAK from me. It's perfectly legal to partially configure configuration. ... a access-list/prefix-list that does not exist must return a DENY( and it does ). Why would we want to break someone entering code from the CLI?` — https://github.com/FRRouting/frr/pull/21516
- **Do not re-introduce the problem a prior fix closed.** If a previous patch already addressed the root cause, the new PR is NAK'd until a different approach is used.
  - Evidence: PR #21125 `This is a straight up NAK from me. This is not an appropriate approach to the problem. It completely recreates the problem that was being fixed here.` — https://github.com/FRRouting/frr/pull/21125
- **Do not add dead / defensive NULL checks against allocator returns.** FRR's memory allocator cannot return NULL.
  - Evidence: PR #21462 `The memory allocator that FRR uses can never return NULL.` / `the code calls common_object_create which mallocs the obj value. it's impossible for this to ever be null.` — https://github.com/FRRouting/frr/pull/21462
- **Do not leak Linux-specific data-plane types into shared files** (e.g. zebra/interface.c). Translate kernel values into generic FRR types so alternate data-planes work.
  - Evidence: PR #21300 `I do not want linux specific code included as part of interface.c. We are working hard to separate out and abstract dataplane concepts that are driven from one data plane. We should be translating the linux specific values to generic FRR values that are understood internally.` — https://github.com/FRRouting/frr/pull/21300
- **Do not create two parallel output paths (JSON vs non-JSON) with duplicated logic.** One code path, one emitter.
  - Evidence: PR #21232 `Yeah please do not have 2 separate functions for output one with json one without. I keep having to fix bugs where someone makes a change in one function but it is not also changed in the other.` — https://github.com/FRRouting/frr/pull/21232
- **Do not return a JSON body with a `warning`/`error` string for "nothing to show" — return empty `{}` instead.** This is reinforced by his authored PR #21244 updating `workflow.rst`.
  - Evidence: PR #21232 `Yeah this is not the behavior that is desired, have json return a empty {} as it was originally doing. This is what 99% of the rest of FRR is doing` — https://github.com/FRRouting/frr/pull/21232 ; authored PR #21244 — https://github.com/FRRouting/frr/pull/21244
- **Do not hide unrelated behavior changes inside a "log improvement" PR.** If the diff touches logic, the commit message must mention and justify it.
  - Evidence: PR #21356 `This is not a log change and is something quite different. I would like to understand what is going on here and why. commit message does not even mention this.` — https://github.com/FRRouting/frr/pull/21356
- **Do not submit with a PR description but an empty commit body.** He will request changes until the rationale is IN the commit.
  - Evidence: PR #21466 `In the PR itself you have a description of what is being done, but in the commit there is nothing. Please put a description of what you are changing in the ocmmit itself.` (state=CHANGES_REQUESTED) — https://github.com/FRRouting/frr/pull/21466 ; PR #17045 `put the discussion in the actual commit message then we can look at this.` — https://github.com/FRRouting/frr/pull/17045
- **Do not ignore frrbot findings.** Even on an otherwise-approvable review he will hold the PR back until frrbot is clean.
  - Evidence: PR #21516 `I hate to be this way but there are frrbot issues that have been found. We do require that this is fixed too.` — https://github.com/FRRouting/frr/pull/21516 ; PR #21466 `Please address the frrbot issues as well as the test failures.` — https://github.com/FRRouting/frr/pull/21466
- **Do not add documentation/comments that are "stupidly over the top".** Wire-protocol header files especially should be terse.
  - Evidence: PR #21557 `This documentation is stupidly over the top and quite frankly not needed.` — https://github.com/FRRouting/frr/pull/21557
- **Do not submit behavior-change PRs without a topotest showing the new behavior.**
  - Evidence: PR #21007 `We need some sort of topotest here from my perspective at the very least to show that things are working as expected now.` — https://github.com/FRRouting/frr/pull/21007
- **Do not layer a new cache/structure onto bgpd if an existing structure (bnc, peer nexthop list) can do the work.** Higher memory cost without justification is a rejection reason.
  - Evidence: PR #21186 `Why can't we use the bnc and it's list of paths to do this work, instead of adding an entirely new structure ( and it's associated cost of higher memory usage ) to do this work?` — https://github.com/FRRouting/frr/pull/21186
- **Do not overload `nexthop` with L2 state (RMAC, VNI, etc.).** Nexthop is L3 reachability; L2 data belongs in a separate structure.
  - Evidence: PR #7852 `I don't understand how a rmac is a property of the nexthop. It's a property of the l2 information *not* the nexthop. Why are we storing it in the nexthop? If the answer if "convenience" then double triple boo` / `A nexthop is L3 reachability. VNI's RMACS are l2 reachability.` — https://github.com/FRRouting/frr/pull/7852
- **Do not paper over BGP state-machine bugs; fix the underlying race.** He refused PR #18274 until the Clearing → next-state transition was explained.
  - Evidence: PR #18274 `I'd like to get to the bottom of the proper way to handle this situation instead of doing this change.` (CHANGES_REQUESTED) + `we should not be moving from clearing to any other state until all routes have been processsed for that peer.` — https://github.com/FRRouting/frr/pull/18274

## Commit message preferences

- **Format: `<subsystem>: <Imperative summary with capitalized first word>`**, sometimes multiple subsystems comma-separated. Trailing period on subject is tolerated but not required.
  - Evidence (authored): `mgmtd: Use correct printf formatting type.` (#21627), `watchfrr: Remove PHASE_STOPS_PENDING` (#21460), `pceplib: obj is already de-refed, no need to check for NULL` (#21462), `ospf6d: Remove ospf6 route when connected wins` (#21476), `bgpd: Modify early route processing to include send to zebra` (#21357), `ripd, yang: add log-neighbor-changes configuration` (#21442), `bfdd, yang: Convert sbfd changes to use yang` (#21040). URLs: https://github.com/FRRouting/frr/pull/21627 , https://github.com/FRRouting/frr/pull/21460 , https://github.com/FRRouting/frr/pull/21476 , https://github.com/FRRouting/frr/pull/21357
- **Body is mandatory and must explain *why*, not just *what*.** He routinely references the offending prior commit by SHA when the change is a follow-up.
  - Evidence: authored #21460 body cites `killed in 2015 with 71e7cd63d4db9bcc5e107d6fc2dba8624b349e9a`; authored #21295 cites `Commit: 9fb7d677d3584eadd1d4568bedd542eb880afcd7 changed this behavior`; authored #19596 cites `commit: b5682ffbf0051b54af972e6da4c3319adb7a292f`. URLs: https://github.com/FRRouting/frr/pull/21460 , https://github.com/FRRouting/frr/pull/21295 , https://github.com/FRRouting/frr/pull/19596
- **Coverity / CID references are pasted verbatim** into the body when the commit is a Coverity fix.
  - Evidence: authored #21627 body pastes `** CID 1670454: Insecure data handling (INTEGER_OVERFLOW)` with the offending snippet. — https://github.com/FRRouting/frr/pull/21627
- **`Signed-off-by:` is non-negotiable on every commit**; always of the form `Signed-off-by: Donald Sharp <email>` on his own commits.
  - Evidence: every authored commit sampled (#21627, #21460, #21462, #21476, #21357, #21295, #21252, #21244, #21040, #20486, #19596, #21254, #21355, #21315). URL: https://github.com/FRRouting/frr/pull/21357
- **No Conventional-Commits / no ticket tags / no `Co-Authored-By:` trailers in his own commits.** Multi-author PRs preserve each contributor's own S-o-b on their respective commits (e.g. PR #21252 has separate Christian Hopps commits).
  - Evidence: PR #21252 commit list — https://github.com/FRRouting/frr/pull/21252
- **One logical change per commit; bundle related cleanups into a series of small commits in one PR, not one mega-commit.**
  - Evidence: authored #21460 is 5 sequential `watchfrr: Remove PHASE_*` commits; authored #21357 is a feature commit followed by an abstraction-of-duplication commit. URLs: https://github.com/FRRouting/frr/pull/21460 , https://github.com/FRRouting/frr/pull/21357

## Documentation / comment tolerance

- **Minimal doc on protocol / wire headers.** Long explanatory blocks that duplicate what the code obviously does will be called out.
  - Evidence: PR #21557 `stupidly over the top and quite frankly not needed` — https://github.com/FRRouting/frr/pull/21557
- **Preserve pre-existing explanatory comments — do not delete them incidentally.**
  - Evidence: PR #20453 `Any particular reason this comment was removed? It's independent of the changes and frankly I think it explains what is going on here.` — https://github.com/FRRouting/frr/pull/20453
- **Prefer `#define` for magic sizes, even as a drive-by cleanup.**
  - Evidence: PR #20453 `Let's use a #define here for the max size. I know it wasn't before, but let's do that :)` — https://github.com/FRRouting/frr/pull/20453
- **Welcomes short documentation updates to `workflow.rst` when behavior contracts are being clarified** (his own PR #21244 updates the JSON-error convention for everyone).
  - Evidence: authored PR #21244 — https://github.com/FRRouting/frr/pull/21244

## Granularity preference

- **Series of small per-subsystem commits in a single PR is fine.** PR #21460 (5 watchfrr cleanup commits), PR #21357 (feature + refactor), PR #21252 (5 zebra/mgmtd NB-move commits) all merged.
  - Evidence: https://github.com/FRRouting/frr/pull/21460 , https://github.com/FRRouting/frr/pull/21357 , https://github.com/FRRouting/frr/pull/21252
- **Cross-subsystem touches must be justified in each commit header** (e.g. `ripd, yang:`, `bfdd, yang:`, `bgpd, tests:`).
  - Evidence: authored #21442 `ripd, yang: add log-neighbor-changes configuration`, authored #21040 `bfdd, yang: Convert sbfd changes to use yang`, authored #21295 `bgpd, tests: Deduplicated late on send down to zebra.` — https://github.com/FRRouting/frr/pull/21442 , https://github.com/FRRouting/frr/pull/21040 , https://github.com/FRRouting/frr/pull/21295
- **Out-of-scope cleanup is deferred, not smuggled in.** If reviewer disagrees with a pattern, the author is told to open a separate cleanup PR.
  - Evidence: PR #21488 `If you think we should switch to a different way of doing it, that is fine but I think it belongs in it's own cleanup work since we would need to touch a bunch of different spots.` — https://github.com/FRRouting/frr/pull/21488
- **Prefers fixing the root cause once, correctly, over a local band-aid that other contributors will copy.**
  - Evidence: PR #19673 `it is far preferable to fix the problem once and "right" such that people coming along behind do not re-introduce the problem or use a pattern that is broken.` — https://github.com/FRRouting/frr/pull/19673

## Review-style signatures

- **Verbatim phrases that recur in his reviews:**
  - `straight up NAK from me` — used twice in sampled PRs (#21516, #21125). URL: https://github.com/FRRouting/frr/pull/21516 , https://github.com/FRRouting/frr/pull/21125
  - `stupidly over the top` — PR #21557. URL: https://github.com/FRRouting/frr/pull/21557
  - `double triple boo` — PR #7852. URL: https://github.com/FRRouting/frr/pull/7852
  - `dubious` / `I'm pretty dubious` — PR #17045. URL: https://github.com/FRRouting/frr/pull/17045
  - `Not a hill I'm going to die on` — PR #19917 (indicates he will yield on minor taste issues). URL: https://github.com/FRRouting/frr/pull/19917
  - `put the discussion in the actual commit message` — PR #17045. URL: https://github.com/FRRouting/frr/pull/17045
  - `@greptile review` — he routinely pings the greptile bot, then overrides it when he disagrees with its findings (`@greptile I am not especially worried about that.`, PR #21357). URLs: https://github.com/FRRouting/frr/pull/21550 , https://github.com/FRRouting/frr/pull/21488 , https://github.com/FRRouting/frr/pull/21476 , https://github.com/FRRouting/frr/pull/21357
  - `I'm gonna pull the trigger on this PR this afternoon unless someone speaks up` — PR #19917 (his merge-call phrasing). URL: https://github.com/FRRouting/frr/pull/19917
- **Occasional profanity when frustrated with clearly-wrong code** — `yeah this makes no fucking sense at all. There is no vrf data with this at all.` (on his own PR #21550 reviewing a partial patch). Treat as stylistic data point, not something to imitate. URL: https://github.com/FRRouting/frr/pull/21550
- **He self-corrects publicly in the same thread when he mis-reads a diff**, e.g. `shit I read this wrong. The ipv4_mapped_ipv6_to_ipv4 sets tunn_id.` (PR #21507). URL: https://github.com/FRRouting/frr/pull/21507
- **Often loops in other maintainers by handle when he wants a second opinion rather than blocking alone** (`@mjstapp @ton31337 @louberger and @riw777 I would like your opinion`, PR #18274). URL: https://github.com/FRRouting/frr/pull/18274
- **Reviews almost never use `APPROVED` state** — in 26 sampled reviewed PRs (including merged ones) every review was `COMMENTED` or `CHANGES_REQUESTED`. Approval is conveyed by silence plus the merge, not by clicking Approve. Evidence: merged PRs #19564, #21507, #20288, #21442, #21357, #21462, #21476 all show no `APPROVED` review from him.

## Positive signals

- **`seems reasonable. change made`** — how he acknowledges a co-maintainer addressing a review point on his own PR #21476. URL: https://github.com/FRRouting/frr/pull/21476
- **`yep makes sense fixed.`** — short closure of a thread once an issue is addressed (PR #21488). URL: https://github.com/FRRouting/frr/pull/21488
- **Acknowledging that a reviewer's pattern argument is fair but deferring** (`so from a quick scan of the source code ... So I was just following coding conventions. If you think we should switch to a different way of doing it, that is fine but I think it belongs in it's own cleanup work`, PR #21488). URL: https://github.com/FRRouting/frr/pull/21488
- **Explicitly noting a fix eliminated a flaky test** in the PR body (`ospf6_point_to_multipoint test fails infrequently ( between 1-8 times when running in parallel with itself 64 times ). Now it never fails.`, PR #21476). URL: https://github.com/FRRouting/frr/pull/21476
- **Clear architectural rationale earns approval faster** — dataplane abstraction (#21300), clean layer separation of L2 vs L3 (#7852), and "fix it once, right" (#19673) are values that align with his approvals.

## Unknowns / low signal

- **Approval signaling.** Sample contains zero `APPROVED` reviews from him even on merged PRs he commented on; unclear whether he ever approves formally or relies on merge-button action by himself/co-maintainers. Pattern is consistent across 26 PRs but the sample is biased toward PRs where he left comments.
- **Tolerance for `Fixes: #NNNN` / issue cross-references.** His own commit bodies reference prior commits by SHA but rarely cite GitHub issues; sample too small to state a rule.
- **Line-length / wrap conventions.** He complained about doc verbosity (#21557) but did not state a concrete per-line limit; his own commit bodies wrap at ~72 chars informally.
- **Reaction to AI-assisted PRs.** The PRs where he pinged `@greptile` show he tolerates bot review input, but he overrides bot findings when he disagrees. No sampled comment explicitly references AI authorship tooling by humans.
- **Reviews of subsystems outside zebra/bgpd/mgmtd/ospf6/watchfrr/pceplib/ripd/ldpd** (e.g. pimd, isisd, vtysh) were thin in the sample.
