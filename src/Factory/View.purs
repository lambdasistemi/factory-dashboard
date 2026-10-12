-- | The graph application: Halogen component rendering the SVG graph,
-- | scenario controls, viewport controls and the permitted context of the
-- | current selection. Pure graph/view-state transitions are separate from
-- | browser effects and the asynchronous geometry engine.
module Factory.View
  ( component
  ) where

import Prelude

import Data.Array (filter, find, head, index, length, mapMaybe, null, mapWithIndex, takeWhile, uncons)
import Data.Either (Either(..))
import Data.Foldable (maximum, minimum)
import Data.Int (toNumber)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String (joinWith)
import Data.Tuple (Tuple(..))
import Effect.Class (liftEffect)

import Effect.Aff.Class (class MonadAff)
import Factory.LayoutEngine as LayoutEngine

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
import Web.TouchEvent.TouchEvent as TE
import Web.TouchEvent.TouchList as TL
import Web.TouchEvent.Touch as Touch
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
import Factory.Layout (Position, Geometry, layoutInput, nodeKey, edgeKey, titleLines, nodeSize)
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
  , geometry :: Maybe Geometry
  , layoutError :: Maybe String
  , revision :: Int
  , dragging :: Maybe { x :: Number, y :: Number }
  }

data Action
  = Init
  | LayoutFinished Int (Either String Geometry)
  | PickNode String
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

component :: forall q i o m. MonadAff m => H.Component q i o m
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
    , geometry: Nothing
    , layoutError: Nothing
    , revision: 0
    , dragging: Nothing
    }

  -- ------------------------------------------------------------ evaluate

  handleAction = case _ of
    Init -> do
      subscribeKeys
      requestLayout

    LayoutFinished revision result -> do
      st <- H.get
      if st.revision /= revision then pure unit
      else case result of
        Left message -> H.modify_ \s -> s { layoutError = Just message }
        Right geometry -> do
          H.modify_ \s -> s { geometry = Just geometry }
          measureAndFit

    PickNode key -> do
      st <- H.get
      case st.doc of
        Left _ -> pure unit
        Right graph -> case find (\id -> nodeKey id == key) (nodeIds graph) of
          Nothing -> pure unit
          Just id -> do
            handleAction (SelectNode id)
            revealNode id

    SwitchScenario key -> do
      let scenario = fromMaybe defaultScenario (find (\s -> s.key == key) scenarios)
      H.modify_ \s ->
        s
          { scenarioKey = key
          , doc = decodeGraph scenario.raw
          , view = initialViewState
          , focused = Nothing
          , geometry = Nothing
          , layoutError = Nothing
          , revision = s.revision + 1
          }
      requestLayout

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

    ExpandRoute id -> do
      st <- H.get
      H.modify_ \s -> s { view = s.view { expansion = VS.expand id st.view.expansion } }

    Navigate navigation ->
      H.modify_ \st ->
        st
          { view = st.view
              { viewport =
                  applyNavigation st.dims (contentBounds st) st.view.viewport navigation
              }
          }

    FitNow -> do
      st <- H.get
      H.modify_ \s -> s { view = s.view { viewport = fitViewport (contentBounds st) st.dims st.view.viewport } }

    FocusNode id -> do
      H.modify_ \s -> s { focused = Just id }
      st <- H.get
      case st.dims of
        Dim dims | dims.width < 700.0 -> revealNode id
        _ -> pure unit

    FocusEdge _ -> pure unit

    BlurGraph -> H.modify_ \s -> s { focused = Nothing }

    GlobalKey key -> handleGlobalKey key

    NodeKey id k
      | k == "Enter" || k == " " -> handleAction (SelectNode id)
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

  requestLayout = do
    st <- H.get
    case st.doc of
      Left _ -> pure unit
      Right graph -> do
        _ <- H.fork do
          result <- H.liftAff (LayoutEngine.calculate (layoutInput graph))
          handleAction (LayoutFinished st.revision result)
        pure unit

  revealNode id = do
    st <- H.get
    case st.geometry, st.dims of
      Just geometry, Dim dims -> case find (\p -> p.id == nodeKey id) geometry.nodes of
        Just p -> H.modify_ \s -> s
          { view = s.view
              { viewport =
                  { scale: 1.0
                  , tx: dims.width / 2.0 - p.x - nodeSize.width / 2.0
                  , ty: dims.height / 2.0 - p.y - nodeSize.height / 2.0
                  }
              }
          }
        Nothing -> pure unit
      _, _ -> pure unit

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
                { viewport = case dims of
                    Dim size | size.width < 700.0 -> { scale: 1.0, tx: 16.0, ty: 16.0 }
                    _ -> fitViewport (contentBounds st) dims st.view.viewport
                }
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
      , HH.div [ HP.class_ (H.ClassName "record-picker") ]
          [ HH.label_
              [ HH.text "Go to record "
              , HH.select [ HE.onValueChange PickNode ]
                  ( [ HH.option [ HP.value "" ] [ HH.text "Choose a record…" ] ] <> case st.doc of
                      Left _ -> []
                      Right graph -> mapMaybe (\id -> map (\n -> HH.option [ HP.value (nodeKey id) ] [ HH.text (kindLabel n.kind <> ": " <> n.title) ]) (lookupNode graph id)) (nodeIds graph)
                  )
              ]
          ]
      , overlay
      , HH.main [ HP.class_ (H.ClassName ("app-main" <> (if st.view.selection == NoSelection then " unselected" else ""))) ]
          [ HH.section
              [ HP.class_ (H.ClassName "graph-stage")
              , HP.ref stageRef
              , HE.onMouseDown (mouseAction DragStart)
              , HE.onMouseMove (mouseAction DragMove)
              , HE.onMouseUp \_ -> DragEnd
              , HE.onMouseLeave \_ -> DragEnd
              , HE.onTouchStart (touchAction DragStart)
              , HE.onTouchMove (touchAction DragMove)
              , HE.onTouchEnd \_ -> DragEnd
              , HE.onTouchCancel \_ -> DragEnd
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

  stageContent st = case st.layoutError of
    Just message -> [ HH.p [ HP.class_ (H.ClassName "empty-state") ] [ HH.text message ] ]
    Nothing -> graphContent st

  graphContent st = case st.doc of
    Right graph
      | length (nodeIds graph) > 0 -> case st.geometry of
          Nothing -> [ HH.p [ HP.class_ (H.ClassName "empty-state") ] [ HH.text "Arranging graph…" ] ]
          Just _ -> [ svgGraph st graph ]
      | otherwise ->
          [ HH.div [ HP.class_ (H.ClassName "empty-state") ]
              [ HH.text "This installation has no records yet." ]
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
          [ HH.span_ [ legendLine "edge-contains", HH.text " contains → parent to child" ]
          , HH.span_ [ legendLine "edge-attaches", HH.text " attaches role → responsibility" ]
          , HH.span_ [ legendLine "edge-communication", HH.text " recorded communication → about work" ]
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
      geometry = fromMaybe { nodes: [], edges: [] } st.geometry
      positions = Map.fromFoldable (map (\p -> Tuple p.id { x: p.x, y: p.y }) geometry.nodes)
      ids = nodeIds graph <> distinctEndpoints visible.unresolved
      positionMap = Map.fromFoldable (mapMaybe (\id -> map (Tuple id) (Map.lookup (nodeKey id) positions)) ids)
      ghostMap = positionMap
      viewport = st.view.viewport
    in
      svgEl "svg"
        [ svgClass "graph"
        , HP.attr (AttrName "role") "group"
        , HP.attr (AttrName "aria-label") "Factory graph"
        ]
        [ svgEl "defs" [] (map arrowMarker [ "contains", "attaches", "communication" ])
        , svgEl "g"
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

  nodeShape node =
    [ svgEl "title" [] [ HH.text node.title ]
    , svgEl "rect"
        [ HP.attr (AttrName "width") (show nodeSize.width)
        , HP.attr (AttrName "height") (show nodeSize.height)
        , HP.attr (AttrName "rx") "10"
        ]
        []
    , svgEl "text"
        [ svgClass "node-kind", HP.attr (AttrName "x") "16", HP.attr (AttrName "y") "23" ]
        [ HH.text (kindLabel node.kind) ]
    ] <> mapWithIndex
      ( \i line -> svgEl "text"
          [ svgClass "node-title", HP.attr (AttrName "x") "16", HP.attr (AttrName "y") (show (49 + i * 20)) ]
          [ HH.text line ]
      )
      (titleLines node.title)

  qualityBadge node = case node.quality of
    Known _ -> [ svgEl "text" [ svgClass "badge", HP.attr (AttrName "x") "16", HP.attr (AttrName "y") "108" ] [ HH.text (fromMaybe "" (head (titleLines (node.status <> " · observed")))) ] ]
    _ ->
      [ svgEl "text"
          [ svgClass "badge"
          , HP.attr (AttrName "x") "16"
          , HP.attr (AttrName "y") "108"
          ]
          [ HH.text (qualityLabel node.quality <> " observation") ]
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
          [ HP.attr (AttrName "cx") (show (nodeSize.width - 16.0))
          , HP.attr (AttrName "cy") "22"
          , HP.attr (AttrName "r") "9"
          ]
          []
      , svgEl "text"
          [ HP.attr (AttrName "x") (show (nodeSize.width - 16.0))
          , HP.attr (AttrName "y") "26"
          , HP.attr (AttrName "text-anchor") "middle"
          ]
          [ HH.text (if collapsed then "+" else "-") ]
      ]

  renderEdge st _ _ edge =
    let
      geometry = fromMaybe { nodes: [], edges: [] } st.geometry
      d = fromMaybe "" (map _.path (find (\e -> e.id == edgeKey edge.id) geometry.edges))
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
        , HE.onKeyDown \ke -> if KE.key ke == "Enter" || KE.key ke == " " then SelectEdge edge.id else FocusEdge edge.id
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
        , svgEl "path" [ HP.attr (AttrName "d") d, HP.attr (AttrName "marker-end") ("url(#arrow-" <> relationClass edge.kind <> ")") ] []
        ]

  arrowMarker name = svgEl "marker"
    [ HP.attr (AttrName "id") ("arrow-" <> name)
    , HP.attr (AttrName "viewBox") "0 0 10 10"
    , HP.attr (AttrName "refX") "9"
    , HP.attr (AttrName "refY") "5"
    , HP.attr (AttrName "markerWidth") "9"
    , HP.attr (AttrName "markerHeight") "9"
    , HP.attr (AttrName "markerUnits") "userSpaceOnUse"
    , HP.attr (AttrName "orient") "auto"
    ]
    [ svgEl "path" [ svgClass ("arrow arrow-" <> name), HP.attr (AttrName "d") "M1 1 L9 5 L1 9" ] [] ]

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
        , HE.onClick \_ -> SelectNode endpoint
        , HE.onKeyDown \ke -> if KE.key ke == "Enter" then SelectNode endpoint else FocusNode endpoint
        ]
        ( [ svgEl "rect"
              [ HP.attr (AttrName "width") (show nodeSize.width)
              , HP.attr (AttrName "height") (show nodeSize.height)
              , HP.attr (AttrName "rx") "6"
              ]
              []
          , svgEl "title" [] [ HH.text r.key ]
          , svgEl "text" [ svgClass "node-kind", HP.attr (AttrName "x") "16", HP.attr (AttrName "y") "23" ] [ HH.text "missing reference" ]
          ] <> mapWithIndex
            ( \i line -> svgEl "text"
                [ svgClass "node-title", HP.attr (AttrName "x") "16", HP.attr (AttrName "y") (show (49 + i * 20)) ]
                [ HH.text line ]
            )
            (titleLines r.key)
        )

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
        , HH.p_
            [ HH.text
                ( case info.edge.kind of
                    Contains -> "Recorded membership: parent work item to child. This is not an execution dependency."
                    AttachesRole -> "A recorded responsibility associated with this work. The role is not a worker identity."
                    RecordsCommunication -> "This role has a recorded communication about the work item. This does not establish a wait or message recipient."
                )
            ]
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

  contentBounds st = case st.geometry of
    Nothing -> Nothing
    Just geometry ->
      let
        xs = map _.x geometry.nodes
        ys = map _.y geometry.nodes
      in
        if null geometry.nodes then Nothing
        else Just
          { minX: fromMaybe 0.0 (minimum xs) - 24.0
          , minY: fromMaybe 0.0 (minimum ys) - 24.0
          , maxX: fromMaybe 0.0 (maximum xs) + nodeSize.width + 24.0
          , maxY: fromMaybe 0.0 (maximum ys) + nodeSize.height + 24.0
          }

  touchAction mk ev = case TL.item 0 (TE.touches ev) of
    Nothing -> DragEnd
    Just touch -> mk (toNumber (Touch.clientX touch)) (toNumber (Touch.clientY touch))

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
