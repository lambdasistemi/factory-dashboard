// Raw synthetic scenario documents. These are data, not generated values:
// they are the shared oracle for the app and its tests, decoded through the
// same strict boundary decoder as any other input. All names are synthetic;
// no real installation, provider or host appears here.
export const rawOrdinary = `
{
  "schema": "factory-graph/1",
  "nodes": [
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "project-1" },
      "kind": "project",
      "title": "Factory Demo",
      "summary": "Synthetic installation used to demonstrate the graph",
      "status": "active",
      "sourceRef": "records/project-1",
      "quality": { "state": "known", "provenance": "recorded-read", "freshness": "2026-10-08T08:00:00Z" }
    },
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "milestone-1" },
      "kind": "milestone",
      "title": "Graph milestone",
      "summary": "Deliver the first readable factory graph",
      "status": "open",
      "sourceRef": "records/milestone-1",
      "quality": { "state": "known", "provenance": "recorded-read", "freshness": "2026-10-08T08:00:00Z" }
    },
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "milestone-2" },
      "kind": "milestone",
      "title": "Attention milestone",
      "summary": "Planned work that has not been read recently",
      "status": "open",
      "sourceRef": "records/milestone-2",
      "quality": { "state": "stale", "provenance": "recorded-read", "asOf": "2026-09-30T09:30:00Z" }
    },
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "epic-1" },
      "kind": "epic-issue",
      "title": "Graph epic",
      "summary": "Own the synthetic graph slice",
      "status": "open",
      "sourceRef": "records/epic-1",
      "quality": { "state": "known", "provenance": "recorded-read", "freshness": "2026-10-08T08:00:00Z" }
    },
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "epic-2" },
      "kind": "epic-issue",
      "title": "Attention epic",
      "summary": "Record whose observation went stale",
      "status": "open",
      "sourceRef": "records/epic-2",
      "quality": { "state": "stale", "provenance": "recorded-read", "asOf": "2026-09-28T10:00:00Z" }
    },
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "ticket-1" },
      "kind": "ticket-issue",
      "title": "Synthetic graph ticket",
      "summary": "First implementation ticket of the demo installation",
      "status": "in progress",
      "sourceRef": "records/ticket-1",
      "quality": { "state": "known", "provenance": "recorded-read", "freshness": "2026-10-08T08:00:00Z" }
    },
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "pr-1" },
      "kind": "pull-request",
      "title": "Add the synthetic graph",
      "summary": "Draft change carrying the first graph slice",
      "status": "review",
      "sourceRef": "records/pr-1",
      "quality": { "state": "known", "provenance": "recorded-read", "freshness": "2026-10-08T08:00:00Z" }
    },
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "pr-2" },
      "kind": "pull-request",
      "title": "Review note <img src=x onerror=window.__xss=1>",
      "summary": "Title text that must render as text, never as markup",
      "status": "review",
      "sourceRef": "records/pr-2",
      "quality": { "state": "known", "provenance": "recorded-read", "freshness": "2026-10-08T08:00:00Z" }
    },
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "role-1" },
      "kind": "role",
      "title": "Graph Maintainer",
      "summary": "Owns the synthetic graph record",
      "status": "active",
      "sourceRef": null,
      "quality": { "state": "known", "provenance": "role-register", "freshness": "2026-10-08T08:00:00Z" }
    },
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "role-2" },
      "kind": "role",
      "title": "Release Steward",
      "summary": "Role with no observation yet",
      "status": "active",
      "sourceRef": null,
      "quality": { "state": "unknown" }
    }
  ],
  "edges": [
    {
      "identity": { "source": "synthetic:demo-installation", "key": "contains-1" },
      "kind": "contains",
      "from": { "namespace": "synthetic:demo-installation", "key": "project-1" },
      "to": { "namespace": "synthetic:demo-installation", "key": "milestone-1" }
    },
    {
      "identity": { "source": "synthetic:demo-installation", "key": "contains-2" },
      "kind": "contains",
      "from": { "namespace": "synthetic:demo-installation", "key": "project-1" },
      "to": { "namespace": "synthetic:demo-installation", "key": "milestone-2" }
    },
    {
      "identity": { "source": "synthetic:demo-installation", "key": "contains-3" },
      "kind": "contains",
      "from": { "namespace": "synthetic:demo-installation", "key": "milestone-1" },
      "to": { "namespace": "synthetic:demo-installation", "key": "epic-1" }
    },
    {
      "identity": { "source": "synthetic:demo-installation", "key": "contains-4" },
      "kind": "contains",
      "from": { "namespace": "synthetic:demo-installation", "key": "milestone-2" },
      "to": { "namespace": "synthetic:demo-installation", "key": "epic-2" }
    },
    {
      "identity": { "source": "synthetic:demo-installation", "key": "contains-5" },
      "kind": "contains",
      "from": { "namespace": "synthetic:demo-installation", "key": "epic-1" },
      "to": { "namespace": "synthetic:demo-installation", "key": "ticket-1" }
    },
    {
      "identity": { "source": "synthetic:demo-installation", "key": "contains-6" },
      "kind": "contains",
      "from": { "namespace": "synthetic:demo-installation", "key": "ticket-1" },
      "to": { "namespace": "synthetic:demo-installation", "key": "pr-1" }
    },
    {
      "identity": { "source": "synthetic:demo-installation", "key": "contains-7" },
      "kind": "contains",
      "from": { "namespace": "synthetic:demo-installation", "key": "ticket-1" },
      "to": { "namespace": "synthetic:demo-installation", "key": "pr-2" }
    },
    {
      "identity": { "source": "synthetic:demo-installation", "key": "attach-1" },
      "kind": "attaches-role",
      "from": { "namespace": "synthetic:demo-installation", "key": "ticket-1" },
      "to": { "namespace": "synthetic:demo-installation", "key": "role-1" }
    },
    {
      "identity": { "source": "synthetic:demo-installation", "key": "attach-2" },
      "kind": "attaches-role",
      "from": { "namespace": "synthetic:demo-installation", "key": "project-1" },
      "to": { "namespace": "synthetic:demo-installation", "key": "role-2" }
    },
    {
      "identity": { "source": "synthetic:demo-installation", "key": "comm-1" },
      "kind": "records-communication",
      "from": { "namespace": "synthetic:demo-installation", "key": "role-1" },
      "to": { "namespace": "synthetic:demo-installation", "key": "ticket-1" }
    },
    {
      "identity": { "source": "synthetic:demo-installation", "key": "comm-2" },
      "kind": "records-communication",
      "from": { "namespace": "synthetic:demo-installation", "key": "role-1" },
      "to": { "namespace": "synthetic:demo-installation", "key": "pr-1" }
    },
    {
      "identity": { "source": "synthetic:demo-installation", "key": "ext-1" },
      "kind": "contains",
      "from": { "namespace": "synthetic:demo-installation", "key": "epic-2" },
      "to": { "namespace": "synthetic:demo-installation", "key": "external-ref-404" }
    }
  ]
}
`;

export const rawEmpty = `
{
  "schema": "factory-graph/1",
  "nodes": [],
  "edges": []
}
`;

export const rawIncomplete = `
{
  "schema": "factory-graph/1",
  "nodes": [
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "project-2" },
      "kind": "project",
      "title": "Quiet installation",
      "summary": "Installation with honest gaps in its records",
      "status": "active",
      "sourceRef": "records/project-2",
      "quality": { "state": "known", "provenance": "recorded-read", "freshness": "2026-10-01T08:00:00Z" }
    },
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "milestone-3" },
      "kind": "milestone",
      "title": "Orphan milestone",
      "summary": "No parent record exists; the gap stays visible",
      "status": "open",
      "sourceRef": "records/milestone-3",
      "quality": { "state": "unknown" }
    },
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "role-3" },
      "kind": "role",
      "title": "Unattached Steward",
      "summary": "No attachment recorded in this installation",
      "status": "active",
      "sourceRef": null,
      "quality": { "state": "missing-reference" }
    },
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "ticket-2" },
      "kind": "ticket-issue",
      "title": "Stale ticket",
      "summary": "Last observation is old and stays labelled as stale",
      "status": "open",
      "sourceRef": "records/ticket-2",
      "quality": { "state": "stale", "provenance": "recorded-read", "asOf": "2026-09-02T08:00:00Z" }
    }
  ],
  "edges": [
    {
      "identity": { "source": "synthetic:demo-installation", "key": "comm-3" },
      "kind": "records-communication",
      "from": { "namespace": "synthetic:demo-installation", "key": "role-3" },
      "to": { "namespace": "synthetic:demo-installation", "key": "ticket-2" }
    }
  ]
}
`;

export const rawInvalid = `
{
  "schema": "factory-graph/1",
  "nodes": [
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "project-3" },
      "kind": "project",
      "title": "Broken installation",
      "summary": "Document carrying several contract violations",
      "status": "active",
      "sourceRef": "records/project-3",
      "estimatePoints": 5,
      "quality": { "state": "known", "provenance": "recorded-read", "freshness": "2026-10-08T08:00:00Z" }
    },
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "role-4" },
      "kind": "role",
      "title": "Leaking Role",
      "summary": "Role record that wrongly carries implementation identity",
      "status": "active",
      "sourceRef": "provider://worker-implementation/role-4",
      "quality": { "state": "unknown" }
    },
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "node-5" },
      "kind": "swimlane",
      "summary": "Record with an undocumented kind and a missing title",
      "status": "open",
      "sourceRef": "records/node-5",
      "quality": { "state": "known", "provenance": "recorded-read", "freshness": "2026-10-08T08:00:00Z" }
    },
    {
      "identity": { "namespace": "synthetic:demo-installation", "key": "project-3" },
      "kind": "project",
      "title": "Duplicate identity",
      "summary": "Same identity as another node in this document",
      "status": "open",
      "sourceRef": "records/duplicate",
      "quality": { "state": "unknown" }
    }
  ],
  "edges": [
    {
      "identity": { "source": "synthetic:demo-installation", "key": "loop-1" },
      "kind": "contains",
      "from": { "namespace": "synthetic:demo-installation", "key": "project-3" },
      "to": { "namespace": "synthetic:demo-installation", "key": "project-3" }
    }
  ]
}
`;
