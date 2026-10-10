module Main (main) where

import Prelude

import Data.Maybe (Maybe(..))
import Effect (Effect)

import Web.DOM.ParentNode (QuerySelector(..))
import Halogen.Aff as HA
import Halogen.VDom.Driver (runUI)
import Web.HTML.HTMLElement (HTMLElement)

import Factory.View (component)

main :: Effect Unit
main = HA.runHalogenAff do
  HA.awaitLoad
  root <- HA.selectElement (QuerySelector "#app")
  case root of
    Nothing -> pure unit
    Just el -> void (runUI component unit (el :: HTMLElement))
