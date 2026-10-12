-- | The scenario registry the app offers. Scenarios are raw documents
-- plus their reader-facing labels; decoding happens through the strict
-- boundary decoder exactly as any input would.
module Factory.Scenarios
  ( Scenario(..)
  , scenarios
  , defaultScenario
  ) where

import Prelude

import Data.Array (filter, head)
import Data.Maybe (fromMaybe)

import Factory.Fixtures (rawEmpty, rawIncomplete, rawInvalid, rawOrdinary)

type Scenario =
  { key :: String
  , label :: String
  , raw :: String
  }

scenarios :: Array Scenario
scenarios =
  [ { key: "ordinary", label: "Complete installation", raw: rawOrdinary }
  , { key: "empty", label: "Empty installation", raw: rawEmpty }
  , { key: "incomplete", label: "Incomplete records", raw: rawIncomplete }
  , { key: "invalid", label: "Refused input", raw: rawInvalid }
  ]

defaultScenario :: Scenario
defaultScenario =
  fromMaybe { key: "none", label: "No scenario", raw: "" }
    $ head (filter (\s -> s.key == "ordinary") scenarios)
