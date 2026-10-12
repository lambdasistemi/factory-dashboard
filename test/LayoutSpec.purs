module Test.LayoutSpec (spec) where

import Prelude

import Control.Monad.Error.Class (class MonadThrow, throwError)
import Data.Either (Either(..))
import Data.Array (length, elem)
import Data.String (joinWith)
import Data.String.CodeUnits as CU
import Data.Foldable (all)
import Effect.Exception (Error, error)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (fail, shouldEqual)

import Factory.Decode (decodeGraph, renderFailure)
import Factory.Domain (Graph, scopedId)
import Factory.Fixtures (rawEmpty, rawOrdinary)
import Factory.Layout (layoutInput, nodeKey, titleLines)

ns :: String
ns = "synthetic:demo-installation"

spec :: Spec Unit
spec = describe "layout" do
  it "places every node of the synthetic installation" do
    graph <- ordinaryGraph
    let placed = layoutInput graph
    length placed.nodes `shouldEqual` 11

  it "includes every unresolved endpoint in the geometry request" do
    graph <- ordinaryGraph
    let placed = layoutInput graph
    length placed.edges `shouldEqual` 12
    (map _.id placed.nodes # elem (nodeKey (scopedId ns "external-ref-404"))) `shouldEqual` true

  it "keeps distinct scoped identities distinct even with separators" do
    (nodeKey (scopedId "a/b" "c") == nodeKey (scopedId "a" "b/c")) `shouldEqual` false

  it "bounds long unbroken labels while preserving ordinary text" do
    let long = "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz"
    length (titleLines long) `shouldEqual` 2
    all (\line -> CU.length line <= 26) (titleLines long) `shouldEqual` true
    joinWith "" (titleLines "Review note <img src=x onerror=window.__xss=1>") `shouldEqual` "Review note <img src=x onerror=window.__xss=1>"

  it "is deterministic across calls" do
    graph <- ordinaryGraph
    layoutInput graph `shouldEqual` layoutInput graph

  it "lays out an empty graph without positions" do
    case decodeGraph rawEmpty of
      Right graph -> do
        let placed = layoutInput graph
        length placed.nodes `shouldEqual` 0
        length placed.edges `shouldEqual` 0
      Left fs -> fail ("empty fixture refused: " <> show (map renderFailure fs))

ordinaryGraph :: forall m. MonadThrow Error m => m Graph
ordinaryGraph = case decodeGraph rawOrdinary of
  Right g -> pure g
  Left fs -> throwError (error ("fixture refused: " <> show (map renderFailure fs)))
