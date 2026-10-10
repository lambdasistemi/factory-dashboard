# Delivery plan

## Decisions

Use PureScript and Halogen with an SVG graph and plain CSS. Avoid a graph-library dependency for this bounded fixture; revisit through a recorded requirement if measured usability demands it. Use the existing project-family Nix, Spago and esbuild conventions with supported pinned versions. Do not copy obsolete Node versions or unrelated crypto/WASM infrastructure from example repositories.

The domain graph and state transitions are pure. A strict boundary decoder constructs approved graph values before rendering. Pure view state carries selection, visible/expanded identities and viewport state; browser effects stay in a small platform boundary. Synthetic fixtures exercise ordinary and incomplete states. Layout and node/edge labels must make relationship types readable without implying that every work relation is hierarchical.

## One runnable vertical slice

Establish the toolchain and executable CI checks, implement the input/domain contract, and deliver the complete synthetic graph experience with its tests and user guide. Keep RED and intermediate implementation commits local until the persistent auditor has approved checkpoints; publish a single bisect-safe accepted implementation commit plus planning records.

## Evidence

Two authorised existing worker seats independently propose check sets before implementation. The coordinator freezes membership, semantics and resource scope. The implementer supplies executable failure controls, then implementation evidence. The persistent auditor reviews committed decisions and receipts through the coordinator, without executing gates or contacting the implementer. A setup failure is never called behavioral RED.

Required check categories: docs, format, static quality, compile/bundle, domain and boundary semantics, browser behavior/network boundary. Prefer independently runnable Nix checks and mirror them in hosted CI. The final browser receipt binds the built artifact to its source revision. Publish a static app preview through the existing PR-preview mechanism, retaining documentation access. Public fixtures and outputs contain no real runtime identity.

## Delivery boundaries

No new dependencies or runtime services beyond the scope justified by this graph. No speech tooling. No provider calls from the product. Operator acceptance still precedes first product release; this ticket is an unreleased milestone increment.

## Record ceiling

80 lines, 8 KiB. Runtime briefs, gate versions, private receipts and staffing records stay outside Git.
