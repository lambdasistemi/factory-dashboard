<!--
Sync Impact Report
- Version change: unratified template -> 1.0.0 (initial constitution)
- Modified principles: none; established five project principles
- Added sections: Product Constraints; Development Workflow
- Removed sections: none
- Templates reviewed: plan-template.md, spec-template.md, tasks-template.md; no changes required
- Command templates: none are generated under .specify/templates/commands; prompts remain global
- Follow-up choices: application design, stack, live communication authority, and source license remain open in docs/open-questions.md
-->

# Factory Dashboard Constitution

## Core Principles

### I. The product record outranks implementation

Docs, specs, vision, and acceptance outrank implementation, always. Code is
regenerable from a good record; the record is not regenerable from code. Every
pull request that changes product behavior updates the affected reader-facing
records in the same change. User-visible acceptance is written before
implementation. When scope must shrink, reduce implementation work before
removing requirements, decisions, evidence, or acceptance records.

### II. Start with the operator's need

Describe a user, their need, and the observable benefit before naming a
mechanism. The three product questions are where the operator is needed, what
moved forward, and why it is happening. Acceptance criteria state what an
operator can see or do, including relevant refusal and unavailable states.

### III. Every meaningful item has a contextual answer path

Every meaningful dashboard item must offer direct contextual communication
with a worker who can answer the operator. A prototype may simulate a
conversation, but it must be labelled as simulation. Live worker messaging,
instruction delivery, or command execution requires separate authorization;
no such authority follows from a view, mockup, or repository scaffold.

### IV. Preserve product boundaries and open choices

The proposed overview groups decisions needing a response, items needing
attention, and changes since the last visit, with investigation through a work
tree and detail pane. This records direction, not a final visual design or
system architecture. Do not infer approval for a dashboard feature, data
source, communication backend, application framework, language, or deployment
design from bootstrap tooling or a prototype. Record undecided choices
explicitly and resolve them through a product decision before relying on them.

### V. Make evidence and limits checkable

Build and documentation gates must check the submitted content and produce
evidence a reader can understand. A placeholder command that always passes is
not a final gate. Reports distinguish local checks from hosted CI, deployed
pages, acceptance, and release. Public issues, pull requests, docs, and wiki
pages contain no credentials or private runtime records.

## Product Constraints

- The product serves factory operators reviewing work across a factory.
- The proposed opening view covers decisions needing a response, items needing
  attention, and changes since the operator's last visit.
- Operators investigate through a work tree and detail pane.
- Every meaningful item provides a direct contextual route to a worker who can
  answer. Prototype conversations remain simulated until a live integration is
  separately authorized.
- Whether the product can issue instructions or commands is undecided. No
  command backend or instruction authority is authorized by this constitution.
- Application design and implementation stack remain open. Documentation
  tooling does not settle those choices.

## Development Workflow

- Write specifications in product language. Keep implementation technology
  undecided until a recorded product decision selects it.
- Write observable acceptance before implementation and update affected docs
  in the same pull request as behavior changes.
- Use Conventional Commits for the release planner. Pull request descriptions
  answer what changed, why, how to verify, and what remains limited.
- The build gate performs the real documentation and presentation checks. Add
  tests when a feature specification requests them; do not substitute a
  passing placeholder for meaningful validation.
- Keep claims bound to the exact candidate and report local and hosted results
  separately.

## Governance

This constitution governs repository templates and product changes. A change
to these principles requires an explicit rationale, an updated Sync Impact
Report, and a review of dependent templates and reader-facing records. Version
the constitution with semantic versioning: major for incompatible principle
changes, minor for new or materially expanded rules, and patch for wording
clarifications. Record the ratification and amendment dates below. Reviewers
check each pull request against this constitution. Unresolved decisions stay
visible in `docs/open-questions.md`; implementation must not silently settle
them.

**Version**: 1.0.0 | **Ratified**: 2026-10-09 | **Last Amended**: 2026-10-09
