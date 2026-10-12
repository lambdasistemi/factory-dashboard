# Explore the complete factory graph

Issue: https://github.com/lambdasistemi/factory-dashboard/issues/4. Parent: #10. Milestone: Read-only factory graph.

## Operator outcome

An operator opens a synthetic factory graph, understands work relationships and role attachments, selects nodes or connections for existing context, and navigates without losing the global view. This is the first runnable product slice, using PureScript and the constitution's production-quality requirements.

## Required behavior

- The initial screen is a connected graph with synthetic project, milestone, epic issue, ticket issue, pull request, role and recorded communication references. Distinguish containment, attachment and communication semantics. Missing relationships are explicitly missing, never invented.
- Stable scoped identities drive selection, expansion and collapse. Pan, zoom and fit work at desktop and narrow widths. Every fixture node and connection is reachable by keyboard; focus and state do not rely on colour alone.
- Node/edge selection displays its permitted context while the global graph remains available. Collapse must not leave invisible selected state without an explicit visible explanation or navigation route.
- Empty, missing-reference, unknown and stale states are distinct and demonstrable through synthetic scenarios.
- The boundary decoder rejects unapproved fields, private worker implementation fields, malformed records and invalid identity references according to the documented graph contract. Preserve unresolved external references as explicit observations when their shape is valid.
- Runtime assets and fixtures are local. The page makes no external requests, writes no communication record, launches no worker and holds no source credential.
- The architecture keeps decoding, domain relationships, view state, rendering and platform effects separate. Domain transitions are pure. FFI is minimal and behavior-checked.
- Local and hosted CI execute meaningful formatting, lint/static-quality, compilation, domain/boundary tests, browser checks and documentation checks. Documentation is text/diagrams only.

## Scope boundaries

No GitHub/local-file adapters, real installation configuration, implemented invariant detectors, prompt delivery, worker conversations or control. Attention/prompt implementation belongs to #8. Preserve the graph vocabulary needed by that future work without implementing speculative engines.

## Acceptance journey

Open the synthetic fixture; follow project to milestone, epic issue, ticket issue, pull request and responsible role using typed source relationships; inspect a communication edge; change selection, collapse/expand, pan/zoom/fit; return to the initial context. Repeat keyboard access and narrow-screen inspection. Invalid input is visibly refused; stale or incomplete permitted input remains honestly labelled. All assets load from the same static instance with no network dependency beyond that instance.

## Record ceiling

This specification is limited to 100 lines and 10 KiB. Requirements above are acceptance-blocking by explicit ticket contract, including privacy and usable navigation; no financial execution is involved.

## Operator review: surrounding interface

The operator accepted the ELK graph quality and rejected the surrounding interface as technical and unusable. The control-room prototype remains the reference for the product experience: selections explain the situation and lead to a useful next step while the global graph remains available.

The primary panel shows the work summary, status, named role responsibilities and connected work. Source identities, provenance and raw timestamps belong in a closed technical disclosure. Developer examples are absent from the ordinary interface and are enabled only by the explicit test URL. Labels use the operator's language. Old or missing information can be shown directly, but must not be presented as an inferred decision or invariant violation.

Every selected work item can prepare a question carrying its title, summary, status and recorded responsibilities. The operator copies that question into an existing worker session; the dashboard sends no message and fabricates no answer. Missing responsibility remains explicit. Live conversations retain their later-milestone scope.

### Control-room correction

The operator named the JavaScript factory dashboard as the implementation reference. Copy its split panes, summary strip, Epics/Workers toggles, lane and attention filters, and stable branch highlighting; preserve the approved ELK geometry. Findings are the central operator outcome, with concrete evidence, candidate recipient, manual prompt and green condition. No fabricated progress or inferred wait dependency is allowed.

This graph-only input supports reference checks and observation-gap findings. The A–H protocol catalog must remain unavailable until its required facts are supplied. This slice does not claim live factory diagnosis or substitute status strings for fresh claims.
