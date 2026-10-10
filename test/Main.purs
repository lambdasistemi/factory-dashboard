module Test.Main (main) where

import Prelude

import Effect (Effect)
import Test.Spec (Spec)
import Test.Spec.Reporter (consoleReporter)
import Test.Spec.Runner.Node (runSpecAndExitProcess)
import Test.DecodeSpec as DecodeSpec
import Test.DomainSpec as DomainSpec
import Test.LayoutSpec as LayoutSpec
import Test.ViewStateSpec as ViewStateSpec

main :: Effect Unit
main = runSpecAndExitProcess [ consoleReporter ] specs

specs :: Spec Unit
specs = do
  DecodeSpec.spec
  DomainSpec.spec
  ViewStateSpec.spec
  LayoutSpec.spec
