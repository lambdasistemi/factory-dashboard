# Module responsibilities

| Responsibility | Owns | May depend on |
| --- | --- | --- |
| Graph domain | Scoped identities, node/edge variants, relationship validation and queries | Pure data libraries only |
| Input decoding | Approved input fields, shape refusal, construction of domain values | Graph domain |
| Graph view state | Selection, expansion, navigation and viewport transitions | Graph domain |
| Synthetic scenarios | Explicit approved fixtures and incomplete/empty/stale scenarios | Input contract |
| Halogen graph view | SVG graph, controls, keyboard interaction, details and status | Domain, view state, approved scenarios, platform boundary |
| Platform boundary | DOM sizing/events and minimal clipboard-free browser interop needed here | Browser APIs; no domain policy |
| Build and verification | Reproducible bundle, independent checks, local static preview | Product public interfaces |

Dependencies flow towards the domain; no circular modules, hidden globals or IO in domain transitions. Data fields are defined in data-model.md; public behavior signatures in functions-model.md. Promote shared helpers only when actual consumers justify them. Module naming and private helper placement belong to the implementer within these boundaries.

Record ceiling: 60 lines, 6 KiB.
