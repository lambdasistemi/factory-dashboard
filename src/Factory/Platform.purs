-- | Browser measurement and focus FFI. The geometry adapter lives separately
-- | in Factory.LayoutEngine.
module Factory.Platform
  ( containerSize
  , focusNode
  , revealQuestion
  , resetDetailsScroll
  , keyboardFocus
  , compactScreen
  , shortcutAllowed
  , developerExamples
  , installDivider
  , copyTextImpl
  ) where

import Prelude

import Data.Maybe (Maybe)
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Web.DOM.Element (Element)

foreign import containerSizeImpl :: Element -> Effect (Nullable { width :: Number, height :: Number })

foreign import focusNodeImpl :: String -> Effect Unit

-- | Current size of a DOM element, or Nothing when it has no positive
-- | size (not rendered, hidden, or detached).
containerSize :: Element -> Effect (Maybe { width :: Number, height :: Number })
containerSize element = toMaybe <$> containerSizeImpl element

-- | Move keyboard focus to the first element matching the selector. No
-- | effect when nothing matches; callers own the selector string.
focusNode :: String -> Effect Unit
focusNode selector = focusNodeImpl selector

-- | Copy an operator-requested question; report failure without exposing errors.
foreign import copyTextImpl :: String -> (Boolean -> Effect Unit) -> Effect Unit

foreign import developerExamples :: Effect Boolean
foreign import installDivider :: Effect Unit

foreign import resetDetailsScroll :: Effect Unit
foreign import shortcutAllowed :: Effect Boolean

foreign import compactScreen :: Effect Boolean

foreign import keyboardFocus :: Effect Boolean

foreign import revealQuestion :: Effect Unit
