-- | The graph application: Halogen component rendering the SVG graph,
-- | scenario controls, viewport controls and the permitted context of the
-- | current selection. Pure graph/view-state transitions are separate from
-- | browser effects and the asynchronous geometry engine.
module Factory.View
  ( component
  ) where

import Prelude

import Data.Array (filter, find, head, index, length, mapMaybe, null, nub, mapWithIndex, takeWhile, uncons)
import Data.Either (Either(..))
import Data.Foldable (maximum, minimum)
import Data.Int (toNumber, fromString)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String (joinWith)
import Data.String.CodeUnits as CU
import Data.Tuple (Tuple(..))
import Effect.Class (liftEffect)

import Effect.Aff (makeAff, nonCanceler)
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
  , incidentEdges
  , kindLabel
  , lookupNode
  , nodeIds
  , qualityLabel
  , relationLabel
  )
import Factory.Layout (Position, Geometry, layoutInput, nodeKey, edgeKey, titleLines, nodeSize)
import Factory.Platform (containerSize, focusNode, copyTextImpl, revealQuestion, resetDetailsScroll, compactScreen, keyboardFocus, shortcutAllowed, developerExamples, installDivider)
import Factory.Desk as Desk
import Factory.Checks as Checks
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
  , copiedText :: String
  , copied :: Maybe Boolean
  , revision :: Int
  , showEpics :: Boolean
  , showWorkers :: Boolean
  , highlight :: Boolean
  , filterMode :: String
  , branch :: String
  , rulesOpen :: Boolean
  , examples :: Boolean
  , dragging :: Maybe { x :: Number, y :: Number }
  }

data Action
  = Init
  | LayoutFinished Int (Either String Geometry)
  | ShowRules Boolean
  | CopyFinding ScopedId
  | OpenFinding ScopedId
  | ToggleEpics
  | ToggleWorkers
  | Highlight Boolean
  | FilterMode String
  | Branch String
  | CopyQuestion String
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
    , copiedText: ""
    , copied: Nothing
    , showEpics: true
    , showWorkers: true
    , highlight: true
    , filterMode: "all"
    , branch: ""
    , rulesOpen: false
    , examples: false
    , dragging: Nothing
    }

  -- ------------------------------------------------------------ evaluate

  handleAction = case _ of
    Init -> do
      examples <- liftEffect developerExamples
      H.modify_ \s -> s { examples = examples }
      liftEffect installDivider
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

    ShowRules open -> H.modify_ \s -> s { rulesOpen = open }

    CopyFinding id -> do
      st <- H.get
      case st.doc of
        Left _ -> pure unit
        Right graph -> do
          handleAction (OpenFinding id)
          handleAction (CopyQuestion (Checks.promptFor graph id))

    OpenFinding id -> do
      H.modify_ \s -> s { rulesOpen = false, branch = "", showEpics = true, showWorkers = true, filterMode = "attention" }
      handleAction (SelectNode id)
      revealNode id

    ToggleEpics -> H.modify_ \s -> s { showEpics = if s.showWorkers then not s.showEpics else true }

    ToggleWorkers -> H.modify_ \s -> s { showWorkers = if s.showEpics then not s.showWorkers else true }

    Highlight on -> H.modify_ \s -> s { highlight = on }

    FilterMode mode -> H.modify_ \s -> s { filterMode = mode }

    Branch key -> H.modify_ \s -> s { branch = key, view = s.view { selection = NoSelection } }

    CopyQuestion question -> do
      copied <- H.liftAff $ makeAff \done -> do
        copyTextImpl question (done <<< Right)
        pure nonCanceler
      H.modify_ \st -> st { copied = Just copied, copiedText = question }
      if copied then pure unit else liftEffect revealQuestion

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
          , branch = ""
          , filterMode = "all"
          , copied = Nothing
          , view = initialViewState
          , focused = Nothing
          , geometry = Nothing
          , layoutError = Nothing
          , revision = s.revision + 1
          }
      requestLayout

    SelectNode id -> do
      liftEffect resetDetailsScroll
      H.modify_ \s -> s { view = s.view { selection = NodeSelected id }, copied = Nothing }

    SelectEdge id -> do
      liftEffect resetDetailsScroll
      H.modify_ \s -> s { view = s.view { selection = EdgeSelected id }, copied = Nothing }

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
      measureAndFit
      st <- H.get
      H.modify_ \s -> s { view = s.view { viewport = fitViewport (contentBounds st) st.dims st.view.viewport } }

    FocusNode id -> do
      H.modify_ \s -> s { focused = Just id }
      compact <- liftEffect compactScreen
      keyboard <- liftEffect keyboardFocus
      if compact && keyboard then revealNode id else pure unit

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
        Just ke -> do
          allowed <- shortcutAllowed
          if (allowed || KE.key ke == "Escape") && not (KE.ctrlKey ke || KE.metaKey ke || KE.altKey ke) then HS.notify listener (GlobalKey (KE.key ke)) else pure unit
        Nothing -> pure unit
    keyListener <- liftEffect (eventListener onKey)
    liftEffect (addEventListener (EventType "keydown") keyListener false (toEventTarget doc))
    _ <- H.subscribe emitter
    pure unit

  handleGlobalKey key = do
    st <- H.get
    case key of
      "Escape" -> if st.rulesOpen then handleAction (ShowRules false) else handleAction ClearSelection
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
        compact <- liftEffect compactScreen
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
                    Dim _ | compact -> { scale: 1.0, tx: 16.0, ty: 16.0 }
                    _ -> fitViewport (contentBounds st) dims st.view.viewport
                }
            }

  -- ------------------------------------------------------------ render

  render st =
    HH.div [ HP.class_ (H.ClassName "app") ]
      [ HH.header [ HP.class_ (H.ClassName "app-header") ]
          [ HH.h1_ [ HH.text "Factory dashboard" ]
          , HH.span [ HP.class_ (H.ClassName "demo-label") ] [ HH.text "Example factory" ]
          , ( if st.examples then HH.details [ HP.class_ (H.ClassName "demo-controls") ]
                [ HH.summary_ [ HH.text "Try examples" ]
                , HH.nav [ HP.class_ (H.ClassName "scenario-bar") ] (map (scenarioButton st) scenarios)
                ]
              else HH.text ""
            )
          , HH.button [ HE.onClick \_ -> ShowRules true ] [ HH.text "Rules" ]
          , HH.p [ HP.class_ (H.ClassName "app-status") ] [ HH.text (statusText st) ]
          , HH.button [ HP.id "factory-dashboard-palette-toggle", HP.attr (AttrName "aria-label") "Switch theme", HP.attr (AttrName "hidden") "" ] []
          ]
      , rulesDialog st
      , summaryStrip st
      , HH.nav [ HP.class_ (H.ClassName "tabs"), HP.attr (AttrName "aria-label") "What to show" ]
          [ HH.button [ HP.attr (AttrName "aria-pressed") (show st.showEpics), HE.onClick \_ -> ToggleEpics ] [ HH.text "Epics" ]
          , HH.button [ HP.attr (AttrName "aria-pressed") (show st.showWorkers), HE.onClick \_ -> ToggleWorkers ] [ HH.text "Workers" ]
          , HH.span [ HP.class_ (H.ClassName "when") ] [ HH.text "Both on shows work and the roles responsible for it." ]
          ]
      , HH.div [ HP.class_ (H.ClassName "tools") ]
          [ HH.select [ HP.attr (AttrName "aria-label") "Lane", HP.value st.branch, HE.onValueChange Branch ]
              ( [ HH.option [ HP.value "" ] [ HH.text "All lanes" ] ] <> case st.doc of
                  Left _ -> []
                  Right graph -> map (\n -> HH.option [ HP.value (nodeKey n.id) ] [ HH.text n.title ]) (Desk.lanes graph)
              )
          , HH.select [ HP.attr (AttrName "aria-label") "What to show", HP.value st.filterMode, HE.onValueChange FilterMode ]
              [ HH.option [ HP.value "all" ] [ HH.text "Everything" ]
              , HH.option [ HP.value "running" ] [ HH.text "What is running" ]
              , HH.option [ HP.value "attention" ] [ HH.text "What needs attention" ]
              ]
          , HH.label [ HP.class_ (H.ClassName "when") ]
              [ HH.input [ HP.type_ HP.InputCheckbox, HP.checked st.highlight, HE.onChecked Highlight ]
              , HH.text " Highlight the selected branch"
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
          , HH.div [ HP.id "divider", HP.class_ (H.ClassName "divider"), HP.attr (AttrName "role") "separator", HP.attr (AttrName "aria-orientation") "vertical", HP.attr (AttrName "aria-label") "Resize the panes", HP.tabIndex 0 ] []
          , HH.aside [ HP.class_ (H.ClassName "details") ] (detailsContent st <> manualFallback st)
          ]
      ]

  rulesDialog st =
    if not st.rulesOpen then HH.text ""
    else
      HH.div [ HP.class_ (H.ClassName "rules-backdrop") ]
        [ HH.section [ HP.class_ (H.ClassName "rules-dialog"), HP.attr (AttrName "role") "dialog", HP.attr (AttrName "aria-modal") "true", HP.attr (AttrName "aria-label") "Factory rules" ]
            ( [ HH.h2_ [ HH.text "Rules about the factory" ]
              , HH.button [ HE.onClick \_ -> ShowRules false ] [ HH.text "Close" ]
              , HH.p_ [ HH.text "A finding clears only when new recorded evidence meets its green condition. Missing evidence cannot pass a rule." ]
              ] <> case st.doc of
                Left _ -> [ HH.p_ [ HH.text "Cannot check: input was refused." ] ]
                Right graph ->
                  [ HH.table_
                      [ HH.thead_ [ HH.tr_ (map (\label -> HH.th_ [ HH.text label ]) [ "Rule", "Live result", "Evidence needed" ]) ]
                      , HH.tbody_
                          ( map
                              ( \rule -> HH.tr_
                                  [ HH.td_ [ HH.text rule.name ]
                                  , HH.td_ [ HH.text rule.result ]
                                  , HH.td_ [ HH.text rule.requires ]
                                  ]
                              )
                              (Checks.rules graph)
                          )
                      ]
                  , HH.h3_ [ HH.text "What needs attention" ]
                  , HH.div_ (map (findingRow graph) (Checks.findings graph))
                  ]
            )
        ]

  findingRow graph finding = HH.div [ HP.class_ (H.ClassName "finding") ]
    [ HH.button [ HE.onClick \_ -> OpenFinding finding.subject ] [ HH.text (titleOfGraph graph finding.subject) ]
    , HH.p_ [ HH.text finding.evidence ]
    , HH.p_ [ HH.text ("Green when: " <> finding.green) ]
    , HH.button [ HE.onClick \_ -> CopyFinding finding.subject ] [ HH.text "Copy prompt" ]
    ]

  titleOfGraph graph id = case lookupNode graph id of
    Just node -> node.title
    Nothing -> nodeKey id

  summaryStrip st = case st.doc of
    Left _ -> HH.text ""
    Right graph -> HH.section [ HP.class_ (H.ClassName "tiles") ]
      ( map
          ( \tile -> HH.div [ HP.class_ (H.ClassName "tile"), HE.onClick \_ -> if tile.label == "Rules broken" then ShowRules true else ClearSelection ]
              [ HH.div [ HP.class_ (H.ClassName "lbl") ] [ HH.text tile.label ]
              , HH.div [ HP.class_ (H.ClassName "big") ] [ HH.text tile.value ]
              ]
          )
          (Desk.summary graph <> [ { label: "Rules broken", value: show (length (filter _.broken (Checks.findings graph))) <> " · " <> show (length (filter (not <<< _.broken) (Checks.findings graph))) <> " to check" } ])
      )

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
          [ HH.text "This example could not be loaded. See the problems in the panel." ]
      ]

  overlay =
    HH.div [ HP.class_ (H.ClassName "stage-overlay") ]
      [ HH.div [ HP.class_ (H.ClassName "view-controls") ]
          [ HH.button [ HE.onClick \_ -> Navigate (ZoomBy 1.25) ] [ HH.text "Zoom in" ]
          , HH.button [ HE.onClick \_ -> Navigate (ZoomBy 0.8) ] [ HH.text "Zoom out" ]
          , HH.button [ HE.onClick \_ -> FitNow ] [ HH.text "Show all" ]
          , HH.button [ HE.onClick \_ -> Navigate ResetView ] [ HH.text "Reset zoom" ]
          ]
      , HH.div [ HP.class_ (H.ClassName "legend") ]
          [ HH.span_ [ legendLine "edge-contains", HH.text " Part of" ]
          , HH.span_ [ legendLine "edge-attaches", HH.text " Responsible role" ]
          , HH.span_ [ legendLine "edge-communication", HH.text " Message about work" ]
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
      visible = Desk.filterVisible graph st (deriveVisible graph st.view.expansion)
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
      graphForDesk = st.doc
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
                <> (if Desk.dimNode graphForDesk st node.id then " dimmed" else "")
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
            ("edge edge-" <> relationClass edge.kind <> (if selected then " selected" else "") <> (if Desk.dimNode st.doc st edge.from || Desk.dimNode st.doc st edge.to then " dimmed" else ""))
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
        [ HH.h2_ [ HH.text "Select a node or a link" ]
        , HH.p_
            [ HH.text
                "Click a node for its status and responsible roles. Click a link to see what connects them. Highlighting keeps the layout in place."
            ]
        , HH.section [ HP.class_ (H.ClassName "overview-updates") ]
            [ HH.h3_ [ HH.text "What needs attention" ]
            , HH.p_ [ HH.text "Inspect the evidence, copy the prompt, then re-check after the source changes." ]
            , HH.div_ (map (findingRow graph) (Checks.findings graph))
            , HH.p_ [ HH.text "Question, wait and claim rules cannot be checked until those protocol facts are supplied." ]
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
                    <> " items are hidden with it."
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
        [ HH.p [ HP.class_ (H.ClassName "eyebrow") ] [ HH.text "Connection" ]
        , HH.h2_
            [ HH.text
                ( case info.edge.kind of
                    Contains -> "Part of the same work"
                    AttachesRole -> "Who is responsible"
                    RecordsCommunication -> "Message about this work"
                )
            ]
        , HH.p_
            [ HH.text
                ( case info.edge.kind of
                    Contains -> endpointText info.toName <> " belongs to " <> endpointText info.fromName <> "."
                    AttachesRole -> endpointText info.toName <> " has a responsibility for " <> endpointText info.fromName <> "."
                    RecordsCommunication -> endpointText info.fromName <> " has communicated about " <> endpointText info.toName <> "."
                )
            ]
        , HH.div [ HP.class_ (H.ClassName "related-items") ]
            [ itemButton graph info.edge.from, itemButton graph info.edge.to ]
        , HH.details [ HP.class_ (H.ClassName "technical") ]
            [ HH.summary_ [ HH.text "Source details" ]
            , HH.p_ [ HH.text info.kindName, HH.text (" · " <> edgeString info.edge.id) ]
            ]
        ]
      NodeContext info ->
        [ HH.section [ HP.class_ (H.ClassName "work-summary") ]
            [ HH.p [ HP.class_ (H.ClassName "eyebrow") ] [ HH.text (kindLabel info.node.kind) ]
            , HH.h2_ [ HH.text info.node.title ]
            , HH.p [ HP.class_ (H.ClassName "work-status") ] [ HH.text info.node.status ]
            , HH.p_ [ HH.text info.node.summary ]
            , HH.p [ HP.class_ (H.ClassName ("quality " <> qualityClass info.node.quality)) ] [ HH.text (readerQuality info.node.quality) ]
            ]
        , HH.section [ HP.class_ (H.ClassName "findings-panel") ]
            (map (findingRow graph) (filter (\f -> f.subject == info.node.id) (Checks.findings graph)))
        , HH.section [ HP.class_ (H.ClassName "answer-panel") ]
            [ HH.h3_ [ HH.text "Who can answer" ]
            , case (if info.node.kind == Role then [] else Checks.recipients graph info.node.id) of
                [] -> HH.p_ [ HH.text (if info.node.kind == Role then "This role's work is shown by its connections." else "No responsible role is listed yet.") ]
                roles -> HH.div [ HP.class_ (H.ClassName "related-items") ] (map (\role -> itemButton graph role.id) roles)
            , HH.details [ HP.class_ (H.ClassName "question"), HP.attr (AttrName "open") "" ]
                [ HH.summary_ [ HH.text "Ask about this" ]
                , HH.p_ [ HH.text "Copy this question into a worker's session." ]
                , HH.textarea [ HP.value (selectedPrompt graph info.node), HP.readOnly true, HP.rows 4, HP.attr (AttrName "aria-label") "Question about selected work" ]
                , HH.button [ HE.onClick \_ -> CopyQuestion (selectedPrompt graph info.node) ] [ HH.text "Copy question" ]
                , HH.p [ HP.attr (AttrName "role") "status" ]
                    [ HH.text
                        ( case st.copied of
                            Just true -> "Copied. Paste it into your worker's session."
                            Just false -> "Select and copy the question above."
                            Nothing -> ""
                        )
                    ]
                ]
            ]
        , HH.section [ HP.class_ (H.ClassName "connections-panel") ]
            [ HH.h3_ [ HH.text "Connected work" ]
            , HH.div [ HP.class_ (H.ClassName "related-items") ]
                ( map (itemButton graph)
                    ( filter
                        ( \id -> case lookupNode graph id of
                            Just node -> node.kind /= Role
                            Nothing -> true
                        )
                        (nub (map (\edge -> if edge.from == info.node.id then edge.to else edge.from) (incidentEdges graph info.node.id)))
                    )
                )
            , HH.p_ [ HH.text (show (length info.communications) <> (if length info.communications == 1 then " message about this item" else " messages about this item")) ]
            , HH.details [ HP.class_ (H.ClassName "technical") ]
                [ HH.summary_ [ HH.text "Source details" ]
                , HH.p_ [ HH.text (fromMaybe "No source listed" info.node.sourceRef) ]
                , HH.p_ [ HH.text (qualityLabel info.node.quality <> qualityDetail info.node.quality) ]
                ]
            ]
        ]

  selectedPrompt graph node =
    if null (filter (\f -> f.subject == node.id) (Checks.findings graph)) then
      questionFor node.title node.summary node.status (if node.kind == Role then [ node.title ] else map _.title (Checks.recipients graph node.id))
    else Checks.promptFor graph node.id

  manualFallback st = case st.copied, st.doc, st.view.selection of
    Just false, Right graph, NodeSelected id -> case lookupNode graph id of
      Nothing -> [ HH.p_ [ HH.text "Select and copy this repair prompt:" ], HH.textarea [ HP.class_ (H.ClassName "manual-prompt"), HP.value st.copiedText, HP.readOnly true, HP.rows 8, HP.attr (AttrName "aria-label") "Repair prompt" ] ]
      _ -> []
    _, _, _ -> []

  itemButton graph id = HH.button
    [ HE.onClick \_ -> SelectNode id ]
    [ HH.text
        ( case lookupNode graph id of
            Just node -> node.title
            Nothing -> "Item not available"
        )
    ]

  -- ------------------------------------------------------------ helpers

  statusText st = case st.doc of
    Left failures -> "Input refused — " <> show (length failures) <> " problems"
    Right graph ->
      let
        visible = Desk.filterVisible graph st (deriveVisible graph st.view.expansion)
      in
        if length visible.nodes == 0 then "No work to show"
        else if visible.hiddenCount > 0 then
          show (length visible.nodes)
            <> " items · "
            <> show (length visible.edges)
            <> " connections · "
            <> show visible.hiddenCount
            <> " hidden"
        else
          ""
            <> show (length visible.nodes)
            <> " items · "
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

-- Reader-facing language; evidence states retain their domain meaning.
readerQuality :: Quality -> String
readerQuality = case _ of
  Known q -> "Last checked " <> readableDate q.freshness
  Stale q -> "Needs a fresh update · last checked " <> readableDate q.asOf
  Unknown -> "Not yet checked"
  MissingReference -> "Source information is missing"

questionFor :: String -> String -> String -> Array String -> String
questionFor title summary status roles =
  "Please explain what is happening with “" <> title <> "” and what should happen next.\n"
    <> "Current status: "
    <> status
    <> ".\n"
    <> summary
    <> "\n"
    <>
      ( if null roles then "No responsible role is listed in the dashboard. Please help identify who can answer."
        else "Listed responsibilities: " <> joinWith ", " roles <> "."
      )

readableDate :: String -> String
readableDate text = case fromString (CU.slice 5 7 text), fromString (CU.slice 8 10 text) of
  Just month, Just day | CU.slice 4 5 text == "-" && CU.slice 7 8 text == "-" ->
    case index [ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" ] (month - 1) of
      Just name -> show day <> " " <> name <> " " <> CU.take 4 text
      Nothing -> text
  _, _ -> text
