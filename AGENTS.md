# MAMAM KASIR — GOLDEN RULES

## Source of truth
1. PRD (`docs/handoff/01_PRD.md`) = business truth.
2. Technical docs/contracts (`docs/handoff/02-08_*.md`) = technical truth.
3. Supplied UI/UX reference = visual/interaction truth for navigation & screen composition; `docs/component-standards-prompt.md` = visual truth for component shape/size/style (see "Visual/component standards" below).
4. Legacy app = behavior/logic reference only, NEVER UI source.
5. Never invent unspecified business rules. If marked UNSPECIFIED, keep it that way.

## Forbidden scope
Do NOT add inventory/stock, sold-out, stock deduction, table management/table numbers, barcode scanning, QRIS gateway, QRIS generation/display, debt, automatic printing, active points/vouchers/claims, full HRD/payroll, or unrelated legacy modules.
Dine In exists without tables.

## Core architecture
Recommended: Flutter/Dart, Riverpod, encrypted SQLite, Supabase/PostgreSQL, API/service layer, Bluetooth ESC/POS. Business logic must be independent of UI. Local DB is durable; do not use localStorage as primary persistence.

## Offline/sync
`Local DB → Outbox/Sync Queue → Server validation → Pull → Local DB`
All main operations work offline: open shift, Saved Bill, edit Saved Bill, checkout, expense, Pemasukan Lain where defined. Pending mutations are durable. Never blind-overwrite. Checked-out transactions use UUID/idempotent semantics. Reconnect alone does not mean synced; swipe-down/reload triggers sync. Failed sync remains retryable.

## Transactions
Every completed transaction has permanent UUID. Checkout is idempotent. Successful checkout stores a complete snapshot. History remains auditable. Canceled transactions remain records, are excluded from omzet, and have no separate refund transaction. Preserve Original → Edited → Canceled history.

## Saved Bill
Belum Bayar. One active Saved Bill per customer. Shared online. Dynamic until checkout. Opening it creates a local cart/workspace; remote Saved Bill remains reference. Cart edits do not immediately update online Saved Bill. If another device pays/closes it, editor is notified and cannot continue it. Unpaid Saved Bill can be deleted directly and does not enter history. Number may reuse `SB-0001` after close/payment.

## Roles/permissions
Roles: Owner, Manager, Cashier; custom roles allowed. One Owner only. User may have multiple roles and branch access is profile-based, not device-based. Permission modes: not allowed / direct / approval required. Server enforces permissions. Cashier approval requests go to Pending Approval. Owner may takeover. Processed request cannot be processed twice. Manager direct sensitive actions are audited and reported to Owner where specified. Permission changes apply immediately.

## Shift/Uang Dompet
`Uang Dompet Awal + Penjualan Tunai − Pengeluaran Tunai = Saldo Kas Seharusnya`.
One active shift per branch. Cash held by Manager/Owner. Shortage > Rp5,000 requires Manager approval. Handover requires close first. Force Close at 00:00. Forgotten post-close transactions need Manager/Owner approval. Manager/Owner corrections are audited; Manager corrections notify Owner.

## Customer
Global across branches. Name required, phone optional. Multiple phones allowed; one phone belongs to one customer. Duplicate phone rejected and existing customer offered. Search name/phone. No customer = `Pelanggan Umum`. Cross-branch customer profile/history may be visible to Manager, but other-branch operational reports remain inaccessible. Phone displayed starting `08`, grouped every four digits. No primary phone. Audit changes.

## Menu
Menu has name, branch-specific price, optional HPP/modal, category, linked Variant Groups and Modifikasi Groups, and package data when applicable. Variants/Modifikasi/Paket are reusable masters. Groups have min/max. Variant/modifikasi options can +/0/-. Paket components can be products or packages, nesting allowed, with circular-reference prevention. Master data used by history cannot hard-delete; use Nonaktif. Nonaktif is NOT sold-out. Historical transactions use snapshots. Saved Bills remain dynamic.

## Payment
Exactly Cash, QRIS, Transfer. No debt. QRIS/Transfer manual only. Split payment may use all three and must equal total. Cash underpayment rejected; overpayment calculates change. Suggested cash amounts plus custom amount. Printer failure never blocks checkout.

## Printing
Bluetooth thermal + ESC/POS. Persistent printer config. Receipt supports store info, totals, discounts, tax/service, delivery fee, payment and change. Reprint = `STRUK COPY`. Saved Bill can print kitchen slip showing `SB-0001`, items/qty/variant/note/status. NO auto print.

## Notifications
Two concepts: Approval Request (action waits) vs Informational Report (action already happened). Two categories: System and Transaction. Transaction headline focuses on amount/order/payment, e.g. `Rp125.000 • Take Away • QRIS`, not cashier name. Approval can push. Manager reports need not push. Max 30 recent notification rows/items; older history in Audit Report. Notifications reference/deep-link, not duplicate transactions.

## Search/UX
Every meaningful list has search. Date filters: Hari Ini, Kemarin, Hari Sebelumnya, Custom Date; one date = exact date. Relevant filters: branch, user/cashier, customer, order type, payment method, status, nominal, etc. Sorting + pagination/infinite loading. Offline search/filter. Empty state `Tidak ada data`. Minimal loading. Errors preserve data and support swipe-down retry. Consistent alerts/filter patterns.

## Visual/component standards
Before writing or editing any UI widget (form field, button, icon button, PIN pad, card, product thumbnail, badge, tab, sheet/slide-up, empty state, loading indicator, snackbar, dialog, divider), read `docs/component-standards-prompt.md`. It is the final, locked spec for shape/size/color/typography of every component type — derived from an audit of this exact codebase, not invented. Do not create a new visual pattern for anything already covered there; reuse or extend the shared widgets under `lib/core/widgets/` (`AppButton`, `AppTextField`, `AppIconButton`, `AppPinKeypad`, `AppCardShell`, `AppItemThumbnail`, `AppStatusBadge`, `AppEmptyState`, `AppSheetHeader`/`IosPageHeader`, `DateFilterTabs`/`SlidingPillTabs`). No inline `BorderRadius.circular(<number>)`, no ad hoc `InputDecoration`/`ElevatedButton`, no new placeholder icon/shape for products — menu items use initials (see PRD: no photos, use initials/icons), rendered via `AppItemThumbnail`. Run the checklist at the end of `docs/component-standards-prompt.md` before considering any UI task done. If a component type isn't covered there, follow its Bagian 19 (how to add a new rule) instead of guessing. Full audit trail/rationale (why each value was chosen, what was found wrong in which file) lives in `docs/component-standards.md` — read it only if you need the history, not for day-to-day work.

## Security
PIN 4 digits. 5 wrong PIN attempts locks account. Auto-lock after 30 minutes inactivity. If no PIN input for 3 days require User ID + password. Auto-lock preserves cart. One user = one active device; second login logs old device out. Support `Cabut Otorisasi Device`. Change PIN twice, no logout. Manual logout clears session. Encrypt local DB and OS secure key storage. Do not block screenshots. Audit login/security/device/PIN/backup/restore/permission events.

## Financial/report rules
Dashboard: Omzet Hari Ini, Total Pengeluaran Hari Ini, Laba Kotor Hari Ini. `Laba Kotor = Omzet − Pengeluaran`; no HPP in daily profit. Monthly net profit: `stok opname awal bulan + total expense bulan ini − sisa stok opname bulan ini`. Expenses include salaries, rent, electricity, purchases, other operational costs. Charts: sales trends and Best Seller, clickable for drilldown. PDF/Excel export.

## Backup/recovery
Owner only. Backup includes all server data. Restore Owner only. New/replacement device = login + server pull, not backup restore. Never rollback newer transactions. Rolling backup keeps latest valid only; delete old only after new validates. Failure is visible/retryable. No Reset Local Data button.

## Attendance
External attendance system is source of truth. Build `AttendanceProvider` integration port/interface only; do not duplicate attendance source.

## Development discipline
Implement phase-by-phase: implement → test → review → checkpoint → next. Do not build everything in one uncontrolled pass. Definition of Done includes business rules, persistence, permissions, offline/sync, audit, errors, tests, and forbidden-feature scan. Ask only for genuinely blocking ambiguity.

## Known UNSPECIFIED
Transaction deletion permission/retention is intentionally UNSPECIFIED. Do not invent policy.
