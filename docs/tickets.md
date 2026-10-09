# First milestone tickets

## Story: Deliver a small, verifiable first release

As a project contributor, I take one bounded ticket, improve the runnable dashboard, and demonstrate its acceptance criteria without pulling future controls into the first release.

These tickets are filed under the [Read-only factory graph milestone](https://github.com/lambdasistemi/factory-dashboard/milestone/1) in the [roadmap](roadmap.md). GitHub tracks their implementation state, native parent/sub-issue relationships and serial dependencies. Duplicate searches found no existing issues before publication.

Each acceptance checkbox must become a directly observable browser check, contract check, integration check or release receipt. The initial sequence is serial. No implementation team is assigned by this plan. Each ticket extends the same dashboard artifact; intermediate completion does not authorise a product release.

## Open and explore the complete factory graph

[Track ticket #4](https://github.com/lambdasistemi/factory-dashboard/issues/4).

**Epic:** Explore the factory through one graph. **Label:** feat. **Dependency:** none. This is the first implementation ticket.

**Goal:** Open a runnable browser view of a complete synthetic factory and inspect its structure through the graph.

**P1 user story:** As a factory operator, I navigate the global graph and observe the work hierarchy, responsible roles and existing communication context without losing my place.

### Graph acceptance criteria

- [ ] The documented local entry point opens the connected graph as the main screen, using entirely synthetic records with no source credentials or external requests.
- [ ] Fixtures contain projects, milestones, epic and ticket issues, pull requests, role attachments and recorded communication links. Distinct relationship types are visibly distinguishable; the graph does not invent missing GitHub parentage.
- [ ] Expansion and collapse preserve stable identities and selection. Pan, zoom, fit and keyboard selection allow every fixture node and connection to be reached on supported desktop and narrow screens.
- [ ] Selecting a node or connection opens its existing context while keeping the global graph available. Inspection never writes a message or starts work.
- [ ] The graph input contract permits approved work and role fields only; worker implementation fields and arbitrary unknown payload fields are rejected rather than passed to the browser.
- [ ] Empty, missing, unknown and stale input states have distinct visible examples. Colour is accompanied by text or another non-colour indicator.
- [ ] A browser check follows project to milestone to epic to ticket to pull request and its responsible role, then returns without losing context.

### Graph non-goals

- Live GitHub or local-file integration.
- Worker questions, replies, team selection or commands.
- A table-first home screen. Derived attention and summaries are delivered by the observation ticket in this same milestone.
- Choosing or exposing concrete worker implementations.

Searched: no existing issues matched graph work or protocol/configuration work; the repository issue list was empty at planning time.

## Configure a private, read-only installation

[Track ticket #5](https://github.com/lambdasistemi/factory-dashboard/issues/5).

**Epic:** Run privately and release with evidence. **Labels:** feat, docs. **Dependency:** the graph ticket.

**Goal:** Start a portable installation from an explicit configuration, or refuse it with a useful redacted error.

**P1 user story:** As an installation operator, I provide configuration and observe which sources and access boundaries are enabled without exposing private values.

### Configuration acceptance criteria

- [ ] One versioned schema and a synthetic example document all fields described in the [configuration contract](configuration.md), including defaults and server-only versus browser-visible classification.
- [ ] Demo mode has no real credentials, file roots or repository bindings. A real installation requires explicit approved sources and access configuration.
- [ ] No host address, user, filesystem root, repository selection, role binding or credential is compiled into the application. A second synthetic installation starts with different values and no source edits.
- [ ] Secrets are resolved server-side from external references. Unknown configuration fields, unsupported versions and missing required values refuse activation without printing private values or paths.
- [ ] The runtime has no background external application traffic except reads to approved GitHub origins. Browser assets are local. Redirects, URLs in records and unapproved repositories cannot expand that access.
- [ ] Explicit local input roots are read-only, bounded and separate from dashboard-owned state; traversal and symlink escapes are refused.
- [ ] Startup and the read-only status surface distinguish invalid configuration, unavailable source and healthy source. Wider network exposure without complete access configuration is refused.

### Configuration non-goals

- A worker installer, automatic machine discovery, secret-management product or host repair tool.
- File mailboxes for outgoing questions, remote execution or provider connections.
- Real production credentials or host details in examples, tests or public reports.

Searched: no existing issues matched protocol/configuration work; the repository issue list was empty at planning time.

## Read configured GitHub work into the graph

[Track ticket #6](https://github.com/lambdasistemi/factory-dashboard/issues/6).

**Epic:** Read the two supported sources. **Label:** feat. **Dependencies:** graph and private configuration tickets.

**Goal:** Populate the running graph with work records from the repositories explicitly selected by the installation.

**P1 user story:** As a factory operator, I open the graph and observe my configured GitHub work with its actual identities and relationships.

### GitHub source acceptance criteria

- [ ] The running dashboard reads only configured repositories using the private credential reference; it exposes no mutation operation and performs no GitHub write.
- [ ] Repository, milestone, issue, parent/sub-issue and pull-request references preserve GitHub identities. A fixture with equal issue numbers in different repositories proves they never collide.
- [ ] An explicitly configured mapping associates projects and repositories and recognises epic issues without changing GitHub vocabulary or inventing missing relationships.
- [ ] Source links identify the corresponding GitHub object. Unconfigured destinations or automatic requests derived from untrusted content are refused.
- [ ] Pagination, incremental refresh, rate limits, access refusal and unavailable GitHub responses are exercised. The UI shows freshness and retains old data only with an explicit stale state.
- [ ] A read-only integration receipt binds the displayed graph to the configured test records while recording no credentials or private response bodies.

### GitHub source non-goals

- Creating or editing issues, milestones, pull requests, comments or repository settings.
- Fetching arbitrary repositories, URLs, private worker identities or external services.
- Outgoing communication or actions that resolve an observed attention finding.

Searched: no existing issues matched graph work; the repository issue list was empty at planning time.

## Read local communication records through a public protocol

[Track ticket #7](https://github.com/lambdasistemi/factory-dashboard/issues/7).

**Epic:** Read the two supported sources. **Labels:** feat, docs. **Dependencies:** graph and private configuration tickets. It follows the GitHub integration in the initial serial plan.

**Goal:** Add role activity and recorded communication to the running graph from installation-selected local files.

**P1 user story:** As a factory operator, I inspect a graph role or connection and observe the existing local communication record and its freshness without revealing the worker implementation.

### Local protocol acceptance criteria

- [ ] The repository publishes a versioned protocol contract for the file forms it supports, including journal events, liveness claims, questions, answers, inbox notes and acknowledgement references where implemented.
- [ ] Public role definitions distinguish product ownership, implementation and audit responsibilities without including provider, model, prompt, launch-command or real worker identity details.
- [ ] The documentation explains producer responsibilities and provides synthetic conforming examples. Optional worker-skill guidance demonstrates emitting those records; the dashboard does not install or enforce that skill on workers.
- [ ] Only explicitly configured files are read. Unsupported versions, malformed records, oversized input, source replacement and out-of-root references are handled with documented unavailable or refusal states.
- [ ] Working, waiting, blocked, paused, retired, unknown and stale observations have defined evidence rules. Journal completion, passed checks, acceptance and release are not treated as equivalent.
- [ ] Communication edges are supported by actual recorded references, not guessed from nearby timestamps. Selecting one shows approved context and its role endpoints.
- [ ] Private implementation fields, unapproved free text and raw filesystem locations never enter graph payloads or diagnostics. Identifiers exposed to the browser are opaque and installation-independent.
- [ ] A read-only fixture run proves that the same graph combines GitHub work with the approved local role records, with all source files unchanged.

### Local protocol non-goals

- Recreating the factory's intelligence, launching workers or inspecting process arguments.
- Writing questions, answers, acknowledgements, inbox notes or control files.
- Turning every arbitrary journal tag into a supported protocol operation.
- Scraping the whole host or requiring producers to use a particular model or agent harness.

Searched: no existing issues matched protocol/configuration work; the repository issue list was empty at planning time.

## Derive attention and information from recorded factory state

[Track ticket #8](https://github.com/lambdasistemi/factory-dashboard/issues/8).

**Epic:** Explore the factory through one graph. **Label:** feat. **Dependencies:** graph, configuration and both source tickets.

**Goal:** Extract useful read-only information from the supported graph, communication and local status records so the operator can see what needs attention and act on the machine.

**P1 user story:** As a factory operator, I notice a pending question, blocker or other evidenced condition, inspect its context and freshness, and go to the machine to address it.

### Derived observation acceptance criteria

- [ ] A documented inventory maps supported communication and status record types to useful observations: pending questions, recorded answers and acknowledgements, waiting or blocked work, role state, handoffs, activity, available history and evidence of completion, acceptance or release. Useful derivable information is included; unavailable information is explicitly identified rather than invented.
- [ ] Each derivation specifies source references, correlation rules, freshness and resolution evidence. Activity does not prove progress; silence does not prove a dead worker; a reply or acknowledgement does not by itself prove a blocker resolved.
- [ ] Attention indicators and graph-derived filters or detail views preserve the global graph and return to the relevant node or connection. Findings explain why they are shown and distinguish recorded facts, rule-based derivations and unknown state.
- [ ] Fixtures exercise a pending question, correlated answer, unresolved blocker, explicit resolution, duplicate or out-of-order events, stale or missing records, and conflicting evidence. Refresh after an external action updates findings without a dashboard write. Positive and negative controls prove that irrelevant or insufficient evidence does not create or clear attention.
- [ ] History and summaries use only available configured records, disclose retention or coverage gaps, and do not imply a complete history where none exists.
- [ ] Derived fields pass the same approved-field projection as source data. Aggregates, labels and evidence references cannot leak private worker details, raw paths or secrets.
- [ ] The interface explains that action happens on the machine in this release. It has no reply, acknowledge, dismiss, assign or resolve operation that writes to sources or conceals an unresolved finding.

### Derived observation non-goals

- Sending questions or answers, writing acknowledgements, controlling workers or resolving issues through the dashboard.
- Provider calls, speculation about worker intent, or inference beyond documented record semantics.
- Additional sources or broader file access to fill evidence gaps.

Searched: this ticket extends the graph and local protocol scope within the same first milestone; no filed issue is replaced by this planning draft.

## Verify the first release's privacy and observation boundaries

[Track ticket #9](https://github.com/lambdasistemi/factory-dashboard/issues/9).

**Epic:** Run privately and release with evidence. **Labels:** test, docs. **Dependencies:** all preceding tickets.

**Goal:** Produce an integrated release candidate with checkable evidence that the supported configuration and disclosure boundaries hold.

**P1 user story:** As an installation operator, I review the release's configuration guide and safety evidence and can distinguish what the dashboard reads, what it exposes, and what it cannot do.

### Release acceptance criteria

- [ ] A representative configured instance loads both sources, preserves the complete graph relationships, and supports read-only inspection, derived attention, status, activity and available history in the documented supported environment. A finding can be traced to evidence; a subsequent source update after an external resolution updates the finding without any dashboard write.
- [ ] Filesystem and network observations prove source files remain unchanged and external application requests are limited to approved GitHub reads. GitHub mutation attempts, unapproved origins and redirect escapes are refused.
- [ ] Secret sentinels placed in prohibited configuration and source fields do not appear in client payloads, assets, logs, errors, caches intended for export or support bundles. Tests also prove a permitted field still reaches the graph.
- [ ] Unauthenticated or out-of-scope access, traversal, symlink escape, malformed or oversized records, missing credentials and unavailable sources exercise their defined refusal or degraded states.
- [ ] A second synthetic installation changes addresses, repositories, roots and role bindings without source edits. Setup instructions explain how producers supply compliant files; they do not require a particular machine or worker implementation.
- [ ] The public artifact and documentation include synthetic examples, the source license, protocol version, supported configuration, checks performed and explicit remaining limits. No private runtime record is shipped.
- [ ] Evidence is bound to the release candidate and reviewed by the operator. Release remains blocked until the configuration and privacy review is accepted; local or hosted build success alone is insufficient.

### Release non-goals

- New views, interactive mailboxes, worker control or team selection.
- A claim of perfect safety in every environment.
- Automatically releasing when checks turn green without the required operator review.

Searched: no existing issues matched protocol/configuration work; the repository issue list was empty at planning time.

## Publishing this plan

The first milestone and its three epic issues carry the roadmap outcomes, shared privacy constraints, serial child order and shared dashboard artifact. All six tickets are linked to their epic through native GitHub sub-issue relationships. The two future milestones are also published, without speculative epics or delivery dates.
