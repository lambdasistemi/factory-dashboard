# Data contract

| Value | Required meaning |
| --- | --- |
| Scoped node identity | Stable across refresh/render; distinguishes repository/source namespace and entity identity |
| Node kind | Project, milestone, epic issue, ticket issue, pull request or role; roles omit implementation identity |
| Node display data | Approved title/summary, status and source reference; no raw private payload |
| Edge identity | Stable source-qualified reference and distinct endpoints |
| Relationship kind | Work membership/parent relation, role attachment or recorded communication; never inferred from proximity |
| Observation quality | Known, unknown, stale or missing reference, with explicit approved provenance/freshness metadata |
| Graph | Validated node and edge collections; duplicate identities rejected; permitted unresolved endpoints represented explicitly |
| Selection | None, node or edge; changes preserve stable graph identity and accessible focus |
| Expansion | Identity-based visible detail/branch state with a defined treatment of collapsed selection |
| Viewport | Finite bounded zoom and translation; fit handles empty and singleton graphs |
| Decode failure | Redacted structured reason for malformed/unknown/forbidden fields or invalid identity shape |

All public fields must be enumerated by the decoder and documented. Optional values retain missing versus unknown meaning; no arbitrary object payload crosses into the view. Source-like text is data and cannot create executable HTML or an automatic external fetch. Additional field choices must preserve this contract and be recorded before use.

Record ceiling: 70 lines, 7 KiB.
