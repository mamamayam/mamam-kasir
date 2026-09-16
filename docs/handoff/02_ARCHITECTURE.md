# TECHNICAL ARCHITECTURE

Recommended baseline: Flutter/Dart + Riverpod + encrypted SQLite + Supabase/PostgreSQL + API/service layer + Bluetooth ESC/POS.

Layers: Presentation → Application/use cases → Domain → Repositories/Data → Local DB/Remote API → Sync → Platform adapters.

Modules: auth, users, roles_permissions, branches, sync, menu, category, variant, modifikasi, paket, customer, shift, cart, saved_bill, checkout, payment, transaction, expense, pemasukan_lain, approval, notification, reports, dashboard, printer, backup, audit, attendance_adapter.

Keep server entities, synchronized local entities, cart/workspace state, outbox, and notifications separate. Business logic must not live only in widgets. UI is not a security boundary. Use exact money types (integer Rupiah or exact decimal), never floating-point. Use UUID for durable IDs. Human-readable SB numbers are presentation IDs. Printer adapter must be isolated from checkout. AttendanceProvider is an adapter boundary.
