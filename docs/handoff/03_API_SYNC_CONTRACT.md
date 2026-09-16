# API & SYNC CONTRACT

Server = synchronized source of truth. Client = durable local operational state + workspace + outbox.

Pipeline: `Local DB → Outbox/Sync Queue → Server validation → Pull → Local DB`.

Outbox fields: ID, entity ID, operation, payload/event, client timestamp, actor/device, base revision, idempotency key, retry status, last error.

Server validates authentication, branch access, permission, object state, revision/conflict, financial/business rules and idempotency. Conflicts must never silently overwrite. Pull server changes after push and merge deterministically.

Checkout must use idempotency. Append-only completed transaction creation is preferred over whole-object overwrite. Saved Bill is shared online but editing creates local workspace; remote bill is unchanged until explicit save/checkout behavior. Cross-device close/payment must surface conflict/closure.

Swipe-down/reload triggers push pending → validate → pull → status update. Reconnect alone doesn't mean synced. Owner sees Online/Offline/Pending Sync/Syncing/Sync Failed. Notifications resolve by UUID/reference. New device/reinstall authenticates and pulls server data.
