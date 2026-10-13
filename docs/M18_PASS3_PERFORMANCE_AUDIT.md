# M18 Pass 3: Measured Read Performance

Branch: `feat/m18-hardening`; unchanged HEAD/base: `d05aac0190897381a9c0eeeb8992c7c9ed21a4c9`.
Pass 1 security and Pass 2 concurrency work remain intact. No API, schema, monetary calculation, financial locking, caching, or delivery semantics changed.

## Method and Fixtures

`ReadPerformanceIntegrationTest` wraps JDBC connections/statements in its own test context, without adding a dependency or changing normal logging configuration. It counts executed statements (ORM and JdbcTemplate), connection acquisitions, and peak concurrently held connections on the calling thread. Endpoint service entry points are measured; HTTP/JWT parsing overhead is excluded. SQL binds are retained only in test memory for replaying actual selected read SQL with `EXPLAIN (ANALYZE, BUFFERS)`; binds are never printed.

The test owns a fresh PostgreSQL 17/Testcontainers database, applies committed Flyway V0-V12, runs ANALYZE, and uses synthetic users without login credentials or devices. Initial fixture: 2,000 messages, 300 inbox records with distinct Activity targets, 1,500 dated Activities/participant rows, 300 expenses/shares, and 30 Fund collections/obligations. Growth probes add 19 groups and 1,900 irrelevant historical Activities, nine target classes (9 then 18 inbox items), 100 settlements/history records, and 330 Fund ledger rows backed by confirmed contributions and Fund expenses.

Counts are regression evidence, not percentage speedups. Timing samples are informational only; no millisecond CI threshold. Base comparisons use the same initial fixture, before later growth/mutation probes. Existing authorization/lifecycle tests accompany budget assertions.

## Results

| Domain / use case | Before | Finding | Change | After | Status |
| --- | --- | --- | --- | --- | --- |
| Chat history, limit 1 / 30 | 10 / 10 statements | Sender join and batched reactions/attachments already avoid per-message SQL | None | 10 / 10 | Existing behavior retained |
| Chat list, 1 / 20 existing group conversations | 8 / 122 | Per-group ensure, membership/status, read/unread and DM projection lookups | Ensure only missing conversations; set-based sequence repair; list projects unread, peer/request and group state | 3 / 3 | Query-growth regression passes |
| Notification inbox, 1 / 30 Activity items | 5 / 63 | Membership plus target status per item | Page-local membership and target facts batched by type/ID; current resolver retains routes/reasons/policy | 5 / 5 | Distinct-target growth regression passes |
| Mixed Notification target classes, 9 / 18 items | Original per-row shape audited; no independent mixed baseline | Different classes require different facts | Same grouped loader; no cross-request cache | 12 / 12 | Routing and stale-state assertions pass |
| Notification unread | 2 statements | Active-user read plus count | None | 2 | Existing partial index retained |
| Calendar dated range, 29 results / 1,500 Activities | 1 statement; global participant aggregate over 1,500 rows | Participant aggregate ran before outer date restriction | Lateral aggregate constrained to selected Activity using existing index | 1 statement; 29 indexed participant aggregate probes | Same overlap/filter/count semantics |
| Expense list, 300 rows | 4 statements | Payer/creator joins and share count already SQL-side | None | 4 | Retained |
| My balances, one peer / 300 expenses | 6 statements | Ledger reads plus public peer projection | None | 6 | Exact ledger calculation retained |
| Settlement list, 100 rows/history entries | 404 statements | One history plus three user reads per row | Bulk history and public users; shared DTO permission calculation | 6 statements | List/detail parity and budget regression |
| Fund collection list, 30 collections | 126 statements | Repeated obligations, contributions, reversal set and user projections | Bulk children, one reversal read, one distinct-user projection set; reuse existing amount/status calculator | 10 statements, including populated confirmed state | Financial and budget regressions |
| Fund transactions, empty / 330 ledger rows | 6 empty; populated probe introduced after baseline | Already joins reversal metadata; public users deduplicated by ID | None | 6 empty / 7 populated (one creator) | No invented populated speedup |
| Home total, initial fixture | 72 statements | Recent Updates reused inbox per-item work | Notification batching; no new Home aggregation | 14 statements | Same bounded sections |
| Home total, 1 / 20 groups | Separate initial before 72; no pre-change 20-group total | Potential per-group growth tested | Finance already bulk; Notification now batch | 14 / 15 | +1 page-count statement, not per-group growth |

Standalone Home component counts: Recent Groups 2, Upcoming Activities 1, Finance Summary 3, Actions Required 4, Recent Updates through inbox 5. Under one Home transaction the ORM reuses the active-user entity, so standalone numbers do not sum exactly. Finance Summary remains 3 statements at twenty groups; Recent Groups adds a paging count once its first page is full. Output bounds remain Groups 5, Upcoming 5, Finance groups 4, Actions 8, Updates 5 from newest 30 inbox candidates.

## Plan Evidence and Index Decisions

- Chat history: backward `uq_messages_conversation_sequence` scan returns 31 candidate rows for limit 30 from 2,000 messages, followed by bounded projection. No duplicate conversation/sequence index needed. Attachments/reactions remain page-batched; indexed history access is shared with existing Chat reads.
- Notification base page: PostgreSQL chose a small sequential scan over 300 recipient records plus top-N sort (about 36-38 KiB). Existing recipient/time and partial unread indexes are present. The proven cost was round trips (63 statements), not this inexpensive base scan. A new `(user_id, created_at, id)` index was considered but not justified by this fixture; realistic multi-recipient volume/deep-page plans would be needed first.
- Calendar baseline: `idx_activities_group_start` selected the range, but a separate HashAggregate scanned all 1,500 participant rows. After: the same Activity range index plus `idx_activity_participants_activity_status` index-only probes for 29 selected activities. Isolated range samples were about 0.96 ms before and 0.43-0.74 ms after; these fluctuate and are not a speedup guarantee. Indexed locality/aggregate cardinality is the acceptance evidence. Broad/no-range reads may prefer global aggregation; that tradeoff is not claimed benchmarked.
- Finance list indexes already match owning group/fund predicates; no new ledger index or cached balance is proposed. Settlement history already has an owning-settlement/time index. Bulk projections remove measured round trips without financial mutation changes.
- No indexes added, no applied migration edited, no V13. No EXPLAIN-based claim of a missing index. Full raw plans/index definitions are diagnostic test output, not copied into this report.

### Existing Index Inventory

Migration definitions and fresh `pg_indexes` were cross-checked for the performance target tables. Every listed table also has its existing primary-key index; composite PKs are called out below.

| Table | Existing non-PK index coverage (migration) |
| --- | --- |
| messages | unique conversation/sequence; sender (V4) |
| message_attachments | message/sort order (V4) |
| message_reactions | unique message/user (V4) |
| message_hidden_users | user; composite message/user PK (V4) |
| conversation_read_states | user; composite conversation/user PK (V4) |
| group_conversations / direct_conversations | unique group / unique ordered user pair; direct user2 (V4) |
| message_requests | unique pending conversation; receiver/status; conversation (V4) |
| group_memberships | group/status; user/status; partial unique active group/user and active owner (V3) |
| activities | group/start; group/status (V5) |
| activity_participants | unique activity/user; activity/status; user/status; partial unique waitlist sequence (V5) |
| notifications | user/created descending; partial user/created unread; partial group (V9) |
| user_activity_reminders | unique activity/user; user; partial due remind_at (V9) |
| expenses | group/occurred descending; payer; partial activity (V7) |
| expense_shares | unique expense/user; user (V7) |
| settlements | group/status; from/to/status (V7) |
| settlement_status_history | settlement/created ascending (V7) |
| group_funds / fund_managers | partial unique active group, group/status / unique fund/user, user (V8) |
| fund_collections | fund/status/deadline (V8) |
| fund_collection_obligations | unique collection/user; user (V8) |
| fund_contributions | fund/status; collection/user/status; user/status (V8) |
| fund_expenses / fund_reimbursements | fund/occurred descending, partial activity / fund/status, user (V8) |
| fund_transactions | fund/created descending; fund/type; partial unique domain reference (V8) |
| fund_transaction_reversals | unique original and reversal transaction references (V8) |

V10 adds active push-token uniqueness, not a replacement read index. V11 changes refresh-session families; V12 scheduling nullability/check semantics. Neither creates a performance-target index. Current schema, not historic design suggestions, controls this inventory.

## Bounds and Remaining Observations

- Chat history clamps page size 1..100 and reads size+1 with a sequence cursor. Inbox clamps 1..100 and uses DB LIMIT/OFFSET; total and unread counts remain exact. Home reads bounded sections and a 30-row inbox candidate page.
- Conversation list and message requests are unpaged. Calendar filters ranges in SQL but from/to are optional and there is no result cap. Expense list, Settlement list, Fund collections/transactions/expenses/reimbursements remain unpaged canonical lists. No silent truncation or breaking paging contract was added.
- Fund public user summaries still perform one lookup per distinct referenced user, rather than per collection; Expense balances still project each distinct peer. Their many-distinct-user shape is source-audited, not benchmarked here. Finance lists can grow with historical rows; API pagination needs explicit contract review rather than an arbitrary cap.
- Global Search conversation text uses its own visibility-filtered SQL path; substring scans and shared Chat visibility/index predicates were source-audited, not timed or changed. No speculative text index/cache.
- New-conversation materialization still has per-missing-group work using the existing race-safe path. The 3-statement Chat budget is for steady-state existing conversations; it does not claim constant setup cost for twenty new groups.
- Batched Notification facts are discarded at request end. Revocation/cancellation/invitation lifecycle and Poll/Task activity routing are tested; inaccessible targets remain non-actionable. No metadata is used as a substitute for current authorization.

## Pass 4 Reliability Evidence and Queue

One diagnostic Chat send with one other member and no push devices executes **27 JDBC statements, 3 connection acquisitions, peak 2 held simultaneously**, on the calling thread. `NotificationDomainEventListener` is synchronous AFTER_COMMIT; `processChatMutationEvent` first uses REQUIRES_NEW for conversation/recipient context, then `processDomainEvent` uses another isolated transaction for inbox/policy. Twenty sends can saturate the normal ten-connection pool while callbacks need additional connections. This matches the Pass 2 timeout; no pool increase or async/delivery redesign was made here. More recipients add isolated persistence work; this pass measured one-recipient fanout, not arbitrary fanout latency.

Exact next queue: characterize and fix Chat after-commit pool starvation without losing committed notification work; WebSocket reconnect/REST catch-up; duplicate/replay handling; Redis degradation; FCM failure isolation; assert notification failure never rolls back business commits; then definitive full backend, full Flutter/analyze/APK, and Samsung physical hardening acceptance. No durable-outbox guarantee is claimed by current synchronous delivery.

## Verification and Git

Final combined affected verification exited 0: **78 tests, 0 failures, 0 errors, 0 skipped**. Classes: performance 1, Chat service 14, Chat realtime 5, Notification 10, Home 6, Calendar/reminder 6, Fund 16, Expense/balance 14, Settlement 6. Fresh Testcontainers initialization applies V0-V12. The full backend baseline remains Pass 1 629/0/0/1; not rerun during Pass 3. No Flutter source/test changed this pass, so no mobile suite/analyze/build was repeated.

Production files: `ChatService.java`, `NotificationService.java`, `CalendarRepository.java`, `FundService.java`, `ExpenseService.java`. Tests: new `ReadPerformanceIntegrationTest.java`; one Chat projection regression added to `ChatServiceIntegrationTest.java`. Agent handoff updated. No staging, commit, push, merge, or protected-file/stash operation.
