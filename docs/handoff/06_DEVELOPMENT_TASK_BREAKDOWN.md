# DEVELOPMENT TASK BREAKDOWN v1

0 Foundation; 1 Local DB; 2 Backend; 3 Auth/device; 4 Permissions; 5 Sync; 6 Master Data; 7 Customer; 8 Shift/Uang Dompet; 9 POS Core; 10 Pricing/Discount; 11 Delivery/Ojol; 12 Saved Bill; 13 Payment/Checkout; 14 Receipt/Printing; 15 Expense; 16 Pemasukan Lain; 17 Transaction Edit; 18 Cancellation/Restore; 19 Approval; 20 Notification; 21 History; 22 Dashboard; 23 Reports; 24 HPP foundation; 25 Attendance integration foundation; 26 Backup/Recovery; 27 Data Safety; 28 Search/Filter/UX infrastructure; 29 Alert/Error infrastructure; 30 UI/UX implementation; 31 Security hardening; 32 Performance; 33 Offline tests; 34 Failure tests; 35 Financial integrity tests; 36 Approval tests; 37 Audit tests; 38 Printer tests; 39 Migration tests; 40 Release Candidate.

UI sequence: App Shell → Login → Dashboard → POS → Product Config → Cart → Saved Bill → Checkout → Payment → Success → History → Transaction Detail → Customer → Shift → Expense → Approval → Notification → Master Data → Reports → Settings.

Mandatory E2E: open shift→sale→payment→receipt; Saved Bill→edit→checkout; cashier→approval; manager direct→owner report; offline→sync; duplicate checkout retry; paid edit→audit; cancel→omzet exclusion; restore approval; close shift→cash reconciliation.
