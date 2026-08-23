# ERD & DATABASE DESIGN v1.0

## 1. Technology & Principles
Primary DB: PostgreSQL.
Schema management: Flyway.

Identifiers:
- UUID
- UUIDv7 recommended if convenient
- UUIDv4 acceptable

Types:
- CITEXT for username/email
- TIMESTAMPTZ
- NUMERIC(19,2) for money

Principles:
- Facts persisted.
- Summaries derived.
- Important history preserved.
- Financial rows avoid hard delete.
- Redis stores ephemeral state.
- Files live in object storage; DB stores metadata/reference.

## 2. Identity & Auth
Tables:
- users
- user_credentials
- user_privacy_settings
- auth_tokens
- refresh_sessions
- user_devices

`refresh_sessions` supports refresh-token rotation/revocation.

Suggested fields:
- id
- user_id
- token_hash
- expires_at
- revoked_at
- replaced_by_session_id
- device_name/platform optional
- created_at

`user_devices` supports FCM:
- id
- user_id
- platform
- push_token
- device_id
- active
- last_seen_at
- created_at
- updated_at

## 3. Social
- friend_requests
- friendships
- user_blocks
- user_presence_snapshots

Realtime presence itself belongs Redis.

## 4. Group
- groups
- group_settings
- group_memberships
- group_invitations
- group_invite_links
- group_join_requests
- group_bans
- group_activity_logs

Important:
- membership history retained
- rejoin creates new row
- one active membership/user/group

## 5. Chat
- conversations
- direct_conversations
- group_conversations
- message_requests
- conversation_sequences
- messages
- message_attachments
- message_edit_history
- message_hidden_users
- message_reactions
- conversation_read_states
- message_pins

## 6. Activity
- activities
- activity_participants
- activity_rsvp_history
- activity_waitlist_sequences
- activity_status_history
- activity_change_logs

## 7. Poll
- polls
- poll_options
- poll_votes
- poll_vote_choices

Anonymous poll stores internal user ID but API/UI hides voter identity.

## 8. Task & Discussion
- tasks
- task_assignees
- task_status_history
- activity_comments

`activity_comments.parent_comment_id` nullable; one reply level enforced in service.

## 9. Calendar
- user_activity_reminders

Calendar is derived from Activity; no duplicate calendar event table required in MVP.

## 10. Finance
- expenses
- expense_shares
- expense_change_logs
- settlements
- settlement_status_history

No authoritative `debts` table.
Debt is derived from Expense facts and COMPLETED settlements.

## 11. Group Fund
- group_funds
- fund_managers
- fund_collections
- fund_collection_obligations
- fund_contributions
- fund_expenses
- fund_reimbursements
- fund_transactions
- fund_transaction_reversals

Fund balance derived from ledger.

## 12. Notification
- notifications
- user_notification_settings
- group_notification_settings
- user_devices

## 13. Important FK / Integrity Rules
- Membership → Group/User
- Activity → Group
- Poll/Task/Comment → Activity
- Expense → Group
- Expense.activity_id nullable but must reference same Group
- Settlement history remains resolvable after member leaves
- Fund entities → Group/Fund
- Financial/history records avoid cascade hard-delete

## 14. Important Constraints
- username unique
- email unique
- one ACTIVE membership/user/group
- one reaction/user/message
- one group conversation/group
- one active fund/group MVP
- amount fields > 0 where applicable
- custom expense shares sum = total
- fund balance cannot go negative
- settlement amount <= current debt

## 15. Index Strategy
Important indexes:
- users(username)
- users(email)
- group_memberships(group_id, user_id, status)
- activities(group_id, start_at)
- messages(conversation_id, sequence)
- notifications(user_id, read_at, created_at)
- expenses(group_id, occurred_at)
- settlements(group_id, status)
- fund_transactions(fund_id, created_at)

## 16. Flyway Plan
```text
V1__identity_and_auth.sql
V2__social.sql
V3__groups.sql
V4__chat.sql
V5__activities.sql
V6__poll_task_discussion.sql
V7__finance.sql
V8__group_fund.sql
V9__notifications_reminders.sql
V10__cross_module_indexes.sql
```

Rules:
- Applied migration is immutable.
- Schema change after release uses V11, V12, ...
- Hibernate uses `ddl-auto=validate`.

## 17. PostgreSQL vs Redis

PostgreSQL:
- User
- Group
- Message
- Activity
- Expense
- Settlement
- Fund
- Notification

Redis:
- Presence
- Typing
- Rate limit
- Temporary WebSocket/session state
- TTL-based ephemeral data

## 18. File Storage
Do not store binary media in PostgreSQL.

DB stores:
- storage key
- content type
- size
- metadata
- business relation

Binary stored in:
- S3-compatible storage / Cloudinary

**ERD & DATABASE DESIGN v1.0 — BASELINE ESTABLISHED**
