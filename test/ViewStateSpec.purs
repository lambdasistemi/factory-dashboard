module Test.ViewStateSpec (spec) where

import Prelude

import Control.Monad.Error.Class (class MonadThrow, throwError)
import Data.Either (Either(..))
import Data.Array (length)
import Data.Maybe (Maybe(..))
import Effect.Exception (Error, error)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (fail, shouldEqual, shouldSatisfy)

import Factory.Decode (decodeGraph, renderFailure)
import Factory.Domain (EdgeId(..), Graph, scopedId)
import Factory.Fixtures (rawOrdinary)
import Factory.ViewState
  ( ContextView(..)
  , Dimensions(..)
  , EndpointName(..)
  , Expansion
  , Navigation(..)
  , Selection(..)
  , collapse
  , deriveVisible
  , emptyExpansion
  , expand
  , fitViewport
  , initialViewport
  , isCollapsed
  , applyNavigation
  , resolveContext
  )

ns :: String
ns = "synthetic:demo-installation"

spec :: Spec Unit
spec = describe "view state" do
  describe "expansion" do
    it "collapses and expands by stable identity" do
      let id = scopedId ns "milestone-1"
      isCollapsed id (collapse id emptyExpansion) `shouldEqual` true
      isCollapsed id (expand id (collapse id emptyExpansion)) `shouldEqual` false

  describe "viewport" do
    it "accumulates pan within bounds" do
      let v = applyNavigation (Dim { width: 800.0, height: 600.0 }) Nothing initialViewport (PanBy { dx: 120.0, dy: 40.0 })
      v `shouldEqual` initialViewport { tx = 120.0, ty = 40.0 }

    it "clamps pan to the documented bounds" do
      let v = applyNavigation (Dim { width: 800.0, height: 600.0 }) Nothing initialViewport (PanBy { dx: 100000.0, dy: -100000.0 })
      v.tx `shouldEqual` 4000.0
      v.ty `shouldEqual` (-4000.0)

    it "clamps zoom to the documented bounds" do
      let
        up = applyNavigation (Dim { width: 800.0, height: 600.0 }) Nothing initialViewport (ZoomBy 100.0)
        down = applyNavigation (Dim { width: 800.0, height: 600.0 }) Nothing initialViewport (ZoomBy (-100.0))
      up.scale `shouldEqual` 4.0
      down.scale `shouldEqual` 0.25

    it "keeps every result inside the finite bounds" do
      let
        v = applyNavigation (Dim { width: 800.0, height: 600.0 }) Nothing initialViewport (ZoomBy 0.5)
      v.tx `shouldSatisfy` betweenNegAndPos4000
      v.ty `shouldSatisfy` betweenNegAndPos4000
      v.scale `shouldSatisfy` (\s -> s >= 0.25 && s <= 4.0)

    it "resets to the initial viewport" do
      let
        moved = applyNavigation (Dim { width: 800.0, height: 600.0 }) Nothing initialViewport (PanBy { dx: 300.0, dy: 200.0 })
        reset = applyNavigation (Dim { width: 800.0, height: 600.0 }) Nothing moved ResetView
      reset `shouldEqual` initialViewport

    it "round-trips back to the initial context" do
      let
        dims = Dim { width: 800.0, height: 600.0 }
        wander1 = applyNavigation dims Nothing initialViewport (PanBy { dx: 250.0, dy: 0.0 })
        wander2 = applyNavigation dims Nothing wander1 (ZoomBy 0.5)
        home = applyNavigation dims Nothing wander2 ResetView
      home `shouldEqual` initialViewport

  describe "fit" do
    it "keeps the initial viewport for an empty graph" do
      fitViewport Nothing (Dim { width: 800.0, height: 600.0 }) initialViewport
        `shouldEqual` initialViewport

    it "centers a singleton at scale one" do
      let bounds = { minX: 300.0, minY: 220.0, maxX: 300.0, maxY: 220.0 }
      let v = fitViewport (Just bounds) (Dim { width: 800.0, height: 600.0 }) initialViewport
      v.scale `shouldEqual` 1.0
      -- the single node must land at the container centre
      v.tx `shouldEqual` (800.0 / 2.0 - 300.0)
      v.ty `shouldEqual` (600.0 / 2.0 - 220.0)

    it "fits a wide graph inside the container" do
      let bounds = { minX: 0.0, minY: 0.0, maxX: 2400.0, maxY: 400.0 }
      let v = fitViewport (Just bounds) (Dim { width: 800.0, height: 600.0 }) initialViewport
      let
        fittedWidth = (bounds.maxX - bounds.minX) * v.scale
        fittedHeight = (bounds.maxY - bounds.minY) * v.scale
      when (fittedWidth > 800.0 + 0.5) (fail "fitted graph is wider than the container")
      when (fittedHeight > 600.0 + 0.5) (fail "fitted graph is taller than the container")

    it "reports an unavailable container explicitly" do
      let bounds = { minX: 0.0, minY: 0.0, maxX: 2400.0, maxY: 400.0 }
      let moved = initialViewport { scale = 2.0 }
      let v = fitViewport (Just bounds) Unavailable moved
      v.scale `shouldEqual` 2.0

  describe "visible graph" do
    it "shows everything when nothing is collapsed" do
      graph <- ordinaryGraph
      let visible = deriveVisible graph emptyExpansion
      length visible.nodes `shouldEqual` 10
      length visible.edges `shouldEqual` 12
      length visible.unresolved `shouldEqual` 1
      visible.hiddenCount `shouldEqual` 0

    it "hides only the containment subtree of a collapsed node" do
      graph <- ordinaryGraph
      let visible = deriveVisible graph (collapse (scopedId ns "project-1") emptyExpansion)
      length visible.nodes `shouldEqual` 3
      visible.hiddenCount `shouldEqual` 7

    it "expands back completely" do
      graph <- ordinaryGraph
      let expanded = expand (scopedId ns "project-1") (collapse (scopedId ns "project-1") emptyExpansion)
      let visible = deriveVisible graph expanded
      length visible.nodes `shouldEqual` 10
      visible.hiddenCount `shouldEqual` 0

  describe "context resolution" do
    it "resolves a selected node with its permitted context" do
      graph <- ordinaryGraph
      case resolveContextOf graph emptyExpansion (NodeSelected (scopedId ns "ticket-1")) of
        NodeContext _ -> pure unit
        other -> fail ("expected node context, got " <> contextName other)

    it "explains a collapsed selection instead of hiding it" do
      graph <- ordinaryGraph
      let expansion = collapse (scopedId ns "epic-1") emptyExpansion
      case resolveContextOf graph expansion (NodeSelected (scopedId ns "ticket-1")) of
        CollapsedSelection { id, hiddenCount } -> do
          id `shouldEqual` scopedId ns "ticket-1"
          hiddenCount `shouldEqual` 2
        other -> fail ("expected collapsed explanation, got " <> contextName other)

    it "restores the same identity after expanding" do
      graph <- ordinaryGraph
      let
        expansion = expand (scopedId ns "epic-1") (collapse (scopedId ns "epic-1") emptyExpansion)
      case resolveContextOf graph expansion (NodeSelected (scopedId ns "ticket-1")) of
        NodeContext { node } -> node.id `shouldEqual` scopedId ns "ticket-1"
        other -> fail ("expected restored node context, got " <> contextName other)

    it "names a missing endpoint explicitly on an unresolved edge" do
      graph <- ordinaryGraph
      case resolveContextOf graph emptyExpansion (EdgeSelected (EdgeId { source: ns, key: "ext-1" })) of
        EdgeContext { toName } -> toName `shouldEqual` MissingEndpoint (scopedId ns "external-ref-404")
        other -> fail ("expected edge context, got " <> contextName other)

    it "answers an unavailable context honestly" do
      graph <- ordinaryGraph
      case resolveContextOf graph emptyExpansion (NodeSelected (scopedId ns "not-in-graph")) of
        UnavailableContext _ -> pure unit
        other -> fail ("expected unavailable context, got " <> contextName other)

ordinaryGraph :: forall m. MonadThrow Error m => m Graph
ordinaryGraph = case decodeGraph rawOrdinary of
  Right g -> pure g
  Left fs -> throwError (error ("fixture refused: " <> show (map renderFailure fs)))

resolveContextOf :: Graph -> Expansion -> Selection -> ContextView
resolveContextOf graph expansion selection = resolveContext graph expansion selection

contextName :: ContextView -> String
contextName = case _ of
  NoContext -> "no context"
  NodeContext _ -> "node context"
  CollapsedSelection _ -> "collapsed selection"
  EdgeContext _ -> "edge context"
  UnavailableContext _ -> "unavailable context"

betweenNegAndPos4000 :: Number -> Boolean
betweenNegAndPos4000 x = x >= -4000.0 && x <= 4000.0
