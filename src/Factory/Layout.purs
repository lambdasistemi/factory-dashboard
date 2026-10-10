-- | Deterministic layout for the synthetic graph: containment defines
-- | depth, roles sit in the row of the record they attach to, and
-- | unresolved external endpoints get their own column so a missing
-- | reference is visible in the graph itself. Layout is pure: same graph,
-- | same positions.
module Factory.Layout
  ( Position
  , nodeSize
  , layoutGraph
  ) where

import Prelude

import Data.Array
  ( filter
  , head
  , length
  , mapMaybe
  , mapWithIndex
  , nub
  , snoc
  , uncons
  , sort
  )
import Data.Foldable (maximum)
import Data.Int (toNumber)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe, isJust)
import Data.Set as Set

import Factory.Domain
  ( Edge
  , Graph
  , Node
  , NodeKind(..)
  , RelationshipKind(..)
  , ScopedId
  , containmentParent
  , edgeIds
  , lookupEdge
  , lookupNode
  , nodeIds
  )

type Position =
  { x :: Number
  , y :: Number
  }

-- | Fixed node box size shared by layout and rendering.
nodeSize :: { width :: Number, height :: Number }
nodeSize = { width: 150.0, height: 44.0 }

columnStep :: Number
columnStep = nodeSize.width + 70.0

rowStep :: Number
rowStep = nodeSize.height + 92.0

allEdges :: Graph -> Array Edge
allEdges graph = mapMaybe (\id -> lookupEdge graph id) (edgeIds graph)

nodePresent :: Graph -> ScopedId -> Boolean
nodePresent graph id = isJust (lookupNode graph id)

depthOf :: Graph -> ScopedId -> Int
depthOf graph = walk Set.empty 0
  where
  walk visited acc id = case containmentParent graph id of
    Nothing -> acc
    Just parent
      | parent `Set.member` visited -> acc
      | otherwise -> walk (Set.insert parent visited) (acc + 1) parent

-- | The row of a node: containment depth for work records, the depth of
-- | the attached work record for roles, zero for orphans and unattached
-- | roles.
rowOf :: Graph -> Node -> Int
rowOf graph node = case node.kind of
  Role -> case head (filter attachesThis (allEdges graph)) of
    Just e -> depthOf graph e.from
    Nothing -> 0
  _ -> depthOf graph node.id
  where
  attachesThis e = e.kind == AttachesRole && e.to == node.id

-- | Assign a position to every node identity in the graph, plus one ghost
-- | column position per distinct unresolved external endpoint. Ordering is
-- | derived from record order and identity, so the layout is stable across
-- | renders.
layoutGraph
  :: Graph
  -> { nodes :: Array { id :: ScopedId, pos :: Position }
     , ghosts :: Array { id :: ScopedId, pos :: Position }
     }
layoutGraph graph =
  let
    nodesInOrder = mapMaybe (lookupNode graph) (nodeIds graph)
    rows = buildRows graph Map.empty nodesInOrder
    rowNumbers = Set.toUnfoldable (Map.keys rows) :: Array Int
    widths = map (\r -> length (rowNodes r rows)) rowNumbers
    widest = fromMaybe 0 (maximum widths)
    placed = placeRows rows rowNumbers
    ghosts = placeGhosts graph ((toNumber widest + 1.0) * columnStep)
  in
    { nodes: placed, ghosts }

type Rows = Map Int (Array Node)

rowNodes :: Int -> Rows -> Array Node
rowNodes r rows = fromMaybe [] (Map.lookup r rows)

buildRows :: Graph -> Rows -> Array Node -> Rows
buildRows graph rows nodes = case unconsOf nodes of
  Nothing -> rows
  Just { head: node, tail } ->
    buildRows graph (Map.alter (appendNode node) (rowOf graph node) rows) tail
  where
  appendNode node Nothing = Just [ node ]
  appendNode node (Just arr) = Just (snoc arr node)

unconsOf :: forall a. Array a -> Maybe { head :: a, tail :: Array a }
unconsOf = uncons

placeRows :: Rows -> Array Int -> Array { id :: ScopedId, pos :: Position }
placeRows rows rowNumbers = case unconsOf rowNumbers of
  Nothing -> []
  Just { head: r, tail } ->
    placeRows rows tail
      <> mapWithIndex
        ( \i node ->
            { id: node.id
            , pos: { x: toNumber i * columnStep, y: toNumber r * rowStep }
            }
        )
        (rowNodes r rows)

placeGhosts :: Graph -> Number -> Array { id :: ScopedId, pos :: Position }
placeGhosts graph ghostX =
  mapWithIndex place absentEndpoints
  where
  absentEndpoints =
    sort
      ( nub
          ( mapMaybe
              ( \e ->
                  if not (nodePresent graph e.to) then Just e.to
                  else if not (nodePresent graph e.from) then Just e.from
                  else Nothing
              )
              (allEdges graph)
          )
      )

  place idx endpoint =
    { id: endpoint
    , pos:
        { x: ghostX
        , y: toNumber (referenceDepth endpoint) * rowStep + toNumber idx * 56.0
        }
    }

  referenceDepth endpoint = case head (filter references (allEdges graph)) of
    Just e -> depthOf graph (if e.to == endpoint then e.from else e.to)
    Nothing -> 0
    where
    references e = e.to == endpoint || e.from == endpoint
