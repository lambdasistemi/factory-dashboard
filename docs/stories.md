# User stories

## Observe the complete factory

As a factory operator, I navigate a connected graph of projects, milestones, epics, tickets, pull requests and roles, and observe their current records without leaving the global view.

The graph is the first implementation ticket and the first release's main screen. Missing or stale data stays visible as missing or stale; it must not appear as success or inactivity.

## Inspect the record behind a connection

As a factory operator, I select a graph node or connection and read its existing work or communication context, so I can understand what the observation means.

The first release reads GitHub and configured local files. Inspection writes nothing to either source and performs no worker operation. Unknown references are reported rather than invented.

## Run privately on my own installation

As an installation operator, I configure approved repositories, local input files and private credentials, and observe only the permitted graph data in the browser.

Unsafe configuration refuses source activation with a redacted explanation. The dashboard does not discover my machine, install workers or send data to model services. The [configuration contract](configuration.md) defines the required boundaries.

## Ask the appropriate agent later

As a factory operator, I select graph context, ask the responsible role a question or answer a pending question, and receive a correlated reply from the appropriate agent so I can address attention without leaving the dashboard.

This is a later milestone after the read-only product has been accepted and released. Communication will use configured local channels, with explicit write authority and honest unavailable or failed-delivery states. The concrete worker implementation stays private.

## Notice attention and changes now

As a factory operator, I open a specialised view derived from the graph and see the decisions, blockers or changes relevant to me, then return to their graph context.

This belongs in the first milestone alongside other useful information derivable from approved communication and local status records. Each finding shows its evidence and freshness. I copy an evidence-backed problem prompt for a recommended role with sufficient authority and go to the machine to send it; a later milestone lets me communicate back from the dashboard. A recorded response or acknowledgement is not proof that the issue was resolved.

## Operate the factory in the long term

As a factory operator, I select teams, speak with the right agents and request permitted work from the graph, with explicit authority and an audit trail.

This is the long-term goal. Team selection, assignment, approvals and other controls require their own design and acceptance conditions before implementation. A graph selection or question must never silently become permission to execute an operation.
