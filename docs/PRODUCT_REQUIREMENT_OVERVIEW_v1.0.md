# PRODUCT REQUIREMENT OVERVIEW v1.0

## 1. Product Overview

**Product name:** weDO

weDO là nền tảng mobile dành cho các nhóm nhỏ, kết hợp:
- Giao tiếp xã hội riêng tư
- Quản lý nhóm
- Hoạt động chung
- Lịch chung
- Task / Poll / Discussion
- Chi phí chung và công nợ
- Quỹ nhóm
- Album / Moments / Location trong các phase sau

Nguyên tắc cốt lõi:

> A Group represents a purpose/context, not just a set of people.

Cùng một nhóm người có thể có nhiều Group khác nhau như Best Friends, Đà Nẵng 2026, Cầu lông thứ 7 hoặc Nhóm học Spring Boot.

## 2. Target Users

Đối tượng chính:
- Người trẻ 18–30
- Nhóm bạn
- Gia đình
- Roommates
- Study groups
- Sports groups
- Travel groups
- Small clubs

## 3. Product Positioning

weDO cân bằng giữa:
- Private social space
- Lightweight group management

UI định hướng: modern, social/lifestyle, clean, rounded, spacious, friendly; không mang cảm giác Jira/accounting/enterprise.

## 4. Main Navigation

```text
Home | Groups | Chat | Calendar | Profile
```

## 5. Home

Hybrid dashboard:
- Recent Groups
- Upcoming Activities
- Finance Summary
- Actions Required
- Recent Updates

## 6. Group Space

```text
Overview | Chat | Activities | Finance | Members
```

## 7. Core Modules

### Authentication & Profile
MVP:
- Email + Password
- Email verification
- Unique username
- Display name
- Avatar
- Bio
- Privacy settings
- Personal QR

Future:
- OTP
- Google
- Apple

### Friend & Social
- Search user
- Friend request
- Accept / Decline / Cancel
- Unfriend
- Block / Unblock
- Stranger message request
- DM privacy

### Group Management
Roles:
- OWNER
- ADMIN
- MEMBER

Features:
- Create group
- Group settings
- Invite members
- Invite link / code / QR
- Join request
- Kick
- Ban
- Archive
- Restore
- Delete
- Transfer ownership

Max active members: 100.

### Chat
- Group chat
- Direct message
- Message request
- Text
- Images
- Reply
- Edit
- Unsend
- Delete for me
- Reaction
- Read receipt
- Typing
- Presence
- Pin
- Search

### Activity
Fields:
- Title
- Description
- Start/end time
- Location
- Capacity
- RSVP

Lifecycle:
```text
PLANNING → CONFIRMED → IN_PROGRESS → COMPLETED
```
Alternative terminal state: CANCELLED.

RSVP:
- NO_RESPONSE
- GOING
- MAYBE
- NOT_GOING
- WAITLIST

### Poll
- Single/multiple choice
- Deadline
- Close early
- Public/anonymous
- Vote change while open
- Optional member-added option

### Task
- One/multiple assignees
- Claim unassigned task
- TODO
- IN_PROGRESS
- DONE

### Discussion
- Comments
- One-level replies
- Edit/delete own comment
- Owner/Admin moderation

### Calendar
Global aggregate of Activities.

Views:
- Month
- Agenda

Filters:
- All
- Going
- Maybe
- No Response
- Waitlist
- Group

### Expense
- Group required
- Optional Activity
- One payer
- Participants
- Equal split
- Custom amount
- Receipt
- Expense history

### Debt & Settlement
Debt is derived, not stored as authoritative mutable state.

Settlement:
- Full / Partial
- Two-sided confirmation
- PENDING / COMPLETED / REJECTED / CANCELLED

### Group Fund
MVP:
- 0 or 1 fund/group
- Fund Manager
- Collection
- Obligation
- Contribution
- Fund Expense
- Reimbursement
- Ledger
- Reversal

Balance is derived from ledger.

### Notifications
Categories:
- Social
- Group
- Chat
- Activity
- Poll
- Task
- Finance
- Fund

Channels:
- In-app
- Push

### Search
Global Search:
- Users
- Joined Groups
- Activities
- Conversations

## 8. Product Principles

1. Backend is source of truth.
2. Important financial data is auditable.
3. Important group actions preserve history.
4. Realtime improves experience but does not replace persistence.
5. Permissions are enforced server-side.
6. UI remains simple even when business rules are complex.

## 9. MVP Scope

MVP:
- Auth/Profile
- Friends
- Groups
- Group Chat
- Activities
- Poll/Task/Discussion
- Calendar
- Expense/Debt/Settlement
- Group Fund
- Notifications
- Search

Future:
- Calls
- Advanced Moments/Albums
- Rich location features
- AI features
- Banking integration

**PRODUCT REQUIREMENT OVERVIEW v1.0 — BASELINE ESTABLISHED**
