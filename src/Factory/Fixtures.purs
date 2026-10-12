-- | FFI bindings for the committed synthetic scenario documents. Each
-- binding is a raw JSON string; nothing here constructs domain values.
module Factory.Fixtures
  ( rawOrdinary
  , rawEmpty
  , rawIncomplete
  , rawInvalid
  ) where

foreign import rawOrdinary :: String

foreign import rawEmpty :: String

foreign import rawIncomplete :: String

foreign import rawInvalid :: String
