<!--
Sync Impact Report
- Version change: 1.0.0 -> 2.0.0
- Rationale: operator replaced the attention-first opening with a graph-first product, required a released read-only foundation before interaction, and fixed public protocol/private implementation and configuration boundaries.
- Principles changed: operator experience, contextual answer sequencing, product boundaries and release evidence.
- Clarification: computable attention and other derived observations belong in the first milestone; communicating back is the next milestone.
- Added: first-release read-only sources; public role/protocol and private implementation distinction; configuration/privacy release gate; long-term milestone roadmap.
- Dependent records updated: README, overview, user stories, product decisions, roadmap, ticket drafts, privacy/configuration contract.
- Existing generic spec/plan/task templates retain their Constitution Check and acceptance sections; no template mechanism changed.
- Open: application stack, runtime support/authentication details, exact configuration/protocol versions, license, future milestone designs.
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

**Version**: 2.0.0 | **Ratified**: 2026-10-09 | **Last Amended**: 2026-10-09
