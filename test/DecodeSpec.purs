module Test.DecodeSpec (spec) where

import Prelude

import Control.Monad.Error.Class (class MonadThrow, throwError)
import Data.Array (any, length)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.String (Pattern(..), Replacement(..), contains, joinWith, replace)
import Effect.Exception (Error, error)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (fail, shouldEqual)

import Factory.Decode (FailureReason(..), decodeGraph, renderFailure)
import Factory.Domain (EdgeId(..), Graph, Node, NodeKind(..), Quality(..), ScopedId, edgeIds, lookupEdge, lookupNode, nodeIds, scopedId)
import Factory.Fixtures (rawEmpty, rawIncomplete, rawInvalid, rawOrdinary)

ns :: String
ns = "synthetic:demo-installation"

spec :: Spec Unit
spec = describe "boundary decoder" do
  describe "approved documents decode" do
    it "decodes the complete synthetic installation" do
      graph <- decodeOk rawOrdinary
      countNodes graph `shouldEqual` 10
      countEdges graph `shouldEqual` 12

    it "keeps roles free of implementation identity" do
      graph <- decodeOk rawOrdinary
      role <- nodeOrFail graph (scopedId ns "role-1")
      case role.kind, role.sourceRef of
        Role, Nothing -> pure unit
        _, _ -> fail "role must be a Role node without a source reference"

    it "preserves source-like titles as data" do
      graph <- decodeOk rawOrdinary
      hostile <- nodeOrFail graph (scopedId ns "pr-2")
      hostile.title
        `shouldEqual` "Review note <img src=x onerror=window.__xss=1>"

    it "preserves a well-formed unresolved external reference" do
      graph <- decodeOk rawOrdinary
      case lookupNode graph (scopedId ns "external-ref-404") of
        Just _ -> fail "an unresolved external reference became an invented node"
        Nothing -> pure unit
      case lookupEdge graph (EdgeId { source: ns, key: "ext-1" }) of
        Just _ -> pure unit
        Nothing -> fail "the unresolved external edge was dropped"

    it "decodes an empty installation as explicitly empty" do
      graph <- decodeOk rawEmpty
      countNodes graph `shouldEqual` 0
      countEdges graph `shouldEqual` 0

    it "decodes incomplete records without inventing relationships" do
      graph <- decodeOk rawIncomplete
      countNodes graph `shouldEqual` 4
      countEdges graph `shouldEqual` 1

    it "keeps known, unknown, stale and missing-reference distinct" do
      graph <- decodeOk rawOrdinary
      incomplete <- decodeOk rawIncomplete
      missing <- nodeOrFail incomplete (scopedId ns "role-3")
      missing.quality `shouldEqual` MissingReference
      known <- nodeOrFail graph (scopedId ns "milestone-1")
      stale <- nodeOrFail graph (scopedId ns "milestone-2")
      unknown <- nodeOrFail graph (scopedId ns "role-2")
      case known.quality, stale.quality, unknown.quality of
        Known _, Stale _, Unknown -> pure unit
        _, _, _ -> fail "observation qualities collapsed into one state"

    it "keeps the approval kinds distinct" do
      graph <- decodeOk rawOrdinary
      project <- nodeOrFail graph (scopedId ns "project-1")
      milestone <- nodeOrFail graph (scopedId ns "milestone-1")
      epic <- nodeOrFail graph (scopedId ns "epic-1")
      ticket <- nodeOrFail graph (scopedId ns "ticket-1")
      pr <- nodeOrFail graph (scopedId ns "pr-1")
      project.kind `shouldEqual` Project
      milestone.kind `shouldEqual` Milestone
      epic.kind `shouldEqual` EpicIssue
      ticket.kind `shouldEqual` TicketIssue
      pr.kind `shouldEqual` PullRequest

  describe "unapproved input is refused with categorical reasons" do
    it "refuses a field outside the documented contract" do
      let doc = nodesDoc [ nodeJson "p" "project" ",\"estimatePoints\":5" ]
      refusesWith "nodes[0].estimatePoints" UnapprovedField doc

    it "refuses implementation identity on a role record" do
      let doc = nodesDoc [ nodeJson "r" "role" ",\"sourceRef\":\"provider://worker/r\"" ]
      refusesWith "nodes[0].sourceRef" ForbiddenRoleField doc

    it "refuses a missing required field" do
      let doc = dropField "title" (nodesDoc [ nodeJson "p" "project" "" ])
      refusesWith "nodes[0].title" MissingRequired doc
    it "refuses an undocumented kind" do
      let doc = nodesDoc [ nodeJson "p" "swimlane" "" ]
      refusesWith "nodes[0].kind" UnknownKind doc

    it "refuses an invalid identity shape" do
      refusesWith "nodes[0].identity" InvalidIdentity
        "{\"schema\":\"factory-graph/1\",\"nodes\":[{\"identity\":{\"namespace\":\"\",\"key\":\"p\"},\"kind\":\"project\",\"title\":\"t\",\"summary\":\"s\",\"status\":\"open\",\"sourceRef\":null,\"quality\":{\"state\":\"unknown\"}}],\"edges\":[]}"

    it "refuses an undocumented observation state" do
      refusesWith "nodes[0].quality.state" UnknownQualityState
        "{\"schema\":\"factory-graph/1\",\"nodes\":[{\"identity\":{\"namespace\":\"s\",\"key\":\"p\"},\"kind\":\"project\",\"title\":\"t\",\"summary\":\"s\",\"status\":\"open\",\"sourceRef\":null,\"quality\":{\"state\":\"freshish\"}}],\"edges\":[]}"

    it "refuses a malformed observation object" do
      refusesWith "nodes[0].quality" MalformedField
        "{\"schema\":\"factory-graph/1\",\"nodes\":[{\"identity\":{\"namespace\":\"s\",\"key\":\"p\"},\"kind\":\"project\",\"title\":\"t\",\"summary\":\"s\",\"status\":\"open\",\"sourceRef\":null,\"quality\":\"known\"}],\"edges\":[]}"

    it "refuses a malformed record" do
      refusesWith "nodes[0]" MalformedField
        "{\"schema\":\"factory-graph/1\",\"nodes\":[\"not-a-record\"],\"edges\":[]}"

    it "refuses duplicate identities" do
      let doc = nodesDoc [ nodeJson "p" "project" "", nodeJson "p" "project" "" ]
      refusesWith "nodes[1].identity" DuplicateIdentity doc

    it "refuses a self-loop edge" do
      refusesWith "edges[0]" SelfLoopEdge
        "{\"schema\":\"factory-graph/1\",\"nodes\":[],\"edges\":[{\"identity\":{\"source\":\"s\",\"key\":\"e\"},\"kind\":\"contains\",\"from\":{\"namespace\":\"s\",\"key\":\"a\"},\"to\":{\"namespace\":\"s\",\"key\":\"a\"}}]}"

    it "refuses a containment that inverts the hierarchy" do
      refusesWith "edges[0]" BadRelationship
        ( nodesAndEdgeDoc [ nodeJson "epic" "epic-issue" "", nodeJson "proj" "project" "" ]
            "contains"
            "epic"
            "proj"
        )

    it "refuses a role attached to a role" do
      refusesWith "edges[0]" BadRelationship
        ( nodesAndEdgeDoc [ nodeJson "r1" "role" "", nodeJson "r2" "role" "" ]
            "attaches-role"
            "r1"
            "r2"
        )

    it "refuses communication that does not start at a role" do
      refusesWith "edges[0]" BadRelationship
        ( nodesAndEdgeDoc [ nodeJson "t" "ticket-issue" "", nodeJson "p" "pull-request" "" ]
            "records-communication"
            "t"
            "p"
        )

    it "refuses a document without the schema marker" do
      refusesWith "$" SchemaMismatch "{\"nodes\":[]}"

    it "refuses text that is not JSON" do
      refusesWith "$" NotJson "not json at all"

    it "refuses the shared invalid scenario with several reasons" do
      case decodeGraph rawInvalid of
        Left fs ->
          if length fs >= 4 then pure unit
          else fail "invalid scenario must report every problem it found"
        Right _ -> fail "invalid scenario must be refused"

  describe "refusals are redacted" do
    it "never echoes record values in rendered reasons" do
      case decodeGraph rawInvalid of
        Left fs -> do
          let rendered = joinWith "\n" (map renderFailure fs)
          when (contains (Pattern "Broken installation") rendered)
            (fail "rendered refusal leaked a record value")
          when (contains (Pattern "provider://worker-implementation") rendered)
            (fail "rendered refusal leaked an implementation identity")
        Right _ -> fail "invalid scenario must be refused"

decodeOk :: forall m. MonadThrow Error m => String -> m Graph
decodeOk raw = case decodeGraph raw of
  Left fs -> throwError (error ("document refused: " <> joinWith "\n" (map renderFailure fs)))
  Right g -> pure g

nodeOrFail :: forall m. MonadThrow Error m => Graph -> ScopedId -> m Node
nodeOrFail graph id = case lookupNode graph id of
  Just n -> pure n
  Nothing -> throwError (error ("missing node " <> show id))

countNodes :: Graph -> Int
countNodes graph = length (nodeIds graph)

countEdges :: Graph -> Int
countEdges graph = length (edgeIds graph)

refusesWith :: forall m. MonadThrow Error m => String -> FailureReason -> String -> m Unit
refusesWith path reason raw = case decodeGraph raw of
  Left fs ->
    if any (\f -> f.path == path && f.reason == reason) fs then pure unit
    else
      throwError
        ( error
            ( "refusal missing " <> show reason <> " at " <> path <> ": "
                <> joinWith "\n" (map renderFailure fs)
            )
        )
  Right _ -> throwError (error "document was accepted but must be refused")

nodeJson :: String -> String -> String -> String
nodeJson key kind extra =
  "{\"identity\":{\"namespace\":\"s\",\"key\":\"" <> key <> "\"},\"kind\":\"" <> kind
    <> "\",\"title\":\"t\",\"summary\":\"s\",\"status\":\"open\",\"sourceRef\":null"
    <> extra
    <> ",\"quality\":{\"state\":\"unknown\"}}"

nodesDoc :: Array String -> String
nodesDoc nodes =
  "{\"schema\":\"factory-graph/1\",\"nodes\":[" <> joinWith "," nodes <> "],\"edges\":[]}"

nodesAndEdgeDoc :: Array String -> String -> String -> String -> String
nodesAndEdgeDoc nodes edgeKind fromKey toKey =
  "{\"schema\":\"factory-graph/1\",\"nodes\":[" <> joinWith "," nodes
    <> "],\"edges\":[{\"identity\":{\"source\":\"s\",\"key\":\"e\"},\"kind\":\""
    <> edgeKind
    <> "\",\"from\":{\"namespace\":\"s\",\"key\":\""
    <> fromKey
    <> "\"},\"to\":{\"namespace\":\"s\",\"key\":\""
    <> toKey
    <> "\"}}]}"

dropField :: String -> String -> String
dropField field doc =
  replace (Pattern ("\"" <> field <> "\":\"t\",")) (Replacement "") doc
