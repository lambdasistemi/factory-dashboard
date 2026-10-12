module Test.ChecksSpec (spec) where

import Prelude
import Data.Array (any, filter, length)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.String (Pattern(..), contains)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (fail, shouldEqual)
import Factory.Checks as Checks
import Factory.Domain (EdgeId(..), NodeKind(..), Quality(..), RelationshipKind(..), mkGraph, scopedId)

spec :: Spec Unit
spec = describe "factory rule evidence" do
  it "goes green only when the missing endpoint is observed" do
    let
      id = scopedId "test" "p"
      missing = scopedId "test" "m"
      parent = { id, kind: Project, title: "Project", summary: "", status: "active", sourceRef: Nothing, quality: Known { provenance: "test", freshness: "now" } }
      child = parent { id = missing, kind = Milestone }
      link = { id: EdgeId { source: "test", key: "link" }, from: id, to: missing, kind: Contains }
    case mkGraph [ parent ] [ link ], mkGraph [ parent, child ] [ link ] of
      Right broken, Right repaired -> do
        length (filter _.broken (Checks.findings broken)) `shouldEqual` 1
        length (filter _.broken (Checks.findings repaired)) `shouldEqual` 0
        contains (Pattern "test/m") (Checks.promptFor broken id) `shouldEqual` true
        contains (Pattern "Green when:") (Checks.promptFor broken id) `shouldEqual` true
        any (\r -> r.result == "Cannot check") (Checks.rules repaired) `shouldEqual` true
      _, _ -> fail "synthetic reference fixture must decode"
  it "keeps missing observations unknown and never infers a WORKING claim" do
    let node = { id: scopedId "test" "role", kind: Role, title: "Owner", summary: "", status: "WORKING", sourceRef: Nothing, quality: Unknown }
    case mkGraph [ node ] [] of
      Right graph -> do
        length (Checks.findings graph) `shouldEqual` 1
        length (filter _.broken (Checks.findings graph)) `shouldEqual` 0
        any (\r -> r.name == "C · WORKING claims are fresh" && r.result == "Cannot check") (Checks.rules graph) `shouldEqual` true
      Left _ -> fail "role fixture must decode"

  it "does not pass a recorded connection when both endpoints are absent" do
    let
      node = { id: scopedId "test" "p", kind: Project, title: "Project", summary: "", status: "active", sourceRef: Nothing, quality: Known { provenance: "test", freshness: "now" } }
      edge = { id: EdgeId { source: "test", key: "missing" }, from: scopedId "test" "a", to: scopedId "test" "b", kind: Contains }
    case mkGraph [ node ] [ edge ] of
      Right graph -> length (filter _.broken (Checks.findings graph)) `shouldEqual` 1
      Left _ -> fail "unresolved endpoints must be retained"
