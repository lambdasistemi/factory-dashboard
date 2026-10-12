# Public behavior signatures

Names below express responsibilities; PureScript module-qualified spellings may follow idiomatic conventions without changing these argument/result contracts.

| Operation | Explicit inputs | Output and contract |
| --- | --- | --- |
| Decode graph | raw input | Either redacted decode failures or validated graph |
| Resolve context | graph, selection | Approved selected context or explicit unavailable state |
| Derive visible graph | graph, expansion | Visible identities and typed connections with hidden-context accounting |
| Apply navigation | graph, view state, navigation action | New view state preserving stable identity and bounded viewport |
| Fit viewport | visible graph bounds, container dimensions | Finite bounded viewport, including empty/singleton cases |
| Render graph | approved graph, view state | Accessible SVG, controls and existing-context details |
| Read container size | element reference | Browser effect returning finite dimensions or explicit unavailable result |

No operation above performs GitHub calls, filesystem access, worker communication or model inference. No implementation, pseudocode or test bodies belong in this planning record.

Record ceiling: 60 lines, 6 KiB.
