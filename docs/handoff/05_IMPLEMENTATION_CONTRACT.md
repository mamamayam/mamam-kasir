# IMPLEMENTATION CONTRACT

Before each phase: read relevant docs → inspect dependencies → implement smallest coherent increment → tests → verify permission/offline/audit/sync implications → report → checkpoint.

Never rewrite unrelated modules, silently change business rules, add legacy features outside PRD, use UI-only security, make checkout depend on printing, or perform destructive sync overwrites.

Definition of Done: business behavior, data model, permissions, persistence, offline behavior, sync, audit/notifications where applicable, errors/retry, tests, and forbidden-feature scan all pass.

If docs conflict, don't choose silently; report the conflict. PRD wins for business behavior.
