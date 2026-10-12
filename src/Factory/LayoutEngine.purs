-- | Asynchronous geometry boundary; raw engine failures are never displayed.
module Factory.LayoutEngine (calculate) where

import Prelude
import Data.Either (Either(..))
import Effect (Effect)
import Effect.Aff (Aff, makeAff, nonCanceler)
import Factory.Layout (Geometry, LayoutInput)

foreign import calculateImpl :: LayoutInput -> (Geometry -> Effect Unit) -> (String -> Effect Unit) -> Effect Unit

calculate :: LayoutInput -> Aff (Either String Geometry)
calculate input = makeAff \done -> do
  calculateImpl input (done <<< Right <<< Right) (done <<< Right <<< Left)
  pure nonCanceler
