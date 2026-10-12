-- | The control-room view: recorded counts, filters and stable highlighting.
module Factory.Desk (lanes, summary, filterVisible, dimNode) where

import Prelude
import Data.Array (any, elem, filter, length, mapMaybe, nub)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), isNothing)
import Factory.Domain (Graph, Node, NodeKind(..), ScopedId, containmentChildren, incidentEdges, lookupEdge, lookupNode, nodeIds)
import Factory.Checks as Checks
import Factory.Layout (nodeKey)
import Factory.ViewState (Selection(..), VisibleGraph)

lanes :: Graph -> Array Node
lanes graph = filter (\n -> n.kind == EpicIssue) (mapMaybe (lookupNode graph) (nodeIds graph))

summary :: Graph -> Array { label :: String, value :: String }
summary graph =
  let
    nodes = mapMaybe (lookupNode graph) (nodeIds graph)
    count kind = length (filter (\n -> n.kind == kind) nodes)
    tickets = filter (\n -> n.kind == TicketIssue) nodes
    closed = length (filter (\n -> n.status == "closed") tickets)
  in
    [ { label: "Lanes", value: show (count EpicIssue) }
    , { label: "Tickets closed", value: show closed <> " of " <> show (length tickets) }
    , { label: "Workers", value: show (count Role) <> " roles" }
    , { label: "Pull requests", value: show (count PullRequest) }
    ]

-- | Containment is acyclic by validated kind rank. Role/message connections
-- | are added once; they must not pull unrelated work into a selected lane.
branchIds :: Graph -> ScopedId -> Array ScopedId
branchIds graph root =
  let
    work = descend root
  in
    nub (work <> mapMaybe (\e -> if elem e.from work then Just e.to else if elem e.to work then Just e.from else Nothing) (nub (work >>= incidentEdges graph)))
  where
  descend id = [ id ] <> (containmentChildren graph id >>= descend)

filterVisible :: forall r. Graph -> { showEpics :: Boolean, showWorkers :: Boolean, branch :: String, filterMode :: String | r } -> VisibleGraph -> VisibleGraph
filterVisible graph controls visible =
  let
    roots = filter (\id -> nodeKey id == controls.branch) (nodeIds graph)
    branch = roots >>= branchIds graph
    matches n = (if n.kind == Role then controls.showWorkers else controls.showEpics)
      && (controls.branch == "" || elem n.id branch)
      &&
        ( case controls.filterMode of
            "running" -> elem n.status [ "working", "WORKING", "active", "in progress" ]
            "attention" -> any (\f -> f.subject == n.id) (Checks.findings graph)
            _ -> true
        )
    seeds = filter matches visible.nodes
    -- Keep ancestors so an attention/running branch retains its context.
    kept = if controls.filterMode == "all" then seeds else filter (\n -> (if n.kind == Role then controls.showWorkers else controls.showEpics) && (controls.branch == "" || elem n.id branch) && (matches n || any (\seed -> elem seed.id (branchIds graph n.id)) seeds)) visible.nodes
    ids = map _.id kept
  in
    visible
      { nodes = kept
      , edges = filter (\e -> (elem e.from ids && (elem e.to ids || isNothing (lookupNode graph e.to))) || (elem e.to ids && isNothing (lookupNode graph e.from))) visible.edges
      , unresolved = filter (\e -> elem e.edge.from ids || elem e.edge.to ids) visible.unresolved
      }

dimNode :: forall failure e r. Either failure Graph -> { highlight :: Boolean, view :: { selection :: Selection | r } | e } -> ScopedId -> Boolean
dimNode doc controls id = case doc of
  Left _ -> false
  Right graph ->
    let
      selected = case controls.view.selection of
        NodeSelected root -> branchIds graph root
        EdgeSelected edge -> case lookupEdge graph edge of
          Just e -> [ e.from, e.to ]
          Nothing -> []
        NoSelection -> []
    in
      controls.highlight && length selected > 0 && not (elem id selected)
