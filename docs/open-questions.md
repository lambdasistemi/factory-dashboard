# Product decisions

## Story: Know what is settled before building

As a contributor, I read the product decisions and know which boundaries to preserve and which choices still need an answer.

## Fixed requirements

The graph is the core and the opening view. It preserves the actual GitHub work structure and attaches the public factory role and communication vocabulary. Other views must be reached through graph context and derived from the same data.

The first milestone is read-only. Its two sources are GitHub work records and explicitly configured local communication files. The dashboard does not call model services, change GitHub, write communication files, discover a machine, install workers or manage the factory.

Roles and the supported protocol are public product design. Concrete worker implementations, provider and model identities, prompts, launch commands, credentials and real installation bindings remain private. Runtime addresses, roots, selected repositories and access settings are configurable.

Before any first product release, the operator must review the configuration and privacy evidence. Successful builds are not sufficient. The project promises defined, tested boundaries and explicit limits, not perfect safety in arbitrary installations.

## Long-term goals

After the observation foundation is accepted and released, the product should support contextual conversations through local channels. Graph-derived attention and history views are also later goals. Eventually the operator should be able to select teams and direct authorised factory operations from the dashboard.

The [roadmap](roadmap.md) keeps these goals visible as milestones without assigning speculative epics, tickets or dates to them.

## Remaining choices

- The application framework, language and runtime packaging. The documentation scaffold does not select these.
- The supported initial operating environments and authentication mechanism within the fixed private-access boundary.
- The exact versioned configuration schema and the initial supported subset of the file protocol. Their tickets must resolve these before integrating real sources.
- The mapping of configured projects and repositories to existing GitHub work relationships; GitHub terms themselves are not being redesigned.
- The source license, which must be selected before the first product release.
- The detailed design, authorisation and release order of later conversations, derived views and team controls.

## Current delivery status

The repository bootstrap is merged. The milestone, epic and ticket definitions in this documentation are proposed planning artifacts pending review and issue creation. The dashboard application is not implemented by these records. Existing prototypes use example data and simulated conversations.
