-- | Pure view state: selection, expansion and viewport transitions.
-- | Domain identity is stable across every transition, the viewport stays
-- | finite and bounded, and a collapsed selection always resolves to an
-- | explicit explanation with a navigation route instead of silently
-- | disappearing.
module Factory.ViewState
  ( Selection(..)
  , Expansion(..)
  , emptyExpansion
  , collapse
  , expand
  , isCollapsed
  , Viewport
  , initialViewport
  , scaleBounds
  , panBounds
  , Dimensions(..)
  , Bounds
  , Navigation(..)
  , applyNavigation
  , fitViewport
  , ViewState
  , initialViewState
  , VisibleGraph
  , deriveVisible
  , EndpointName(..)
  , ContextView(..)
  , resolveContext
  ) where

import Prelude

import Data.Array (filter, length, mapMaybe)
import Data.Foldable (sum)
import Data.Maybe (Maybe(..), fromMaybe, isJust)
import Data.Set (Set)
import Data.Set as Set

import Factory.Domain
  ( Edge
  , EdgeId
  , Graph
  , Node
  , ScopedId
  , attachedRoles
  , communications
  , containmentChildren
  , containmentParent
  , edgeIds
  , kindLabel
  , lookupEdge
  , lookupNode
  , nodeIds
  , relationLabel
  )

data Selection
  = NoSelection
  | NodeSelected ScopedId
  | EdgeSelected EdgeId

derive instance eqSelection :: Eq Selection

-- | Identity-based branch state. Collapsing a node hides its containment
-- | subtree; identities stay stable so selection survives.
newtype Expansion = Expansion (Array ScopedId)

derive instance eqExpansion :: Eq Expansion

emptyExpansion :: Expansion
emptyExpansion = Expansion []

collapse :: ScopedId -> Expansion -> Expansion
collapse id (Expansion arr)
  | id `elemOf` arr = Expansion arr
  | otherwise = Expansion (arr <> [ id ])

expand :: ScopedId -> Expansion -> Expansion
expand id (Expansion arr) = Expansion (filter (_ /= id) arr)

isCollapsed :: ScopedId -> Expansion -> Boolean
isCollapsed id (Expansion arr) = id `elemOf` arr

elemOf :: ScopedId -> Array ScopedId -> Boolean
elemOf id arr = length (filter (_ == id) arr) > 0

-- | Finite, bounded viewport over the graph plane.
type Viewport =
  { tx :: Number
  , ty :: Number
  , scale :: Number
  }

initialViewport :: Viewport
initialViewport = { tx: 0.0, ty: 0.0, scale: 1.0 }

scaleBounds :: { min :: Number, max :: Number }
scaleBounds = { min: 0.25, max: 4.0 }

panBounds :: { absTx :: Number, absTy :: Number }
panBounds = { absTx: 4000.0, absTy: 4000.0 }

data Dimensions
  = Dim { width :: Number, height :: Number }
  | Unavailable

derive instance eqDimensions :: Eq Dimensions

-- | Content bounds of the visible graph, in graph coordinates.
type Bounds =
  { minX :: Number
  , minY :: Number
  , maxX :: Number
  , maxY :: Number
  }

data Navigation
  = PanBy { dx :: Number, dy :: Number }
  | ZoomBy Number
  | FitToGraph
  | ResetView

derive instance eqNavigation :: Eq Navigation

clampN :: Number -> Number -> Number -> Number
clampN lo hi v
  | v < lo = lo
  | v > hi = hi
  | otherwise = v

-- | Apply one navigation action. Results are always finite and clamped to
-- | the documented bounds; out-of-range requests are clamped, never
-- | propagated.
applyNavigation :: Dimensions -> Maybe Bounds -> Viewport -> Navigation -> Viewport
applyNavigation dims bounds v = case _ of
  PanBy { dx, dy } ->
    v
      { tx = clampN (-panBounds.absTx) panBounds.absTx (v.tx + dx)
      , ty = clampN (-panBounds.absTy) panBounds.absTy (v.ty + dy)
      }
  ZoomBy factor ->
    v { scale = clampN scaleBounds.min scaleBounds.max (v.scale * factor) }
  ResetView -> initialViewport
  FitToGraph -> fitViewport bounds dims v

-- | Fit the visible graph into the container. An empty graph keeps the
-- | initial viewport; a singleton graph centers on the single node at
-- | scale one; an unavailable container keeps the current scale and only
-- | recentres translation to zero.
fitViewport :: Maybe Bounds -> Dimensions -> Viewport -> Viewport
fitViewport mbBounds dims v = case mbBounds of
  Nothing -> initialViewport
  Just b -> case dims of
    Unavailable -> v { tx = 0.0, ty = 0.0 }
    Dim d ->
      let
        contentW = b.maxX - b.minX
        contentH = b.maxY - b.minY
      in
        if contentW <= 0.0 && contentH <= 0.0 then
          { tx: d.width / 2.0 - b.minX
          , ty: d.height / 2.0 - b.minY
          , scale: 1.0
          }
        else
          let
            scaleW = if contentW <= 0.0 then top else d.width / contentW
            scaleH = if contentH <= 0.0 then top else d.height / contentH
            scale = clampN scaleBounds.min scaleBounds.max (min scaleW scaleH)
            offX = (d.width - contentW * scale) / 2.0
            offY = (d.height - contentH * scale) / 2.0
          in
            { tx: offX - b.minX * scale
            , ty: offY - b.minY * scale
            , scale: scale
            }

type ViewState =
  { selection :: Selection
  , expansion :: Expansion
  , viewport :: Viewport
  }

initialViewState :: ViewState
initialViewState =
  { selection: NoSelection
  , expansion: emptyExpansion
  , viewport: initialViewport
  }

nodePresent :: Graph -> ScopedId -> Boolean
nodePresent graph id = isJust (lookupNode graph id)

edgesOfGraph :: Graph -> Array Edge
edgesOfGraph graph = mapMaybe (\id -> lookupEdge graph id) (edgeIds graph)

-- | True when some containment ancestor of the identity is collapsed.
-- | Cycle-guarded: a malformed cycle simply stops the walk.
hiddenUnder :: Graph -> Set ScopedId -> ScopedId -> Boolean
hiddenUnder graph collapsed = walk Set.empty
  where
  walk visited id = case containmentParent graph id of
    Nothing -> false
    Just parent
      | parent `Set.member` visited -> false
      | parent `Set.member` collapsed -> true
      | otherwise -> walk (Set.insert parent visited) parent

-- | The graph as the viewer may see it after expansion state is applied.
-- | A collapsed node stays visible as its own handle; only its containment
-- | subtree hides, and the hidden count is reported, never guessed.
type VisibleGraph =
  { nodes :: Array Node
  , edges :: Array Edge
  , hiddenCount :: Int
  , unresolved :: Array { edge :: Edge, endpoint :: ScopedId }
  }

deriveVisible :: Graph -> Expansion -> VisibleGraph
deriveVisible graph (Expansion collapsedArr) =
  let
    collapsed = Set.fromFoldable collapsedArr
    allIds = nodeIds graph
    visibleIds = filter (\id -> not (hiddenUnder graph collapsed id)) allIds
    visibleSet = Set.fromFoldable visibleIds
    visibleNode id = (id `Set.member` visibleSet) || not (nodePresent graph id)
    allEdges = edgesOfGraph graph
    visibleEdges = filter (\e -> visibleNode e.from && visibleNode e.to) allEdges
    unresolved =
      map (\e -> { edge: e, endpoint: e.to })
        (filter (\e -> e.from `Set.member` visibleSet && not (nodePresent graph e.to)) allEdges)
  in
    { nodes: mapMaybe (lookupNode graph) visibleIds
    , edges: visibleEdges
    , hiddenCount: length allIds - length visibleIds
    , unresolved
    }

-- | How an edge endpoint reads in context: present records show their kind
-- | and title; anything else is an explicit missing reference.
data EndpointName
  = Present { kind :: String, title :: String }
  | MissingEndpoint ScopedId

derive instance eqEndpointName :: Eq EndpointName

instance showEndpointName :: Show EndpointName where
  show (Present r) = "present " <> r.title
  show (MissingEndpoint id) = "missing " <> show id

-- | The permitted context of the current selection. A selection whose node
-- | is collapsed resolves to an explicit explanation carrying the expand
-- | route; it never silently disappears. A selection that refers to nothing
-- | resolves to an explicit unavailable state.
data ContextView
  = NoContext
  | NodeContext
      { node :: Node
      , parentLabel :: Maybe String
      , roles :: Array Node
      , communications :: Array Edge
      }
  | CollapsedSelection
      { id :: ScopedId
      , title :: String
      , hiddenCount :: Int
      , expandAt :: ScopedId
      , behindLabel :: String
      }
  | EdgeContext
      { edge :: Edge
      , kindName :: String
      , fromName :: EndpointName
      , toName :: EndpointName
      }
  | UnavailableContext String

derive instance eqContextView :: Eq ContextView

subtreeSize :: Graph -> ScopedId -> Int
subtreeSize graph root = count Set.empty root
  where
  count visited id
    | id `Set.member` visited = 0
    | otherwise =
        let
          children = containmentChildren graph id
          nextVisited = Set.insert id visited
        in
          length children + sum (map (count nextVisited) children)

nearestCollapsedAncestor :: Graph -> Set ScopedId -> ScopedId -> Maybe ScopedId
nearestCollapsedAncestor graph collapsed = walk Set.empty
  where
  walk visited id = case containmentParent graph id of
    Nothing -> Nothing
    Just parent
      | parent `Set.member` visited -> Nothing
      | parent `Set.member` collapsed -> Just parent
      | otherwise -> walk (Set.insert parent visited) parent

behindTitle :: Graph -> Maybe ScopedId -> String
behindTitle graph = case _ of
  Nothing -> "a collapsed record"
  Just parent -> case lookupNode graph parent of
    Just n -> n.title
    Nothing -> "a collapsed record"

resolveContext :: Graph -> Expansion -> Selection -> ContextView
resolveContext graph (Expansion collapsedArr) = case _ of
  NoSelection -> NoContext
  NodeSelected id -> case lookupNode graph id of
    Nothing -> UnavailableContext ("no record with identity " <> show id)
    Just node ->
      let
        collapsed = Set.fromFoldable collapsedArr
      in
        if hiddenUnder graph collapsed id then
          CollapsedSelection
            { id
            , title: node.title
            , hiddenCount: subtreeSize graph id
            , expandAt: fromMaybe id (nearestCollapsedAncestor graph collapsed id)
            , behindLabel: behindTitle graph (nearestCollapsedAncestor graph collapsed id)
            }
        else
          NodeContext
            { node
            , parentLabel: parentLabelOf graph id
            , roles: attachedRoles graph id
            , communications: communications graph id
            }
  EdgeSelected eid -> case lookupEdge graph eid of
    Nothing -> UnavailableContext ("no edge with identity " <> show eid)
    Just e ->
      EdgeContext
        { edge: e
        , kindName: relationLabel e.kind
        , fromName: endpointNameOf e.from
        , toName: endpointNameOf e.to
        }
  where
  parentLabelOf g id = case containmentParent g id of
    Nothing -> Nothing
    Just parentId -> case lookupNode g parentId of
      Nothing -> Nothing
      Just parent -> Just (kindLabel parent.kind <> " " <> parent.title)

  endpointNameOf id = case lookupNode graph id of
    Just n -> Present { kind: kindLabel n.kind, title: n.title }
    Nothing -> MissingEndpoint id
