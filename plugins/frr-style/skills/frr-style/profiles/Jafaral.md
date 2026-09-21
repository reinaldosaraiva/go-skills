---
login: Jafaral
full_name: Jafar Al-Gharaibeh
generated_at: 2026-04-22T14:00:00Z
sample_size_reviews: 40
sample_size_authored: 20
sources: [gh search prs, gh api pulls/comments, gh api pulls/reviews, gh api issues/comments, gh api pulls/commits]
notes: >
  FRRouting org member with merge access. Not listed in MAINTAINERS or CODEOWNERS
  but actively merges PRs across subsystems. Heavy pimd ownership (author + reviewer).
  Uses @greptile bot extensively for automated pre-review.
---

# Maintainer profile: Jafaral

Sampled 40 reviews and 20 authored PRs on 2026-04-22. Every rule below cites observed evidence.

## NAK triggers

- **Reject whitespace-only or cosmetic changes mixed into functional PRs.** Repeated pattern across multiple reviews. Evidence: [#19480](https://github.com/FRRouting/frr/pull/19480) — "drop whitespace change" (3 separate inline comments on ospfd files). [#20031](https://github.com/FRRouting/frr/pull/20031) — "no need for this whitespace change." [#18436](https://github.com/FRRouting/frr/pull/18436) — "drop white space change" and pointed author to frrbot for formatting fixes.

- **Reject code that defines symbols without consumers.** Evidence: [#21557](https://github.com/FRRouting/frr/pull/21557) — "This defines errors values, but I don't see those used in the code." (top-level issue comment, factual observation about header-only change with no call sites).

- **Reject PRs missing test coverage for bug fixes.** Evidence: [#21047](https://github.com/FRRouting/frr/pull/21047) — "Can you add test coverage for the fix? see tests/topotests." (issue comment, PR still open months later).

- **Reject poorly structured commits — squash duplicates, shorten titles, add descriptions.** Evidence: [#19480](https://github.com/FRRouting/frr/pull/19480) — CHANGES_REQUESTED with a detailed explanation: "Squash all commit with the same title to one commit [...] Use a short title for the new squashed commit, and copy the description you have for the PR to the commit message." Included a concrete example of a too-long title showing wrapping on GitHub.

- **Reject wrong commit-message prefix when the change scope is mischaracterized.** Evidence: [#20202](https://github.com/FRRouting/frr/pull/20202) — CHANGES_REQUESTED: "change the prefix 'lib:' to 'build:' in the commit message since that is a change to the build system, it is not a change to the lib code."

- **Block PRs in subsystems he owns until he personally reviews the logic.** Evidence: [#19319](https://github.com/FRRouting/frr/pull/19319) — CHANGES_REQUESTED with body: "Blocking this until I get a chance to review the code." Inline: "for a long time, we only had sm mode, and so `ip pim` just meant both sm and ssm. I need to look again at the logic change I made with dm mode before accepting this change or propose new changes."

- **Reject functional changes that lack a linked issue or proper description.** Evidence: [#20202](https://github.com/FRRouting/frr/pull/20202) — "I do see that you have an open issue related to this change. Can you please link it in the commit message, and also add a proper description?"

## Commit message preferences

- **Use `subsystem:` prefix matching the daemon or area changed, not the directory.** Evidence: [#20202](https://github.com/FRRouting/frr/pull/20202) — explicitly corrected `lib:` to `build:` for a build-system change. Own authored PRs consistently use daemon prefix: `pimd:`, `bgpd:`, `bfdd:`, `nhrpd:`, `ospfd:`, `ci:`, `doc:`, `tests:`.

- **Keep the title line short and descriptive; put details in the body.** Evidence from authored PRs: titles are terse imperatives (e.g., "pimd: fix crash due to double free" [#21354](https://github.com/FRRouting/frr/pull/21354), "bgpd: fix off-by-one error in FlowSpec operator array bounds check" [#21054](https://github.com/FRRouting/frr/pull/21054)). Body always explains the *why* in 2-4 lines.

- **Use bullet-point body for multi-item changes.** Evidence: [#21356](https://github.com/FRRouting/frr/pull/21356) — "- Clearer message when RP reachability is the root cause / - 'join-group' better reflects the action being performed / - If pim isn't enabled on an interface just move on, no need for log". Also [#21499](https://github.com/FRRouting/frr/pull/21499) and [#21475](https://github.com/FRRouting/frr/pull/21475) follow same pattern.

- **Include Signed-off-by.** Standard FRR DCO requirement; all authored commits carry it.

- **Link related issues in the commit message when they exist.** Evidence: explicitly asked for this in [#20202](https://github.com/FRRouting/frr/pull/20202).

## Documentation / comment tolerance

- **Low tolerance for dead code and unused definitions.** The pushback on [#21557](https://github.com/FRRouting/frr/pull/21557) ("defines errors values, but I don't see those used") suggests he expects every symbol introduced to have at least one consumer in the same PR.

- **Accepts concise inline documentation.** Own authored PRs contain brief explanatory comments but no large DOC blocks. Commit bodies serve as the primary documentation medium.

- **Directs contributors to the official dev-guide rather than explaining style inline.** Evidence: [#19480](https://github.com/FRRouting/frr/pull/19480) — linked directly to `docs.frrouting.org/projects/dev-guide/en/latest/workflow.html#submitting-patches-and-enhancements` and `#commit-guidelines`.

## Granularity preference

- **Expects each commit to be self-contained with a matching title.** Evidence: [#19480](https://github.com/FRRouting/frr/pull/19480) — "Squash all commit with the same title to one commit."

- **Accepts multi-commit PRs when each commit is distinct.** Own authored PRs like [#21431](https://github.com/FRRouting/frr/pull/21431) (guard channel OIL) are single-commit. But [#21499](https://github.com/FRRouting/frr/pull/21499) (README refresh) bundles multiple items with bullet-point body. Cross-subsystem PRs reviewed and merged include 17-file PRs like [#21252](https://github.com/FRRouting/frr/pull/21252) (768 additions, mgmt frontend in zebra).

- **Demands test coverage for bug fixes.** Evidence: [#21047](https://github.com/FRRouting/frr/pull/21047) — "Can you add test coverage for the fix?"

- **Expects topotest configs to use multiline strings and proper indentation.** Evidence: [#20326](https://github.com/FRRouting/frr/pull/20326) — "please use the multiline string here and everywhere else, much clearer" and "can you do indent these to make it the config clearer?" with a concrete code example.

## Review-style signatures

- **Tone: terse, factual, directive.** Comments are typically one sentence. Does not soften with pleasantries on inline comments. Uses imperative mood: "Drop this line please." ([#21047](https://github.com/FRRouting/frr/pull/21047)), "drop whitespace change" ([#19480](https://github.com/FRRouting/frr/pull/19480)), "no need for this whitespace change" ([#20031](https://github.com/FRRouting/frr/pull/20031)).

- **Asks clarifying questions when logic is unclear, expects the author to explain.** Evidence: [#19199](https://github.com/FRRouting/frr/pull/19199) — "I don't understand why these has to match? The group addr has nothing to do with the igmp packet destination. Can you explain?" Also: "`group_addr` too?" (terse follow-up).

- **Warm and encouraging toward new contributors in CHANGES_REQUESTED reviews.** Evidence: [#19480](https://github.com/FRRouting/frr/pull/19480) — ends the detailed style correction with "Thank you very much for your contributions!"

- **Heavy @greptile bot usage.** Invokes `@greptile review` on PRs before or during his own review in at least 10 sampled PRs ([#20936](https://github.com/FRRouting/frr/pull/20936), [#21303](https://github.com/FRRouting/frr/pull/21303), [#21507](https://github.com/FRRouting/frr/pull/21507), [#21217](https://github.com/FRRouting/frr/pull/21217), [#19199](https://github.com/FRRouting/frr/pull/19199), [#21255](https://github.com/FRRouting/frr/pull/21255), [#21252](https://github.com/FRRouting/frr/pull/21252)). Sometimes delegates follow-up to greptile: "@greptile, if this addressed in the code, please resolve." Corrects greptile when wrong: "@greptile, in error cases we want to just return an empty json object. You recommendation above goes against the common behavior we have." ([#21232](https://github.com/FRRouting/frr/pull/21232)).

- **Inline review comments rather than top-level essays.** When leaving feedback, prefers per-line or per-file comments. Top-level CHANGES_REQUESTED bodies are typically empty string ("") with the substance in inline threads. Exception: detailed onboarding feedback for new contributors ([#19480](https://github.com/FRRouting/frr/pull/19480)).

- **Points to frrbot for formatting fixes.** Evidence: [#18436](https://github.com/FRRouting/frr/pull/18436) — "click the frrbot in the ci below. You can see the suggestions there. It will also give you a command to apply all of the suggestion by pulling a diff directly to your code."

- **Cites banned-function rules from FRR style.** Evidence: [#18436](https://github.com/FRRouting/frr/pull/18436) — "`sprintf`, `strcat`, `strcpy`, `inet_ntoa`, `ctime` are banned; please use `snprintf`, `strlcat`, `strlcpy`, `inet_ntop`, `ctime_r`"

- **Uses @mergifyio backport commands immediately after approving.** Observed in at least 8 PRs ([#21303](https://github.com/FRRouting/frr/pull/21303), [#21277](https://github.com/FRRouting/frr/pull/21277), [#21118](https://github.com/FRRouting/frr/pull/21118), [#21217](https://github.com/FRRouting/frr/pull/21217), [#21251](https://github.com/FRRouting/frr/pull/21251), [#21373](https://github.com/FRRouting/frr/pull/21373), [#21278](https://github.com/FRRouting/frr/pull/21278), [#21476](https://github.com/FRRouting/frr/pull/21476)). Typical pattern: APPROVED review, then immediately "@mergifyio backport stable/10.6 stable/10.5 ..." in issue comment.

## Positive signals

- **Silent APPROVED with empty body is the norm.** Out of ~25 APPROVED reviews sampled, all had empty body (""). No "LGTM" or "looks good" phrases observed. An empty-body APPROVED is his standard positive signal.

- **Backport command = strong endorsement.** When he issues `@mergifyio backport` immediately after approval, that signals the fix is important enough for stable branches. Evidence: [#21118](https://github.com/FRRouting/frr/pull/21118) backported to 7 stable branches (10.0 through 10.6).

- **Merges PRs he approves directly.** Confirmed merge access; merged at least 8 PRs from the sample: [#21585](https://github.com/FRRouting/frr/pull/21585), [#21303](https://github.com/FRRouting/frr/pull/21303), [#21536](https://github.com/FRRouting/frr/pull/21536), [#21507](https://github.com/FRRouting/frr/pull/21507), [#21277](https://github.com/FRRouting/frr/pull/21277), [#21316](https://github.com/FRRouting/frr/pull/21316), [#21217](https://github.com/FRRouting/frr/pull/21217), [#21251](https://github.com/FRRouting/frr/pull/21251).

- **Re-engages after author addresses feedback.** Evidence: [#19319](https://github.com/FRRouting/frr/pull/19319) — initially blocked with CHANGES_REQUESTED, then months later: "@ak503 can you please rebase this PR? I will get it in." This shows he returns to unblock PRs once satisfied. [#21303](https://github.com/FRRouting/frr/pull/21303) — posted "@greptile fixed" on 4 threads, then APPROVED the next day.

## Subsystem authority

- **Primary: pimd/pim6d.** Author of most pimd fixes in recent months ([#21354](https://github.com/FRRouting/frr/pull/21354), [#21431](https://github.com/FRRouting/frr/pull/21431), [#21481](https://github.com/FRRouting/frr/pull/21481), [#21356](https://github.com/FRRouting/frr/pull/21356), [#21216](https://github.com/FRRouting/frr/pull/21216), [#19199](https://github.com/FRRouting/frr/pull/19199)). Explicitly blocks pimd PRs for personal review ([#19319](https://github.com/FRRouting/frr/pull/19319)).

- **Active cross-subsystem reviewer with merge authority.** Reviews and merges PRs in ospfd, bgpd, isisd, eigrpd, ldpd, nhrpd, bfdd, vrrpd, pceplib, lib/, CI, docs. Not specialized in any single non-pimd area but has broad merge authority.

- **CI/build system.** Authored CI workflow improvements ([#21475](https://github.com/FRRouting/frr/pull/21475), [#21175](https://github.com/FRRouting/frr/pull/21175), [#21158](https://github.com/FRRouting/frr/pull/21158)).

- **Security hardening.** Multiple authored PRs harden packet parsing: nhrpd ([#21097](https://github.com/FRRouting/frr/pull/21097), [#21187](https://github.com/FRRouting/frr/pull/21187)), bfdd ([#21105](https://github.com/FRRouting/frr/pull/21105), [#21255](https://github.com/FRRouting/frr/pull/21255)), bgpd FlowSpec ([#21054](https://github.com/FRRouting/frr/pull/21054)).

- **lib/mgmt_msg area: limited direct evidence.** Approved [#21252](https://github.com/FRRouting/frr/pull/21252) (mgmt frontend in zebra, 768 additions) without inline comments, suggesting familiarity but not deep ownership. No authored PRs touching `lib/mgmt_msg_native.h` in sample. His comment on [#21557](https://github.com/FRRouting/frr/pull/21557) was a general code-quality observation (unused definitions), not a subsystem-specific technical objection.

## Unknowns / low signal

- **Re-engagement pattern after author responds to non-pimd feedback.** Only one clear re-engagement cycle observed outside pimd ([#20202](https://github.com/FRRouting/frr/pull/20202) CHANGES_REQUESTED then APPROVED same day). Insufficient data to determine if he goes silent on non-pimd PRs when the author responds.

- **Tolerance for header-only / preparatory PRs.** The [#21557](https://github.com/FRRouting/frr/pull/21557) comment is the only data point. Unclear whether he would accept a header-only PR with a clear "preparatory for follow-up PR #X" justification, or if he categorically requires consumers in-tree.

- **Not listed in MAINTAINERS or CODEOWNERS files** despite having org membership and merge access. Formal governance role is unclear from repository metadata alone.

- **Backport scope criteria.** He issues backport commands to varying numbers of stable branches (1 to 7) but the selection criteria are not explicit in the sample. Likely based on severity and affected versions, but no direct evidence of the decision logic.

- **YANG / mgmtd internals depth.** No authored or reviewed PRs touching YANG models or mgmtd core in the sample. His authority over `lib/mgmt_msg_native.h` specifically should be considered uncertain.
