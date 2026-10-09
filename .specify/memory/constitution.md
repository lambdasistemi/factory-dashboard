<!--
Sync Impact Report
- Version change: 2.0.0 -> 2.1.0
- Rationale: operator requires production-quality structure and code regardless of language.
- Added principle VI: explicit architecture boundaries, deterministic domain rules, conditional strict TypeScript discipline, reproducible builds and executable quality gates.
- Existing graph-first, read-only, public protocol/private implementation and operator release-approval principles remain in force.
- Dependent records updated: implementation tickets and product decisions. Existing generic spec/plan/task Constitution Check sections remain applicable without changing template mechanisms.
- Open: application stack, runtime support/authentication details, configuration/protocol encodings, license and rule-set acceptance.
-->

# Factory Dashboard Constitution

## Core Principles

### I. The product record outranks implementation

Docs, specs, vision, and acceptance outrank implementation, always. Code is regenerable from a good record; the record is not regenerable from code. Every behavior change updates its reader-facing record in the same change. Write user-visible acceptance before implementation. Reduce implementation scope before removing requirements, decisions or evidence.

### II. The graph is the product's core

The opening interface is a connected, global factory graph. Preserve actual GitHub entities and relationships, and attach the public factory role and communication vocabulary. Selection exposes context while preserving the global view. Read-only views of attention, status, activity and available history derive from that graph and belong in the first milestone. Extract useful information supported by approved communication and local status records, with evidence and freshness.

### III. Release observation before interaction

The first milestone reads exactly two source classes: configured GitHub work records and configured local communication files. It writes to neither source, sends no worker messages, launches no workers and calls no model services. Unknown, stale and unavailable observations never masquerade as successful or idle work.

Initially the operator notices attention in the dashboard and acts on the machine. The next milestone enables communicating back to address findings. The long-term goal includes contextual conversations, team selection and authorised factory operation. Keep these goals visible as milestones. Define their detailed design and acceptance later; no implementation or control authority follows from documenting that destination.

### IV. Publish coordination, keep implementation private

The supported protocol, file forms, role definitions and their semantics are public product design. Worker implementations, providers, models, prompts, launch commands, credentials and concrete installation bindings stay private. No private implementation information enters a public example or browser payload merely because it exists in a source record.

Configuration supplies addresses, ports, approved repositories, file locations, role bindings, access policy and secret references. Producers supply compliant communication files. The dashboard may suggest skills, but does not install, discover or repair the factory.

### V. Configuration and privacy are release conditions

A versioned configuration contract must define every field, default, validation rule and disclosure class. The browser receives a permitted graph projection, never the private server configuration or raw runtime records. The runtime's only external application access is configured GitHub reads; browser assets are locally served.

Acceptance must demonstrate source read-only behavior, permitted network access, private access controls, data minimisation, input refusal, redacted diagnostics and portability to a second synthetic installation. The operator reviews the evidence before release. A passing local build or hosted check does not by itself approve a release. State supported environments and residual limits; do not claim perfect safety.

### VI. Production-quality structure is mandatory

Factory Dashboard is production software. Maintainable architecture, correctness and operational clarity are acceptance requirements from the first runnable graph onward, regardless of language. A small feature scope must still have a deliberate design. Prototype code enters the product only after it meets the same contracts and checks.

Separate source adapters and runtime input validation, the domain graph and obligation model, invariant evaluation, approved-data projection and prompt generation, and UI rendering through explicit interfaces. Keep domain rules deterministic and independently testable; inject time and external effects. Filesystem, network, credentials and private runtime configuration stay outside domain logic and browser modules. Dependencies have a documented direction with no circular module dependencies or hidden global state. Organise by coherent responsibilities, keeping interfaces and abstractions as small as the real requirements permit; this does not require separate services or packages for every responsibility.

If TypeScript is selected, enable strict compiler checking including unchecked indexed access and exact optional property handling. Model states, scoped identities and failures explicitly, using discriminated unions where appropriate. Treat external input as unknown until runtime validation succeeds; compile-time types never establish trust in GitHub or file payloads. Unchecked casts, any, non-null assertions and suppressed diagnostics require a narrow documented boundary justification and behavior checks; they cannot bypass the privacy or protocol contract.

Every behavior-changing PR must pass the applicable formatter, linter, type checker, build and meaningful tests for the selected stack. The first implementation establishes those executable local and hosted CI gates. Test public behavior and module boundaries: valid, invalid, stale, missing and conflicting records; exact correlation; parser-to-graph-to-finding-to-prompt flows; privacy projection; and keyboard-accessible UI behavior. Demonstrate both a triggering fault and a healthy counterexample for every detector, plus insufficient-evidence handling. Do not substitute mocked internal agreement, snapshots alone, a placeholder gate or unexecuted tests for observable evidence.

Pin dependencies and retain lockfiles, document reproducible build/run commands and supported environments, make failures actionable without leaking private data, and document the architecture and public contracts with the code. Review changes for responsibility boundaries, complexity, duplication, dependency cost and error handling. Runtime work must have bounded input, resource and failure behavior. No merge or release may waive these requirements silently; any proposed exception requires an explicit rationale, risk, compensating evidence and operator acceptance before use.

## Product Constraints

- The first implementation ticket delivers the runnable graph with synthetic inputs.
- Only the first milestone is decomposed into epics and tickets at this planning stage.
- Communication and control are later milestones, after the read-only foundation is accepted and released.
- Attention and other computable read-only information are included in the first milestone and derive from graph context; responding through the dashboard is deferred.
- GitHub vocabulary remains GitHub's; the project defines its own additional role and communication vocabulary.
- The application stack and source license remain open. Documentation tooling does not settle either.

## Development Workflow

Describe the user, the observation or action, the successful result and relevant refusals before choosing a mechanism. Keep specs and acceptance bound to the actual candidate. Public issues and pull requests explain what changes, why, how to verify, and what remains limited. They may document public roles and protocol design but must not include private worker or host records.

Use the existing documentation and presentation checks for product records. Implementation tickets add meaningful checks for their specified behavior. No placeholder check or self-reported completion replaces observable evidence. Do not automatically expand the team or start later milestones from this roadmap.

## Governance

This constitution governs project templates and product changes. Amend it with a rationale, updated impact report and review of dependent records. Major versions change principles incompatibly, minor versions add material rules, and patch versions clarify wording. Keep unresolved decisions visible in `docs/open-questions.md`.

**Version**: 2.1.0 | **Ratified**: 2026-10-09 | **Last Amended**: 2026-10-09
