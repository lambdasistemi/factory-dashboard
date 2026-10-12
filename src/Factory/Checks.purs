-- | Evidence-backed checks. A missing prerequisite is unknown, never green.
module Factory.Checks (Finding, Rule, findings, rules, promptFor, recipients) where

import Prelude
import Data.Array (filter, length, mapMaybe, nub)
import Data.Maybe (Maybe(..))
import Data.String (joinWith)
import Factory.Domain (Graph, Node, Quality(..), ScopedId(..), attachedRoles, containmentParent, edgeIds, lookupEdge, lookupNode, nodeIds)

type Finding = { rule :: String, subject :: ScopedId, evidence :: String, green :: String, broken :: Boolean }
type Rule = { name :: String, result :: String, requires :: String }

findings :: Graph -> Array Finding
findings graph =
  let
    references = mapMaybe
      ( \id -> do
          edge <- lookupEdge graph id
          case lookupNode graph edge.from, lookupNode graph edge.to of
            Just _, Nothing -> Just { rule: "References resolve", subject: edge.from, evidence: "A connection from this item points to missing " <> recordName edge.to <> ".", green: "The referenced record is observed, or an authorised correction of the reference is recorded.", broken: true }
            Nothing, Just _ -> Just { rule: "References resolve", subject: edge.to, evidence: "A connection to this item starts at missing " <> recordName edge.from <> ".", green: "The referenced record is observed, or an authorised correction of the reference is recorded.", broken: true }
            Nothing, Nothing -> Just { rule: "References resolve", subject: edge.from, evidence: "A recorded connection has two missing endpoints: " <> recordName edge.from <> " and " <> recordName edge.to <> ".", green: "Both endpoints are observed, or an authorised correction of the reference is recorded.", broken: true }
            _, _ -> Nothing
      )
      (edgeIds graph)
    observations = mapMaybe
      ( \id -> do
          node <- lookupNode graph id
          case node.quality of
            Known _ -> Nothing
            Stale q -> Just { rule: "Observations are current", subject: id, evidence: node.title <> " has a stale observation from " <> q.asOf <> ".", green: "A fresh observation is recorded; inspect the source rather than changing the status to hide the finding.", broken: false }
            _ -> Just { rule: "Observations are current", subject: id, evidence: node.title <> " has missing or unknown observation coverage.", green: "The configured source supplies a valid, attributable observation.", broken: false }
      )
      (nodeIds graph)
  in
    references <> observations

rules :: Graph -> Array Rule
rules graph =
  let
    fs = findings graph
    result name =
      let
        count = length (filter (\f -> f.rule == name) fs)
      in
        if count == 0 then "Supported for observed records" else show count <> " to investigate"
    unknown name requires = { name, result: "Cannot check", requires }
  in
    [ { name: "References resolve", result: if length (nodeIds graph) == 0 then "Cannot check: no records" else result "References resolve", requires: "Every recorded connection has both endpoints in the observed graph." }
    , { name: "Observations are current", result: if length (nodeIds graph) == 0 then "Cannot check: no records" else result "Observations are current", requires: "Recorded observation quality; no claim about worker process liveness." }
    , unknown "A · Open questions have an available recipient" "Correlated open questions, supervisor bindings, fresh claims and pause intent."
    , unknown "B · Waiting for children has a source of progress" "Blocking obligations, child assignments and fresh activity claims."
    , unknown "C · WORKING claims are fresh" "Claim expiry and observation times. Node status alone is not a claim."
    , unknown "D · Blocked work has explained activity" "Blocked assignment, activity claim and explicit pause/wake conditions."
    , unknown "E · A working lane has relevant working activity" "Lane intent and fresh claims linked to the required assignment."
    , unknown "F · Open dispatched work has an owner or intentional pause" "Dispatch, owner presence, outstanding obligations and pause intent."
    , unknown "G · Blocking wait chains have an explained end" "Typed blocking dependencies, alternatives, external wake sources and fresh claims. Communication edges are not waits."
    , unknown "H · COMPLETE preserves unfinished obligations" "Terminal assignments, exactly correlated questions, answers and accountable handoffs."
    ]

-- | Walk only recorded containment and responsibility edges. These are
-- | candidate recipients, not a claim of process presence or extra authority.
recipients :: Graph -> ScopedId -> Array Node
recipients graph id = case attachedRoles graph id of
  [] -> case containmentParent graph id of
    Just parent -> recipients graph parent
    Nothing -> []
  roles -> roles

promptFor :: Graph -> ScopedId -> String
promptFor graph subject =
  let
    fs = filter (\f -> f.subject == subject) (findings graph)
    names = nub (map _.title (recipients graph subject))
    recipient = if length names == 0 then "Installation operator: no responsible role is recorded for this scope." else "Recorded responsible roles: " <> joinWith ", " names <> ". Confirm which role has authority before acting."
  in
    joinWith "\n\n"
      [ "Factory check for " <> recordName subject <> "."
      , recipient
      , joinWith "\n" (map (\f -> f.rule <> ": " <> f.evidence) fs)
      , "Inspect the current configured sources and reconcile these observations within your authority. Preserve evidence and intentional pauses. Do not start workers or declare an issue resolved just to clear this finding."
      , "Green when:\n" <> joinWith "\n" (map _.green fs)
      , "Journal the evidence and action. The dashboard must re-check the recorded facts; copying this prompt does not resolve the finding."
      ]

recordName :: ScopedId -> String
recordName (ScopedId id) = id.namespace <> "/" <> id.key
