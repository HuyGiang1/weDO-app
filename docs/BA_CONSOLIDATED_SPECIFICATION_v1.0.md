# BA CONSOLIDATED SPECIFICATION v1.0

## 1. Actors
- Guest
- User
- Group Member
- Group Admin
- Group Owner
- Fund Manager

## 2. Authentication & Profile
- User ID immutable.
- Username unique.
- Display name non-unique.
- Email unique.
- Phone/avatar/bio optional.
- Personal QR supported.
- Search by username ON by default.
- Search by QR ON by default.
- Search by email/phone OFF by default.

## 3. Friend & Block Rules
- Sender may cancel pending friend request.
- Cancel → resend immediately.
- Receiver decline → sender cooldown 24h.
- Unfriend → new request immediately possible.
- Block removes friendship and direct interaction.
- Block does not remove shared group membership or financial history.
- Unblock does not restore friendship and has no cooldown.

## 4. Stranger Message Request
- Non-friend DM creates Message Request.
- Max 3 TEXT messages before accept.
- No image/file before accept.
- Receiver actions: Accept / Decline / Block.
- Accept: opens direct conversation (does not create friendship).
- Decline: retains history, starts sender 72h cooldown.
- Block: cancels pending message request (terminal state CANCELLED, no 72h cooldown; does not revive on unblock).

DM policy:
- Everyone (DEFAULT): Friends DM directly; non-friends must go through Message Request flow (max 3 TEXT messages before accept).
- Mutual groups: Only non-friends with mutual groups can create Message Request.
- Friends only: Non-friends cannot create Message Request.

Friend request policy:
- Everyone (DEFAULT): Any valid user can send a friend request.
- Mutual groups: Only users sharing mutual groups can send a friend request.
- None: Do not accept friend requests.

Presence privacy:
- Show online status: ON by default (TRUE).
- Show last seen: ON by default (TRUE).
- Users may update privacy settings at any time.

## 5. Group Roles

### OWNER
- Highest authority.
- Manage Admin/Member.
- Transfer ownership.
- Archive/restore/delete.
- Kick/Ban Admin or Member.
- Manage settings.

### ADMIN
- Manage Member.
- Moderate group.
- Cannot manage Owner.

### MEMBER
- Normal participation.
- May edit group name/avatar only if setting allows.

## 6. Group Lifecycle
```text
ACTIVE
ARCHIVED
DELETED
```

ARCHIVED:
- Read-only.
- History preserved.
- Owner may restore.

DELETED:
- Owner only.
- Strong confirmation.

## 7. Membership
- Max 100 ACTIVE members.
- Membership history preserved.
- Rejoin creates new membership row.
- One active membership/user/group.
- Member/Admin may leave.
- Owner cannot leave while others remain.
- Owner must transfer ownership first.
- Old Owner becomes Admin after transfer.

## 8. Invite / Join / Ban
Invitation:
- Direct: sent to specific user; bypasses join approval; no expiry; authorized Owner/Admin may cancel PENDING invitation; receiver may accept or decline; ACCEPTED / DECLINED / CANCELLED are terminal states.
- Link / Code / QR: shareable token with optional expiry, usage limit, and revoke capability.

Join policy:
- AUTO_JOIN: join via valid link/code enters group directly (if capacity < 100 and not banned).
- APPROVAL_REQUIRED: creates PENDING join request for Owner/Admin review.

Join request lifecycle:
- PENDING → APPROVED (creates active membership) / REJECTED.
- Requester may CANCEL own PENDING join request (terminal state, does not create membership).
- Eligible user may submit new request later if not banned or already active member.

Banned user:
- Cannot join.
- Cannot request join.

## 9. Group Chat
One group chat/group in MVP.

History:
- FULL_HISTORY
- FROM_JOIN_TIME
Default: FULL_HISTORY.

Message:
- Text
- Up to 10 images
- Optional caption

Edit <= 15 minutes.
Unsend <= 15 minutes.
Delete-for-me anytime.

Reply:
- One message
- No thread
- Reply to unsent shows withdrawn placeholder.

Reaction:
- Max 1 emoji/user/message
- Switch replaces
- Same toggles off

Read receipt:
- Seen by X
- Excludes sender

Pin:
- Owner/Admin
- Member if setting allows
- Max 20/group
- Unsent pin auto-unpins

## 10. Presence & Typing
Presence:
- Online
- Offline
- Last seen

Typing:
- Realtime only
- Ephemeral

## 11. Activity
Lifecycle:
```text
PLANNING → CONFIRMED → IN_PROGRESS → COMPLETED
```
or CANCELLED.

Rules:
- Confirm manual.
- IN_PROGRESS auto when now >= start.
- COMPLETED auto when now >= end, or manual if no end.
- Confirmed time/location edit → log + notify GOING/MAYBE.
- Capacity decrease rejected if new capacity < current GOING count.
- Capacity increase auto-promotes waitlisted users FIFO up to new capacity (or all if unlimited).
- Completed/cancelled lock core edits.

## 12. RSVP
States:
- NO_RESPONSE
- GOING
- MAYBE
- NOT_GOING
- WAITLIST

Rules:
- Self only.
- Full capacity + GOING request → WAITLIST.
- Promotion FIFO.
- Vacancy auto-promotes first waitlisted user.
- Late GOING while IN_PROGRESS allowed.
- Completed/cancelled → locked.

## 13. Poll
- Single/multiple.
- Optional member-added options.
- Deadline / close early.
- Result immediate/after close.
- Vote change while open.
- Max selections optional.
- PUBLIC/ANONYMOUS.
- Visibility locked after first vote.
- Option with votes cannot be materially changed/deleted.
- Disabled option retains votes.

## 14. Task
- 1+ assignees.
- Unassigned may be claimed.
- Shared status for multi-assignee task.
- TODO / IN_PROGRESS / DONE.
- Assignee + Owner/Admin + Activity Creator may update.
- Activity completion does not auto-complete task.
- No subtasks MVP.

## 15. Discussion
- Comment + one-level reply.
- Own edit/delete.
- Owner/Admin moderation logged.
- Completed Activity keeps discussion.
- Cancelled Activity may lock new comments.

## 16. Calendar
Global aggregate from Activity.

Includes:
- Planning
- Confirmed
- In-progress
- Completed
- Cancelled

Reminder:
- Default proposal 1 day + 1 hour.
- Customizable.
- Disable.
- Time changes reschedule.

Conflict = warning only.
Timezone must be handled consistently.

## 17. Expense
Every expense:
- belongs to Group
- optional same-group Activity
- one payer
- date
- total
- participants
- split method
- note/receipt optional

Split:
- EQUAL
- CUSTOM_AMOUNT

Custom sum must equal total.
Payer may participate.
No self-debt.
Multiple payers = separate expenses.

## 18. Debt
No authoritative `debts` table.

Current debt derived from:
- Expense
- ExpenseShare
- COMPLETED Settlement

Former-member debt persists.
Block does not break finance.

## 19. Settlement
- Full / Partial
- amount > 0
- amount <= current debt

Two-sided confirmation:
A. Debtor says paid → Creditor confirms.
B. Creditor says received → Debtor confirms.

Statuses:
- PENDING
- COMPLETED
- REJECTED
- CANCELLED

Only COMPLETED affects debt.

## 20. Group Fund
- 0 or 1 fund/group MVP.
- Owner manages.
- Owner may grant Fund Manager to Admin.
- Others view/submit.

Fund:
- ACTIVE
- CLOSED

Balance:
- derived
- never direct-edit

Formula concept:
Confirmed Contributions - Fund Expenses - Completed Reimbursements ± Adjustments/Reversals.

## 21. Collection & Contribution
Collection:
- title
- description
- deadline
- selected members
- amount/member may differ

Contribution:
- PENDING
- CONFIRMED
- REJECTED
- CANCELLED

Obligation derived:
- UNPAID
- PARTIAL
- PAID
- OVERDUE

Rules:
- Only CONFIRMED increases balance.
- Member may cancel pending.
- No overpayment.
- Pending + confirmed count toward remaining amount.
- Late payment allowed.

## 22. Fund Expense & Reimbursement
Fund Expense:
- Owner/Fund Manager.
- Immediate balance deduction.
- No second approval.
- No negative balance.

Reimbursement:
- amount
- reason
- proof
- manager approve/reject
- approval only if enough balance
- otherwise stays pending
- Fund↔Member reimbursement is not debt

## 23. Fund Ledger
Transaction types:
- contribution
- fund expense
- reimbursement
- adjustment
- reversal

No hard-delete financial transaction.
Correction via reversal/corrected entry.

## 24. Notifications
Channels:
- In-app
- Push

Categories:
- Social
- Group
- Chat
- Activity
- Poll
- Task
- Finance
- Fund

Priority:
- H
- N
- L

Mute:
- 1h
- 8h
- 1d
- until unmuted

Critical business notifications are not suppressed by chat mute.

## 25. Home
- Recent Groups
- Upcoming Activities
- Finance Summary
- Actions Required
- Recent Updates

## 26. Navigation
```text
Home | Groups | Chat | Calendar | Profile
```

Group Space:
```text
Overview | Chat | Activities | Finance | Members
```

## 27. Acceptance Principles
- Permissions enforced server-side.
- Invalid state transitions rejected.
- Financial history auditable.
- Privacy/block affect API, not only UI.
- Realtime does not replace persistent truth.
- Critical flows testable end-to-end.

**BA CONSOLIDATED SPECIFICATION v1.0 — BASELINE ESTABLISHED**
