module Factory.Domain
  ( ScopedId(..)
  , scopedId
  , NodeKind(..)
  , kindLabel
  , Quality(..)
  , qualityLabel
  , Node
  , EdgeId(..)
  , RelationshipKind(..)
  , relationLabel
  , Edge
  , Graph(..)
  , GraphError(..)
  , renderGraphError
  , mkGraph
  , lookupNode
  , lookupEdge
  , nodeIds
  , edgeIds
  , containmentChildren
  , containmentParent
  , attachedRoles
  , communications
  , incidentEdges
  , isWorkKind
  ) where

import Prelude

import Data.Array (filter, find, mapMaybe, uncons)
import Data.Either (Either(..))
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..))

-- | A stable identity for a graph node, scoped by its source namespace so
-- | that records from different sources never collide.
newtype ScopedId = ScopedId { namespace :: String, key :: String }

derive instance eqScopedId :: Eq ScopedId
derive instance ordScopedId :: Ord ScopedId

instance showScopedId :: Show ScopedId where
  show (ScopedId r) = "(" <> r.namespace <> "#" <> r.key <> ")"

scopedId :: String -> String -> ScopedId
scopedId namespace key = ScopedId { namespace, key }

-- | The entity kinds a synthetic installation records.
data NodeKind
  = Project
  | Milestone
  | EpicIssue
  | TicketIssue
  | PullRequest
  | Role

derive instance eqNodeKind :: Eq NodeKind
derive instance ordNodeKind :: Ord NodeKind

instance showNodeKind :: Show NodeKind where
  show = kindLabel

kindLabel :: NodeKind -> String
kindLabel = case _ of
  Project -> "project"
  Milestone -> "milestone"
  EpicIssue -> "epic issue"
  TicketIssue -> "ticket issue"
  PullRequest -> "pull request"
  Role -> "role"

-- | Approved display kinds. Roles are factory roles, not workers.
isWorkKind :: NodeKind -> Boolean
isWorkKind = case _ of
  Role -> false
  _ -> true

-- | Containment depth used to validate the work chain.
rank :: NodeKind -> Int
rank = case _ of
  Project -> 0
  Milestone -> 1
  EpicIssue -> 2
  TicketIssue -> 3
  PullRequest -> 4
  Role -> 5

-- | How trustworthy an observation is. Each constructor is a distinct,
-- honestly labelled state; nothing decays silently into another.
data Quality
  = Known { provenance :: String, freshness :: String }
  | Unknown
  | Stale { provenance :: String, asOf :: String }
  | MissingReference

derive instance eqQuality :: Eq Quality

qualityLabel :: Quality -> String
qualityLabel = case _ of
  Known _ -> "known"
  Unknown -> "unknown"
  Stale _ -> "stale"
  MissingReference -> "missing reference"

instance showQuality :: Show Quality where
  show = qualityLabel

-- | A graph node carrying only approved display data. Roles carry no
-- | implementation identity, so their source reference is absent.
type Node =
  { id :: ScopedId
  , kind :: NodeKind
  , title :: String
  , summary :: String
  , status :: String
  , sourceRef :: Maybe String
  , quality :: Quality
  }

-- | A stable, source-qualified edge identity with distinct endpoints.
newtype EdgeId = EdgeId { source :: String, key :: String }

derive instance eqEdgeId :: Eq EdgeId
derive instance ordEdgeId :: Ord EdgeId

instance showEdgeId :: Show EdgeId where
  show (EdgeId r) = "(" <> r.source <> "#" <> r.key <> ")"

data RelationshipKind
  = Contains
  | AttachesRole
  | RecordsCommunication

derive instance eqRelationshipKind :: Eq RelationshipKind
derive instance ordRelationshipKind :: Ord RelationshipKind

instance showRelationshipKind :: Show RelationshipKind where
  show = relationLabel

relationLabel :: RelationshipKind -> String
relationLabel = case _ of
  Contains -> "contains"
  AttachesRole -> "attaches role"
  RecordsCommunication -> "recorded communication"

type Edge =
  { id :: EdgeId
  , kind :: RelationshipKind
  , from :: ScopedId
  , to :: ScopedId
  }

-- | A validated graph. Construction rejects duplicate identities, self
-- | loops and — when both endpoints resolve — relationships whose endpoint
-- | kinds contradict the documented contract. Unresolved endpoints with a
-- | valid identity shape are preserved and surface as explicit missing
-- | references at query time.
newtype Graph = Graph
  { nodes :: Map ScopedId Node
  , edges :: Map EdgeId Edge
  , nodeOrder :: Array ScopedId
  , edgeOrder :: Array EdgeId
  }

data GraphError
  = DuplicateNode ScopedId
  | DuplicateEdge EdgeId
  | SelfLoop EdgeId
  | BadContainment EdgeId NodeKind NodeKind
  | BadAttachment EdgeId
  | BadCommunication EdgeId

derive instance eqGraphError :: Eq GraphError

renderGraphError :: GraphError -> String
renderGraphError = case _ of
  DuplicateNode id -> "duplicate node identity " <> show id
  DuplicateEdge id -> "duplicate edge identity " <> show id
  SelfLoop id -> "edge " <> show id <> " has identical endpoints"
  BadContainment id from to ->
    "edge " <> show id <> " cannot contain a " <> kindLabel to
      <> " inside a "
      <> kindLabel from
  BadAttachment id ->
    "edge " <> show id <> " must attach a role to a work record"
  BadCommunication id ->
    "edge " <> show id <> " must record communication from a role"

instance showGraphError :: Show GraphError where
  show = renderGraphError

-- | Validate and construct a graph. Duplicate identities, self loops and
-- | semantically impossible relationships are rejected; well-formed
-- | references to absent identities are preserved.
mkGraph :: Array Node -> Array Edge -> Either GraphError Graph
mkGraph nodes edges = do
  { nmap, norder } <- foldNodes Map.empty [] nodes
  { emap, eorder } <- foldEdges Map.empty [] edges
  validateEdges (Graph { nodes: nmap, edges: emap, nodeOrder: norder, edgeOrder: eorder }) (edgeList emap eorder)
  pure (Graph { nodes: nmap, edges: emap, nodeOrder: norder, edgeOrder: eorder })
  where
  foldNodes nmap norder rest = case uncons rest of
    Nothing -> Right { nmap, norder }
    Just { head: n, tail } ->
      if Map.member n.id nmap then Left (DuplicateNode n.id)
      else foldNodes (Map.insert n.id n nmap) (norder <> [ n.id ]) tail

  foldEdges emap eorder rest = case uncons rest of
    Nothing -> Right { emap, eorder }
    Just { head: e, tail } ->
      if Map.member e.id emap then Left (DuplicateEdge e.id)
      else if e.from == e.to then Left (SelfLoop e.id)
      else foldEdges (Map.insert e.id e emap) (eorder <> [ e.id ]) tail

  validateEdges graph rest = case uncons rest of
    Nothing -> Right unit
    Just { head: e, tail } -> case semanticCheck graph e of
      Left err -> Left err
      Right _ -> validateEdges graph tail

  edgeList emap eorder = mapMaybe (\id -> Map.lookup id emap) eorder

  semanticCheck (Graph g) e = case e.kind of
    Contains -> case Map.lookup e.from g.nodes, Map.lookup e.to g.nodes of
      Just from, Just to ->
        if rank from.kind < rank to.kind then Right unit
        else Left (BadContainment e.id from.kind to.kind)
      _, _ -> Right unit
    AttachesRole -> case Map.lookup e.from g.nodes, Map.lookup e.to g.nodes of
      Just from, Just to ->
        if isWorkKind from.kind && not (isWorkKind to.kind) then Right unit
        else Left (BadAttachment e.id)
      _, _ -> Right unit
    RecordsCommunication -> case Map.lookup e.from g.nodes, Map.lookup e.to g.nodes of
      Just from, Just to ->
        if not (isWorkKind from.kind) && isWorkKind to.kind then Right unit
        else Left (BadCommunication e.id)
      _, _ -> Right unit

lookupNode :: Graph -> ScopedId -> Maybe Node
lookupNode (Graph g) id = Map.lookup id g.nodes

lookupEdge :: Graph -> EdgeId -> Maybe Edge
lookupEdge (Graph g) id = Map.lookup id g.edges

nodeIds :: Graph -> Array ScopedId
nodeIds (Graph g) = g.nodeOrder

edgeIds :: Graph -> Array EdgeId
edgeIds (Graph g) = g.edgeOrder

edgesOf :: Graph -> Array Edge
edgesOf (Graph g) = mapMaybe (\id -> Map.lookup id g.edges) g.edgeOrder

-- | Containment children of a node, in record order, that are present.
containmentChildren :: Graph -> ScopedId -> Array ScopedId
containmentChildren graph parent =
  map (_.to)
    (filter (\e -> e.kind == Contains && e.from == parent) (edgesOf graph))

containmentParent :: Graph -> ScopedId -> Maybe ScopedId
containmentParent graph child =
  (_.from)
    <$> find (\e -> e.kind == Contains && e.to == child) (edgesOf graph)

-- | Roles attached to a work record.
attachedRoles :: Graph -> ScopedId -> Array Node
attachedRoles graph work =
  mapMaybe
    ( \e ->
        if e.kind == AttachesRole && e.from == work then
          case lookupNode graph e.to of
            Just role@(node) | not (isWorkKind node.kind) -> Just role
            _ -> Nothing
        else Nothing
    )
    (edgesOf graph)

-- | Recorded communication edges involving a node.
communications :: Graph -> ScopedId -> Array Edge
communications graph id =
  filter (\e -> e.kind == RecordsCommunication && (e.from == id || e.to == id))
    (edgesOf graph)

incidentEdges :: Graph -> ScopedId -> Array Edge
incidentEdges graph id =
  filter (\e -> e.from == id || e.to == id) (edgesOf graph)
