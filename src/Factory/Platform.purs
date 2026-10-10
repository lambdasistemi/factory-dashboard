-- | The whole typed FFI surface of the app: reading the graph container's
-- | size and moving keyboard focus. Everything else is PureScript.
module Factory.Platform
  ( containerSize
  , focusNode
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
