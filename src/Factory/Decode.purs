-- | Strict boundary decoder: raw scenario text becomes either a list of
-- | redacted, categorical failures or a validated domain graph. Every
-- | approved field is enumerated here; anything else is refused. Failure
-- | rendering never echoes record values, so a refusal cannot leak payload
-- | content.
module Factory.Decode
  ( DecodeFailure(..)
  , FailureReason(..)
  , renderFailure
  , decodeGraph
  , schemaValue
  ) where

import Prelude

import Data.Argonaut.Core (Json, isNull, toArray, toObject, toString)
import Data.Argonaut.Parser (jsonParser)
import Data.Array (filter, mapMaybe, mapWithIndex, null, snoc, uncons)
import Data.Either (Either(..))
import Data.Foldable (foldMap)
import Data.Maybe (Maybe(..))
import Foreign.Object (Object)
import Foreign.Object as Object

import Factory.Domain
  ( Edge
  , EdgeId(..)
  , Graph
  , GraphError(..)
  , Node
  , NodeKind(..)
  , Quality(..)
  , RelationshipKind(..)
  , ScopedId(..)
  , isWorkKind
  , mkGraph
  )

-- | The schema marker every input must carry.
schemaValue :: String
schemaValue = "factory-graph/1"

data FailureReason
  = NotJson
  | SchemaMismatch
  | UnapprovedField
  | ForbiddenRoleField
  | MissingRequired
  | MalformedField
  | InvalidIdentity
  | DuplicateIdentity
  | UnknownKind
  | UnknownQualityState
  | SelfLoopEdge
  | BadRelationship

derive instance eqFailureReason :: Eq FailureReason

type DecodeFailure =
  { path :: String
  , reason :: FailureReason
  }

renderReason :: FailureReason -> String
renderReason = case _ of
  NotJson -> "input is not a JSON document"
  SchemaMismatch -> "document does not declare the supported graph contract"
  UnapprovedField -> "field is not part of the documented graph contract"
  ForbiddenRoleField -> "role records carry no implementation identity"
  MissingRequired -> "required field is absent"
  MalformedField -> "field has the wrong shape"
  InvalidIdentity -> "identity must have a non-empty namespace and key"
  DuplicateIdentity -> "identity is already used in this document"
  UnknownKind -> "kind is not one of the documented kinds"
  UnknownQualityState -> "observation state is not one of the documented states"
  SelfLoopEdge -> "edge endpoints must be distinct"
  BadRelationship -> "relationship contradicts its documented endpoint kinds"

instance showFailureReason :: Show FailureReason where
  show = renderReason

-- | Render a refusal. Categorical and structural only: paths and field
-- | names may appear; record values never do.
renderFailure :: DecodeFailure -> String
renderFailure f = renderReason f.reason <> " at " <> f.path

-- | Decode raw scenario text. All failures are collected so a refusal can
-- | explain every problem it found, not just the first.
decodeGraph :: String -> Either (Array DecodeFailure) Graph
decodeGraph raw = case jsonParser raw of
  Left _ -> Left [ { path: "$", reason: NotJson } ]
  Right json -> case toObject json of
    Nothing -> Left [ { path: "$", reason: SchemaMismatch } ]
    Just root -> decodeDocument root

decodeDocument :: Object Json -> Either (Array DecodeFailure) Graph
decodeDocument root =
  let
    rootFailures =
      unapprovedKeys root [ "schema", "nodes", "edges" ] "$"
        <> requiredObjectFields root [ "nodes", "edges" ] "$"

    schemaFailures = case Object.lookup "schema" root of
      Nothing -> [ { path: "$", reason: SchemaMismatch } ]
      Just j -> case toString j of
        Just s | s == schemaValue -> []
        _ -> [ { path: "$", reason: SchemaMismatch } ]

    nodeResults = arrayResults "nodes" root decodeNode
    edgeResults = arrayResults "edges" root decodeEdge

    failures =
      rootFailures
        <> schemaFailures
        <> foldMap failuresOf nodeResults
        <> foldMap failuresOf edgeResults
        <> duplicateIdFailures "nodes" (peekIdentities peekNodeIdentity (Object.lookup "nodes" root))
        <> duplicateIdFailures "edges" (peekIdentities peekEdgeIdentity (Object.lookup "edges" root))
        <> semanticFailuresOf (valuesOf nodeResults) (valuesOf edgeResults)
  in
    if not (null failures) then Left failures
    else case mkGraph (valuesOf nodeResults) (valuesOf edgeResults) of
      Left graphError -> Left [ fromGraphError graphError ]
      Right graph -> Right graph

arrayResults
  :: forall a
   . String
  -> Object Json
  -> (Int -> Json -> Either (Array DecodeFailure) a)
  -> Array (Either (Array DecodeFailure) a)
arrayResults name root decode = case Object.lookup name root of
  Nothing -> []
  Just j -> case toArray j of
    Nothing -> [ Left [ { path: name, reason: MalformedField } ] ]
    Just items -> mapWithIndex (\i v -> decode i v) items

peekIdentities :: (Json -> Maybe String) -> Maybe Json -> Array (Maybe String)
peekIdentities peek mj = case mj >>= toArray of
  Nothing -> []
  Just items -> map peek items

valuesOf :: forall a. Array (Either (Array DecodeFailure) a) -> Array a
valuesOf results = mapMaybe rightOf results
  where
  rightOf (Right v) = Just v
  rightOf (Left _) = Nothing

failuresOf :: forall a. Either (Array DecodeFailure) a -> Array DecodeFailure
failuresOf (Left fs) = fs
failuresOf (Right _) = []

-- | Report the second and later occurrence of an identity at its exact
-- | index, so a duplicate refusal points at the offending record. The peek
-- | works even when the record carries other failures, because identity
-- | duplication is about the document's shape, not its other fields.
duplicateIdFailures
  :: String
  -> Array (Maybe String)
  -> Array DecodeFailure
duplicateIdFailures base peeks = go [] [] (mapWithIndex (\i p -> { i, p }) peeks)
  where
  go seen acc rest = case uncons rest of
    Nothing -> acc
    Just { head: { i: _, p: Nothing }, tail } -> go seen acc tail
    Just { head: { i, p: Just k }, tail } ->
      if memberOf k seen then
        go seen
          ( snoc acc
              { path: base <> "[" <> show i <> "].identity"
              , reason: DuplicateIdentity
              }
          )
          tail
      else go (snoc seen k) acc tail

peekNodeIdentity :: Json -> Maybe String
peekNodeIdentity j = do
  obj <- toObject j
  idj <- Object.lookup "identity" obj
  idObj <- toObject idj
  ns <- toString =<< Object.lookup "namespace" idObj
  key <- toString =<< Object.lookup "key" idObj
  if ns == "" || key == "" then Nothing else Just (ns <> "#" <> key)

peekEdgeIdentity :: Json -> Maybe String
peekEdgeIdentity j = do
  obj <- toObject j
  idj <- Object.lookup "identity" obj
  idObj <- toObject idj
  source <- toString =<< Object.lookup "source" idObj
  key <- toString =<< Object.lookup "key" idObj
  if source == "" || key == "" then Nothing else Just (source <> "#" <> key)

fromGraphError :: GraphError -> DecodeFailure
fromGraphError = case _ of
  DuplicateNode _ -> { path: "nodes", reason: DuplicateIdentity }
  DuplicateEdge _ -> { path: "edges", reason: DuplicateIdentity }
  SelfLoop _ -> { path: "edges", reason: SelfLoopEdge }
  BadContainment _ _ _ -> { path: "edges", reason: BadRelationship }
  BadAttachment _ -> { path: "edges", reason: BadRelationship }
  BadCommunication _ -> { path: "edges", reason: BadRelationship }

-- | Every key of the object that is not in the approved set is a failure.
unapprovedKeys :: Object Json -> Array String -> String -> Array DecodeFailure
unapprovedKeys obj approved base =
  map
    (\k -> { path: base <> "." <> k, reason: UnapprovedField })
    (filter (\k -> not (memberOf k approved)) (Object.keys obj))

memberOf :: String -> Array String -> Boolean
memberOf k list = not (null (filter (\a -> a == k) list))

requiredObjectFields :: Object Json -> Array String -> String -> Array DecodeFailure
requiredObjectFields obj required base =
  map
    (\k -> { path: base <> "." <> k, reason: MissingRequired })
    (filter (\k -> not (Object.member k obj)) required)

decodeNode :: Int -> Json -> Either (Array DecodeFailure) Node
decodeNode i j = case toObject j of
  Nothing -> Left [ { path: "nodes[" <> show i <> "]", reason: MalformedField } ]
  Just obj -> decodeNodeObject i obj

decodeNodeObject :: Int -> Object Json -> Either (Array DecodeFailure) Node
decodeNodeObject i obj =
  let
    base = "nodes[" <> show i <> "]"
    keyFailures = unapprovedKeys obj nodeApproved base

    identityResult = decodeIdentity (base <> ".identity") (Object.lookup "identity" obj)

    kindResult = case Object.lookup "kind" obj of
      Nothing -> Left [ { path: base <> ".kind", reason: MissingRequired } ]
      Just kj -> case toString kj of
        Nothing -> Left [ { path: base <> ".kind", reason: MalformedField } ]
        Just s -> case kindOf s of
          Just k -> Right k
          Nothing -> Left [ { path: base <> ".kind", reason: UnknownKind } ]

    stringField name = case Object.lookup name obj of
      Nothing -> Left [ { path: base <> "." <> name, reason: MissingRequired } ]
      Just v -> case toString v of
        Nothing -> Left [ { path: base <> "." <> name, reason: MalformedField } ]
        Just s -> Right s

    titleResult = stringField "title"
    summaryResult = stringField "summary"
    statusResult = stringField "status"

    sourceRefResult = case Object.lookup "sourceRef" obj of
      Nothing -> Left [ { path: base <> ".sourceRef", reason: MissingRequired } ]
      Just v
        | isNull v -> Right Nothing
        | otherwise -> case toString v of
            Nothing -> Left [ { path: base <> ".sourceRef", reason: MalformedField } ]
            Just s -> Right (Just s)

    qualityResult = case Object.lookup "quality" obj of
      Nothing -> Left [ { path: base <> ".quality", reason: MissingRequired } ]
      Just v -> decodeQuality base v

    roleLeak = case kindResult, sourceRefResult of
      Right Role, Right (Just _) ->
        [ { path: base <> ".sourceRef", reason: ForbiddenRoleField } ]
      _, _ -> []
  in
    case identityResult, kindResult, titleResult, summaryResult, statusResult, sourceRefResult, qualityResult of
      Right (ScopedId identity), Right k, Right title, Right summary, Right status, Right sourceRef, Right quality ->
        if null roleLeak && null keyFailures then
          Right
            { id: ScopedId identity
            , kind: k
            , title
            , summary
            , status
            , sourceRef
            , quality
            }
        else
          Left
            ( keyFailures
                <> roleLeak
                <> failuresOf identityResult
                <> failuresOf kindResult
                <> failuresOf titleResult
                <> failuresOf summaryResult
                <> failuresOf statusResult
                <> failuresOf sourceRefResult
                <> failuresOf qualityResult
            )
      _, _, _, _, _, _, _ ->
        Left
          ( keyFailures
              <> roleLeak
              <> failuresOf identityResult
              <> failuresOf kindResult
              <> failuresOf titleResult
              <> failuresOf summaryResult
              <> failuresOf statusResult
              <> failuresOf sourceRefResult
              <> failuresOf qualityResult
          )

nodeApproved :: Array String
nodeApproved = [ "identity", "kind", "title", "summary", "status", "sourceRef", "quality" ]

kindOf :: String -> Maybe NodeKind
kindOf = case _ of
  "project" -> Just Project
  "milestone" -> Just Milestone
  "epic-issue" -> Just EpicIssue
  "ticket-issue" -> Just TicketIssue
  "pull-request" -> Just PullRequest
  "role" -> Just Role
  _ -> Nothing

decodeQuality :: String -> Json -> Either (Array DecodeFailure) Quality
decodeQuality base v = case toObject v of
  Nothing -> Left [ { path: base <> ".quality", reason: MalformedField } ]
  Just obj ->
    let
      qbase = base <> ".quality"
      stateResult = case Object.lookup "state" obj of
        Nothing -> Left [ { path: qbase <> ".state", reason: MissingRequired } ]
        Just sj -> case toString sj of
          Nothing -> Left [ { path: qbase <> ".state", reason: MalformedField } ]
          Just s -> Right s

      stringIn name = case Object.lookup name obj of
        Nothing -> Left [ { path: qbase <> "." <> name, reason: MissingRequired } ]
        Just fv -> case toString fv of
          Nothing -> Left [ { path: qbase <> "." <> name, reason: MalformedField } ]
          Just s -> Right s

      withKeys approved value =
        let
          extras = unapprovedKeys obj approved qbase
        in
          if null extras then Right value
          else Left extras
    in
      case stateResult of
        Left fs -> Left fs
        Right "known" ->
          case stringIn "provenance", stringIn "freshness" of
            Right p, Right f ->
              withKeys [ "state", "provenance", "freshness" ]
                (Known { provenance: p, freshness: f })
            _, _ ->
              Left (foldMap failuresOf [ stringIn "provenance", stringIn "freshness" ])
        Right "unknown" -> withKeys [ "state" ] Unknown
        Right "stale" ->
          case stringIn "provenance", stringIn "asOf" of
            Right p, Right a ->
              withKeys [ "state", "provenance", "asOf" ]
                (Stale { provenance: p, asOf: a })
            _, _ ->
              Left (foldMap failuresOf [ stringIn "provenance", stringIn "asOf" ])
        Right "missing-reference" -> withKeys [ "state" ] MissingReference
        Right _ -> Left [ { path: qbase <> ".state", reason: UnknownQualityState } ]

decodeIdentity :: String -> Maybe Json -> Either (Array DecodeFailure) ScopedId
decodeIdentity base mj = case mj of
  Nothing -> Left [ { path: base, reason: MissingRequired } ]
  Just v -> case toObject v of
    Nothing -> Left [ { path: base, reason: InvalidIdentity } ]
    Just obj ->
      let
        extras = unapprovedKeys obj [ "namespace", "key" ] base
        nsResult = nonEmptyString base "namespace" obj
        keyResult = nonEmptyString base "key" obj
      in
        case nsResult, keyResult of
          Right ns, Right key
            | ns == "" || key == "" ->
                Left [ { path: base, reason: InvalidIdentity } ]
            | null extras -> Right (ScopedId { namespace: ns, key })
            | otherwise -> Left extras
          _, _ ->
            Left
              ( [ { path: base, reason: InvalidIdentity } ]
                  <> extras
                  <> foldMap failuresOf [ nsResult, keyResult ]
              )

nonEmptyString :: String -> String -> Object Json -> Either (Array DecodeFailure) String
nonEmptyString base name obj = case Object.lookup name obj of
  Nothing -> Left [ { path: base <> "." <> name, reason: MissingRequired } ]
  Just v -> case toString v of
    Nothing -> Left [ { path: base <> "." <> name, reason: MalformedField } ]
    Just s -> Right s

decodeEdge :: Int -> Json -> Either (Array DecodeFailure) Edge
decodeEdge i j = case toObject j of
  Nothing -> Left [ { path: "edges[" <> show i <> "]", reason: MalformedField } ]
  Just obj -> decodeEdgeObject i obj

decodeEdgeObject :: Int -> Object Json -> Either (Array DecodeFailure) Edge
decodeEdgeObject i obj =
  let
    base = "edges[" <> show i <> "]"
    keyFailures = unapprovedKeys obj [ "identity", "kind", "from", "to" ] base

    identityResult = decodeEdgeIdentity (base <> ".identity") (Object.lookup "identity" obj)

    kindResult = case Object.lookup "kind" obj of
      Nothing -> Left [ { path: base <> ".kind", reason: MissingRequired } ]
      Just kj -> case toString kj of
        Nothing -> Left [ { path: base <> ".kind", reason: MalformedField } ]
        Just s -> case relationOf s of
          Just k -> Right k
          Nothing -> Left [ { path: base <> ".kind", reason: UnknownKind } ]

    fromResult = decodeIdentity (base <> ".from") (Object.lookup "from" obj)
    toResult = decodeIdentity (base <> ".to") (Object.lookup "to" obj)
  in
    case identityResult, kindResult, fromResult, toResult of
      Right edgeId, Right k, Right from, Right to ->
        if from == to then
          Left (keyFailures <> [ { path: base, reason: SelfLoopEdge } ])
        else if null keyFailures then
          Right { id: edgeId, kind: k, from, to }
        else
          Left keyFailures
      _, _, _, _ ->
        Left
          ( keyFailures
              <> failuresOf identityResult
              <> failuresOf kindResult
              <> failuresOf fromResult
              <> failuresOf toResult
          )

decodeEdgeIdentity :: String -> Maybe Json -> Either (Array DecodeFailure) EdgeId
decodeEdgeIdentity base mj = case mj of
  Nothing -> Left [ { path: base, reason: MissingRequired } ]
  Just v -> case toObject v of
    Nothing -> Left [ { path: base, reason: InvalidIdentity } ]
    Just obj ->
      let
        extras = unapprovedKeys obj [ "source", "key" ] base
        sourceResult = nonEmptyString base "source" obj
        keyResult = nonEmptyString base "key" obj
      in
        case sourceResult, keyResult of
          Right source, Right key ->
            if null extras then Right (EdgeId { source, key })
            else Left extras
          _, _ ->
            Left
              ( [ { path: base, reason: InvalidIdentity } ]
                  <> extras
                  <> foldMap failuresOf [ sourceResult, keyResult ]
              )

relationOf :: String -> Maybe RelationshipKind
relationOf = case _ of
  "contains" -> Just Contains
  "attaches-role" -> Just AttachesRole
  "records-communication" -> Just RecordsCommunication
  _ -> Nothing

-- | Semantic endpoint validation once all records decoded: applies only
-- | when both endpoints are present, mirroring the domain rules so the
-- | refusal can name the exact offending edge index.
semanticFailuresOf :: Array Node -> Array Edge -> Array DecodeFailure
semanticFailuresOf nodes edges =
  let
    findNode id = filter (\n -> n.id == id) nodes
  in
    mapMaybe
      ( \indexed ->
          let
            base = "edges[" <> show indexed.i <> "]"
            e = indexed.e
          in
            case findNode e.from, findNode e.to of
              [ from ], [ to ] ->
                case e.kind of
                  Contains
                    | rankOf from.kind >= rankOf to.kind -> Just { path: base, reason: BadRelationship }
                  AttachesRole
                    | not (isWorkKind from.kind) || isWorkKind to.kind -> Just { path: base, reason: BadRelationship }
                  RecordsCommunication
                    | isWorkKind from.kind || not (isWorkKind to.kind) -> Just { path: base, reason: BadRelationship }
                  _ -> Nothing
              _, _ -> Nothing
      )
      (mapWithIndex (\i e -> { i, e }) edges)

rankOf :: NodeKind -> Int
rankOf = case _ of
  Project -> 0
  Milestone -> 1
  EpicIssue -> 2
  TicketIssue -> 3
  PullRequest -> 4
  Role -> 5
