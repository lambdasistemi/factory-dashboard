# Product decisions

## Fixed product requirements

The dashboard is an operator-facing view of factory work. It must help answer where the operator is needed, what moved forward, and why it is happening. The proposed opening view groups decisions needing a response, items needing attention, and changes since the last visit, with investigation through a work tree and detail pane.

Every meaningful dashboard item must offer direct contextual communication with a worker who can answer. Prototype conversations are simulations only. This requirement does not authorize live worker messaging or command execution.

## Open choices

- The visual design and interaction details of the overview, work tree, and detail pane.
- Which factory records appear, how they are refreshed, and how changes are explained.
- How contextual communication reaches a worker, how replies relate to work items, and what authority a reply grants. A live backend needs a separate authorization decision.
- Whether the product may issue instructions or commands.
- The dashboard application's framework, language, and deployment design.
- The repository's source license.

## Bootstrap choices

This repository uses a documentation-only Nix and MkDocs scaffold to publish its product record. That choice does not select an application stack or dashboard behavior.
