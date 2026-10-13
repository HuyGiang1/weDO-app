# M18 Pass 1: Security and Authorization Audit

Branch baseline: `d05aac0190897381a9c0eeeb8992c7c9ed21a4c9` (`dev`). This is a backend authorization audit, not a new role or schema design. Rows below describe server enforcement; Flutter controls are not an authorization boundary.

| Domain | Authoritative access/ownership context | Read and mutation boundary |
| --- | --- | --- |
| Auth / Profile | JWT principal and current user record | Public auth entry points are explicit; private profile mutation uses the principal ID and active-user check. Refresh rotation/reuse and logout are covered by existing auth tests. |
| Social | Authenticated caller and target user | Relationship/block rules are enforced in Social services; caller ID comes from the principal. |
| Group | Current group membership, role, and group status | Active members read; owner/admin management and owner-only transfer/ban rules remain in Group services. Archived groups are read-only. |
| Activity | Activity's stored group ID | Group membership and lifecycle permissions govern create/edit/RSVP; archived, removed, and banned access follows Group rules. |
| Poll / Task / Discussion | Stored child activity, then its group | Voting, task ownership/assignment, and comment moderation use server permission policies. Completed/cancelled Discussion and archived groups are read-only. |
| Chat | Stored conversation and message sender | Group membership or DM participant status controls private reads; sender-only edit/unsend and stranger-request restrictions remain in Chat service. |
| Expense / Settlement | Stored expense/settlement and group | Current group membership controls reads; payer/participant and settlement participant checks control mutations. |
| Fund | Stored fund, collection, contribution and group | Member reads, owner/fund-manager mutations, contribution ownership, and ledger rules are enforced by Fund service. Nested collection GET now verifies its supplied fund ID after authorizing against the collection's actual fund. |
| Notification | Recipient ID from principal; group settings use current membership | Personal inbox/read/settings/device operations now recheck active account status. Another user's notification ID remains a not-found response. |
| Calendar / Reminder | Stored activity/task and user reminder context | Group visibility and reminder ownership derive from stored objects, not a caller-supplied user ID. |
| Media | Authenticated uploader, parsed category/context, and durable owning reference | Presign/finalization and signed private reads require their owning domain permission. Legacy public filesystem reads are limited to legacy `avatars/` files. |
| Search / Home | Principal and domain-scoped queries | Results inherit each domain's current visibility before pagination/projection; Home updates additionally require an actionable target. |

## Proven Pass 1 Changes

- The legacy public media reader previously accepted arbitrary category names under the local media root. It now serves only legacy `avatars/`; private S3 media still requires authorized signed access.
- The nested Fund collection detail URL previously ignored its `fundId` path segment. It now rejects mismatched parent IDs without authorizing against a caller-supplied parent.
- Personal Notification endpoints previously relied on a valid but potentially stale access JWT without checking account suspension/deactivation. They now use the existing active-user policy.
- The local verification listener previously logged email and raw one-time code. It now logs only the user ID. Local manual registration needs private email delivery; seeded QA accounts remain available.
- Spring Security's unused default in-memory user auto-configuration previously logged a generated password at startup. The JWT-only application now excludes that auto-configuration; the security context test asserts no `UserDetailsService` bean is created.
- The Flutter Chat client previously put its access JWT in the WebSocket query string, exposing it to URL-oriented diagnostics. It now connects to `/ws` without a query token and uses its already-supported `Authorization: Bearer` handshake header. The supported-client audit found no production dependency on query authentication; the backend fallback is removed. Handshake regression covers valid bearer success and missing/invalid bearer, valid query-only JWT, and token-like query rejection. Framework web DEBUG logging is disabled in that test so supplied query values are not logged.
- Fund monetary response fields were emitted as JSON numbers although Expense/Balance and the existing Fund serialization test require decimal strings. Response DTOs now use JSON strings; request binding is unchanged.

## Boundaries and Follow-up

- Existing stateless access JWTs have a documented residual validity window after remote logout. Refresh rotation, reuse, expiry and concurrent refresh remain the revocation boundary; no access-token blacklist was introduced.
- No new security error-code family or global 403/404 collapse was introduced. Private resource denial continues to use the owning domain's established not-found/access-denied convention.
- Pass 2: Activity RSVP uses pessimistic Activity/participant and waitlist-sequence locks; Chat increments `conversation_sequences` atomically and V4 uniquely constrains `(conversation_id, sequence)`; Fund uses row locks for collection/contribution/ledger-sensitive paths. Recheck final-slot, contribution-limit/balance, and Settlement contention together under targeted load. Pass 1 makes no concurrency changes.
- Pass 3: Notification page mapping calls target-actionability resolution per row, and that resolver can issue additional SQL; the API permits pages up to 100. V9 already has recipient/time and unread indexes, and Chat history has a conversation/sequence uniqueness index. Measure actual query counts and plans across Chat, Notification, Calendar, and Finance before changing queries or indexes.
- Pass 4: Flutter Chat realtime has reconnect backoff and client-message IDs; Notification uses after-commit dispatch and `REQUIRES_NEW` for isolated delivery updates. Verify reconnect replay/dedup and push-failure isolation under fault injection. Pass 1 makes no reliability changes.
