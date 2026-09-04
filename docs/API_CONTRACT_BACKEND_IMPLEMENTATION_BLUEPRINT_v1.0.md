# API CONTRACT & BACKEND IMPLEMENTATION BLUEPRINT v1.0

**Project:** Ứng dụng kết nối, giao tiếp, chia sẻ và quản lý hoạt động nhóm  
**Document type:** Backend API Contract + Spring Boot Implementation Blueprint  
**Version:** 1.0  
**Status:** BASELINE  
**Mobile:** Flutter + Dart  
**Backend:** Spring Boot  
**Database:** PostgreSQL  
**ORM:** Spring Data JPA / Hibernate  
**Migration:** Flyway  
**Realtime:** WebSocket + Redis  
**Media:** S3-compatible storage / Cloudinary  
**Push:** Firebase Cloud Messaging  
**API documentation:** OpenAPI / Swagger  
**API style:** REST + WebSocket  
**Authentication:** Email + Password + JWT Access Token + Refresh Token

---

## 1. Document Purpose

Tài liệu này là baseline kỹ thuật chính thức cho backend và API của ứng dụng. Nó được xây dựng dựa trên Product Requirement Overview, BA Consolidated Specification, Screen Map / UX Flow và ERD / Database Design đã chốt.

Tài liệu trả lời các câu hỏi: Flutter gọi endpoint nào; request/response DTO gồm gì; validation ở đâu; quyền nào áp dụng; Service/Repository nào chịu trách nhiệm; API nào cần `@Transactional`; API nào cần locking; khi nào dùng REST/WebSocket/Redis; error code nào client phải xử lý; domain event nào được phát; màn hình nào sử dụng API nào; và Spring Boot nên được triển khai theo blueprint nào.

Chuỗi tài liệu chuẩn:

```text
PRODUCT REQUIREMENT OVERVIEW
        ↓
BA CONSOLIDATED SPECIFICATION
        ↓
SCREEN MAP / UX FLOW
        ↓
ERD & DATABASE DESIGN
        ↓
API CONTRACT & BACKEND IMPLEMENTATION BLUEPRINT
        ↓
SYSTEM ARCHITECTURE
        ↓
DEVELOPMENT PLAN
        ↓
IMPLEMENTATION
```

---

## 2. System Context

```text
Flutter Mobile App
        │
        ├── HTTPS / REST ───────────────► Spring Boot ─► Spring Data JPA ─► PostgreSQL
        │
        ├── WebSocket ──────────────────► Spring Boot ─► Redis
        │
        ├── Media upload ───────────────► S3-compatible storage / Cloudinary
        │
        └── Push notification ◄───────── FCM ◄───────── Spring Boot
```

### Responsibilities

- **Flutter:** UI, navigation, client state, form state, display formatting, local cache, REST calls, WebSocket connection, optimistic UI where safe.
- **Spring Boot:** authentication, authorization, business validation, state transitions, transaction management, financial calculation, group permissions, aggregation, notification generation, realtime orchestration and data consistency.
- **PostgreSQL:** persistent source of truth.
- **Redis:** presence, typing, short-lived rate limits, WebSocket-related ephemeral state and selected caches.
- **Object storage:** avatars, chat images, receipts and payment proofs.
- **FCM:** push notifications.

---

## 3. API Conventions

### 3.1 Base URL and versioning

```text
/api/v1
```

Breaking changes require a new version such as `/api/v2`; existing contracts must not be silently broken.

### 3.2 Resource naming

Use nouns/resources:

```http
GET  /api/v1/groups
POST /api/v1/groups
GET  /api/v1/groups/{groupId}
```

Do not use `/getGroups`, `/createGroup`, `/deleteExpense`.

### 3.3 HTTP methods

- `GET`: read/query.
- `POST`: create a resource or execute an explicit business action.
- `PATCH`: partial update.
- `PUT`: idempotently replace/update one current state, e.g. RSVP or reaction.
- `DELETE`: remove/revoke/hide when that semantic is appropriate.

### 3.4 Explicit business actions

Protected state machines are changed by action endpoints instead of letting the client set arbitrary statuses.

```http
POST /api/v1/groups/{groupId}/archive
POST /api/v1/groups/{groupId}/restore
POST /api/v1/activities/{activityId}/confirm
POST /api/v1/activities/{activityId}/cancel
POST /api/v1/settlements/{settlementId}/confirm
POST /api/v1/settlements/{settlementId}/reject
```

### 3.5 HTTP status convention

- `200 OK`: successful query/update/action.
- `201 Created`: new resource created.
- `204 No Content`: successful action without response body.
- `400 Bad Request`: malformed request or input validation.
- `401 Unauthorized`: missing/invalid authentication.
- `403 Forbidden`: authenticated but not permitted.
- `404 Not Found`: resource does not exist or is not visible.
- `409 Conflict`: business-state conflict.
- `429 Too Many Requests`: rate limited.
- `500 Internal Server Error`: unexpected backend failure.

### 3.6 Standard error format

```json
{
  "timestamp": "2026-08-22T15:00:00Z",
  "status": 409,
  "code": "GROUP_MEMBER_LIMIT_REACHED",
  "message": "The group has reached its maximum capacity.",
  "path": "/api/v1/groups/123/join"
}
```

Validation error:

```json
{
  "timestamp": "2026-08-22T15:00:00Z",
  "status": 400,
  "code": "VALIDATION_FAILED",
  "message": "Request validation failed.",
  "errors": {
    "name": "must not be blank",
    "amount": "must be greater than zero"
  }
}
```

Spring Boot uses a central `@RestControllerAdvice`. Flutter branches primarily on `code`, not by parsing human-readable messages.

### 3.7 DTO rule

Never expose JPA Entity directly through the API.

```text
Entity ↔ Mapper ↔ Request/Response DTO
```

Reasons: security, API stability, hiding internal fields, avoiding lazy-loading serialization problems and separating persistence from contract.

### 3.8 Validation strategy

**Input validation** uses Bean Validation such as `@NotBlank`, `@Email`, `@Size`, `@Positive`, `@Valid`.

**Business validation** belongs in Service, for example group capacity 100, banned member, completed activity, expense split mismatch, settlement larger than debt, contribution larger than remaining obligation and insufficient fund balance.

### 3.9 Date/time

API uses ISO-8601. Activity also stores an IANA timezone such as `Asia/Ho_Chi_Minh`.

```json
{
  "startAt": "2026-09-01T19:00:00+07:00",
  "timezone": "Asia/Ho_Chi_Minh"
}
```

Java uses `Instant`/`OffsetDateTime`; PostgreSQL uses `TIMESTAMPTZ`.

### 3.10 Money

Java uses `BigDecimal`; PostgreSQL uses `NUMERIC(19,2)`. Never use `float`/`double` as the authoritative financial type. Formatting such as `600.000đ` is a Flutter responsibility.

### 3.11 Pagination

Normal lists use page-based pagination:

```http
GET /api/v1/groups/{groupId}/expenses?page=0&size=20
```

```json
{
  "items": [],
  "page": 0,
  "size": 20,
  "totalElements": 53,
  "totalPages": 3,
  "hasNext": true
}
```

Chat history uses cursor/sequence pagination:

```http
GET /api/v1/conversations/{conversationId}/messages?beforeSequence=1250&limit=30
```

### 3.12 Transaction policy

Use `@Transactional` when a single business command modifies multiple related records. Critical transaction boundaries include registration, group creation/join/ban/ownership transfer, message sequence allocation, RSVP + waitlist promotion, expense + shares, settlement confirmation, collection/contribution, fund expense and reimbursement approval.

### 3.13 Concurrency and locking

Use database locking for race-sensitive operations. Spring Data JPA may use `@Lock(LockModeType.PESSIMISTIC_WRITE)` where appropriate. Critical cases: final activity slot, FIFO waitlist promotion, message sequence allocation, contribution remaining amount, fund spending, reimbursement approval and settlement confirmation when debt must be revalidated.

### 3.14 Cross-resource integrity

Every ID supplied by Flutter must be validated in its business context. Examples: Expense from Group A cannot reference Activity from Group B; Task assignees must belong to the activity/group context; Collection obligations cannot target unrelated users.

### 3.15 Soft-delete/history principle

Do not casually hard-delete membership, message, activity, expense, settlement or fund history. Status and visibility rules preserve auditability.

---

## 4. Authentication & Security Model

### 4.1 Authentication

MVP uses Email + Password with Spring Security, JWT access tokens, server-revocable refresh tokens and `PasswordEncoder`.

The current user identity is always derived from authentication context; the client must never be trusted to submit `currentUserId` for authorization.

### 4.2 Access token

Short-lived, recommended 15-60 minutes. Contains only stable/minimal identity claims such as user ID and expiration. Do not encode volatile group roles into JWT.

### 4.3 Refresh token

Recommended 7-30 days with refresh-token rotation. Using refresh token A invalidates A and produces new access + refresh credentials.

### 4.4 Authentication vs authorization

Authentication answers **who the user is**. Authorization answers **whether that authenticated user may perform an action** based on current membership, role, ownership, privacy, block and domain state.

---

## 5. Authentication API

### AUTH-01 Register

**Endpoint:** `POST /api/v1/auth/register`  
**Authentication:** Public  
**Request DTO:** `RegisterRequest`

```json
{
  "email": "user@example.com",
  "password": "password"
}
```

**Business flow:** normalize email; ensure unique email; validate password; create User; hash password; create UserCredential; create default privacy settings; create default notification settings; create email verification token; publish verification event.

**Transaction:** YES  
**Repositories:** UserRepository, UserCredentialRepository, UserPrivacySettingsRepository, UserNotificationSettingsRepository, AuthTokenRepository.  
**Response:** user ID, email, verification state and `nextStep=VERIFY_EMAIL`.  
**Errors:** `EMAIL_ALREADY_EXISTS`, `INVALID_EMAIL`, `INVALID_PASSWORD`.  
**Events:** `USER_REGISTERED`, `EMAIL_VERIFICATION_REQUESTED`.

### AUTH-02 Verify Email

**Endpoint:** `POST /api/v1/auth/verify-email`

```json
{
  "userId": "...",
  "code": "123456"
}
```

Validate active token, expiration and attempts; compare hashed code; consume token; set `email_verified_at`. Errors: `VERIFICATION_CODE_INVALID`, `VERIFICATION_CODE_EXPIRED`, `VERIFICATION_ATTEMPTS_EXCEEDED`, `EMAIL_ALREADY_VERIFIED`.

### AUTH-03 Resend Verification

**Endpoint:** `POST /api/v1/auth/resend-verification`  
Uses Redis rate limiting to prevent abuse.

### AUTH-04 Complete Initial Profile

**Endpoint:** `POST /api/v1/auth/complete-profile`

```json
{
  "username": "huygiang",
  "displayName": "Huy Giang",
  "bio": null,
  "avatarStorageKey": null
}
```

Username must be unique. Display name is required. Avatar and bio are optional.

### AUTH-05 Username Availability

**Endpoint:** `GET /api/v1/auth/usernames/{username}/availability`

### AUTH-06 Login

**Endpoint:** `POST /api/v1/auth/login`

```json
{
  "email": "user@example.com",
  "password": "..."
}
```

Validate credentials/account status/email verification, then return access token, refresh token, expiration and basic user information. Errors: `AUTH_INVALID_CREDENTIALS`, `EMAIL_NOT_VERIFIED`, `ACCOUNT_SUSPENDED`, `ACCOUNT_DEACTIVATED`.

### AUTH-07 Refresh Token

**Endpoint:** `POST /api/v1/auth/refresh`  
Uses refresh-token rotation.

### AUTH-08 Logout

**Endpoint:** `POST /api/v1/auth/logout`  
Revokes refresh session/token.

### AUTH-09 Forgot Password

**Endpoint:** `POST /api/v1/auth/forgot-password`  
Response must remain neutral whether an email exists, preventing account enumeration.

### AUTH-10 Reset Password

**Endpoint:** `POST /api/v1/auth/reset-password`  
Validate reset token, update hashed password and invalidate existing refresh sessions.

---

## 6. Profile & User API

### USER-01 Get My Profile

`GET /api/v1/me`

Returns private profile fields appropriate to the current user: ID, username, email, phone, displayName, avatarUrl, bio, account status and verification state.

### USER-02 Update Profile

`PATCH /api/v1/me/profile`

Editable: display name, bio, avatar reference and other safe profile fields. Email, username and account status are not changed through this endpoint.

### USER-03 Change Username

`PATCH /api/v1/me/username`  
Normalize, validate format and enforce uniqueness.

### USER-04 Get Privacy Settings

`GET /api/v1/me/privacy`

Returns current privacy settings with defaults applied upon registration:
- `discoverByUsername`: boolean (default `true`)
- `discoverByQr`: boolean (default `true`)
- `discoverByEmail`: boolean (default `false`)
- `discoverByPhone`: boolean (default `false`)
- `dmPolicy`: enum `EVERYONE` (default), `MUTUAL_GROUPS`, `FRIENDS_ONLY`
- `friendRequestPolicy`: enum `EVERYONE` (default), `MUTUAL_GROUPS`, `NONE`
- `showOnlineStatus`: boolean (default `true`)
- `showLastSeen`: boolean (default `true`)

Semantics of `dmPolicy`:
- `EVERYONE`: Friends DM directly; non-friends must use Message Request (max 3 text messages).
- `MUTUAL_GROUPS`: Only non-friends sharing a group can send Message Request.
- `FRIENDS_ONLY`: Non-friends cannot send Message Request.

Semantics of `friendRequestPolicy`:
- `EVERYONE`: Any valid user can send friend requests.
- `MUTUAL_GROUPS`: Only users sharing a mutual group can send friend requests.
- `NONE`: Friend requests are blocked.

### USER-05 Update Privacy Settings

`PATCH /api/v1/me/privacy`

Supports partial updates to any of the privacy fields listed above.

### USER-06 Change Password

`POST /api/v1/me/change-password`  
Verify current password, hash new password and optionally revoke other sessions.

### USER-07 Personal QR

`GET /api/v1/me/qr`  
Returns a stable application/user deep-link value; Flutter may generate the QR bitmap locally. No QR-image table is required.

### USER-08 Public Profile

`GET /api/v1/users/{userId}`  
Returns privacy-filtered public fields, relationship status, mutual group count, messaging/friend-request capability and presence fields if allowed.

### USER-09 Search Users

`GET /api/v1/users/search?q={query}&page=0&size=20`  
Search respects `discover_by_*` privacy settings.

---

## 7. Friend / Social / Block API

### SOCIAL-01 Send Friend Request

`POST /api/v1/users/{userId}/friend-requests`

Validate: not self, target exists, no block in either direction, target privacy allows request, not already friends, no pending request and declined cooldown has expired. Create PENDING request and publish notification event.

Errors: `CANNOT_FRIEND_SELF`, `USER_BLOCKED`, `ALREADY_FRIENDS`, `FRIEND_REQUEST_ALREADY_PENDING`, `FRIEND_REQUEST_COOLDOWN_ACTIVE`, `FRIEND_REQUEST_NOT_ALLOWED`.

### SOCIAL-02 Received Friend Requests

`GET /api/v1/me/friend-requests?direction=received`

### SOCIAL-03 Sent Friend Requests

`GET /api/v1/me/friend-requests?direction=sent`

### SOCIAL-04 Accept Friend Request

`POST /api/v1/friend-requests/{requestId}/accept`  
Transaction: request PENDING -> ACCEPTED and create ACTIVE friendship using canonical pair IDs.

### SOCIAL-05 Decline Friend Request

`POST /api/v1/friend-requests/{requestId}/decline`  
PENDING -> DECLINED; sender receives a 24-hour resend cooldown.

### SOCIAL-06 Cancel Friend Request

`POST /api/v1/friend-requests/{requestId}/cancel`  
Sender only. PENDING -> CANCELLED. No cooldown.

### SOCIAL-07 Friends List

`GET /api/v1/me/friends?page=0&size=30`

### SOCIAL-08 Unfriend

`DELETE /api/v1/friends/{userId}`  
Friendship becomes ENDED; DM history remains; immediate re-request is allowed.

### SOCIAL-09 Block User

`POST /api/v1/users/{userId}/block`

Transaction: create directional block, end friendship, cancel pending friend request, cancel pending message request, prevent future direct social interaction, but preserve shared-group membership/business history and required financial/activity visibility.

### SOCIAL-10 Unblock User

`DELETE /api/v1/users/{userId}/block`  
Does not restore friendship and creates no cooldown.

### SOCIAL-11 Blocked Users

`GET /api/v1/me/blocked-users`

---

## 8. Group API

### GROUP-01 Create Group

`POST /api/v1/groups`

```json
{
  "name": "Đà Nẵng 2026",
  "description": "Chuyến đi hè",
  "avatarStorageKey": null
}
```

**Authorization:** any ACTIVE authenticated user.  
**Transaction:** YES.

Business flow:
1. Validate current user ACTIVE.
2. Create Group ACTIVE with owner_user_id=current user.
3. Create default GroupSettings.
4. Create ACTIVE GroupMembership role OWNER.
5. Create one GROUP Conversation.
6. Create conversation sequence state.
7. Write GROUP_CREATED activity log.
8. Commit all operations.

### GROUP-02 My Groups

`GET /api/v1/groups`  
Filters: ACTIVE / ARCHIVED.

### GROUP-03 Recent Groups

`GET /api/v1/groups/recent`  
Used by Home and Groups screens.

### GROUP-04 Group Detail

`GET /api/v1/groups/{groupId}`

### GROUP-05 Group Overview

`GET /api/v1/groups/{groupId}/overview`

Aggregates group identity, current user's role/permissions, upcoming activities, required actions, poll/task previews, finance/fund summary and recent updates.

### GROUP-06 Update Group

`PATCH /api/v1/groups/{groupId}`

Owner/Admin can edit description. Name/avatar are Owner/Admin by default and may be editable by Members only when corresponding group settings allow.

### GROUP-07 Group Settings

`GET /api/v1/groups/{groupId}/settings`  
`PATCH /api/v1/groups/{groupId}/settings`

Settings include member name/avatar editing, member Activity creation, member message pinning, join policy and chat history policy.

### GROUP-08 Members

`GET /api/v1/groups/{groupId}/members`  
`GET /api/v1/groups/{groupId}/members/{userId}`

### GROUP-09 Promote Admin

`POST /api/v1/groups/{groupId}/members/{userId}/promote-admin`  
Owner only.

### GROUP-10 Demote Admin

`POST /api/v1/groups/{groupId}/members/{userId}/demote-admin`  
Owner only.

### GROUP-11 Kick Member

`POST /api/v1/groups/{groupId}/members/{userId}/kick`

Owner can kick Admin or Member. Admin can kick Member only. Kicked user may rejoin later. Membership history is retained.

### GROUP-12 Ban Member

`POST /api/v1/groups/{groupId}/members/{userId}/ban`

Same role restrictions as Kick. Creates active ban and prevents join/request until unbanned.

### GROUP-13 Leave Group

`POST /api/v1/groups/{groupId}/leave`

Member/Admin can leave. Admin loses role. Owner cannot leave while another active member exists and must transfer ownership first.

### GROUP-14 Transfer Ownership

`POST /api/v1/groups/{groupId}/transfer-ownership`

```json
{
  "newOwnerUserId": "..."
}
```

Transaction: lock group, ensure target is active member/admin, new owner -> OWNER, old owner -> ADMIN, update owner_user_id and write activity log.

### GROUP-15 Direct Invitation

`POST /api/v1/groups/{groupId}/invitations`

Direct invite acceptance bypasses join approval policy. Banned users cannot be invited successfully.

### GROUP-16 My Group Invitations

`GET /api/v1/me/group-invitations`

### GROUP-17 Accept/Decline Invitation

`POST /api/v1/group-invitations/{id}/accept`  
`POST /api/v1/group-invitations/{id}/decline`

Acceptance transaction checks group ACTIVE, invite valid, user not banned, no ACTIVE membership and active member count below 100.

### GROUP-18 Create Invite Link/Code/QR

`POST /api/v1/groups/{groupId}/invite-links`

Supports expiration and usage limit. QR is generated from invite code/deep link; no QR-image table is needed.

### GROUP-19 Invite Links

`GET /api/v1/groups/{groupId}/invite-links`  
`POST /api/v1/group-invite-links/{id}/revoke`

### GROUP-20 Resolve/Join by Invite Code

`GET /api/v1/group-invites/{inviteCode}`  
`POST /api/v1/group-invites/{inviteCode}/join`

`AUTO_JOIN` creates active membership if valid; `APPROVAL_REQUIRED` creates a pending join request. Invite-link usage count increments only when active membership is actually created.

### GROUP-21 Join Requests

`GET /api/v1/groups/{groupId}/join-requests`  
`POST /api/v1/group-join-requests/{requestId}/approve`  
`POST /api/v1/group-join-requests/{requestId}/reject`

Approval is transactional and rechecks group capacity, ban and membership state.

### GROUP-22 Bans

`GET /api/v1/groups/{groupId}/bans`  
`DELETE /api/v1/groups/{groupId}/bans/{userId}`

Unban does not automatically rejoin the user.

### GROUP-23 Archive/Restore/Delete

`POST /api/v1/groups/{groupId}/archive`  
`POST /api/v1/groups/{groupId}/restore`  
`DELETE /api/v1/groups/{groupId}`

Archive preserves history/memberships but makes the group read-only. Restore is Owner only. Delete is soft/business delete and requires strong confirmation at UI level.

### GROUP-24 Activity Log

`GET /api/v1/groups/{groupId}/activity-log?page=0&size=30`

---

## 9. Chat & Direct Message API

### CHAT-01 Open/Create Direct Conversation

`POST /api/v1/direct-conversations`

```json
{
  "userId": "..."
}
```

Backend reuses the canonical pair conversation and determines access status `OPEN`, `REQUEST_PENDING` or `REQUEST_DECLINED` based on friendship, privacy, block and existing Message Request state.

### CHAT-02 Conversation List

`GET /api/v1/conversations`

Returns conversation identity, type, last message preview/time, unread count and appropriate presence indicator.

### CHAT-03 Message Requests

`GET /api/v1/message-requests`

### CHAT-04 Accept/Decline Message Request

`POST /api/v1/message-requests/{id}/accept`  
`POST /api/v1/message-requests/{id}/decline`

Rules: before acceptance sender may send max 3 TEXT messages and no images/files; decline keeps conversation/request history and starts 72-hour cooldown; Accept opens direct conversation but does not create friendship.

### CHAT-05 Message History

`GET /api/v1/conversations/{conversationId}/messages?beforeSequence={seq}&limit=30`

Must enforce group history policy, join time, delete-for-me rows, UNSENT representation, block/direct access and active/historical membership rules.

### CHAT-06 Send Message

Primary realtime command is WebSocket `SEND_MESSAGE`.

```json
{
  "clientMessageId": "client-generated-id",
  "conversationId": "...",
  "type": "TEXT",
  "content": "Tối nay sân cũ nhé",
  "replyToMessageId": null,
  "attachments": []
}
```

Transaction: authorize conversation; validate Message Request restrictions; validate <=10 images; allocate monotonic conversation sequence; persist message; update conversation last_message; commit; publish/broadcast `MESSAGE_CREATED`. `clientMessageId` supports retry/idempotency.

### CHAT-07 Edit Message

`PATCH /api/v1/messages/{messageId}`  
Sender only, ACTIVE message, <=15 minutes. Preserve edit history and return/broadcast Edited state.

### CHAT-08 Unsend Message

`POST /api/v1/messages/{messageId}/unsend`  
Sender only, <=15 minutes. Message becomes UNSENT, normal content is no longer exposed, and any active pin is removed automatically.

### CHAT-09 Delete For Me

`DELETE /api/v1/messages/{messageId}/me`  
Creates message_hidden_users visibility row; does not affect other users.

### CHAT-10 Reaction

`PUT /api/v1/messages/{messageId}/reaction`

```json
{
  "emoji": "👍"
}
```

No reaction -> create. Different emoji -> replace. Same emoji -> toggle off. Maximum one emoji/user/message is enforced by database key + service behavior.

### CHAT-11 Read State

`PUT /api/v1/conversations/{conversationId}/read-state`

```json
{
  "lastReadSequence": 1234
}
```

Read state stores last-read sequence instead of one seen row per message.

### CHAT-12 Pin Message

`POST /api/v1/messages/{messageId}/pin`  
`DELETE /api/v1/messages/{messageId}/pin`  
`GET /api/v1/conversations/{conversationId}/pins`

Owner/Admin or Member if group setting permits. Max 20 active pins/group conversation.

### CHAT-13 Search Messages

`GET /api/v1/conversations/{conversationId}/messages/search?q=&senderId=&from=&to=`

Search respects all history visibility, hidden and UNSENT rules.

---

## 10. WebSocket Contract

Suggested endpoint:

```text
/ws
```

Connection must be authenticated.

### Client -> Server commands

```text
SEND_MESSAGE
EDIT_MESSAGE
UNSEND_MESSAGE
SET_REACTION
MARK_READ
TYPING_START
TYPING_STOP
```

### Server -> Client events

```text
MESSAGE_CREATED
MESSAGE_EDITED
MESSAGE_UNSENT
REACTION_UPDATED
MESSAGE_READ
MESSAGE_PINNED
MESSAGE_UNPINNED
USER_TYPING
USER_STOPPED_TYPING
PRESENCE_CHANGED
```

### Typing

Ephemeral; Redis key such as `typing:{conversationId}:{userId}` with short TTL (about 5 seconds). Not persisted as business data.

### Presence

Live presence resides in Redis; persistent last-seen snapshot may be written to `user_presence_snapshots`. Presence exposure always respects privacy settings.

---

## 11. Activity API

### ACT-01 Create Activity

`POST /api/v1/groups/{groupId}/activities`

```json
{
  "title": "Đánh cầu lông",
  "description": null,
  "startAt": "2026-09-01T19:00:00+07:00",
  "endAt": "2026-09-01T21:00:00+07:00",
  "timezone": "Asia/Ho_Chi_Minh",
  "location": {
    "type": "PHYSICAL",
    "name": "Sân ABC",
    "address": "...",
    "latitude": null,
    "longitude": null
  },
  "maxParticipants": 8
}
```

Authorization: Owner/Admin; Member when group setting permits. Create state `PLANNING`. Snapshot eligible users to preserve `NO_RESPONSE` semantics. Initialize waitlist sequence. Past start times should generally be rejected except administrative/correction flow.

### ACT-02 Activity List

`GET /api/v1/groups/{groupId}/activities`  
Filters: status, RSVP, creator, from/to.

### ACT-03 Activity Detail

`GET /api/v1/activities/{activityId}`  
Returns core info, current user's RSVP, counts/capacity, waitlist, poll/task/expense/discussion previews and permission flags.

### ACT-04 Update Activity

`PATCH /api/v1/activities/{activityId}`

Creator may edit own Activity; Owner/Admin may edit any Activity. Allowed fields depend on state. CONFIRMED time/location changes are logged and notify Going/Maybe participants. IN_PROGRESS allows limited practical edits. CANCELLED core fields are locked. COMPLETED allows only limited correction/logging.

### ACT-05 Confirm Activity

`POST /api/v1/activities/{activityId}/confirm`  
`PLANNING -> CONFIRMED`.

### ACT-06 Cancel Activity

`POST /api/v1/activities/{activityId}/cancel`

```json
{
  "reason": "Thời tiết xấu"
}
```

### ACT-07 Complete Activity

`POST /api/v1/activities/{activityId}/complete`  
Useful for activities without end time. Activities with end time can automatically transition based on scheduler/domain logic.

### ACT-08 RSVP

`PUT /api/v1/activities/{activityId}/rsvp`

```json
{
  "status": "GOING"
}
```

User can request GOING/MAYBE/NOT_GOING. WAITLIST is assigned by backend, not chosen directly.

Transaction + locking flow:
1. Lock capacity-sensitive activity/participant state.
2. Ensure Activity is not COMPLETED/CANCELLED.
3. Ensure user eligible.
4. If GOING requested and capacity available -> GOING.
5. If full -> WAITLIST and assign monotonic FIFO position.
6. When GOING slot is freed, promote first WAITLIST automatically.
7. Write RSVP history.
8. Publish `RSVP_CHANGED` / `WAITLIST_PROMOTED` events.

Late GOING is allowed while IN_PROGRESS. Completed/cancelled RSVP is locked.

### ACT-09 Participants

`GET /api/v1/activities/{activityId}/participants`  
Groups response by GOING, MAYBE, NOT_GOING, NO_RESPONSE, WAITLIST.

---

## 12. Poll API

### POLL-01 Create Poll

`POST /api/v1/activities/{activityId}/polls`

```json
{
  "question": "Đi Hội An ngày nào?",
  "type": "SINGLE_CHOICE",
  "options": ["Thứ 6", "Thứ 7", "Chủ nhật"],
  "allowMemberAddOption": true,
  "maxSelections": null,
  "voteVisibility": "PUBLIC",
  "resultVisibility": "IMMEDIATE",
  "deadlineAt": "2026-09-01T12:00:00+07:00"
}
```

Vote visibility cannot be changed after the first vote.

### POLL-02 List/Detail

`GET /api/v1/activities/{activityId}/polls`  
`GET /api/v1/polls/{pollId}`

### POLL-03 Vote

`PUT /api/v1/polls/{pollId}/vote`

```json
{
  "optionIds": ["..."]
}
```

Poll must be OPEN and before deadline. Single choice requires exactly one option. Multiple choice enforces maxSelections when configured. Existing vote may be changed while poll remains open.

### POLL-04 Add Option

`POST /api/v1/polls/{pollId}/options`  
Allowed only when creator enabled member-added options.

### POLL-05 Edit/Delete/Disable Option

Before any vote, option creator may edit/delete their option where allowed. Once voted, materially changing/deleting is forbidden. Poll Creator/Owner/Admin may disable an option while retaining existing votes.

`POST /api/v1/poll-options/{optionId}/disable`

### POLL-06 Close Poll

`POST /api/v1/polls/{pollId}/close`  
Creator/authorized moderator may close early. No further vote/option changes afterward.

### POLL-07 Public Voters

`GET /api/v1/polls/{pollId}/voters`  
Only for PUBLIC polls. Anonymous polls still store user IDs internally for integrity but API never exposes voter identity.

---

## 13. Task API

### TASK-01 Create Task

`POST /api/v1/activities/{activityId}/tasks`

```json
{
  "title": "Thuê xe",
  "description": null,
  "assigneeUserIds": ["...", "..."],
  "dueAt": "2026-09-01T12:00:00+07:00"
}
```

Task may have 1+ assignees or remain unassigned. Multiple assignees share ONE task status.

### TASK-02 List/Detail

`GET /api/v1/activities/{activityId}/tasks`  
`GET /api/v1/tasks/{taskId}`  
Filters: status, assignedToMe.

### TASK-03 Update Task

`PATCH /api/v1/tasks/{taskId}`  
Core task edits are controlled by Activity Creator/Owner/Admin.

### TASK-04 Change Status

`PUT /api/v1/tasks/{taskId}/status`

```json
{
  "status": "IN_PROGRESS"
}
```

Any assignee, Owner/Admin or Activity Creator can change shared status. Every transition is logged with actor, old status, new status and timestamp.

### TASK-05 Claim Unassigned Task

`POST /api/v1/tasks/{taskId}/claim`

No subtasks in MVP. Completing Activity does not automatically complete tasks.

---

## 14. Activity Discussion API

`GET    /api/v1/activities/{activityId}/comments`  
`POST   /api/v1/activities/{activityId}/comments`  
`POST   /api/v1/comments/{commentId}/replies`  
`PATCH  /api/v1/comments/{commentId}`  
`DELETE /api/v1/comments/{commentId}`

Rules:
- One reply level only.
- User can edit/delete own comments.
- Owner/Admin can moderate; moderation is logged.
- COMPLETED activities may retain active discussion.
- CANCELLED activities may lock new comments based on domain setting/rule.

---

## 15. Calendar & Reminder API

### CAL-01 Global Calendar

`GET /api/v1/calendar/activities?from=&to=&rsvp=&groupId=&status=`

Aggregates Activities across user's groups. Views may include PLANNING as tentative and CANCELLED as cancelled. Filters support All, Going, Maybe, No Response, Waitlist and Group.

There is no Calendar business table; calendar is a read model over Activity + Participant + Reminder.

### CAL-02 Reminder

`GET /api/v1/activities/{activityId}/reminder`  
`PUT /api/v1/activities/{activityId}/reminder`

```json
{
  "enabled": true,
  "offsetMinutes": 60
}
```

Default proposal is 1 day + 1 hour, user-customizable/disableable. Activity time changes reschedule affected reminders.

---

## 16. Expense API

### FIN-01 Create Expense - Equal Split

`POST /api/v1/groups/{groupId}/expenses`

```json
{
  "title": "Tiền sân",
  "amount": 600000,
  "payerUserId": "...",
  "splitMethod": "EQUAL",
  "participantUserIds": ["...", "...", "..."],
  "activityId": null,
  "expenseDate": "2026-09-01",
  "note": null,
  "receiptStorageKey": null
}
```

One payer only. Payer may be a participant. Backend calculates all ExpenseShare values; Flutter is not authoritative.

### FIN-02 Create Expense - Custom Amount

Same endpoint with `splitMethod=CUSTOM_AMOUNT` and explicit shares.

```json
{
  "title": "Ăn tối",
  "amount": 1000000,
  "payerUserId": "...",
  "splitMethod": "CUSTOM_AMOUNT",
  "shares": [
    {"userId": "...", "amount": 300000},
    {"userId": "...", "amount": 700000}
  ]
}
```

Service requires `sum(shares) == expense.amount`. No self-debt is generated for payer's own share.

### FIN-03 Expense From Activity

`activityId` is optional and must reference an Activity in the same Group. UI may suggest GOING members, but later RSVP changes never mutate existing Expense participation/shares.

### FIN-04 Expense List

`GET /api/v1/groups/{groupId}/expenses?activityId=&involvingMe=&createdByMe=&from=&to=`

### FIN-05 Expense Detail

`GET /api/v1/expenses/{expenseId}`  
Includes payer, shares, activity reference, receipt, creator and change-history summary.

### FIN-06 Update Expense

`PATCH /api/v1/expenses/{expenseId}`

Creator may edit own Expense; Owner/Admin can perform corrections. Amount/payer/participants/split changes require audit log and debt recalculation from facts. If settlements already depend on related balances, service must warn/restrict according to consistency rules.

### FIN-07 Cancel Expense

`POST /api/v1/expenses/{expenseId}/cancel`  
No hard-delete financial history.

---

## 17. Balance / Debt API

There is no authoritative `debts` table.

Current pairwise debt is derived from:

```text
Expense payer + ExpenseShare facts
minus COMPLETED Settlements
then pairwise netting
```

### BAL-01 My Group Balances

`GET /api/v1/groups/{groupId}/balances/me`

```json
{
  "totalOwedByMe": 300000,
  "totalOwedToMe": 550000,
  "balances": [
    {
      "user": {
        "id": "...",
        "displayName": "Nam",
        "avatarUrl": "..."
      },
      "direction": "OWES_YOU",
      "amount": 200000
    }
  ]
}
```

### BAL-02 Balance With User

`GET /api/v1/groups/{groupId}/balances/{userId}`  
Includes net amount, source Expense breakdown, completed Settlements and pending settlement action context.

Frontend is never allowed to set arbitrary debt.

---

## 18. Settlement API

### SET-01 Create Settlement

`POST /api/v1/groups/{groupId}/settlements`

```json
{
  "otherUserId": "...",
  "amount": 100000,
  "declarationType": "I_PAID"
}
```

Backend derives debtor/creditor from current pairwise balance and declaration semantics. Validate amount > 0 and <= current outstanding debt. Initial state: PENDING.

### SET-02 Confirm

`POST /api/v1/settlements/{id}/confirm`

Two-sided confirmation:
- debtor says I_PAID -> creditor confirms;
- creditor says I_RECEIVED -> debtor confirms.

Only COMPLETED affects debt.

### SET-03 Reject

`POST /api/v1/settlements/{id}/reject`

### SET-04 Cancel

`POST /api/v1/settlements/{id}/cancel`  
Creator may cancel while still PENDING.

### SET-05 List

`GET /api/v1/groups/{groupId}/settlements?status=&involvingMe=&otherUserId=`

Settlement confirmation is transaction-sensitive and should revalidate current financial state where required.

---

## 19. Group Fund API

Zero or one Fund per Group in MVP.

### FUND-01 Create Fund

`POST /api/v1/groups/{groupId}/fund`  
Owner only.

### FUND-02 Get Fund

`GET /api/v1/groups/{groupId}/fund`

### FUND-03 Fund Overview

`GET /api/v1/funds/{fundId}/overview`

Returns computed balance, active collection preview, pending contribution-verification count, pending reimbursements, recent transactions and current-user permissions.

Fund balance is NEVER directly edited or trusted from a stored balance field. It is derived from the ledger:

```text
Confirmed Contributions
- Fund Expenses
- Completed Reimbursements
± Adjustments/Reversals
```

### FUND-04 Managers

`GET    /api/v1/funds/{fundId}/managers`  
`POST   /api/v1/funds/{fundId}/managers/{userId}`  
`DELETE /api/v1/funds/{fundId}/managers/{userId}`

Owner always manages. Owner may grant Fund Manager to eligible Admin.

### FUND-05 Create Collection

`POST /api/v1/funds/{fundId}/collections`

```json
{
  "title": "Quỹ tháng 9",
  "description": null,
  "deadlineAt": "2026-09-10T23:59:59+07:00",
  "obligations": [
    {"userId": "...", "requiredAmount": 500000},
    {"userId": "...", "requiredAmount": 300000}
  ]
}
```

Transaction creates collection + member obligations. Required amount may differ per member.

### FUND-06 Collection List/Detail

`GET /api/v1/funds/{fundId}/collections`  
`GET /api/v1/collections/{collectionId}`

Derived obligation state: UNPAID, PARTIAL, PAID, OVERDUE. Those states are computed from required, confirmed/pending contributions and deadline rather than being an authoritative manually-editable status.

### FUND-07 Submit Contribution

`POST /api/v1/collections/{collectionId}/contributions`

```json
{
  "amount": 200000,
  "paymentTime": "2026-09-03T12:00:00+07:00",
  "proofStorageKey": "...",
  "note": "Đã chuyển khoản"
}
```

Initial state PENDING. Late contribution after deadline remains allowed.

Concurrency-sensitive validation:

```text
maximum new contribution
= required amount
- confirmed contributions
- existing pending contributions
```

No overpayment is accepted.

### FUND-08 My Contributions / Verification Queue

`GET /api/v1/collections/{collectionId}/my-contributions`  
`GET /api/v1/funds/{fundId}/contributions?status=PENDING`

### FUND-09 Confirm Contribution

`POST /api/v1/contributions/{contributionId}/confirm`

Owner/Fund Manager. Transaction: lock contribution/context, ensure PENDING, confirm, create ledger IN transaction, publish event. Only CONFIRMED increases balance.

### FUND-10 Reject/Cancel Contribution

`POST /api/v1/contributions/{id}/reject`  
`POST /api/v1/contributions/{id}/cancel`

Manager rejects PENDING; member may cancel own PENDING contribution.

### FUND-11 Create Fund Expense

`POST /api/v1/funds/{fundId}/expenses`

```json
{
  "title": "Tiền xe",
  "amount": 1000000,
  "expenseDate": "2026-09-01",
  "receiptStorageKey": null,
  "note": null
}
```

Owner/Fund Manager. Transaction + lock computes current ledger balance, requires amount <= available balance, creates FundExpense and OUT ledger transaction. No negative fund balance.

### FUND-12 Fund Expense List/Detail

`GET /api/v1/funds/{fundId}/expenses`  
`GET /api/v1/fund-expenses/{expenseId}`

### FUND-13 Request Reimbursement

`POST /api/v1/funds/{fundId}/reimbursements`

```json
{
  "amount": 500000,
  "reason": "Ứng tiền mua đồ ăn",
  "receiptStorageKey": "..."
}
```

Any eligible member may submit; initial state PENDING.

### FUND-14 Approve/Reject Reimbursement

`POST /api/v1/reimbursements/{id}/approve`  
`POST /api/v1/reimbursements/{id}/reject`

Approval transaction locks fund context, verifies PENDING and sufficient balance, marks completed and creates OUT ledger transaction. If balance is insufficient, request remains PENDING and API returns `FUND_INSUFFICIENT_BALANCE`.

### FUND-15 Ledger Transactions

`GET /api/v1/funds/{fundId}/transactions`  
`GET /api/v1/fund-transactions/{transactionId}`

Types: CONTRIBUTION, FUND_EXPENSE, REIMBURSEMENT, ADJUSTMENT, REVERSAL.

### FUND-16 Reverse/Correct Transaction

`POST /api/v1/fund-transactions/{id}/reverse`

```json
{
  "reason": "Sai số tiền"
}
```

Creates compensating/reversal ledger entry. Never delete historical financial transactions.

### FUND-17 Close Fund

`POST /api/v1/funds/{fundId}/close`  
Owner only. History remains viewable; new fund operations are disabled.

---

## 20. Notification API

### NOTI-01 Notification Center

`GET /api/v1/notifications?page=0&size=30`

Notification contains category, priority, actor, target/deep link, timestamp and read state.

### NOTI-02 Unread Count

`GET /api/v1/notifications/unread-count`

### NOTI-03 Mark Read

`POST /api/v1/notifications/{notificationId}/read`

### NOTI-04 Mark All Read

`POST /api/v1/notifications/read-all`

### NOTI-05 Notification Settings

`GET   /api/v1/me/notification-settings`  
`PATCH /api/v1/me/notification-settings`

Categories: Social, Group, Chat/DM, Activity, Poll, Task, Finance, Fund.

### NOTI-06 Group Notification Settings

`GET /api/v1/groups/{groupId}/notification-settings`  
`PUT /api/v1/groups/{groupId}/notification-settings`

Mute choices: 1h, 8h, 1 day, until unmuted. Chat mute must not suppress critical business events.

### Push behavior

If user is currently viewing a conversation, use realtime delivery without push. Otherwise group-chat pushes should aggregate by conversation. High-value business events such as waitlist promotion, settlement confirmation and contribution verification remain explicit.

Stale deep-link target actions must become non-actionable rather than causing invalid state mutation.

---

## 21. Search, Upload & Home Read Models

### SEARCH-01 Global Search

`GET /api/v1/search?q={query}&type={optional}`

MVP categories: PEOPLE, joined GROUPS, ACTIVITIES, CONVERSATIONS.

### MEDIA-01 Request Upload Target

`POST /api/v1/uploads/presign`

```json
{
  "category": "CHAT_IMAGE",
  "fileName": "photo.jpg",
  "contentType": "image/jpeg",
  "fileSize": 1234567
}
```

Backend validates auth, category, content type and size. Response returns upload target and `storageKey`. Business endpoints store only validated references/metadata, not Base64 blobs.

Categories: AVATAR, GROUP_AVATAR, CHAT_IMAGE, EXPENSE_RECEIPT, CONTRIBUTION_PROOF, FUND_EXPENSE_RECEIPT, REIMBURSEMENT_RECEIPT.

### HOME-01 Home Dashboard

`GET /api/v1/home`

Aggregated read model may return Recent Groups, Upcoming Activities, Finance Summary, Actions Required and Recent Updates. This is not a database entity.

### HOME-02 Actions Required

`GET /api/v1/me/actions-required`

Potential action types: RSVP_REQUIRED, POLL_VOTE_REQUIRED, TASK_DUE, SETTLEMENT_CONFIRMATION, FUND_CONTRIBUTION, CONTRIBUTION_VERIFICATION, REIMBURSEMENT_APPROVAL.

---

## 22. Group Security Matrix

| Action | Owner | Admin | Member |
|---|---:|---:|---:|
| View group | Yes | Yes | Yes |
| Chat | Yes | Yes | Yes |
| Edit description | Yes | Yes | No |
| Edit name/avatar | Yes | Yes | Config |
| Create Activity | Yes | Yes | Config |
| Pin message | Yes | Yes | Config |
| Approve join | Yes | Yes | No |
| Promote/Demote Admin | Yes | No | No |
| Kick Member | Yes | Yes | No |
| Kick Admin | Yes | No | No |
| Ban Member | Yes | Yes | No |
| Ban Admin | Yes | No | No |
| Transfer ownership | Yes | No | No |
| Archive/Restore | Yes | No | No |
| Delete group | Yes | No | No |

---

## 23. Activity Security Matrix

| Action | Owner/Admin | Activity Creator | Other Member |
|---|---:|---:|---:|
| View | Yes | Yes | Yes |
| Create | Yes | According to group setting | According to group setting |
| Edit core details | Yes | Yes | No |
| Confirm/Cancel | Yes | Yes | No |
| RSVP self | Yes | Yes | Yes |
| Change another user's RSVP | No | No | No |
| Moderate comment | Yes | Own comments | Own comments |

---

## 24. Finance & Fund Security Matrix

### Expense / Settlement

| Action | Owner/Admin | Member |
|---|---:|---:|
| View permitted group finance | Yes | Yes |
| Create Expense | Yes | Yes |
| Edit own Expense | Yes | Yes |
| Correct another Expense | Yes | No |
| Settle own debt | Yes | Yes |
| Confirm settlement involving self | Yes | Yes |
| Arbitrarily set debt | No | No |

### Group Fund

| Action | Owner | Fund Manager | Member |
|---|---:|---:|---:|
| View Fund | Yes | Yes | Yes |
| Create Fund | Yes | No | No |
| Create Collection | Yes | Yes | No |
| Verify Contribution | Yes | Yes | No |
| Add Fund Expense | Yes | Yes | No |
| Request Reimbursement | Yes | Yes | Yes |
| Approve Reimbursement | Yes | Yes | No |
| Assign Fund Manager | Yes | No | No |
| Close Fund | Yes | No | No |

---

## 25. Core Error Code Catalogue

### Authentication

```text
AUTH_INVALID_CREDENTIALS
AUTH_TOKEN_EXPIRED
AUTH_TOKEN_INVALID
REFRESH_TOKEN_INVALID
EMAIL_NOT_VERIFIED
EMAIL_ALREADY_EXISTS
USERNAME_ALREADY_EXISTS
ACCOUNT_SUSPENDED
ACCOUNT_DEACTIVATED
```

### Social

```text
CANNOT_FRIEND_SELF
ALREADY_FRIENDS
FRIEND_REQUEST_ALREADY_PENDING
FRIEND_REQUEST_COOLDOWN_ACTIVE
FRIEND_REQUEST_NOT_ALLOWED
USER_BLOCKED
MESSAGE_REQUEST_LIMIT_REACHED
MESSAGE_REQUEST_COOLDOWN_ACTIVE
DM_NOT_ALLOWED
```

### Group

```text
GROUP_NOT_FOUND
GROUP_ARCHIVED
GROUP_DELETED
NOT_GROUP_MEMBER
GROUP_MEMBER_LIMIT_REACHED
USER_BANNED_FROM_GROUP
GROUP_INVITATION_NOT_FOUND
GROUP_INVITATION_EXPIRED
JOIN_REQUEST_ALREADY_PENDING
INSUFFICIENT_GROUP_PERMISSION
TRANSFER_OWNERSHIP_REQUIRED
INVALID_OWNERSHIP_TARGET
```

### Chat

```text
CONVERSATION_NOT_FOUND
CONVERSATION_ACCESS_DENIED
MESSAGE_NOT_FOUND
MESSAGE_EDIT_WINDOW_EXPIRED
MESSAGE_UNSEND_WINDOW_EXPIRED
MESSAGE_ALREADY_UNSENT
PIN_LIMIT_REACHED
INVALID_MESSAGE_ATTACHMENT
```

### Activity

```text
ACTIVITY_NOT_FOUND
ACTIVITY_CLOSED
ACTIVITY_ALREADY_STARTED
ACTIVITY_ALREADY_COMPLETED
INVALID_ACTIVITY_TIME
ACTIVITY_CAPACITY_INVALID
RSVP_LOCKED
```

### Poll / Task

```text
POLL_NOT_FOUND
POLL_CLOSED
POLL_DEADLINE_PASSED
INVALID_POLL_SELECTION
MAX_POLL_SELECTIONS_EXCEEDED
POLL_OPTION_DISABLED
POLL_OPTION_CHANGE_NOT_ALLOWED
POLL_VOTERS_PRIVATE
TASK_NOT_FOUND
TASK_UPDATE_NOT_ALLOWED
TASK_ALREADY_ASSIGNED
TASK_NOT_CLAIMABLE
```

### Finance

```text
EXPENSE_NOT_FOUND
INVALID_EXPENSE_AMOUNT
EXPENSE_SPLIT_TOTAL_MISMATCH
EXPENSE_PARTICIPANT_INVALID
EXPENSE_UPDATE_NOT_ALLOWED
NO_OUTSTANDING_DEBT
SETTLEMENT_NOT_FOUND
SETTLEMENT_AMOUNT_EXCEEDS_DEBT
SETTLEMENT_ALREADY_RESOLVED
SETTLEMENT_CONFIRMATION_NOT_ALLOWED
```

### Fund

```text
FUND_NOT_FOUND
FUND_ALREADY_EXISTS
FUND_CLOSED
NOT_FUND_MANAGER
COLLECTION_NOT_FOUND
CONTRIBUTION_EXCEEDS_REMAINING_AMOUNT
CONTRIBUTION_NOT_PENDING
FUND_INSUFFICIENT_BALANCE
REIMBURSEMENT_NOT_FOUND
REIMBURSEMENT_ALREADY_RESOLVED
```

---

## 26. Domain Event Catalogue

```text
USER_REGISTERED
EMAIL_VERIFICATION_REQUESTED
FRIEND_REQUEST_SENT
FRIEND_REQUEST_ACCEPTED
USER_BLOCKED
GROUP_CREATED
GROUP_MEMBER_JOINED
GROUP_MEMBER_LEFT
GROUP_MEMBER_KICKED
GROUP_MEMBER_BANNED
GROUP_OWNERSHIP_TRANSFERRED
GROUP_ARCHIVED
MESSAGE_CREATED
MESSAGE_EDITED
MESSAGE_UNSENT
MESSAGE_REACTION_CHANGED
ACTIVITY_CREATED
ACTIVITY_CONFIRMED
ACTIVITY_TIME_CHANGED
ACTIVITY_LOCATION_CHANGED
ACTIVITY_CANCELLED
ACTIVITY_STARTED
ACTIVITY_COMPLETED
RSVP_CHANGED
WAITLIST_PROMOTED
POLL_CREATED
POLL_CLOSED
TASK_ASSIGNED
TASK_STATUS_CHANGED
EXPENSE_CREATED
EXPENSE_UPDATED
EXPENSE_CANCELLED
SETTLEMENT_CREATED
SETTLEMENT_COMPLETED
SETTLEMENT_REJECTED
FUND_CREATED
COLLECTION_CREATED
CONTRIBUTION_SUBMITTED
CONTRIBUTION_CONFIRMED
CONTRIBUTION_REJECTED
FUND_EXPENSE_CREATED
REIMBURSEMENT_REQUESTED
REIMBURSEMENT_COMPLETED
```

Domain events may use Spring `ApplicationEventPublisher` inside the modular monolith. They do not imply microservices.

---

## 27. DTO Catalogue

### Auth

```text
RegisterRequest / RegisterResponse
VerifyEmailRequest
ResendVerificationRequest
CompleteProfileRequest
LoginRequest / LoginResponse
RefreshTokenRequest / RefreshTokenResponse
ForgotPasswordRequest
ResetPasswordRequest
ChangePasswordRequest
```

### User / Social

```text
UserSummaryResponse
UserPublicProfileResponse
MyProfileResponse
UpdateProfileRequest
UpdateUsernameRequest
UpdatePrivacySettingsRequest
FriendRequestResponse
FriendResponse
BlockedUserResponse
```

### Group

```text
CreateGroupRequest
UpdateGroupRequest
GroupSummaryResponse
GroupDetailResponse
GroupOverviewResponse
GroupSettingsResponse
UpdateGroupSettingsRequest
GroupMemberResponse
CreateInvitationRequest
GroupInvitationResponse
CreateInviteLinkRequest
InviteLinkResponse
JoinRequestResponse
TransferOwnershipRequest
GroupActivityLogResponse
```

### Chat

```text
ConversationSummaryResponse
ConversationDetailResponse
MessageResponse
MessageAttachmentResponse
SendMessageCommand
EditMessageRequest
SetReactionRequest
UpdateReadStateRequest
MessageRequestResponse
PinnedMessageResponse
MessageSearchResultResponse
```

### Activity / Poll / Task / Discussion

```text
CreateActivityRequest
UpdateActivityRequest
ActivitySummaryResponse
ActivityDetailResponse
ChangeRsvpRequest
ActivityParticipantResponse
CreatePollRequest
PollResponse
VotePollRequest
CreatePollOptionRequest
CreateTaskRequest
UpdateTaskRequest
UpdateTaskStatusRequest
TaskResponse
CreateCommentRequest
UpdateCommentRequest
CommentResponse
ActivityReminderRequest
```

### Finance

```text
CreateExpenseRequest
CustomExpenseShareRequest
UpdateExpenseRequest
ExpenseSummaryResponse
ExpenseDetailResponse
BalanceSummaryResponse
BalanceWithUserResponse
BalanceDetailResponse
CreateSettlementRequest
SettlementResponse
```

### Fund

```text
CreateFundRequest
FundOverviewResponse
CreateCollectionRequest
CollectionObligationRequest
CollectionDetailResponse
SubmitContributionRequest
ContributionResponse
CreateFundExpenseRequest
FundExpenseResponse
CreateReimbursementRequest
ReimbursementResponse
FundTransactionResponse
ReverseTransactionRequest
```

---

## 28. Spring Boot Implementation Blueprint

Recommended feature-first package direction before Phase 6 finalizes exact architecture:

```text
com.app
├── auth
├── user
├── social
├── group
├── chat
├── activity
├── poll
├── task
├── discussion
├── calendar
├── finance
├── fund
├── notification
├── media
├── security
└── common
```

A feature may contain:

```text
controller/
service/
repository/
entity/
dto/
mapper/
event/
exception/
```

### Controller responsibility

- Accept HTTP request.
- Bind Request DTO.
- Execute `@Valid` input validation.
- Extract path/query parameters.
- Obtain authenticated principal/current user.
- Call Service.
- Return response/status.

Controller must remain thin and must not contain long business workflows.

### Service responsibility

- Business validation.
- Authorization coordination.
- State transitions.
- Cross-repository workflow.
- Transaction boundaries.
- Locking strategy where required.
- Domain event publication.

### Repository responsibility

- Find/save/exists/count.
- Persistence queries.
- Fetch with locking.
- Database-specific retrieval concerns.

Business workflow does not belong in Repository.

### Mapper responsibility

- Request DTO -> domain/entity input.
- Entity/projection -> Response DTO.

Manual mapping is acceptable initially. MapStruct may be introduced later.

---

## 29. Important Spring Boot Concept Map

```text
@RestController
→ REST endpoint controller

@RequestMapping
→ controller base path

@GetMapping / @PostMapping / @PatchMapping / @PutMapping / @DeleteMapping
→ HTTP route methods

@RequestBody
→ JSON body -> Java DTO

@PathVariable
→ value from URL path

@RequestParam
→ query/filter parameter

@Valid
→ Bean Validation on DTO

@Entity
→ Java persistence mapping

JpaRepository
→ persistence abstraction

@Service
→ business layer

@Transactional
→ atomic all-or-nothing business operation

@RestControllerAdvice
→ centralized API exception handling

Spring Security
→ authentication + request security pipeline

PasswordEncoder
→ safe password hashing

JWT
→ authenticated current-user identity

Pessimistic Lock
→ protect race-sensitive database state

WebSocket
→ realtime bidirectional communication

Redis
→ ephemeral realtime/cache/rate-limit state

ApplicationEventPublisher
→ decouple business action from secondary effects

Flyway
→ versioned PostgreSQL schema migration

OpenAPI / Swagger
→ executable API documentation
```

---

## 30. Screen -> API Mapping

### Home

```text
GET /api/v1/home
GET /api/v1/notifications/unread-count
```

### Groups list

```text
GET /api/v1/groups
GET /api/v1/groups/recent
GET /api/v1/me/group-invitations
```

### Group Overview

```text
GET /api/v1/groups/{id}/overview
```

### Members

```text
GET /api/v1/groups/{id}/members
```

### Global Chat

```text
GET /api/v1/conversations
GET /api/v1/message-requests
```

### Conversation

```text
GET /api/v1/conversations/{id}/messages
GET /api/v1/conversations/{id}/pins
WebSocket message/read/reaction/typing/presence events
```

### Activity List / Detail

```text
GET /api/v1/groups/{id}/activities
GET /api/v1/activities/{id}
PUT /api/v1/activities/{id}/rsvp
GET /api/v1/activities/{id}/polls
GET /api/v1/activities/{id}/tasks
GET /api/v1/activities/{id}/comments
```

### Calendar

```text
GET /api/v1/calendar/activities
```

### Finance Dashboard

```text
GET /api/v1/groups/{id}/balances/me
GET /api/v1/groups/{id}/expenses
GET /api/v1/groups/{id}/fund
```

### Create Expense

```text
POST /api/v1/groups/{id}/expenses
```

### Fund Dashboard

```text
GET /api/v1/funds/{id}/overview
```

### Notification Center

```text
GET /api/v1/notifications
POST /api/v1/notifications/{id}/read
```

### Profile

```text
GET /api/v1/me
```

---

## 31. Idempotency & Retry Safety

Mobile networks can retry requests. Duplicate creation must be considered for message send and financial commands.

Candidates:

```text
SEND_MESSAGE
Create Settlement
Submit Contribution
Create Fund Expense
Approve Reimbursement
```

Possible mechanisms to finalize in Architecture/Implementation:
- `clientMessageId` / `clientRequestId`.
- `Idempotency-Key` header.
- unique business constraints.
- transaction + duplicate-key handling.

Backend remains authoritative even if Flutter retries.

---

## 32. Source-of-Truth Rules

Flutter must never be authoritative for:

```text
debt
fund balance
waitlist promotion
member permissions
poll validity
settlement validity
contribution remaining amount
```

Authoritative facts:

```text
Expense + ExpenseShare
→ debt inputs

COMPLETED Settlement
→ debt reduction

Fund transaction ledger
→ fund balance

ActivityParticipant
→ RSVP / capacity state

GroupMembership + GroupBan
→ group access

Privacy + Friendship + Block + MessageRequest
→ DM access
```

Flutter may calculate previews for UX, but Spring Boot revalidates everything before commit.

---

## 33. Non-Persistent Realtime State

The following should not be modeled as ordinary long-lived PostgreSQL business state:

```text
typing indicator
current WebSocket connection
online heartbeat
short-lived rate-limit counters
short-lived presence cache
```

Redis/in-memory infrastructure is the primary owner of these states. Persistent last-seen may be snapshotted to PostgreSQL.

---

## 34. Implementation Order

Recommended dependency order:

```text
1. Common error model + exception infrastructure
2. PostgreSQL/Flyway baseline
3. User Entity + Authentication
4. JWT + Spring Security
5. Profile + Privacy
6. Friend + Block
7. Group + Membership + Invitation + Permission
8. Activity Core + RSVP + Waitlist
9. Poll + Task + Discussion
10. Chat REST history
11. WebSocket Chat + Redis Presence/Typing
12. Expense + ExpenseShare + Balance calculation
13. Settlement
14. Group Fund + Collection + Contribution + Ledger + Reimbursement
15. Notifications + FCM
16. Calendar + Reminder
17. Search + Media upload
18. Home aggregation
19. Full integration/e2e hardening
```

This is a dependency order, not a day-by-day study schedule.

---

## 35. Testing Expectations

Every critical Service should have:

```text
happy-path test
input-validation test
permission test
business-state transition test
transaction rollback test
edge-case test
```

Concurrency-sensitive tests are especially required for:

```text
Activity final slot
FIFO waitlist promotion
Message sequence allocation
Contribution remaining amount with concurrent pending submissions
Fund concurrent spending
Reimbursement approval
Settlement duplicate/double confirmation
```

API integration tests should cover authentication and HTTP contract. OpenAPI examples should reflect the same DTOs and error codes.

---

## 36. OpenAPI / Swagger

Use Springdoc OpenAPI to expose an executable development reference, typically at `/swagger-ui.html` or the equivalent configured Springdoc path.

Endpoints should document:
- summary/description;
- request schema;
- response schema;
- security requirement;
- status codes;
- representative business errors.

The written Blueprint remains the business/implementation baseline. OpenAPI becomes the machine-readable/runtime API reference.

---

## 37. Out of MVP API

No MVP API contract is defined for:

```text
voice messages
voice/video calls
Discord-style channels
live location
Moments
Shared Album
AI planner/summary/generation
bank API integration
automatic payment reconciliation
multiple funds per group
custom group roles
subtasks
end-to-end encryption
```

They require future specification/versioning.

---

## 38. Baseline Business Decisions Preserved

This API contract explicitly preserves the locked BA decisions:

```text
Email + Password MVP
Owner / Admin / Member
max 100 ACTIVE members/group
one Group Chat/group
FULL_HISTORY or FROM_JOIN_TIME
message edit <=15 minutes
message unsend <=15 minutes
max 10 images/message
max 20 pinned messages/group
max one emoji/user/message
Message Request max 3 text messages before accept
no image/file before Message Request accept
friend decline cooldown 24h
message-request decline cooldown 72h
block removes friendship/direct social interaction but not shared business history
Activity state machine PLANNING -> CONFIRMED -> IN_PROGRESS -> COMPLETED, plus CANCELLED
FIFO waitlist
Single/Multiple Poll
PUBLIC/ANONYMOUS vote exposure rule
one shared Task status for multiple assignees
one reply level in Activity discussion
one payer/Expense
EQUAL or CUSTOM_AMOUNT split
pairwise net debt, no arbitrary Debt table mutation
two-sided Settlement confirmation
zero or one Fund/group
collection-based contributions
manual contribution verification
no overpayment against remaining obligation
no negative Fund balance
ledger-derived Fund balance
no hard-delete financial transaction history
in-app + push notifications
conversation-aggregated group-chat push
```

---

## 39. Phase 5 Acceptance Definition

Phase 5 is complete when:

```text
Every MVP business module has an API surface.
Authentication strategy is fixed.
Authorization model is fixed.
Common DTO/error conventions are fixed.
REST vs WebSocket responsibilities are fixed.
Redis responsibilities are identified.
Financial source-of-truth rules are fixed.
Transaction-sensitive APIs are identified.
Concurrency-sensitive APIs are identified.
Core domain events are identified.
Screen-to-API mapping exists.
Spring Boot implementation responsibilities are understandable.
An implementation Agent can build APIs without inventing new business rules.
```

---

## 40. Final Baseline Status

**API CONTRACT & BACKEND IMPLEMENTATION BLUEPRINT v1.0**  
**Status: BASELINE ESTABLISHED**

No endpoint, permission rule, protected state transition, financial calculation rule or persistence assumption should be changed during implementation without checking impact on:

```text
PRODUCT REQUIREMENT OVERVIEW
BA CONSOLIDATED SPECIFICATION
SCREEN MAP / UX
ERD & DATABASE DESIGN
API CONTRACT
FLUTTER CLIENT
TESTS
```

The next design phase is **SYSTEM ARCHITECTURE**, where the project will finalize Spring Boot module/layer architecture, Flutter architecture, WebSocket/Redis topology, object storage/FCM integration, deployment boundaries and detailed package/code structure.
