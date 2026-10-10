module Test.LayoutSpec (spec) where

import Prelude

import Control.Monad.Error.Class (class MonadThrow, throwError)
import Data.Either (Either(..))
import Data.Array (length)
import Effect.Exception (Error, error)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (fail, shouldEqual)

import Factory.Decode (decodeGraph, renderFailure)
import Factory.Domain (Graph, scopedId)
import Factory.Fixtures (rawEmpty, rawOrdinary)
import Factory.Layout (layoutGraph)

ns :: String
ns = "synthetic:demo-installation"

spec :: Spec Unit
spec = describe "layout" do
  it "places every node of the synthetic installation" do
    graph <- ordinaryGraph
    let placed = layoutGraph graph
    length placed.nodes `shouldEqual` 10

  it "places unresolved endpoints in their own ghost column" do
    graph <- ordinaryGraph
    let placed = layoutGraph graph
    length placed.ghosts `shouldEqual` 1
    case placed.ghosts of
      [ ghost ] -> ghost.id `shouldEqual` scopedId ns "external-ref-404"
      _ -> fail "expected exactly one ghost"

  it "is deterministic across calls" do
    graph <- ordinaryGraph
    layoutGraph graph `shouldEqual` layoutGraph graph

  it "lays out an empty graph without positions" do
    case decodeGraph rawEmpty of
      Right graph -> do
        let placed = layoutGraph graph
        length placed.nodes `shouldEqual` 0
        length placed.ghosts `shouldEqual` 0
      Left fs -> fail ("empty fixture refused: " <> show (map renderFailure fs))

ordinaryGraph :: forall m. MonadThrow Error m => m Graph
ordinaryGraph = case decodeGraph rawOrdinary of
  Right g -> pure g
  Left fs -> throwError (error ("fixture refused: " <> show (map renderFailure fs)))
