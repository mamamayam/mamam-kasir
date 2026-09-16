# DATABASE CONTRACT

Logical entities: users, roles, permissions, user_roles, user_branch_access, devices/sessions, branches; categories, menus, menu_branch_prices, variant_groups/options, menu_variant_groups, modifikasi_groups/options, menu_modifikasi_groups, paket, paket_components; customers, customer_phones; shifts, carts/workspaces, saved_bills/items; transactions/items/item_variants/item_modifikasi/package snapshots/discounts/payments; expense_categories, expenses, pemasukan_lain; approval_requests, notifications, audit_logs; outbox, sync_state, backup metadata.

Integrity: UUID IDs, exact money, FKs, global unique phone, explicit branch access, unique active device per user, approval state transitions, unique outbox idempotency, circular-package prevention. Completed transaction stores final display/business snapshots directly on transaction items so master changes do not alter history. Saved Bills remain dynamic until checkout.

Transaction deletion permission/retention is UNSPECIFIED; no purge policy may be invented.
