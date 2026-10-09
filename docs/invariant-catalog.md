# From broken expectations to problem prompts

## Story: Hand the problem to someone who can address it

As a factory operator, I see a branch needing attention, copy a complete problem prompt, and send it to the recommended supervisor without having to diagnose the underlying graph myself.

The first milestone's practical output is an evidence-backed request that can improve the factory's state. Graph inspection remains available, but understanding every edge is not a prerequisite to using the finding. The dashboard prepares the request locally; the operator delivers it. Automatic conversations remain the next milestone.

This page translates the operator's A–H findings into proposed detection and prompt contracts. The wider [invariant research](graph-invariants.md) explains sampling, correlation, authority and unknown states.

## Reported observations, not a new live census

The operator supplied the following results during planning. Their sampling time, scope, source completeness and detector implementation were not supplied with the table, and these counts have not been independently reproduced here. They are research inputs, not current dashboard measurements. Private lane and worker names are omitted.

| Rule | Operator-reported result | Interpretation to verify |
| --- | --- | --- |
| A: unanswered questions and unavailable parents | 16 seats; nine share one paused epic owner. | A shared coordination problem may explain many findings. Distinguish intentional pause from expired evidence. |
| B: a supervisor waiting for children without a viable child | No cases reported. | Zero is not a pass until relevant coverage and a positive detector control are known. |
| C: expired WORKING claims | Seven seats. | The activity claim is stale; actual activity remains unverified. |
| D: blocked seats without claims | Two seats. | The required observation is missing; do not guess the activity state. |
| E: working lanes containing only WAITING seats | Three lanes. | Check what the lane's working label promises and whether membership is complete. |
| F: open children without presence or explicit pause | Five lanes, containing 22 open children. | Distinguish dispatched unfinished work from an undispatched backlog. |
| G: waiting chains with unexplained ends | Eight chains; no cycles reported. | Missing release paths matter even without a cycle. |
| H: completed seats retaining open questions | One example has six open questions; the total was not supplied. | Check for transferred, cancelled, superseded or unresolved obligations. |

These populations can overlap. Do not sum the rows into a count of distinct problems, and do not treat all affected branches as equally urgent.

## A: Questions need an accountable answer route

An open question needs a responsible recipient with a usable answer route, or a recorded escalation, delegation or intentional suspension covering that obligation. A fresh WAITING claim can be consistent with a parent listening for questions. A pause is an authority fact; an expired claim is an observation gap. Neither justifies automatically waking or replacing the parent.

**Prompt recipient:** the parent's supervisor with authority over the affected obligations; otherwise the operator. Group questions sharing the same failed route and scope.

**Prompt request:** revalidate the questions and the parent's state; identify which are covered by the pause, already answered or delegated; arrange a permitted answer route or request the required decision. Report each obligation's disposition. Never infer permission to resume a deliberately paused branch.

**Control cases:** a freshly listening parent; an authorised pause covering the questions; a delegated answer; an expired parent claim; an unrelated answer that must not clear a question.

## B: Waiting for children needs a relevant release path

This rule applies to an explicit blocking wait for child output, not every supervisor listening on its channels. One present child is insufficient if it cannot produce the awaited result. A child that is working on the relevant obligation, or a recorded external or human release condition, can establish a plausible route. AND waits require every prerequisite; OR waits need a valid alternative.

**Prompt recipient:** the waiting supervisor if it can resolve the delegation, otherwise the lowest common authorised supervisor of the blocking set.

**Prompt request:** identify the exact child output being awaited and who can still produce it; reconcile delivery or ownership where permitted, or escalate the missing prerequisite. Request missing evidence when the path cannot be established.

**Control cases:** a listener with no blocked task; a relevant working child; an unrelated working child; an AND wait with only one viable prerequisite; a human decision that legitimately releases the branch.

## C: A WORKING claim has a validity interval

After its configured lease expires, a WORKING claim cannot support a current working badge. That is a definite freshness defect in the observation, not proof that execution stopped. Clock skew, source read failures, superseding claims and sampling delay must be considered.

**Prompt recipient:** the role's supervisor or the configured producer owner when the evidence identifies a reporting failure.

**Prompt request:** check actual activity through the recipient's authorised means; restore accurate reporting or record the correct state. Renew a working claim only after verification. Do not restart work merely to remove the warning.

**Control cases:** just inside and outside the validity interval; a newer valid claim; future-dated or invalid time; a failed source read; an intentional pause whose protocol has no expiring lease.

## D: A blocked assignment needs its required state record

For a dispatched, unfinished assignment whose protocol requires a state claim, a missing claim is a coverage defect. An arbitrary old claim is not enough to make the role healthy: freshness and applicability still matter. Some source protocols may not provide claims; show that limitation rather than inventing one.

**Prompt recipient:** the assignment's supervisor, with escalation to the source owner if the input is unavailable.

**Prompt request:** establish whether the role is working, waiting, intentionally paused or handed off, and arrange the appropriate durable record under the existing protocol. Reconcile the original blocker separately.

**Control cases:** a legitimate blocked-and-waiting role; a claim for the wrong run; an expired claim; unsupported claim format; an already retired assignment.

## E: A lane label must match the state it promises

Separate **active work scope** from **currently observed execution**. An active lane can legitimately consist entirely of waiting roles. If the UI claims that execution is happening now, it needs relevant fresh evidence; if coverage is incomplete, show unknown. A manually reported working label that disagrees with sampled evidence is a source disagreement, not permission to overwrite the source.

**Prompt recipient:** the lane owner if the discrepancy comes from its records; the dashboard/source owner if aggregation or mapping is wrong.

**Prompt request:** reconcile the label with the awaited work and evidence. Identify an external dependency, deliberate pause or missed handoff if one explains the wait. If the issue is presentation only, correct the interpretation rather than inventing activity.

**Control cases:** an active lane awaiting review; a running task with fresh evidence; stale membership; a task wrongly included from another lane; a WORKING claim for unrelated work.

## F: Dispatched unfinished children retain supervision

Open GitHub issues alone do not require running seats. For work explicitly dispatched and still unfinished, there must be an accountable supervisor, a valid successor/handoff, or an authorised pause covering the affected scope. Absence of a fresh claim means supervision is unverified unless stronger evidence establishes that it ended.

**Prompt recipient:** the nearest recorded ancestor with authority to reconcile those assignments, otherwise the operator.

**Prompt request:** classify each child as backlog, dispatched, completed, transferred or intentionally paused; establish ownership for the remaining obligations within authority. Do not launch new workers or reactivate paused work merely because an issue is open.

**Control cases:** an undispatched backlog; an intentionally paused lane; a completed child with a still-open tracking issue; an orphaned dispatched assignment; missing observation coverage.

## G: A blocking chain needs an explained end

Follow only actual blocking dependencies, not every communication edge. A chain can end at relevant working activity, a human decision, an external check, a timer or a valid pause/wake condition. Reaching a desk is not sufficient by itself: identify the decision or obligation it owes. A waiting auditor may be listening normally, or may need an undelivered checkpoint; its role name does not settle the question.

A closed cycle of exclusive waits has no declared route to progress. Ordinary two-way communication and cycles with valid alternatives are not deadlocks. With incomplete records the outcome is an unexplained route, not a proven deadlock.

**Prompt recipient:** the lowest supervisor with authority over the complete blocking set, or the owner of the terminal human/external obligation when that is sufficient.

**Prompt request:** identify the terminal missing deliverable or decision and reconcile the handoff or escalation. For a genuine cycle, obtain an authorised way to break it. Preserve unknowns and inspect current state before acting.

**Control cases:** a viable multi-level chain; a closed exclusive cycle; a cycle with a human alternative; a missing terminal claim; an auditor waiting on a checkpoint already delivered but not acknowledged.

## H: COMPLETE does not erase open obligations

COMPLETE ends an assignment; it need not mean every task succeeded. Every unresolved question must be answered, explicitly cancelled or superseded, or handed off with a recorded accountable recipient and required acknowledgement. Archived question files are history, not automatically open questions. Merely having an answer file is not enough either: exact correlation and applicable disposition matter.

**Prompt recipient:** the completing role's supervisor or an already accepted successor. Do not ask a retired role to resume itself.

**Prompt request:** reconcile the remaining question ledger against answers and handoff records. Preserve historical files. Record justified closure or transfer, and escalate anything still ownerless. Do not auto-answer, delete questions or mark them resolved to improve the count.

**Control cases:** a successful correlated answer; an authorised cancellation; a capacity handoff accepted by a successor; an unacknowledged transfer; an unrelated answer; historical retained question files.

## The operator sees a short action, the recipient gets the detail

Each finding card needs only a plain-language problem, affected scope, observation age and recommended recipient, followed by **Copy problem prompt**. Expandable graph context and evidence support investigation without requiring it before copying. Distinguish "needs a decision", "broken coordination" and "cannot verify state" in language, not only colour.

The copied prompt carries the diagnosis or uncertainty, evidence references, the bounded investigation and possible repair steps within existing authority, and the expected reply. That reply should identify the finding, current evidence, dispositions of affected obligations, changes actually made and anything still needing a higher decision. Successful copying is not successful resolution. Only newer admissible source records can resolve the finding on the next sample.

Group findings by shared causal evidence, scope and recipient. For example, several questions with the same paused answer route can produce one coordination prompt listing their separate obligations. Causation remains a hypothesis until supported; preserve individual findings and do not group merely because timestamps are close. Route ambiguous or human-only decisions to the operator rather than repeatedly recommending an unavailable recipient.

## Example prompt for a shared paused answer route

This template uses synthetic references. A real prompt substitutes only permitted graph fields and evidence references, including rule version and source coverage. It never includes private implementation details, credentials, raw paths or untrusted source text as executable instructions.

```text
To: supervisor for scope S
Finding: A-17, answer route unavailable; sampled revision 42
Why you: your recorded authority covers the affected parent and assignments.

Observed: questions Q-1, Q-2 and Q-3 remain unresolved in the sampled records.
Their answer recipient is paused under decision P-4. Evidence: E-1 to E-5.
No delegated answer route or question-specific suspension is recorded.
Coverage: all three question streams read successfully; the pause is recorded.
Uncertainty: records may have changed since this snapshot; do not assume intent.

Please:
1. Re-read the current questions, answers, handoffs and pause authority.
2. Establish which obligations the pause covers and whether an authorised
   delegate or existing answer already addresses each question.
3. Within your existing authority, arrange the missing disposition or answer
   route. If a human decision is needed, escalate that decision explicitly.
4. Preserve the pause unless its authorised owner permits a change.

Report the finding ID, current evidence, disposition of each question,
any changes actually made, and remaining decision/owner. Do not mark a
question resolved merely because this prompt was received. This request
provides context and grants no new authority.
```

## Acceptance of the first rule set

Treat A–H as priority candidates for the first milestone, alongside exact correlation and candidate-bound acceptance from the broader research. Freeze rule meanings and input requirements before calling a detector complete. Every implemented rule needs a triggering fixture, a healthy counterexample, an insufficient-evidence case, a prompt-content check and a recipient-routing check through the real configured-file-to-graph path. A zero-case run must report coverage and show that a seeded matching case is detected.

Prompt checks must prove the request is useful without inspecting the graph first, preserves uncertainty and authority, excludes prohibited fields, and names the evidence that would demonstrate resolution. No automatic delivery, acknowledgement, dismissal, mailbox write or worker restart belongs in this milestone.
