-- | Pure geometry input. No source text or private records cross the layout boundary.
module Factory.Layout (Position, Geometry, LayoutInput, nodeSize, nodeKey, edgeKey, layoutInput, titleLines) where

import Prelude
import Data.Array (mapMaybe, nub, sort)
import Data.String.CodeUnits as CU
import Factory.Domain (Graph, ScopedId(..), EdgeId(..), nodeIds, edgeIds, lookupEdge)

type Position = { x :: Number, y :: Number }
type Geometry = { nodes :: Array { id :: String, x :: Number, y :: Number }, edges :: Array { id :: String, path :: String } }
type LayoutInput = { nodes :: Array { id :: String, width :: Number, height :: Number }, edges :: Array { id :: String, sources :: Array String, targets :: Array String } }

nodeSize :: { width :: Number, height :: Number }
nodeSize = { width: 244.0, height: 126.0 }

nodeKey :: ScopedId -> String
nodeKey (ScopedId r) = show (CU.length r.namespace) <> ":" <> r.namespace <> r.key

edgeKey :: EdgeId -> String
edgeKey (EdgeId r) = show (CU.length r.source) <> ":" <> r.source <> r.key

layoutInput :: Graph -> LayoutInput
layoutInput graph =
  let
    edges = mapMaybe (lookupEdge graph) (sort (edgeIds graph))
    ids = sort (nub (nodeIds graph <> (edges >>= \e -> [ e.from, e.to ])))
  in
    { nodes: map (\id -> { id: nodeKey id, width: nodeSize.width, height: nodeSize.height }) ids
    , edges: map (\e -> { id: edgeKey e.id, sources: [ nodeKey e.from ], targets: [ nodeKey e.to ] }) edges
    }

-- | Bounded monospace lines: full original text remains in the inspector and title.
titleLines :: String -> Array String
titleLines text
  | CU.length text <= 26 = [ text ]
  | CU.length text <= 52 = [ CU.take 26 text, CU.drop 26 text ]
  | otherwise = [ CU.take 26 text, CU.take 25 (CU.drop 26 text) <> "…" ]
