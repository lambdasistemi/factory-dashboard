-- | The graph application: Halogen component rendering the SVG graph,
-- | scenario controls, viewport controls and the permitted context of the
-- | current selection. All transitions live in the pure domain, view-state
-- | and layout modules; browser effects stay behind the platform FFI.
module Factory.View
  ( component
  ) where

import Prelude

import Data.Array (filter, find, head, index, length, mapMaybe, null, takeWhile, uncons)
import Data.Either (Either(..))
import Data.Foldable (maximum, minimum)
import Data.Int (toNumber)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String (joinWith)
import Data.Tuple (Tuple(..))
import Effect.Class (class MonadEffect, liftEffect)

import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Core (AttrName(..), Namespace(..))
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Subscription as HS

import Web.DOM.Document (toEventTarget)
import Web.Event.Event (EventType(..))
import Web.Event.EventTarget (addEventListener, eventListener)
import Web.HTML (window)
import Web.HTML.Window (document)
import Web.HTML.HTMLDocument (toDocument)
import Web.HTML.HTMLElement (HTMLElement, toElement)
import Web.UIEvent.KeyboardEvent as KE
import Web.UIEvent.MouseEvent as ME

import Factory.Decode (DecodeFailure, decodeGraph, renderFailure)
import Factory.Domain
  ( Edge
  , EdgeId(..)
  , Graph
  , NodeKind(..)
  , Quality(..)
  , RelationshipKind(..)
  , ScopedId(..)
  , attachedRoles
  , containmentChildren
  , containmentParent
  , kindLabel
  , lookupNode
  , nodeIds
  , qualityLabel
  , relationLabel
  )
import Factory.Layout (Position, layoutGraph, nodeSize)
import Factory.Platform (containerSize, focusNode)
import Factory.Scenarios (defaultScenario, scenarios)
import Factory.ViewState
  ( ContextView(..)
  , Dimensions(..)
  , EndpointName(..)
  , Navigation(..)
  , Selection(..)
  , ViewState
  , applyNavigation
  , deriveVisible
  , fitViewport
  , initialViewState
  , isCollapsed
  , resolveContext
  )
import Factory.ViewState as VS

type State =
  { scenarioKey :: String
  , doc :: Either (Array DecodeFailure) Graph
  , view :: ViewState
  , dims :: Dimensions
  , focused :: Maybe ScopedId
  , dragging :: Maybe { x :: Number, y :: Number }
  }

data Action
  = Init
  | SwitchScenario String
  | SelectNode ScopedId
  | SelectEdge EdgeId
  | ClearSelection
  | ToggleCollapse ScopedId
  | ExpandRoute ScopedId
  | Navigate Navigation
  | FitNow
  | FocusNode ScopedId
  | FocusEdge EdgeId
  | BlurGraph
  | GlobalKey String
  | NodeKey ScopedId String
  | DragStart Number Number
  | DragMove Number Number
  | DragEnd

svgNamespace :: Namespace
svgNamespace = Namespace "http://www.w3.org/2000/svg"

stageRef :: H.RefLabel
stageRef = H.RefLabel "stage"

component :: forall q i o m. MonadEffect m => H.Component q i o m
component =
  H.mkComponent
    { initialState: initialState
    , render: render
    , eval: H.mkEval $ H.defaultEval
        { handleAction = handleAction
        , initialize = Just Init
        }
    }
  where
  initialState _ =
    { scenarioKey: defaultScenario.key
    , doc: decodeGraph defaultScenario.raw
    , view: initialViewState
    , dims: Unavailable
    , focused: Nothing
    , dragging: Nothing
    }

  -- ------------------------------------------------------------ evaluate

  handleAction = case _ of
    Init -> do
      subscribeKeys
      measureAndFit

    SwitchScenario key -> do
      let scenario = fromMaybe defaultScenario (find (\s -> s.key == key) scenarios)
      H.modify_ \s ->
        s
          { scenarioKey = key
          , doc = decodeGraph scenario.raw
          , view = initialViewState
          , focused = Nothing
          }
      measureAndFit

    SelectNode id ->
      H.modify_ \s -> s { view = s.view { selection = NodeSelected id } }

    SelectEdge id ->
      H.modify_ \s -> s { view = s.view { selection = EdgeSelected id } }

    ClearSelection ->
      H.modify_ \s -> s { view = s.view { selection = NoSelection } }

    ToggleCollapse id -> do
      st <- H.get
      let
        expansion' =
          if isCollapsed id st.view.expansion then VS.expand id st.view.expansion
          else VS.collapse id st.view.expansion
      H.modify_ \s -> s { view = s.view { expansion = expansion' } }
      measureAndFit

    ExpandRoute id -> do
      st <- H.get
      H.modify_ \s -> s { view = s.view { expansion = VS.expand id st.view.expansion } }
      measureAndFit

    Navigate navigation ->
      H.modify_ \st ->
        st
          { view = st.view
              { viewport =
                  applyNavigation st.dims (contentBounds st) st.view.viewport navigation
              }
          }

    FitNow -> measureAndFit

    FocusNode id -> H.modify_ \s -> s { focused = Just id }

    FocusEdge _ -> pure unit

    BlurGraph -> H.modify_ \s -> s { focused = Nothing }

    GlobalKey key -> handleGlobalKey key

    NodeKey id k
      | k == "Enter" || k == " " -> handleAction (SelectNode id)
      | k == "c" -> handleAction (ToggleCollapse id)
      | otherwise -> pure unit

    DragStart x y -> H.modify_ \s -> s { dragging = Just { x, y } }

    DragMove x y -> do
      st <- H.get
      case st.dragging of
        Just d ->
          H.modify_ \s ->
            s
              { dragging = Just { x, y }
              , view = s.view
                  { viewport =
                      applyNavigation st.dims (contentBounds st) st.view.viewport
                        (PanBy { dx: x - d.x, dy: y - d.y })
                  }
              }
        Nothing -> pure unit

    DragEnd -> H.modify_ \s -> s { dragging = Nothing }

  -- ------------------------------------------------------------ keyboard

  subscribeKeys = do
    { emitter, listener } <- liftEffect HS.create
    doc <- liftEffect (map toDocument (window >>= document))
    let
      onKey ev = case KE.fromEvent ev of
        Just ke -> HS.notify listener (GlobalKey (KE.key ke))
        Nothing -> pure unit
    keyListener <- liftEffect (eventListener onKey)
    liftEffect (addEventListener (EventType "keydown") keyListener false (toEventTarget doc))
    _ <- H.subscribe emitter
    pure unit

  handleGlobalKey key = do
    st <- H.get
    case key of
      "Escape" -> handleAction ClearSelection
      "f" -> handleAction FitNow
      "+" -> handleAction (Navigate (ZoomBy 1.25))
      "-" -> handleAction (Navigate (ZoomBy 0.8))
      "0" -> handleAction (Navigate ResetView)
      "ArrowUp" -> case st.focused of
        Just id -> case st.doc of
          Right graph -> case containmentParent graph id of
            Just parent -> liftEffect (focusNode (nodeSelector parent))
            Nothing -> pure unit
          Left _ -> pure unit
        Nothing -> pure unit
      "ArrowDown" -> case st.focused of
        Just id -> case st.doc of
          Right graph -> case firstChildOrRole graph id of
            Just target -> liftEffect (focusNode (nodeSelector target))
            Nothing -> pure unit
          Left _ -> pure unit
        Nothing -> pure unit
      "ArrowLeft" -> focusSibling st (-1)
      "ArrowRight" -> focusSibling st 1
      "c" -> case st.focused of
        Just id -> handleAction (ToggleCollapse id)
        Nothing -> pure unit
      _ -> pure unit

  firstChildOrRole :: Graph -> ScopedId -> Maybe ScopedId
  firstChildOrRole graph id =
    case head (containmentChildren graph id) of
      Just child -> Just child
      Nothing -> map (_.id) (head (attachedRoles graph id))

  focusSibling st direction = case st.focused of
    Nothing -> pure unit
    Just id -> case st.doc of
      Right graph -> case containmentParent graph id of
        Nothing -> pure unit
        Just parent -> do
          let
            children = containmentChildren graph parent
            myIndex = length (takeWhile (_ /= id) children)
            pick = if direction > 0 then myIndex else myIndex - 1
            siblings = filter (_ /= id) children
          case index siblings pick of
            Just target -> liftEffect (focusNode (nodeSelector target))
            Nothing -> pure unit
      Left _ -> pure unit

  -- ------------------------------------------------------------ measure

  measureAndFit = do
    mel <- H.getHTMLElementRef stageRef
    case mel of
      Nothing -> pure unit
      Just el -> do
        msize <- liftEffect (containerSize (toElement (el :: HTMLElement)))
        let
          dims = case msize of
            Just s | s.width > 0.0 && s.height > 0.0 -> Dim s
            _ -> Unavailable
        H.modify_ \st ->
          st
            { dims = dims
            , view = st.view
                { viewport = fitViewport (contentBounds st) dims st.view.viewport }
            }

  -- ------------------------------------------------------------ render

  render st =
    HH.div [ HP.class_ (H.ClassName "app") ]
      [ HH.header [ HP.class_ (H.ClassName "app-header") ]
          [ HH.h1_ [ HH.text "Factory graph" ]
          , HH.nav [ HP.class_ (H.ClassName "scenario-bar") ]
              (map (scenarioButton st) scenarios)
          , HH.p [ HP.class_ (H.ClassName "app-status") ] [ HH.text (statusText st) ]
          ]
      , HH.main [ HP.class_ (H.ClassName "app-main") ]
          [ HH.section
              [ HP.class_ (H.ClassName "graph-stage")
              , HP.ref stageRef
              , HE.onMouseDown (mouseAction DragStart)
              , HE.onMouseMove (mouseAction DragMove)
              , HE.onMouseUp \_ -> DragEnd
              , HE.onMouseLeave \_ -> DragEnd
              ]
              (stageContent st)
          , HH.aside [ HP.class_ (H.ClassName "details") ] (detailsContent st)
          ]
      ]

  scenarioButton st scenario =
    HH.button
      [ HP.class_ (H.ClassName "scenario-button")
      , HP.attr (AttrName "data-scenario") scenario.key
      , HP.attr (AttrName "aria-pressed") (if scenario.key == st.scenarioKey then "true" else "false")
      , HE.onClick \_ -> SwitchScenario scenario.key
      ]
      [ HH.text scenario.label ]

  stageContent st = case st.doc of
    Right graph
      | length (nodeIds graph) > 0 -> [ svgGraph st graph, overlay ]
      | otherwise ->
          [ HH.div [ HP.class_ (H.ClassName "empty-state") ]
              [ HH.text "This installation has no records yet." ]
          , overlay
          ]
    Left _ ->
      [ HH.div [ HP.class_ (H.ClassName "empty-state") ]
          [ HH.text "Input refused — the refusal list is shown beside the graph." ]
      ]

  overlay =
    HH.div [ HP.class_ (H.ClassName "stage-overlay") ]
      [ HH.div [ HP.class_ (H.ClassName "view-controls") ]
          [ HH.button [ HE.onClick \_ -> Navigate (ZoomBy 1.25) ] [ HH.text "Zoom in" ]
          , HH.button [ HE.onClick \_ -> Navigate (ZoomBy 0.8) ] [ HH.text "Zoom out" ]
          , HH.button [ HE.onClick \_ -> FitNow ] [ HH.text "Fit" ]
          , HH.button [ HE.onClick \_ -> Navigate ResetView ] [ HH.text "Reset view" ]
          ]
      , HH.div [ HP.class_ (H.ClassName "legend") ]
          [ HH.span_ [ legendLine "edge-contains", HH.text " contains" ]
          , HH.span_ [ legendLine "edge-attaches", HH.text " attaches role" ]
          , HH.span_ [ legendLine "edge-communication", HH.text " recorded communication" ]
          ]
      ]

  legendLine cls =
    svgEl "svg"
      [ svgClass ("edge " <> cls)
      , HP.attr (AttrName "viewBox") "0 0 34 8"
      , HP.attr (AttrName "aria-hidden") "true"
      ]
      [ svgEl "path"
          [ HP.attr (AttrName "d") "M1 4 H33"
          , HP.attr (AttrName "stroke") "currentColor"
          ]
          []
      ]

  svgGraph st graph =
    let
      visible = deriveVisible graph st.view.expansion
      laid = layoutGraph graph
      positionMap = Map.fromFoldable (map (\e -> Tuple e.id e.pos) laid.nodes)
      ghostMap = Map.fromFoldable (map (\e -> Tuple e.id e.pos) laid.ghosts)
      viewport = st.view.viewport
    in
      svgEl "svg"
        [ svgClass "graph"
        , HP.attr (AttrName "role") "group"
        , HP.attr (AttrName "aria-label") "Factory graph"
        ]
        [ svgEl "g"
            [ HP.attr (AttrName "id") "viewport"
            , HP.attr (AttrName "transform")
                ( "translate(" <> show viewport.tx <> "," <> show viewport.ty
                    <> ") scale("
                    <> show viewport.scale
                    <> ")"
                )
            ]
            ( map (renderEdge st positionMap ghostMap) visible.edges
                <> map (renderGhost ghostMap) (distinctEndpoints visible.unresolved)
                <> map (renderNode st positionMap) visible.nodes
            )
        ]

  renderNode st positionMap node =
    let
      pos = fromMaybe { x: 0.0, y: 0.0 } (Map.lookup node.id positionMap)
      selected = st.view.selection == NodeSelected node.id
      collapsed = isCollapsed node.id st.view.expansion
      hasChildren = case st.doc of
        Right graph -> length (containmentChildren graph node.id) > 0
        Left _ -> false
      ariaText =
        kindLabel node.kind
          <> ": "
          <> node.title
          <> (if collapsed then " (collapsed)" else "")
          <> (if selected then " (selected)" else "")
    in
      svgEl "g"
        [ svgClass
            ( "node kind-" <> kindClass node.kind
                <> (if selected then " selected" else "")
                <> (if collapsed then " collapsed" else "")
            )
        , HP.attr (AttrName "data-node-id") (idString node.id)
        , HP.attr (AttrName "transform") (translateOf pos)
        , HP.attr (AttrName "tabindex") "0"
        , HP.attr (AttrName "role") "button"
        , HP.attr (AttrName "aria-label") ariaText
        , HE.onKeyDown \ke -> NodeKey node.id (KE.key ke)
        , HE.onFocus \_ -> FocusNode node.id
        , HE.onBlur \_ -> BlurGraph
        ]
        ( [ svgEl "g"
              [ svgClass "node-body"
              , HE.onClick \_ -> SelectNode node.id
              ]
              (nodeShape node <> qualityBadge node)
          ]
            <> (if hasChildren then [ collapseToggle node collapsed ] else [])
        )

  nodeShape node = case node.kind of
    Role ->
      [ svgEl "circle"
          [ HP.attr (AttrName "cx") (show (nodeSize.width / 2.0))
          , HP.attr (AttrName "cy") "22"
          , HP.attr (AttrName "r") "22"
          ]
          []
      , svgEl "text"
          [ HP.attr (AttrName "x") (show (nodeSize.width / 2.0))
          , HP.attr (AttrName "y") "58"
          , HP.attr (AttrName "text-anchor") "middle"
          ]
          [ HH.text node.title ]
      ]
    _ ->
      [ svgEl "rect"
          [ HP.attr (AttrName "width") (show nodeSize.width)
          , HP.attr (AttrName "height") (show nodeSize.height)
          , HP.attr (AttrName "rx") "6"
          ]
          []
      , svgEl "text"
          [ HP.attr (AttrName "x") "10"
          , HP.attr (AttrName "y") "18"
          ]
          [ HH.text node.title ]
      , svgEl "text"
          [ svgClass "node-kind"
          , HP.attr (AttrName "x") "10"
          , HP.attr (AttrName "y") "33"
          ]
          [ HH.text (kindLabel node.kind) ]
      ]

  qualityBadge node = case node.quality of
    Known _ -> []
    _ ->
      [ svgEl "text"
          [ svgClass "badge"
          , HP.attr (AttrName "x") "10"
          , HP.attr (AttrName "y") "-6"
          ]
          [ HH.text (qualityLabel node.quality) ]
      ]

  collapseToggle node collapsed =
    svgEl "g"
      [ svgClass "collapse-toggle"
      , HP.attr (AttrName "role") "button"
      , HP.attr (AttrName "tabindex") "-1"
      , HP.attr (AttrName "aria-label")
          ((if collapsed then "expand " else "collapse ") <> node.title)
      , HE.onClick \_ -> ToggleCollapse node.id
      ]
      [ svgEl "circle"
          [ HP.attr (AttrName "cx") (show (nodeSize.width + 8.0))
          , HP.attr (AttrName "cy") "22"
          , HP.attr (AttrName "r") "9"
          ]
          []
      , svgEl "text"
          [ HP.attr (AttrName "x") (show (nodeSize.width + 8.0))
          , HP.attr (AttrName "y") "26"
          , HP.attr (AttrName "text-anchor") "middle"
          ]
          [ HH.text (if collapsed then "+" else "-") ]
      ]

  renderEdge st positionMap ghostMap edge =
    let
      fromPos = endpointPos positionMap ghostMap edge.from
      toPos = endpointPos positionMap ghostMap edge.to
      fromRole = isRoleNode st edge.from
      toRole = isRoleNode st edge.to
      d = pathBetween fromRole toRole fromPos toPos edge.kind
      selected = st.view.selection == EdgeSelected edge.id
      fromTitle = titleOf st edge.from
      toTitle = titleOf st edge.to
    in
      svgEl "g"
        [ svgClass
            ("edge edge-" <> relationClass edge.kind <> (if selected then " selected" else ""))
        , HP.attr (AttrName "data-edge-id") (edgeString edge.id)
        , HP.attr (AttrName "tabindex") "0"
        , HP.attr (AttrName "role") "button"
        , HP.attr (AttrName "aria-label")
            (relationLabel edge.kind <> ": " <> fromTitle <> " to " <> toTitle)
        , HE.onClick \_ -> SelectEdge edge.id
        , HE.onFocus \_ -> FocusEdge edge.id
        , HE.onBlur \_ -> BlurGraph
        ]
        [ svgEl "path"
            [ svgClass "edge-hit"
            , HP.attr (AttrName "d") d
            , HP.attr (AttrName "fill") "none"
            , HP.attr (AttrName "pointer-events") "all"
            ]
            []
        , svgEl "path" [ HP.attr (AttrName "d") d ] []
        ]

  renderGhost ghostMap endpoint =
    let
      pos = fromMaybe { x: 0.0, y: 0.0 } (Map.lookup endpoint ghostMap)
      (ScopedId r) = endpoint
    in
      svgEl "g"
        [ svgClass "ghost"
        , HP.attr (AttrName "data-ghost-id") (idString endpoint)
        , HP.attr (AttrName "transform") (translateOf pos)
        , HP.attr (AttrName "tabindex") "0"
        , HP.attr (AttrName "role") "button"
        , HP.attr (AttrName "aria-label") ("missing reference: " <> r.key)
        ]
        [ svgEl "rect"
            [ HP.attr (AttrName "width") (show nodeSize.width)
            , HP.attr (AttrName "height") (show nodeSize.height)
            , HP.attr (AttrName "rx") "6"
            ]
            []
        , svgEl "text"
            [ HP.attr (AttrName "x") "10"
            , HP.attr (AttrName "y") "18"
            ]
            [ HH.text ("missing: " <> r.key) ]
        , svgEl "text"
            [ svgClass "node-kind"
            , HP.attr (AttrName "x") "10"
            , HP.attr (AttrName "y") "33"
            ]
            [ HH.text "external reference" ]
        ]

  -- ------------------------------------------------------------ details

  detailsContent st = case st.doc of
    Left failures ->
      [ HH.div [ HP.class_ (H.ClassName "refusal") ]
          [ HH.h2_ [ HH.text ("Input refused — " <> show (length failures) <> " problems") ]
          , HH.ul_ (map (\f -> HH.li_ [ HH.text (renderFailure f) ]) failures)
          ]
      ]
    Right graph -> case resolveContext graph st.view.expansion st.view.selection of
      NoContext ->
        [ HH.h2_ [ HH.text "Nothing selected" ]
        , HH.p_
            [ HH.text
                "Select a record or connection to inspect its context. Every node and connection is reachable with Tab and the arrow keys; Enter selects, c collapses, f fits."
            ]
        ]
      UnavailableContext message ->
        [ HH.h2_ [ HH.text "Context unavailable" ]
        , HH.p_ [ HH.text message ]
        ]
      CollapsedSelection info ->
        [ HH.h2_ [ HH.text info.title ]
        , HH.p_
            [ HH.text
                ( "This record is collapsed behind "
                    <> info.behindLabel
                    <> "; "
                    <> show info.hiddenCount
                    <> " records are hidden with it."
                )
            ]
        , HH.p_
            [ HH.button
                [ HP.class_ (H.ClassName "expand")
                , HE.onClick \_ -> ExpandRoute info.expandAt
                ]
                [ HH.text "Expand" ]
            ]
        ]
      EdgeContext info ->
        [ HH.h2_ [ HH.text info.kindName ]
        , HH.dl_
            [ HH.dt_ [ HH.text "From" ]
            , HH.dd_ [ HH.text (endpointText info.fromName) ]
            , HH.dt_ [ HH.text "To" ]
            , HH.dd_ [ HH.text (endpointText info.toName) ]
            , HH.dt_ [ HH.text "Reference" ]
            , HH.dd_ [ HH.text (edgeString info.edge.id) ]
            ]
        ]
      NodeContext info ->
        [ HH.h2_ [ HH.text info.node.title ]
        , HH.p [ HP.class_ (H.ClassName "kind") ] [ HH.text (kindLabel info.node.kind) ]
        , HH.dl_
            [ HH.dt_ [ HH.text "Status" ]
            , HH.dd_ [ HH.text info.node.status ]
            , HH.dt_ [ HH.text "Summary" ]
            , HH.dd_ [ HH.text info.node.summary ]
            , HH.dt_ [ HH.text "Source" ]
            , HH.dd_ [ HH.text (fromMaybe "none recorded" info.node.sourceRef) ]
            , HH.dt_ [ HH.text "Observation" ]
            , HH.dd_
                [ HH.span
                    [ HP.class_ (H.ClassName ("quality " <> qualityClass info.node.quality)) ]
                    [ HH.text (qualityLabel info.node.quality) ]
                , HH.text (qualityDetail info.node.quality)
                ]
            , HH.dt_ [ HH.text "Parent" ]
            , HH.dd_ [ HH.text (fromMaybe "no parent recorded" info.parentLabel) ]
            , HH.dt_ [ HH.text "Attached roles" ]
            , HH.dd_
                [ HH.text
                    ( case info.roles of
                        [] -> "no attachment recorded"
                        roles -> joinWith ", " (map (_.title) roles)
                    )
                ]
            , HH.dt_ [ HH.text "Recorded communications" ]
            , HH.dd_ [ HH.text (show (length info.communications)) ]
            ]
        ]

  -- ------------------------------------------------------------ helpers

  statusText st = case st.doc of
    Left failures -> "Input refused — " <> show (length failures) <> " problems"
    Right graph ->
      let
        visible = deriveVisible graph st.view.expansion
        label = case find (\s -> s.key == st.scenarioKey) scenarios of
          Just s -> s.label
          Nothing -> ""
      in
        if length visible.nodes == 0 then label <> ": no records yet"
        else if visible.hiddenCount > 0 then
          label
            <> ": "
            <> show (length visible.nodes)
            <> " records, "
            <> show (length visible.edges)
            <> " connections, "
            <> show visible.hiddenCount
            <> " hidden"
        else
          label
            <> ": "
            <> show (length visible.nodes)
            <> " records, "
            <> show (length visible.edges)
            <> " connections"

  contentBounds st = case st.doc of
    Right graph ->
      let
        visible = deriveVisible graph st.view.expansion
        laid = layoutGraph graph
        positionMap = Map.fromFoldable (map (\e -> Tuple e.id e.pos) laid.nodes)
        positions = mapMaybe (\n -> Map.lookup n.id positionMap) visible.nodes
        xs = map (_.x) positions <> map (\g -> g.pos.x) laid.ghosts
        ys = map (_.y) positions <> map (\g -> g.pos.y) laid.ghosts
      in
        if null positions && null laid.ghosts then Nothing
        else
          Just
            { minX: fromMaybe 0.0 (minimum xs)
            , minY: fromMaybe 0.0 (minimum ys)
            , maxX: fromMaybe 0.0 (maximum xs) + nodeSize.width
            , maxY: fromMaybe 0.0 (maximum ys) + nodeSize.height
            }
    Left _ -> Nothing

  mouseAction mk me = mk (toNumber (ME.clientX me)) (toNumber (ME.clientY me))

-- ------------------------------------------------------------ top-level

svgEl
  :: forall r w
   . String
  -> Array (HH.IProp r Action)
  -> Array (HH.HTML w Action)
  -> HH.HTML w Action
svgEl name props children =
  HH.elementNS svgNamespace (HH.ElemName name) props children

svgClass :: forall r i. String -> HH.IProp r i
svgClass = HP.attr (AttrName "class")

nodeSelector :: ScopedId -> String
nodeSelector id = "[data-node-id=\"" <> idString id <> "\"]"

idString :: ScopedId -> String
idString (ScopedId r) = r.namespace <> "/" <> r.key

edgeString :: EdgeId -> String
edgeString (EdgeId r) = r.source <> "/" <> r.key

kindClass :: NodeKind -> String
kindClass = case _ of
  Project -> "project"
  Milestone -> "milestone"
  EpicIssue -> "epic-issue"
  TicketIssue -> "ticket-issue"
  PullRequest -> "pull-request"
  Role -> "role"

relationClass :: RelationshipKind -> String
relationClass = case _ of
  Contains -> "contains"
  AttachesRole -> "attaches"
  RecordsCommunication -> "communication"

qualityClass :: Quality -> String
qualityClass = case _ of
  Known _ -> "known"
  Unknown -> "unknown"
  Stale _ -> "stale"
  MissingReference -> "missing"

qualityDetail :: Quality -> String
qualityDetail = case _ of
  Known q -> " — " <> q.provenance <> ", fresh " <> q.freshness
  Stale q -> " — last read " <> q.asOf
  _ -> ""

endpointText :: EndpointName -> String
endpointText = case _ of
  Present r -> r.kind <> ": " <> r.title
  MissingEndpoint (ScopedId r) -> "missing reference: " <> r.key

titleOf :: State -> ScopedId -> String
titleOf st id = case st.doc of
  Right graph -> case lookupNode graph id of
    Just n -> n.title
    Nothing -> "missing reference"
  Left _ -> "missing reference"

endpointPos :: Map ScopedId Position -> Map ScopedId Position -> ScopedId -> Position
endpointPos positionMap ghostMap id = case Map.lookup id positionMap of
  Just p -> p
  Nothing -> case Map.lookup id ghostMap of
    Just p -> p
    Nothing -> { x: 0.0, y: 0.0 }

pathBetween :: Boolean -> Boolean -> Position -> Position -> RelationshipKind -> String
pathBetween fromRole toRole from to kind =
  let
    circleR = 22.0
    circleCx p = p.x + nodeSize.width / 2.0
    circleCy = nodeSize.height / 2.0
    x1 =
      if fromRole then
        (if to.x >= from.x then circleCx from + circleR else circleCx from - circleR)
      else if to.x >= from.x then from.x + nodeSize.width
      else from.x
    y1 = if fromRole then from.y + circleCy else from.y + nodeSize.height / 2.0
    x2 =
      if toRole then
        (if from.x <= to.x then circleCx to - circleR else circleCx to + circleR)
      else if from.x <= to.x then to.x
      else to.x + nodeSize.width
    y2 = if toRole then to.y + circleCy else to.y + nodeSize.height / 2.0
  in
    case kind of
      Contains ->
        "M" <> show x1 <> " " <> show y1 <> " L" <> show x2 <> " " <> show y2
      _ ->
        let
          mx = (x1 + x2) / 2.0
          lift = case kind of
            RecordsCommunication -> -60.0
            _ -> 60.0
        in
          "M" <> show x1 <> " " <> show y1
            <> " Q"
            <> show mx
            <> " "
            <> show (min y1 y2 + lift)
            <> " "
            <> show x2
            <> " "
            <> show y2

translateOf :: Position -> String
translateOf pos = "translate(" <> show pos.x <> "," <> show pos.y <> ")"

-- | Distinct unresolved endpoints among the visible graph, in record
-- order, so the ghost column renders one marker per missing reference.
distinctEndpoints
  :: Array { edge :: Edge, endpoint :: ScopedId }
  -> Array ScopedId
distinctEndpoints unresolved =
  foldDistinct (map (_.endpoint) unresolved) []
  where
  foldDistinct rest acc = case unconsOf rest of
    Nothing -> acc
    Just { head, tail } ->
      if head `idIn` acc then foldDistinct tail acc
      else foldDistinct tail (acc <> [ head ])

idIn :: ScopedId -> Array ScopedId -> Boolean
idIn id arr = length (filter (_ == id) arr) > 0

unconsOf :: forall a. Array a -> Maybe { head :: a, tail :: Array a }
unconsOf = uncons

isRoleNode :: State -> ScopedId -> Boolean
isRoleNode st id = case st.doc of
  Right graph -> case lookupNode graph id of
    Just node -> node.kind == Role
    Nothing -> false
  Left _ -> false
