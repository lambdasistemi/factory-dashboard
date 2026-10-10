module Test.DomainSpec (spec) where

import Prelude

import Control.Monad.Error.Class (class MonadThrow, throwError)
import Data.Array (length)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect.Exception (Error, error)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (fail, shouldEqual, shouldNotEqual)

import Factory.Decode (decodeGraph, renderFailure)
import Factory.Domain
  ( Edge
  , EdgeId(..)
  , Graph
  , GraphError(..)
  , Node
  , NodeKind(..)
  , Quality(..)
  , RelationshipKind(..)
  , renderGraphError
  , attachedRoles
  , communications
  , containmentChildren
  , containmentParent
  , incidentEdges
  , lookupNode
  , mkGraph
  , scopedId
  )
import Factory.Fixtures (rawOrdinary)

ns :: String
ns = "synthetic:demo-installation"

spec :: Spec Unit
spec = describe "graph domain" do
  describe "construction" do
    it "accepts well-formed nodes and edges" do
      case
        mkGraph [ node "p" Project, node "m" Milestone ]
          [ edge "e" Contains "p" "m" ]
        of
        Right _ -> pure unit
        Left err -> fail ("valid graph refused: " <> show err)

    it "preserves an edge to an unresolved external identity" do
      case mkGraph [ node "p" Project ] [ edge "e" Contains "p" "absent-1" ] of
        Right _ -> pure unit
        Left err -> fail ("unresolved endpoint rejected: " <> show err)

    it "rejects duplicate node identities" do
      case mkGraph [ node "p" Project, node "p" Milestone ] [] of
        Left (DuplicateNode _) -> pure unit
        Left err -> fail ("wrong rejection: " <> renderGraphError err)
        Right _ -> fail "expected duplicate rejection"

    it "rejects duplicate edge identities" do
      case
        mkGraph [ node "p" Project, node "m" Milestone ]
          [ edge "e" Contains "p" "m", edge "e" Contains "m" "p" ]
        of
        Left (DuplicateEdge _) -> pure unit
        Left err -> fail ("wrong rejection: " <> renderGraphError err)
        Right _ -> fail "expected duplicate rejection"

    it "rejects a self loop" do
      case mkGraph [ node "p" Project ] [ edge "e" Contains "p" "p" ] of
        Left (SelfLoop _) -> pure unit
        Left err -> fail ("wrong rejection: " <> renderGraphError err)
        Right _ -> fail "expected self-loop rejection"

    it "rejects containment that skips or inverts the chain" do
      case
        mkGraph [ node "epic" EpicIssue, node "proj" Project ]
          [ edge "e" Contains "epic" "proj" ]
        of
        Left (BadContainment _ _ _) -> pure unit
        Left err -> fail ("wrong rejection: " <> renderGraphError err)
        Right _ -> fail "expected containment rejection"

    it "rejects attachment that does not end at a role" do
      case
        mkGraph [ node "t" TicketIssue, node "pr" PullRequest ]
          [ edge "e" AttachesRole "t" "pr" ]
        of
        Left (BadAttachment _) -> pure unit
        Left err -> fail ("wrong rejection: " <> renderGraphError err)
        Right _ -> fail "expected attachment rejection"

    it "rejects communication that does not start at a role" do
      case
        mkGraph [ node "t" TicketIssue, node "pr" PullRequest ]
          [ edge "e" RecordsCommunication "t" "pr" ]
        of
        Left (BadCommunication _) -> pure unit
        Left err -> fail ("wrong rejection: " <> renderGraphError err)
        Right _ -> fail "expected communication rejection"

  describe "queries on the synthetic installation" do
    it "answers containment children in record order" do
      graph <- ordinaryGraph
      containmentChildren graph (scopedId ns "project-1")
        `shouldEqual` [ scopedId ns "milestone-1", scopedId ns "milestone-2" ]

    it "answers the containment parent" do
      graph <- ordinaryGraph
      containmentParent graph (scopedId ns "ticket-1")
        `shouldEqual` Just (scopedId ns "epic-1")
      containmentParent graph (scopedId ns "project-1") `shouldEqual` Nothing

    it "answers attached roles" do
      graph <- ordinaryGraph
      map (_.title) (attachedRoles graph (scopedId ns "ticket-1"))
        `shouldEqual` [ "Graph Maintainer" ]

    it "answers recorded communications" do
      graph <- ordinaryGraph
      length (communications graph (scopedId ns "role-1")) `shouldEqual` 2

    it "answers incident edges" do
      graph <- ordinaryGraph
      length (incidentEdges graph (scopedId ns "pr-1")) `shouldEqual` 2

    it "does not invent the unresolved external node" do
      graph <- ordinaryGraph
      lookupNode graph (scopedId ns "external-ref-404") `shouldEqual` Nothing

  describe "observation quality" do
    it "keeps the four states distinct" do
      Known { provenance: "a", freshness: "b" } `shouldNotEqual` Unknown
      Stale { provenance: "a", asOf: "b" } `shouldNotEqual` Unknown
      MissingReference `shouldNotEqual` Unknown
      Known { provenance: "a", freshness: "b" }
        `shouldNotEqual` Stale { provenance: "a", asOf: "b" }

ordinaryGraph :: forall m. MonadThrow Error m => m Graph
ordinaryGraph = case decodeGraph rawOrdinary of
  Right g -> pure g
  Left fs -> throwError (error ("fixture refused: " <> show (map renderFailure fs)))

node :: String -> NodeKind -> Node
node key kind =
  { id: scopedId "s" key
  , kind
  , title: key
  , summary: ""
  , status: "open"
  , sourceRef: Nothing
  , quality: Unknown
  }

edge :: String -> RelationshipKind -> String -> String -> Edge
edge key kind fromKey toKey =
  { id: EdgeId { source: "s", key }
  , kind
  , from: scopedId "s" fromKey
  , to: scopedId "s" toKey
  }

