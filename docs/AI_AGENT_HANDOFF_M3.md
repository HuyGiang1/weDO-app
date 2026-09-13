# AI AGENT HANDOFF: MILESTONE 3 — USER PROFILE + PRIVACY

## Checkpoint

- Branch: `feat/m3-user-profile-privacy`
- M3 commits: `edcc020`, `660006f`, `8cb23b7`, `c78025a`, `0bd926d`, `269674f`, `6057b07`.
- M3.8 closure work remains uncommitted until mentor approval.

## Backend API Freeze

| API | Contract |
| --- | --- |
| `GET /api/v1/me` | ACTIVE Bearer caller; `MyProfileResponse`. |
| `PATCH /api/v1/me/profile` | Safe allow-list profile PATCH; `MyProfileResponse`. |
| `PATCH /api/v1/me/username` | Canonical lowercase username; PostgreSQL uniqueness is authoritative. |
| `GET/PATCH /api/v1/me/privacy` | `PrivacySettingsResponse`; nullable request fields mean unchanged. |
| `GET /api/v1/users/{userId}` | ACTIVE Bearer caller and ACTIVE target; exact five-field `UserPublicProfileResponse`. |
| `POST /api/v1/me/change-password` | Validates current password, changes credential, revokes refresh sessions, returns 204. |
| `GET /api/v1/me/qr` | Stable `{ deepLink: "wedo://user/<UUID>" }`; owner privacy does not hide it. |
| `POST /api/v1/users/qr/resolve` | ACTIVE caller/target plus `discoverByQr`; safe profile or uniform 404. |

`UserPublicProfileResponse` is exactly `id`, `username`, `displayName`, `avatarStorageKey`, and `bio`.

## Flutter Freeze

Authenticated routes: `/profile`, `/profile/change-password`, `/profile/privacy`, `/profile/qr`.

Screens use repository/API boundaries; no M3 screen owns Dio, access tokens, or secure storage. Password success uses `AuthSessionController.endSessionAfterPasswordChange()` to clear local state after the backend confirms success.

## Schema and Concurrency

M3 adds no migration. It reuses `users`, `user_credentials`, `user_privacy_settings`, and `refresh_sessions`. Username uniqueness is PostgreSQL CITEXT plus flush-time constraint handling. Credential updates use the existing lock. Privacy PATCH has accepted whole-row last-write-wins behavior. QR is stateless and has no persisted record.

## M4 Privacy Contract

Defaults: `discoverByUsername=true`, `discoverByQr=true`, `discoverByEmail=false`, `discoverByPhone=false`, `showOnlineStatus=true`, `showLastSeen=true`.

| Policy | Runtime values | Default | Future owner |
| --- | --- | --- | --- |
| `FriendRequestPolicy` | `EVERYONE`, `MUTUAL_GROUPS`, `NONE` | `EVERYONE` | M4 friend-request eligibility |
| `DmPolicy` | `EVERYONE`, `MUTUAL_GROUPS`, `FRIENDS_ONLY` | `EVERYONE` | Future messaging policy |

M4 must enforce discovery and request policies in its services. Known-ID public-profile lookup is independent of discoverability. M4 owns search, friendship, blocks, mutual groups, relationship/presence enrichment, and messaging eligibility; it must not casually extend the base public DTO.

## QR Future Contract

QR is `wedo://user/<UUID>`, where UUID is an identifier, not a secret or authorization token. There is no QR table, rotation, expiry, signature, encryption, scanner, camera, sharing/export, or OS deep-link registration. Future scanning must submit the payload to the resolver; it must not treat the payload as authorization.

## Security and Limitations

- Public DTOs exclude PII/security/internal fields.
- Unknown/non-active QR targets and disabled QR discovery use the same public 404 contract.
- Already-issued stateless access JWTs may remain valid until normal expiry after password change.
- Privacy concurrent writes are whole-row last-write-wins.
- Physical device testing is not required for M3; live Flutter/Dart to Spring Boot to PostgreSQL is the closure gate.

## Verification

Live M3 E2E passed terminally: `00:29 +1: All tests passed!`. It exercised two unique real accounts through the production Flutter/Dart networking/session layers, Spring Security, and local PostgreSQL for profile, username, privacy, public profile, QR, password/session invalidation, old-refresh rejection, and new-password login. `OtpResolverTest` is skipped by ordinary full Maven runs unless `wedo.e2e.user-id` is set; the live harness supplies that property and uses it only to resolve a test account OTP through temporary IPC.

Shared merge-risk files: `UserController`, API blueprint, Flutter routes/app composition, `pubspec`, and privacy models.
