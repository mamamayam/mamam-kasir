# PRD — MAMAM KASIR v1

Mamam Kasir is an offline-first multi-branch F&B POS for Mamam Ayam/Mamam Global.

### POS
Take Away primary; Dine In without tables; Delivery; Ojol with platform/name + external Order ID. Screen selection only; no barcode. Grid/List menu. No photos, use initials/icons. Search, category, notes, customer, Variant, Modifikasi, Paket, custom price, item + overall discounts, delivery fee (quick/custom), tax/service where configured. No stock/sold-out.

### Checkout
Cash, QRIS, Transfer only. Manual QRIS/Transfer, no gateway/QR display. Split payment supported. Cash suggestions/custom; underpayment rejected; change on overpayment. Printer failure does not block sale.

### Snapshot
Completed transaction captures UUID, time/date, branch, user, customer, order type, Ojol details, items/qty/prices, variants, Modifikasi, Paket, notes, discounts, delivery fee, tax, service, payment/split, payment amount, change and relevant final information. Historical data survives master changes.

### Saved Bill
Belum Bayar; one active per customer; shared online; dynamic. Editing turns it into local cart/workspace; remote record remains reference. Cart changes don't immediately sync to Saved Bill. Checkout uses local cart. Cross-device close/payment notification. Unpaid bill can be deleted directly, no history. Number can reuse SB-0001.

### Access
Owner/Manager/Cashier; one Owner. Multiple roles possible. Branch-scoped operational data for Manager. Customer is global. Owner manages roles/permissions. Permission modes: deny/direct/approval.

### Shift
Uang Dompet; one active shift/branch; cashier handover requires close; Manager Bypass; Force Close 00:00. Formula: `Uang Dompet Awal + Penjualan Tunai − Pengeluaran Tunai = Saldo Kas Seharusnya`. Shortage > Rp5,000 approval. Close report includes opening cash, cash sales, expenses, expected/physical cash, discrepancy, transaction count, omzet, cash/noncash, expenses. Manager/Owner can correct after close with audit; Manager changes notify Owner.

### Expenses
Fields nominal/category/note/payment/time/user/branch. Cashier/Manager/Owner entry; Manager direct + Owner report. Cashier edits require approval; Manager direct + Owner notification; Owner unrestricted. Cancellation = Batalkan Pengeluaran; remains history, excluded from active calculations. Categories Owner-managed.

### Pemasukan Lain
Included as separate financial concept. Implement only defined behavior; do not invent missing rules.

### Master data
Menu: name, branch price, optional HPP/modal, category, linked Variant Groups, Modifikasi Groups, package info. Menu created centrally available to all branches; default/global or branch prices. Variants reusable with group min/max and +/0/- options. Modifikasi reusable with group min/max and +/0/- options, usable across products/variants/packages. Paket can contain products/packages, nested, variant groups, branch price; circular references prohibited. Used masters cannot hard-delete; Nonaktif only. Nonaktif isn't sold-out.

### Customer
Global. Name required, phone optional, multiple phones. Phone unique. Name should not duplicate. Search name/phone. Cashier can create immediately. No customer = Pelanggan Umum. Phone shown as 08xx grouped every four digits. No primary phone. Edit Owner/Manager or Cashier by permission. Audit. Analytics: spend, transaction count, frequent items/order, daily spend and other useful analysis.

### Edit/cancel/restore
Manager edits paid transaction directly; Owner unrestricted. Editable: customer, order type, item/qty, variant, Modifikasi, price, discount, payment method, payment amount. No automatic cash discrepancy adjustment. Show changes/link previous version. Audit + Owner report for Manager edits. Cancellation = Batalkan Transaksi; canceled remains history, excluded omzet, no separate refund transaction. Once canceled cannot edit/cancel again. Restore requires Manager/Owner approval. Canceled shown red. Transaction deletion permission/retention = UNSPECIFIED.

### History
All transactions remain; canceled red; newest first. Search UUID/customer/cashier/nominal/date. Filters: Hari Ini, Kemarin, Hari Sebelumnya, Custom Date plus relevant filters. Detail shows latest successful receipt version; change history separate from receipt.

### Dashboard/reports
Omzet Hari Ini, Total Pengeluaran Hari Ini, Laba Kotor Hari Ini. Daily gross profit = omzet - expenses, no HPP. Monthly net profit formula: `stok opname awal bulan + total expense bulan ini − sisa stok opname bulan ini`. Expenses include salaries, rent, electricity, purchases, other operational. Sales trends + Best Seller with clickable drilldown. PDF/Excel. Branch comparison deferred.

### Offline/sync
Offline: open shift, Saved Bill, edit, checkout, expenses. Durable local DB. Return online then swipe-down/reload sync. `Local DB → Outbox → Server validation → Pull → Local DB`. No blind overwrite. Reinstall login pulls server data; unsynced never uploaded is unrecoverable. Logout retains encrypted local data but inaccessible to another user. No reset local data.

### Backup
Owner-only backup/restore; all server data; latest-valid rolling backup; validate before deleting prior. No rollback of newer transactions.

### Attendance
External system source of truth; integration interface only.
