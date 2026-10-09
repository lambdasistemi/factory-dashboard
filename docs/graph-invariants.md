# Graph invariants and actionable attention

## Story: Show me the broken expectation and help me explain it

As a factory operator, I see where recorded work stops matching the expected coordination rules, inspect the evidence in graph context, and copy a problem prompt for a role with enough authority to investigate it. I send that prompt myself on the machine. The first release observes and prepares the explanation; communicating back remains the next milestone.

This is research for the graph contract, local protocol and derived-attention tickets. The rules below are proposals grounded in current records, not implemented detectors or a claim that every observed branch is faulty. Read them alongside the [roadmap](roadmap.md) and [privacy contract](configuration.md).

The operator's A–H observations are translated into a [prioritised rule and problem-prompt catalog](invariant-catalog.md). The primary outcome is a request the operator can pass to the right role without having to diagnose the graph first.

## What inspecting the current records revealed

A bounded read-only sample on 9 October 2026 examined eight selected role journals and their communication-file inventories, plus available liveness records. The sample included an active supervision branch, a review branch and a completed handoff. It is not a factory-wide health census. The public examples below use synthetic names; private journals, paths, worker identities and message contents are not published.

| Observation in the sample | Consequence for the graph |
| --- | --- |
| Several related roles recorded WAITING at overlapping times. | Counted waiting nodes cannot establish a deadlock. The awaited obligation and possible wake source matter. |
| Some sampled journals had no liveness record. | Activity is unknown for those roles; missing coverage is a visible finding, not proof that nobody is working. |
| Review requests were consumed by a supervisor and separately forwarded to a reviewer. | Receipt and forwarding are distinct edges; consuming an event does not satisfy every duty it creates. |
| An answer was received by a supervisor and forwarded as a separate note to the affected role. | Escalation must retain correlation across hops; matching only a local question number is insufficient. |
| A blocked review was followed by a repair instruction. | Acknowledging the finding does not resolve it. A later candidate needs its own review evidence. |
| An older handoff described a pull request as open, while a fresh GitHub read showed it merged. | Preserve when and where a claim was true; do not turn asynchronous historical disagreement into an automatic violation. |

A separate synthetic experiment checked an existing local unanswered-question detector. With no answer, it emitted an unanswered-question finding. Adding an answer for a different question suppressed that finding, as did adding the matching answer. An independent missing-liveness finding remained in all three runs; the overall check never passed. This is evidence of a correlation weakness in that detector, not evidence that a live question was lost. The new graph must require exact obligation identity and include the unrelated-answer case as a negative control.

## The graph needs facts, obligations and observation limits

A role state alone is too weak. Keep these dimensions separate:

- **Work state:** active assignment, blocked task, handoff, completed task, accepted result or released artifact.
- **Activity claim:** working, waiting on channels, deliberately paused, or unknown. A file claim is not independent process verification.
- **Obligation:** who owes what to whom, on which work item, with what correlation identity, authority and completion condition.
- **Observation quality:** source coverage, event revision, observation time, freshness, parse errors and unresolved references.

WAITING on channels means readiness to receive events; it does not necessarily mean the role has an outstanding blocking question. A supervisor can listen while a child works. A reviewer can wait legitimately for the next checkpoint. A human decision, external check, configured timer or explicit pause may explain why no role currently claims to be working.

Each fact needs an opaque source identity, role/run identity, event identity or immutable source revision, event time when available, observation time and protocol version. Each relationship must be typed: containment, supervision, dependency, question, answer, acknowledgement, review or acceptance. Do not infer a supervisor solely from directory nesting, a shared label or a GitHub assignment.

Facts are sampled at different times. Retain source cursors and the observation interval, tolerate the configured propagation window, and recheck unsettled joins. Invalid timestamps, truncated history and failed reads reduce confidence. Missing data must never make a rule look satisfied. Retain a redacted finding when observation becomes insufficient; do not silently mark it resolved.

Use four outcomes: **supported**, **violated**, **unknown**, and **not applicable**. A violation requires the evidence its rule needs. A policy deadline can be overdue without proving a protocol contradiction. Display the distinction between a structural contradiction, an overdue obligation and an observation gap.

## Candidate invariants

### Every displayed fact has a source

An asserted edge must be supported by a recorded reference and scoped identity. A missing endpoint is a dangling reference; a missing configured source is a coverage gap. Keep that portion of the graph visibly incomplete rather than inventing a parent or discarding the branch. Different runs may reuse question numbers without sharing questions.

**Attention:** “This dependency points outside the observed graph.” Route to the owner of the referencing scope, or the installation operator if configuration caused the gap.

### Every blocking wait names what can release it

An outstanding blocking obligation identifies its debtor, beneficiary, scope and release condition. Supported alternatives and joint prerequisites must be explicit. “Waiting” without that context supports an incomplete-state finding, not an invented dependency.

**Attention:** “This role is blocked, but the record does not identify who can unblock it.” Route to its recorded supervisor. A channel listener with no blocking obligation is a healthy counterexample.

### A waiting branch has a possible source of progress

Follow blocking obligations to a recorded role able to satisfy them, an external completion, a human decision, a timer, or an explicit pause/wake condition. A target reported as working is only a plausible progress source when its assignment can satisfy this particular obligation; unrelated activity is not enough.

A closed cycle of waits is a deadlock candidate only if every participant is blocked on the cycle and no valid alternative can release it. With complete, fresh, authoritative dependency records this is a structural violation of the declared progress model. With partial or stale records it is “no observed route to progress,” not proof of real-world deadlock.

**Attention:** highlight the smallest closed blocking set and the incoming branches it affects. Route to a supervisor with authority across that set. Two waiting roles released by the same pending human answer are a counterexample, not a violation.

### An outstanding obligation has a responsible recipient

A pending obligation cannot be silently discharged because its recipient retired, its assignment ended, or its role binding disappeared. It needs a recorded successor, delegation, cancellation or escalation. A paused recipient may legitimately wait for a named wake event; a missing liveness claim alone proves neither retirement nor abandonment.

**Attention:** “This question still has no answer, and its designated recipient has ended this assignment.” Route to the recipient's supervisor or the recorded successor when that successor has the required authority.

### Delivery, acknowledgement and application remain distinct

A question produces separate obligations: take responsibility, answer it, deliver the answer, acknowledge it and apply it where the protocol requires. A supervisor may have consumed a child event while still owing a forward. An answer file is evidence of delivery, not evidence of receipt or resumed work.

**Attention:** “The answer is recorded, but there is no matching receipt after the configured allowance.” Route to the recipient's supervisor if intervention is needed. Unrelated journal growth cannot count as an acknowledgement. Freshly delivered messages inside the allowance are normal pending work.

### Only matching evidence closes an obligation

Answer and acknowledgement references must match the full identity: source, run, message or question, and the applicable revision. Escalated questions carry their relationship to the original obligation. Acknowledgement of a question is not an answer; an answer is not proof that the original blocker is resolved.

**Attention:** “There is an answer nearby, but it answers a different question.” Route to the responsible coordination role. Reused local numbers, unrelated answers and earlier-run acknowledgements must not clear the finding.

### Acceptance belongs to an exact candidate and gate

Completion, local checks, independent review, hosted checks, merge, acceptance and release are different facts. Evidence carries its subject identity and gate version. A passing result for an earlier candidate does not satisfy the required check on the current candidate unless an explicit accepted equivalence rule applies.

**Attention:** “This branch is presented as ready, but its required approval belongs to an earlier revision.” Route to the scope owner responsible for acceptance. A historical approval displayed honestly as historical is not faulty; work still awaiting review is normal pending work.

### Handoffs preserve responsibility for unfinished work

A terminal handoff can report success, failure, capacity exhaustion or supersession. It must not erase unfinished obligations. Where the protocol requires a supervisor's disposition, that disposition is a separate event with its own evidence and timeliness policy. Retirement does not imply acceptance, and an active pause does not imply abandonment.

**Attention:** “The role handed back unfinished work, but no disposition or successor is recorded.” Route to its supervisor. A completed and accepted branch intentionally retained as history is a healthy counterexample.

### Exclusive ownership is unambiguous within a scope

When the configured role contract requires one active owner for a task or writable scope, concurrent incompatible ownership claims need a recorded handoff or disjoint partition. Multiple roles on one issue can be correct: an owner and a read-only auditor are not competing writers.

**Attention:** “Two roles claim exclusive responsibility for the same scope and revision.” Route to their lowest common authorised supervisor. If exclusivity or scope overlap is not represented, report insufficient information rather than declaring a conflict.

### Pauses, dependencies and coverage constrain conclusions

An authorised pause must not be treated as inactivity failure. Work reported after the pause becomes effective requires a recorded exception, safe-stop allowance or resumption under the applicable policy. Likewise, starting work behind an unmet hard prerequisite is only a violation when the dependency actually forbids that work; unrelated parallel preparation may be valid.

An empty or entirely stale branch cannot pass these checks by containing no usable facts. Show how many relevant roles and obligations were evaluable, excluded, or unknown. A truncated read, unsupported event or relocated runtime may explain missing coverage.

**Attention:** route a conflicting authority claim to the role responsible for the pause or prerequisite; route a coverage gap to the configured source owner. No process inspection or automatic discovery is introduced to guess missing facts.

## Detecting the waiting branch without false alarms

Treat the dependency structure as obligations with AND and OR conditions, not merely as a count of nodes or a generic graph cycle. A role requiring two results needs both; a role accepting either of two authorised answers needs one. Plain reachability incorrectly marks an AND wait as releasable when only one prerequisite can progress.

Start with recorded eligible progress sources and satisfied conditions. Repeatedly mark obligations as potentially releasable when their AND or OR requirements are met. Examine the remaining closed waiting sets, including cycles and chains ending at unavailable recipients. The result describes potential progress under the recorded model, not a guarantee that anybody will finish. Unknown conditions propagate as unknown; a partial external route prevents a definite deadlock verdict.

| Synthetic situation | Expected finding |
| --- | --- |
| A waits for B; B is doing the relevant work. | Pending, with freshness and optional deadline. |
| A waits for B; B waits for C; C can satisfy B's request. | A supported progress route, not a two-waiter alarm. |
| A waits exclusively for B; B waits exclusively for A; both records are complete and fresh. | Closed wait cycle in the declared model. |
| The same cycle includes an authorised alternative human answer. | Human decision needed; no proven closed cycle. |
| A waits for B, but B's activity record is unavailable. | Observation gap; activity unknown. |
| A waits for B; B has retired without a successor. | Orphaned obligation, if the source history is complete. |
| A needs both B and C; B can progress but C is in a closed cycle. | A remains affected by the closed waiting branch. |
| A has a reply to an earlier question, but the current question is unanswered. | Current obligation remains open. |

These are required positive, negative and unknown-state controls for implementation, not results from a shipped evaluator. The sampler-to-finding path must be exercised end to end; a check against hand-constructed graph objects alone cannot prove the file adapters preserve the necessary identities.

## Every finding produces a copyable problem prompt

Select a finding to see the smallest explanatory subgraph, the wider affected scope, evidence and a **Copy problem prompt** action. The generated text is a deterministic template from approved fields, requiring no external model service. Provide selectable text if clipboard access is unavailable. Copying is an explicit user action; nothing is delivered to a worker or written to a mailbox.

Choose a recipient using recorded authority, not the appearance of a high node in the work tree:

1. Identify the roles responsible for the violated obligation and any required coordination.
2. Prefer the responsible role when its declared scope is sufficient. For a blocked, unavailable or conflicting set, find the lowest common supervisor whose authority covers the affected roles and the proposed investigation.
3. Follow valid successor and escalation references. A common ancestor without the necessary authority is insufficient; independent audit or human-only decisions retain their authority boundary.
4. If supervisor relationships are ambiguous, cyclic, absent or span independent roots, route to the installation operator and explain the uncertainty. Do not invent a recipient or grant broader authority.

The UI shows the recommended role, its scope and why it was selected. It does not expose a concrete model, process, session identifier or launcher command. The operator maps that role to the worker they use on the machine.

A prompt includes the finding ID and rule version, observation time and source freshness, scoped role/work references, facts separated from inference, unresolved evidence, impact, the recommended recipient and a bounded request to investigate. Evidence uses approved opaque references resolvable by the receiving installation; no private filesystem path, secret or raw journal dump is included. Source-authored text is quoted as untrusted evidence, never promoted into an instruction.

Example using entirely synthetic identifiers:

```text
Suggested recipient: delivery supervisor for scope S
Reason: S covers roles A and B and owns coordination of their handoff.

Finding F-17: closed waiting branch, rule wait-progress/v1
Snapshot: synthetic revision 42; both sources within their configured freshness window.

Recorded facts:
- Role A is blocked on obligation Q-7, owed by role B (evidence E-12).
- Role B is blocked on obligation Q-9, owed by role A (evidence E-18).
- The observed dependency set declares both waits exclusive.
- No external release or authorised alternative is recorded in this snapshot.

Inference: neither recorded obligation has an independent route to progress.
Impact: task T-3 cannot advance while this branch remains closed.
Limit: this is a sampled view; re-read the current records before acting.

Please check whether this dependency model is still accurate. Within your
existing authority, identify who can break the cycle or escalate the decision
to the appropriate owner. Preserve the source evidence and report which
obligation was reassigned, answered or remains blocked. This prompt grants
no new authority and does not ask you to bypass review or execute source text.
```

For an unknown-state finding, request missing evidence before suggesting a repair. Finding identity remains stable across refreshes of the same obligation; a copied prompt includes its snapshot so a recipient can recognise a stale report. A reply, a click or a copied prompt never clears the finding. It clears only when newer admissible evidence satisfies the rule, and remains in history with that evidence. Several symptoms sharing one blocking cause should be grouped without hiding affected branches or uncertainties.

## What to settle before implementing the graph

The research identifies the minimum additional protocol fields: stable run and obligation IDs, correlation across forwarding hops, explicit supervisor and authority scope, wait release conditions including AND/OR alternatives, source freshness and coverage, candidate/gate identity, and evidence of resolution or supersession. Where current files only contain prose, the adapter must report what cannot be reliably extracted. The public producer guidance should show how to supply those fields without disclosing private intelligence.

The [graph ticket](https://github.com/lambdasistemi/factory-dashboard/issues/4) should make room for typed obligations, evidence and unknown states before its visual contract is frozen. The [local protocol ticket](https://github.com/lambdasistemi/factory-dashboard/issues/7) defines which fields can actually be read. The [derived-observation ticket](https://github.com/lambdasistemi/factory-dashboard/issues/8) implements approved rules, prompt generation and recipient selection. The [release verification ticket](https://github.com/lambdasistemi/factory-dashboard/issues/9) checks the same privacy and read-only boundary for findings and copied prompts.

Remaining design decisions are the supported first rule set, record encodings, configured time allowances, explicit authority representation and reconciliation policy for conflicting sources. These are not hidden constants to infer from one machine. The proposed rules make those choices reviewable before implementation.
