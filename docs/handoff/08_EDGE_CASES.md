# EDGE CASES & INTEGRITY

- Duplicate checkout retry = exactly one transaction.
- Printer failure never rolls back a paid sale.
- Split payment must equal total.
- Cash underpayment rejected.
- Saved Bill is unique per customer; cross-device closure creates notification/conflict.
- Inactive masters cannot be newly selected; history remains snapshot-based.
- Circular Paket rejected.
- Approval race cannot be processed twice; Owner takeover wins through server state validation.
- One active shift per branch; handover closes prior shift; Force Close ends it.
- Discrepancy > Rp5,000 needs Manager approval.
- Canceled sales excluded from omzet but retained historically.
- Restore requires approval.
- Duplicate customer phone rejected.
- Manager cross-branch customer history does not grant cross-branch operational access.
- Outbox durable; no blind overwrite; failed sync retryable.
- Security: 5 wrong PIN lock; 30-minute auto-lock; 3-day PIN inactivity requires credentials; second-device login logs out first.

Financial formulas:
`Laba Kotor = Omzet − Pengeluaran`
`Saldo Kas Seharusnya = Uang Dompet Awal + Penjualan Tunai − Pengeluaran Tunai`
`Monthly Net = stok opname awal bulan + total expense bulan ini − sisa stok opname bulan ini`
No HPP in daily profit.
