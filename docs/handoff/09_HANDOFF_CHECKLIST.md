# HANDOFF CHECKLIST

## Included
- Golden rules
- Consolidated PRD
- Architecture
- API/sync contract
- Database contract
- Implementation contract
- Development task breakdown
- UI/UX IA
- Edge cases/financial integrity
- Legacy app ZIP
- Component visual standards (`docs/component-standards-prompt.md`)

## User must add
Put the approved UI/UX reference files in `reference/ui-ux/` before giving the package to the coding agent.

## Agent startup
1. Read AGENTS.md.
2. Read every doc.
3. Inspect legacy source for logic only.
4. Inspect UI/UX reference, then `docs/component-standards-prompt.md` for component shape/size/style rules.
5. Produce implementation plan/dependency order.
6. Start Phase 0.

## Gate
After every phase: implement → test → review → checkpoint → next.
Final gate: full E2E, offline/sync, permissions/security, financial reconciliation, audit, printer failure, migration/recovery, search/filter coverage, UI/UX acceptance (incl. component-standards checklist), forbidden-feature scan.
