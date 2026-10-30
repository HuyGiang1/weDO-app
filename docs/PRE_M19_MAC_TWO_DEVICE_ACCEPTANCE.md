# Pre-M19 Mac Two-Device Acceptance

## Hotspot demo readiness — 2026-10-19 ~16:26 local

Runtime-only preparation complete; this does **not** claim the unfinished full functional matrix is complete. Existing branch/worktree preserved; no product edits, full test reruns, commit/push/merge/M19, cache cleanup or QA reset.

| Check | Current verified result |
| --- | --- |
| Topology | iPhone hotspot host<QA_HOTSPOT_IP>; Mac`en0`<QA_HOTSPOT_IP>; Samsung<QA_HOTSPOT_IP> |
| Internet / Firebase Hosting | PASS; hosting, assetlinks and AASA HTTP200 |
| PostgreSQL / Redis / MinIO | Retained containersUP; pg_isready/PONG/readiness200; existing volumes intact |
| Backend | PID83450; actuatorUP via127.0.0.1 and<QA_HOTSPOT_IP>; APIhealthUP |
| iPhone hotspot host→Mac | Physical Safari health200 from<QA_HOTSPOT_IP>; authenticated appHome200 |
| Samsung→Mac | Physical browser health200 from<QA_HOTSPOT_IP>; authenticated appHome200 |
| App configuration | Both rebuilt/in-place installed with`http://<QA_HOTSPOT_IP>:8080`; no source/signing edits |
| Samsung connectivity | **LAN MODE**, reverse list empty; USB not needed |
| Physical smoke | Existing QA group; one text each direction; one small QA PNG Samsung→iPhone, visibly rendered; no reload required |
| Private media | Fresh presign200/upload/send201/authorized access200; old media retained; no public bucket or signed-URL exposure |
| Android FCM | Fresh markerGATEWAY_ACCEPTED, actual SystemUI notification visible, tap→correct chat |
| Public links | Android canonical HTTPS→weDO, domainsverified; iOS bridge unchanged/AASA200, OS-level Universal Link handoff not re-verified this session |
| Final devices | QA Owner and QA Member1 authenticated atHome, no dialogs; hotspot remainsON |

Evidence: `/tmp/wedo-hotspot-two-way-samsung.log`, USBresponses`1a15375643f`/`1a1537acde8`, `/tmp/wedo-hotspot-received-image.png`, `/tmp/wedo-hotspot-fcm-tap.log`, `/tmp/wedo-hotspot-samsung-final.log`; safe access log19Oct16:14–16:25 shows actual device IPs/statuses. Only normal QA chat messages were added; no ownership/membership/finance/fund/archive changes. Existing automated baseline762PASS/analyze clean reused, not rerun.

Start/reuse: `bash /tmp/wedo-mac-demo-start.sh`. Stop backend only: `bash /tmp/wedo-mac-demo-stop.sh`; add`--infra` only to stop the three weDO containers intentionally. Runtime started with existing external secret/license locations, never printed. Start log `/tmp/wedo-hotspot-start-20261019.log`; PIDfile `/tmp/wedo-mac-demo-backend.pid`. If hotspot IP changes, stop backend, redetectIP, rerun helper to refresh media binding and rebuild endpoint-config apps as needed; do not reuse old192.168 addresses.

Date: 2026-10-18 (Asia/Ho_Chi_Minh). **Continuation from 748-test candidate (`feat/pre-m19-ui-polish` @ `cdb0bd7`).** The earlier 50-point walkthrough and prior continuation checkpoints are preserved below as historical evidence. M18 remains closed; M19 has not started. No stage, commit, push, or dev merge.

## Current full acceptance — 2026-10-18 ~18:15 local continuation (Gemini takeover)

### 1. Runtime & Automated Baseline Verification
- **Branch / HEAD**: `feat/pre-m19-ui-polish` at `cdb0bd7` (`cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`), protected stash `stash@{0}` intact, Mac LAN IP `<QA_LAN_IP>` (`en0`), ~10.0–11.7 GiB free disk.
- **Infrastructure**: PostgreSQL (`wedo-postgres` on `127.0.0.1:55432`), Redis (`wedo-redis` on `127.0.0.1:6379`), AIStor/MinIO (`wedo-minio` on `<QA_LAN_IP>:9000` / `127.0.0.1:9000`, readiness `HTTP 200`), and Spring Boot backend (PID `66523`, `/actuator/health` `UP` across `db`, `redis`, `diskSpace`) are all running with existing volumes preserved.
- **Automated Suite & Installed Binaries**:
  - Full Flutter test suite: **748 PASS** (`/tmp/wedo-full-tests-ban-204.log`).
  - `flutter analyze`: **No issues found** (`/tmp/wedo-analyze-ban-204.log`).
  - Installed binaries (`mobile/build/app/outputs/flutter-apk/app-debug.apk` built Oct 18 15:09; `mobile/build/ios/iphoneos/Runner.app` built Oct 18 15:10) are newer than the latest source edit (`mobile/lib/features/groups/data/group_api.dart` modified Oct 18 15:08). No source files were modified in this continuation session, so no rebuild or reinstall was required.

### 2. Interrupted Block/Unblock (`HTTP 204`) Physical Regression (`F026`) — PASS
- Tested in isolated fixture group **`PRE-M19 Group Lifecycle Lab 18-10`** (`e980d29f-2ca2-4dbb-a0e7-1222462eb1fa`; main demo group `weDO QA Team` untouched):
  1. **Owner Ban (`HTTP 204` success UI)**: iPhone (`QA Owner`) opened `Thành viên nhóm` -> `QA Member 1` -> `Cấm khỏi nhóm`, entered reason `PRE-M19 verified 204 regression`, and confirmed `Cấm thành viên`. The app handled `HTTP 204` as success with **zero false error banner**, popped `MemberManagementScreen`, and returned cleanly to `Thành viên nhóm` showing only `QA Owner` (`/tmp/wedo-ios-usb-response-13d7ec6155bf.json`).
  2. **Member Access Revoked**: Samsung (`QA Member 1`) lost access immediately (`Thông tin nhóm` -> `Thử lại`).
  3. **Owner Ban List & Unban**: iPhone (`QA Owner`) opened `Danh sách chặn` (`Danh sách cấm`), verified `QA Member 1` (`@qa_member1`) with reason `PRE-M19 verified 204 regression` (`/tmp/wedo-ios-usb-response-7ce9fecbcaf3.json`), tapped `Bỏ cấm`, and verified `Đã bỏ cấm người dùng` + `Nhóm chưa có người dùng bị cấm` (`/tmp/wedo-ios-usb-response-a56089f71ccc.json`).
  4. **Member Rejoin & Final State Restoration**: Samsung rejoined `PRE-M19 Group Lifecycle Lab 18-10` via default invite code `-4LMXjKpxpD0` (`Đã tham gia nhóm!`, `/tmp/wedo-748-ban-unban-rejoin-samsung.log`), and iPhone `Thành viên nhóm` confirmed both `QA Owner` (`Trưởng nhóm`) and `QA Member 1` (`Thành viên`) active (`/tmp/wedo-ios-usb-response-7def221d0931.json`).

### 3. Additional Physical Matrix Scenarios Verified / Consolidated in This Session
- **Home & Navigation**:
  - `F017` (Pending action deep link): iPhone Home `Cần bạn phản hồi` -> `Chọn địa điểm` opened `Chi tiết bình chọn` and returned cleanly (`/tmp/wedo-ios-usb-response-f9bcdf34ac09.json`) — **PASS**.
  - `F019` (Home refresh & retry recovery): Verified pull-to-refresh and retry recovery across both devices (`/tmp/wedo-f020-f022-samsung.log`, `/tmp/wedo-ios-usb-response-1a14df5f163.json`) — **PASS**.
- **Groups & Permissions (Isolated Lab `PRE-M19 Group Lifecycle Lab 18-10`)**:
  - `F020` (My Groups list / search / join-by-code / refresh): Verified on both devices (`/tmp/wedo-f020-f022-samsung.log`, `/tmp/wedo-ios-usb-response-7def221d0931.json`) — **PASS**.
  - `F022` (Group detail role visibility): Verified Owner management controls vs Member read-only/mute/leave controls (`/tmp/wedo-f020-f022-samsung.log`, `/tmp/wedo-ios-usb-response-8a19a82d1d99.json`) — **PASS**.
  - `F023` (Edit group info & Member permission denial): Owner edited and restored description (`Đã cập nhật thông tin nhóm`, `/tmp/wedo-ios-usb-response-8a19a82d1d99.json`); Member edit attempt was rejected by server permission gate (`/tmp/wedo-f023-member-denied-samsung.log`) — **PASS**.
  - `F029` (Transfer ownership): Two-way ownership transfer `QA Owner -> QA Member 1 -> QA Owner` verified across both physical devices (`Đã chuyển quyền trưởng nhóm`, `/tmp/wedo-ios-usb-response-2d493585742b.json`, `/tmp/wedo-f029-samsung-new-owner.log`, `/tmp/wedo-ios-usb-response-2e86bd8c8434.json`, `/tmp/wedo-f029-transfer-back-samsung.log`) — **PASS**.
  - `F030` (Activity log timeline): Verified localized lifecycle audit events in `Nhật ký hoạt động` (`/tmp/wedo-f030-f039-samsung.log`) — **PASS**.
  - `F031` (Group invitations list): Verified acceptance and empty state `Không có lời mời nào đang chờ` (`/tmp/wedo-f031-invitations-samsung.log`) — **PASS**.
  - `F033` & `F034` (Invite links default/custom/usage limit/copy/revoke): Custom single-use code `dJmvxXHRuuYV` (`maxUses: 1`) incremented `0 / 1 -> 1 / 1` after Samsung join (`/tmp/wedo-f036-f033-member-leave-and-custom-join.log`, `/tmp/wedo-ios-usb-response-b811289a587a.json`); custom code `GAhB54oX1hvf` revoked to `Đã thu hồi` — **PASS**.
  - `F035` (Join-request `APPROVAL_REQUIRED`): Samsung previewed `Cần phê duyệt` and submitted `Gửi yêu cầu tham gia` (`Đã gửi yêu cầu tham gia!`, `/tmp/wedo-f035-preview-card-samsung.log`, `/tmp/wedo-f035-request-sent-samsung.log`); iPhone Owner inspected `Yêu cầu tham gia (1)` showing `Từ chối` and `Duyệt`, rejected request (`Không có yêu cầu tham gia đang chờ`), and restored `OPEN` policy (`/tmp/wedo-ios-usb-response-8e5e7bd17505.json`, `c87fd0ff8a96.json`, `d866e9c8ea5f.json`) — **PARTIAL** (reject path executed end-to-end; approve button verified on card before Samsung USB disconnect).
  - `F036` (Leave group & Owner restriction): Owner leave blocked while member active (`Vui lòng chuyển quyền trưởng nhóm trước khi rời nhóm.`, `/tmp/wedo-ios-usb-response-768eb6822149.json`); Member leave confirmed and succeeded (`/tmp/wedo-f036-f033-member-leave-and-custom-join.log`) — **PASS**.
  - `F037` (Archive / restore & write gates): Owner archived lab group, verified archived banner and write gate in `Sửa thông tin nhóm`, and restored (`Khôi phục nhóm`, `/tmp/wedo-ios-usb-response-01ca700a3721.json`, `/tmp/wedo-ios-usb-response-f770846d246b.json`) — **PASS**.
  - `F038` (Delete group confirmation & cancel): Owner inspected `Delete Group` confirmation dialog and cancelled safely (`/tmp/wedo-ios-usb-response-913ebc897949.json`; P3 cosmetic English dialog copy noted) — **PASS**.
  - `F039` & `F073` (Group notification timed/permanent mute & unmute): Verified `Trong 1 giờ`, `Cho đến khi bật lại`, and `Bật lại thông báo` on Samsung (`/tmp/wedo-f039-f073-mute-states-samsung.log`, `/tmp/wedo-f036-f039-unmute-leave-dialog-samsung.log`) — **PASS**.
- **Activities, Polls, Tasks, Calendar & Expenses**:
  - `F076` & `F079` (Activity list lifecycle filters & Activity detail schedule/organizer/tools): Verified on iPhone Owner (`/tmp/wedo-ios-usb-response-c9e4085cbdf4.json`, `/tmp/wedo-ios-usb-response-084bd8c2ec34.json`) — **PASS**.
  - `F091` (Poll voters list & results percentages): Verified `Danh sách người bình chọn` (`QA Member 1` -> `Quán cà phê`) and `Kết quả bình chọn` (`100%` / `0%`) on iPhone Owner (`/tmp/wedo-ios-usb-response-b2b9561530ea.json`) — **PASS**.
  - Consolidated existing physical log evidence into matrix rows `F081`, `F086`, `F087`, `F088`, `F089`, `F093`, `F104`, and `F108`.
- **Matrix Totals (141 scenario families)**:
  - **PASS**: 91
  - **FAIL**: 0 (previous `F026` FAIL resolved and physically verified PASS)
  - **BLOCKED**: 1 (`F066` — iPhone Save to Photos succeeds and creates the asset in PhotoKit, but reopening the protected iOS Photos app UI is gated by OS Face ID/passcode authentication)
  - **PARTIAL / NOT EXECUTED**: 49 (`22 PARTIAL` + `27 NOT EXECUTED`; includes unauthenticated onboarding/registration/password-reset mutations on shared QA accounts and remaining secondary permutations).

### 3b. Group Invite Links & Friend QR Productization (2026-10-18 ~23:55 local continuation — FULL PASS)

- **HOST & LINK STRATEGY (`LIVE & DEPLOYED`)**:
  - Live verified HTTPS host: `https://wedo-3304c.web.app` (and `wedo-3304c.firebaseapp.com`).
  - Canonical Group Invite URL: `https://wedo-3304c.web.app/inv/<inviteCode>` (server-issued case-sensitive codes preserved).
  - Canonical Friend URL: `https://wedo-3304c.web.app/u/<userId>` (UUID-based public identifier, zero auth tokens or secrets).
  - Live hosted digital asset links:
    - Android: `https://wedo-3304c.web.app/.well-known/assetlinks.json` (SHA256 fingerprint for `com.wedo.mobile`).
    - iOS: `https://wedo-3304c.web.app/.well-known/apple-app-site-association` (`/inv/*` and `/u/*` applinks).
  - WeDo-branded fallback web pages deployed at `/inv/*` and `/u/*` with `"Mở trong ứng dụng weDO"` CTA and safe `wedo://` scheme fallbacks.

- **ANDROID APP LINKS (`PASS` — PHYSICALLY VERIFIED)**:
  - `AndroidManifest.xml` configured with `android:autoVerify="true"` intent filters for `https://wedo-3304c.web.app` and `https://wedo-3304c.firebaseapp.com` across `/inv/.*` and `/u/.*`, plus custom scheme `wedo://inv/.*` and `wedo://u/.*`.
  - Android OS verification status on physical Samsung `<QA_ANDROID_SERIAL>` via `pm get-app-links com.wedo.mobile`:
    - `wedo-3304c.web.app: verified`
    - `wedo-3304c.firebaseapp.com: verified`
  - Verified across all 3 app states (cold/terminated `am force-stop`, backgrounded, and running in foreground): opens `com.wedo.mobile` directly without opening Samsung Internet.

- **iOS UNIVERSAL LINKS & CUSTOM URI (`PASS` — PHYSICALLY VERIFIED)**:
  - `Info.plist`, `AppDelegate.swift`, and `SceneDelegate.swift` registered `wedo://` URL types, `NSUserActivityTypeBrowsingWeb` continuation, and `WeDoDeepLinkBridge` method channel.
  - Local Apple Personal Team signing and bundle identifier preserved cleanly.
  - Physical iPhone `<QA_IPHONE_UDID>` (`<QA_LAN_IP>`) opened `--payload-url "https://wedo-3304c.web.app/inv/-4LMXjKpxpD0"` and `--payload-url "https://wedo-3304c.web.app/u/d78a1d06-2d51-4ca5-914f-b0d33b0e4f98"`, resolving directly into weDO and making the corresponding authenticated backend API calls (`GET /api/v1/group-invites/-4LMXjKpxpD0 200` and `POST /api/v1/users/qr/resolve 200`).

- **GROUP SHARE UX & JOIN-BY-CODE ENHANCEMENT (`PASS` — PHYSICALLY VERIFIED)**:
  - `GroupInviteLinksScreen`: `Sao chép liên kết` copies canonical `https://wedo-3304c.web.app/inv/<inviteCode>`; `Chia sẻ` opens native OS share sheet (`Intent.createChooser` on Android, `UIActivityViewController` on iOS).
  - `JoinByInviteCodeScreen`: Users can input either a raw case-sensitive invite code (`-4LMXjKpxpD0`) OR paste a full canonical HTTPS invite link (`https://wedo-3304c.web.app/inv/-4LMXjKpxpD0`). The screen automatically extracts and preserves the case-sensitive code, previews the group details, and allows joining.
  - Exhausted single-use invite links (e.g. `dJmvxXHRuuYV` after 1 use) display `"Liên kết mời đã hết lượt sử dụng."` cleanly.

- **FRIEND QR GENERATOR & SCANNER (`PASS` — PHYSICALLY VERIFIED)**:
  - `PersonalQrScreen` (`Hồ sơ` -> `Mã QR của tôi`) displays canonical `https://wedo-3304c.web.app/u/<userId>` with user avatar, name, handle, instructions, `Sao chép liên kết`, `Chia sẻ` (native OS share sheet), and `Quét QR`.
  - Built-in Camera QR Scanner implemented with native camera preview and decoding:
    - Android: Native CameraX / Camera + ZXing `MultiFormatReader`.
    - iOS: `AVFoundation` `AVCaptureMetadataOutput` (`.qr`).
  - Samsung (`QA Member 1`) tapped `Quét QR`, requested runtime camera permission, opened the camera scanner, and physically scanned iPhone's displayed QR code at `23:36:20`, instantly resolving `QA Owner`'s profile.

- **PUBLIC USER PROFILE & FULL SOCIAL LIFECYCLE (`PASS` — PHYSICALLY VERIFIED)**:
  - Deep-link `/u/<userId>` and QR scanner resolve through backend `POST /api/v1/users/qr/resolve` (supporting both canonical HTTPS URLs and legacy `wedo://` URIs).
  - Backend privacy settings enforced: If target user has `discoverByQr=false`, backend returns HTTP 404, and app displays `"Không tìm thấy người dùng hoặc người dùng đã tắt tìm kiếm qua mã QR."` without opening the profile.
  - `PublicUserProfileScreen` handles all relationship states dynamically:
    - **Self**: When opening own `/u/<id>`, action buttons (`Thêm bạn bè`, `Nhắn tin`) are hidden.
    - **Stranger**: Displays `"Thêm bạn bè"` and `"Nhắn tin"`. Tapping `"Thêm bạn bè"` calls `POST /api/v1/users/<id>/friend-requests 201`, updates the button to `"Hủy lời mời"`, and displays SnackBar `"Đã gửi lời mời kết bạn."`.
    - **Outgoing Pending**: Tapping `"Hủy lời mời"` cancels the request and restores `"Thêm bạn bè"`.
    - **Incoming Pending / Friends**: Tapping `"Bạn bè"` displays confirmation dialog `"Bạn có chắc muốn hủy kết bạn với <name>?"`. Confirming executes unfriend and returns button to `"Thêm bạn bè"`.
    - **Block / Unblock**: Header popup menu provides `"Chặn người dùng"`. Confirming blocks user (`"Đã chặn người dùng."`), disables messaging, and replaces action button with `"Bỏ chặn"`. Tapping `"Bỏ chặn"` immediately unblocks and restores `"Thêm bạn bè"`.
  - Production Navigation: `ProfileScreen` (`Hồ sơ`) now includes direct entry points for:
    - `Mã QR của tôi` (`AppRoutes.personalQr`)
    - `Quét QR` (`AppRoutes.scanQr`)
    - `Bạn bè` (`AppRoutes.friends`)
    - `Lời mời kết bạn` (`AppRoutes.friendRequests`)
    - `Người dùng đã chặn` (`AppRoutes.blockedUsers`)
  - Full Flutter suite: **762 PASS**, `flutter analyze` clean. Backend tests: **3 PASS**.

### 4. Device Transport Note & Handoff State
- Physical Samsung `<QA_ANDROID_SERIAL>` (`QA Member 1`) USB connection and `adb reverse` (`8080`, `9000`) are restored; Samsung rejoined `PRE-M19 Group Lifecycle Lab 18-10` and is sitting cleanly on **`Trang chủ` (`Home`)** (`/tmp/wedo-samsung-rejoin-and-home.log`).
- iPhone `<QA_IPHONE_UDID>` (`QA Owner`) was relaunched cleanly to **`Trang chủ` (`Home`)** over Wi-Fi LAN (`<QA_LAN_IP>:8080`).
- Main demo group **`weDO QA Team`** is completely intact (`QA Owner` receivable `30.000 ₫`, `QA Member 1` payable `30.000 ₫`, upcoming activity `Demo nhóm weDO — Cùng lên kế hoạch`, poll `Chọn địa điểm`, task `Chuẩn bị đồ dùng`).

### 5. User Manual Acceptance Test Plan (Realistic Product Pass)
1. **Home / Navigation**: Verify `Trang chủ` on both iPhone (`QA Owner`) and Samsung (`QA Member 1`) shows the 5 sections (`Nhóm gần đây`, `Hoạt động sắp tới`, `Tóm tắt tài chính`, `Cần bạn phản hồi`, `Cập nhật gần đây`) and switch across the 5 bottom tabs (`Trang chủ`, `Nhóm`, `Trò chuyện`, `Lịch`, `Hồ sơ`).
2. **Group + Role Differences**: Open `weDO QA Team` -> `Thông tin nhóm`; verify iPhone (`Trưởng nhóm`) sees management/settings/invite controls while Samsung (`Thành viên`) sees member-appropriate read/mute/leave controls.
3. **Two-Way Chat**: In `weDO QA Team` chat, send a Vietnamese message from iPhone -> Samsung and reply from Samsung -> iPhone; verify instant realtime delivery without reload.
4. **Portrait + Landscape Image**: Send or scroll to the portrait (`9:16`), landscape (`16:9`), and square (`1:1`) images in `weDO QA Team` chat; verify natural aspect-ratio thumbnails with no stretching or distortion.
5. **Fullscreen / Zoom / Save**: Tap an image to open the dark fullscreen viewer; test pinch-to-zoom, pan, double-tap zoom (`2.5×` / reset `1×`), and tap `Lưu` to save to iPhone Photos and Samsung Gallery.
6. **Reconnect / Catch-Up**: Move one device to `Trang chủ` (or background), send 2 messages from the other device, then reopen the chat and verify both messages catch up in order with zero duplicates.
7. **Samsung Background Push + Deep-Link**: Press Android Home on Samsung, send a new chat message from iPhone Owner, verify the system FCM notification arrives on Samsung, and tap it to open `weDO QA Team` chat directly.
8. **Activity + RSVP**: Open `Demo nhóm weDO — Cùng lên kế hoạch` (`20/10/2026 10:00 — 11:30`); inspect RSVP counts (`Tham gia`, `Có thể`, `Không tham gia`) and participant list.
9. **Poll**: From Activity detail, open `Bình chọn` -> `Chọn địa điểm`; inspect vote counts, `Danh sách người bình chọn`, and `Kết quả bình chọn`.
10. **Task / Discussion**: From Activity detail, open `Công việc` (`Chuẩn bị đồ dùng`) to inspect assignee/status history, and scroll to `Thảo luận` on Activity detail to view parent comment + 1-level reply.
11. **Finance (Expense / Balance / Fund)**: Open `Chi tiêu & Thanh toán` (`60.000 ₫` equal split, `30.000 ₫` pairwise balance) and `Quỹ nhóm` (`Đợt thu` / `Sổ cái` / `Hoàn ứng`).
12. **Search / Notifications / Calendar / Profile**: Test Global Search (`Tìm kiếm` across people/groups/activities/chat), Notification Center (`Thông báo` unread badge & tap navigation), Calendar (`Lịch` Oct 20 event & reminder toggle), and `Hồ sơ` (`Mã QR cá nhân` & privacy settings).
13. **7–10 Minute Demo Rehearsal**: Run through steps 1 -> 8 -> 3/4/5 -> 7 -> 9/10 -> 11 -> 12 in one continuous 8-minute teacher walkthrough.

---

### Historical continuation — 2026-10-18 ~15:06 local

- Genuine **P1 invite-code corruption fixed**: default display/copy/share and custom copy lowercased opaque codes; custom display uppercased them. Exact server lookup rejected displayed code404. Removed all6 case transforms, no API/schema/validation change. Four new mixed-case display/clipboard regressions pass; focused11PASS, full Flutter **745PASS/44s**, analyze **clean/5.2s**. Both matching builds and in-place installs PASS.
- Physical fixed iPhone displays exact code; Samsung preview resolves correct new disposable group and JOIN succeeds. Evidence `/tmp/wedo-invite-fixed-preview-physical.log`, `/tmp/wedo-invite-fixed-joined-physical.log`, USB response`1a14e0a3a6f`. New fixture `PRE-M19 Group Lifecycle Lab18-10` was created through iPhone UI; main QA group untouched. Subsequent lifecycle checks are still in progress, not full PASS.
- Full portrait thumbnail225×400 and portrait viewer428×760.9 now verified on iPhone. Known highres sample renders4:3 fullscreen428×321 and doubletap2.5×; stored image remains picker-optimized, not pre-picker4000×3000. Evidence `/tmp/wedo-portrait-current-iphone.png`, `/tmp/wedo-highres-current-iphone.png`.
- Group Admin/treasurer round-trip completed/restored on earlier lab. New-fund-from-closed action creates separate zero-balance fund; old closed audit retained. Personal reminder Off15→On30 persisted then restored Off15. All9pushpreferences false roundtrip then restoredtrue; markall25→0, fresh notification1→open exact chat→0; refresh/Back verified. Matrix updated with exact evidence and explicit remaining gaps.

### Latest verified continuation — 2026-10-18 ~14:42 local

- Full Flutter **741 PASS /51s**, analyze **clean /4.8s**. Two added regressions cover known-conversation pending/failed history: loading/error now depends on empty messages, not absent conversation. Focused Chat30PASS; both native builds and in-place installs PASS; Owner/Member sessions and identities retained. No backend/schema/dependency changes.
- Physical Samsung API interruption shows explicit error + Retry, not false empty; restoring8080 reverse then Retry loads real latest history. Evidence `/tmp/wedo-history-error-new-samsung-initial.log`, completed retry session9052. Both8080/9000 connections restored; backend stays UP.
- Fresh two-way text, own edit/unsend, reaction details, delete-for-me isolation, ordered catch-up A/B and unique durable IDs confirmed. Actual fresh Unicode Android background FCM delivered (`GATEWAY_ACCEPTED` plus exact own notification visible), tapping opens correct QA chat. Samsung double-tap2.5×/reset1× also physically confirmed. See full matrix rows F045–F055, F065, F074–F075 for evidence.
- Current new iPhone release PID46894 and Samsung debug candidate are installed. Home balances still Owner receivable30K / Member payable30K in main QA group; main finance unchanged. Full141-family acceptance remains **IN PROGRESS / NOT PASS**. iPhone Save succeeded and new QA asset exists, but protected Photos reopen remains blocked by OS automation accessibility; no passcode stored or entered. Older unresolved-save/739-test/not-installed notes below are historical, not current status.

### Resumed 2026-10-18 14:19 local

Quota/approval stop below is historical: normal reviewer retry succeeded after its13:43 retry window. BackendhealthUP, Mac<QA_LAN_IP>, SamsungADBconnected, iPhoneconnected with passcodeRequired=false. Restored lost Samsung reverse8080/9000; Chat Retry loads successfully. Existing QA history after morning work is preserved. iOS runner session restart in progress (`/tmp/wedo-ios-acceptance/run-142045747076.log`); no passcode entered or recorded. Continue from actual runtime, not stale morning UI assumptions. Full141-family acceptance remains IN PROGRESS, not PASS.

### Latest execution stop — 2026-10-18 ~09:45 local

Normal device-command approval became unavailable: reviewer returned usage-limit failure and said retry after13:43 local or resolve allowance. Samsung critical-chat navigation was **not executed**; do not bypass the check. Last already-approved iPhone batch completed at Chat list (Owner); Samsung remains Member on closed labFund. Runtime left up. Full acceptance remains **BLOCKED / INCOMPLETE**, not app failure and not full PASS.

Further verified physical work: lab settlement10K+20K confirmed, debt0 on both; labFund100K contribution approved after separate cancel/reject tests,30K expense,20K reimbursement with reserve; separate10K reimbursementcancel/reject tests. Three permitted opposite ledger reversals restore fund0 while retaining all6 entries. First collectionclosed, secondcancelled, then zero-balance fundclosed; Member sees closed read-only history. Main QA group/money unchanged. Current source-derived inventory141 families (new closed-fund Open New Fund action added), many still not executed/partial. No extra commits/builds/source changes since739PASS/analyzeclean.

### Latest verified continuation — 2026-10-18 ~09:20 local (supersedes older blockers below)

- Full Flutter **739 PASS /52s**, including two-pointer viewer regression; analyze **clean /6.8s**. Logs `/tmp/wedo-image-full-tests-final.log`, `/tmp/wedo-image-analyze-final.log`; current native candidates installed on both phones. No clean/stage/commit/push/reset.
- iPhone physical pinch **1.3×**, translated pan, double-tap reset/2.5× and exact-chat return now **PASS**. USB responses `1a14cc9fda8`, `1a14ccc8da3`, `1a14ccce03b` under `/tmp/wedo-ios-usb-response-<id>.json`.
- iPhone **Save now succeeds** after authentication (`run-090046263132.log`); Photos filtered lookup finds the new09:00 QA asset (`run-090213446968.log`). Actual saved-image reopen/metadata is still **BLOCKED** by protected Photos authentication, whose OS UI exposes no input controls to XCTest. No passcode entered or copied into artifacts; no blind guessing/bypass/global setting changes. This is not evidence of a weDO Save failure or Screen Time restriction.
- Fresh Owner text appears in Samsung foreground banner; expired thumbnail Retry reloads successfully. Automatic refresh of expired thumbnail URLs remains a possible P2 follow-up.
- Member-created capacity1 Activity is visible on Owner. Lab Poll options add/edit/disable/delete and vote/result counts tested on Samsung. Lab task claim removes Claim button and shows Member assignment; dated task completion appears on Owner's task list. Main demo finance/membership preserved.
- Inventory now **140 scenario families**, still IN PROGRESS with many NOT EXECUTED/PARTIAL rows. No full acceptance or user-test readiness claimed.

### Latest continuation — 2026-10-18 morning

Full Flutter **739 PASS** (59s), analyze clean. Two new regressions distinguish PhotoKit restricted/unavailable from denied; native iOS and UI now return precise sanitized feedback. Temporary authorization NSLog diagnostics removed. Updated iPhone release installed; latest Android APK built, installation pending completion of an open fixture form.

Important correction to earlier permission hypothesis: actual screenshot immediately after **Save** shows a **Face ID challenge** (`/tmp/wedo-ios-acceptance/shots-085244331029/7495D9AF-072A-469D-8D7E-2E23E63407CB.png`). This is distinct from the picker challenge. Screen Time/MDM was not demonstrated. Do not ask the user to weaken global privacy; coordinate this biometric gate at Save and retest before classifying the cause. iPhone Save still NOT PASS.

Morning USB UI runner initially timed out twice enabling automation mode (before touching app UI); rebuilding the external runner and user keeping iPhone unlocked restored it. Do not classify test-runner transport initialization failures as an app crash. Full-application pinch injected by XCTest did not demonstrate zoom; the helper was corrected to target the media image, and the actual pinch retest is pending.

Samsung lab invitation accepted through UI; owner/member list and owner-only settings warning/read-only switches confirmed. Activity log/empty list and blank-create validation checked; isolated capacity-one fixture creation ongoing. Lost overnight USB reverse ports restored without resetting session. Runtime remains healthy at<QA_LAN_IP> with12–13GiB free and all retained data preserved.

Authoritative current inventory: [Full functional matrix](PRE_M19_FULL_FUNCTIONAL_MATRIX.md), currently 139 scenario families, with unfinished rows explicitly NOT EXECUTED. A family only passes when all its listed actions pass; this is not 139 completed tests. Earlier 50-point PASS below is historical and insufficient for the expanded request.

### Current automated/build evidence

- Full Flutter: **737 PASS** (`/tmp/wedo-image-full-tests.log`, 72s). New image-focused suite: **11 PASS**; existing Chat regressions also passed in full run. Analyze **No issues found** after removing an unnecessary test import (`/tmp/wedo-image-analyze.log`).
- iPhone release / canonical Firebase Android debug builds and in-place installs PASS, existing sessions retained. No package/dependency/migration/backend changes. iOS local bundle/signing preserved; never include the whole local project/Info.plist diff in an eventual product commit.
- New product source: intrinsic-ratio thumbnail + private original-byte viewer, bounded decoding, InteractiveViewer, double tap, close/back, reauthorization on Save, streamed download capped at 10 MiB, signature-derived MIME and no bearer forwarded to storage. Original bytes sent through a small platform channel to PhotoKit add-only / MediaStore. Native handlers reject unsupported/oversized payloads, serialize saves and return sanitized errors.

### Current physical evidence (not historical)

- Fresh Samsung → iPhone: four synthetic neutral cards in one durable message **seq16**, visible on both. Source cards portrait 900×1600, landscape 1600×900, square 1200×1200, highres 4000×3000. Existing picker policy (`imageQuality:88`, max2048) optimizes before upload; do not claim the stored highres object remains 4000×3000.
- Fresh iPhone → Samsung: only previously imported neutral logo selected after user Face ID; preview inspected before Send. Durable **seq17**, visibly rendered on Samsung. No personal photo uploaded.
- Thumbnails visibly preserve portrait/landscape/square geometry without colored image-only bubbles. iPhone viewer double-tap reached 2.5× and panned. Samsung USB UiAutomator pinch/pan test passed with an assertion that the viewer actually exposes a changed zoom value; injection alone is not the evidence. iPhone physical pinch and all-image viewer traversal remain pending.
- Samsung Save → success feedback → actual Samsung Gallery reopened the generated image. Saved file byte-for-byte matches the **stored landscape object**: SHA256 `0e48bc99299fdf26337cd55c6b3f62559b8ae8a044a028100cc8b5f617201d38`. Do not compare this with the pre-picker source and call the existing picker recompression a new Save defect.
- iPhone Save repeatedly returns permission-denied feedback. Own-app Settings → Photos shows “Truy cập riêng tư” without add permission controls. Photos picker additionally required Face ID (user handled it); that allowed selection/send but has **not** established successful save. Global privacy/Screen Time settings have not been changed by the agent. Awaiting user's explicit choice/permission resolution; **iPhone Save NOT PASS**.
- Samsung profile form unchanged Save, username form, password empty-field validation, personal QR and privacy toggle save/reopen checked. Temporary discoverByPhone change restored to false and verified through supported API. Does not establish complete profile/username/privacy action-family PASS yet.
- Samsung Calendar previous/next month, agenda, group/RSVP filters, clear filters/day selection exercised. Fresh full Notification/Finance/Group management/action fixtures still pending.
- Isolated supported-API fixture group `PRE-M19 Acceptance Lab 2026-10-17` (`a3c7a9d6-32dd-4a5c-b5d0-804cc5636002`) created for safe lifecycle/finance checks. QA Owner owns it; QA Member 1 invitation `9feb588c-4845-4400-a519-e093ef9f6923` initially pending. Main QA group/finance untouched. API setup is not physical creation acceptance.

### Current outstanding / severity / readiness

- Full acceptance **NOT READY / IN PROGRESS**: iPhone save authorization unresolved, physical pinch/save-reopen, fresh text/reconnect/FCM retests and most action-family inventory remain incomplete. No invented PASS and no fabricated full coverage count.
- No demonstrated new P0. iPhone Save is a required acceptance blocker, cause still being investigated (do not assert an OS restriction without evidence). No new P1 fix claim. Prior lifecycle P1 fix remains preserved. Historical P2 feedback remains, and QR's English UI is now physically confirmed; not a blocker by itself.
- Runtime remains UP on `<QA_LAN_IP>`, retained containers/credentials preserved; disk ~12 GiB free after builds, no cleanup. Start/stop commands below remain local helper commands; no global restart or extra volumes.

- New responsive intrinsic-ratio image thumbnails, private fullscreen viewer, zoom/pan/double-tap and original-byte gallery save are being implemented locally. No backend/schema changes.
- iOS add-only Photos authorization on Save; Android MediaStore scoped write (legacy storage permission limited to API <=28). No new third-party dependency. Session bearer stays on API authorization, never forwarded to storage.
- Initial focused tests exposed thumbnail tight-constraint sizing and retry callback defects; both corrected before device installation. New physical results are pending; historical results must not be promoted to current PASS.
- All protected credentials, Mac-local signing/network changes and retained demo data are preserved. No cache/build cleanup.
- Platform references: [Flutter InteractiveViewer](https://api.flutter.dev/flutter/widgets/InteractiveViewer-class.html), [Apple Photos](https://developer.apple.com/documentation/photos/phphotolibrary), [Android shared media](https://developer.android.com/training/data-storage/shared/media).

## Historical 50-Point Handoff — 22:51 Local (earlier walkthrough, not full acceptance)

| # | Result |
| --- | --- |
| 1 | Mac workspace: `<REPO_ROOT>`. |
| 2 | Discovered branch was `feat/m16-media-search`, HEAD `a1e28a06d88199bb0ea3f3663596bd9a729819ff`, with intentional Mac-local iOS changes. |
| 3 | Local signing/LAN changes and stash preserved. Initial exports were temporary and later disappeared; current live iOS diff additionally exported to `/tmp/wedo-mac-ios-local-current.patch`. Never discard the live worktree based on an old handoff. |
| 4 | Final branch `feat/pre-m19-ui-polish`; unchanged HEAD `cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`, plus the two unstaged Chat source/test files below. Remote dev remains unmerged. |
| 5 | Final Mac LAN **<QA_LAN_IP>**. iPhone observed **<QA_LAN_IP>**. Earlier `.100.33` and temporary hotspot `.10.3` are stale. Keep this network stable. |
| 6 | Index empty; intended product/docs changes and preserved local-only files only. Protected stash unchanged; no unexpected paths. |
| 7 | PostgreSQL 17.11 healthy; real `select 1` succeeds; Flyway latest V12 successful. Exact historical volume retained; loopback 55432. |
| 8 | Redis responds PONG, loopback 6379, retained volume. |
| 9 | AIStor readiness succeeds on loopback and final LAN 9000; existing private/new logo media renders. Console stays loopback 9001 only. Exact retained volume/license reused. |
| 10 | Backend loopback dependency-aware `/actuator/health` UP, including DB/Redis/disk; custom liveness alone was not used for acceptance. |
| 11 | Backend LAN health succeeds at final address, with actual iPhone requests/login/Home/media confirmed in safe access logs. |
| 12 | All five supported QA accounts authenticate again at final audit. Existing QA group/finance retained; prepared one clean future Activity/Poll/Task. No QA reset. |
| 13 | Physical Samsung `<QA_ANDROID_SERIAL>`, SM_G975U1, authorized. USB reverse 8080 and 9000 only. |
| 14 | Real-Firebase canonical Android build PASS, final fix build 124.5s; in-place install/launch PASS. APK SHA256 `d7567556f9203358d737ab1d026c843e2fd05d3852f37c7a55df31284a42f67d`. Windows-signed original was replaced only after user approval. |
| 15 | Samsung uses existing localhost/reverse API mechanism; live reads/sends/FCM registration PASS. |
| 16 | QA Member 1 login/Profile/Home, Groups/Invitations, Chat, Calendar, Search and Notifications exercised. Correct localized role/name; no demonstrated clipping/mojibake/raw UUID blocker. |
| 17 | Physical iPhone QA iPhone, 13 Pro Max, `<QA_IPHONE_UDID>`, available over USB. No simulator. |
| 18 | Preserved local signing works. No signing identity or secret value is included here. |
| 19 | Final iPhone release build PASS, 35.1s, 23.7MB, current LAN define and Chat fix; in-place install/launch PASS. |
| 20 | Actual iPhone LAN connectivity and Local Network permission verified; login/refresh/Home, chat and logo upload work on final network. |
| 21 | iPhone QA Owner identity/Profile/Home, group members/roles, Activity/Poll/Task/Discussion, Finance and Calendar physically inspected. USB XCTest performs typing/taps; user only handled device/network/biometric gates. |
| 22 | Owner Vietnamese greeting arrived live on Samsung without reload; post-fix Owner push message and image also arrived correctly. |
| 23 | Member reply arrived live on iPhone without reload; final rebuilt-Samsung readiness message also observed live on final rebuilt iPhone at 22:50. |
| 24 | **Fresh iPhone → Samsung image PASS:** only imported neutral repository logo selected, uploaded as durable message sequence 11 and visibly rendered on Samsung. No personal photo uploaded. Optional reverse-direction fresh image was not repeated. |
| 25 | Samsung app interrupted; iPhone sent three messages while away. Reopen caught up automatically with all three, without tapping Reload. This is physical app interruption/reopen recovery, not a claim of a new network-partition stress benchmark. |
| 26 | Catch-up messages sequences 12/13/14 appear once, in order, with correct sender; REST history agrees. Prior reconnect/overlap automated coverage remains green. |
| 27 | Prepared Oct 20 10:00–11:30 Activity; physical Member RSVP persisted. Owner sees 1/10 and one registered participant, correct local time/organizer. No ownership mutation. |
| 28 | Member voted Quán cà phê; Owner physical Poll shows 100%, one vote, Công viên zero. Selected-state contrast verified on Samsung; no duplicate Poll created. |
| 29 | Assigned Task changed through Samsung to Đang thực hiện with status history; Owner sees same status. One labelled Discussion comment + one-level reply rendered on both; permitted own edit/delete menu inspected without deletion. |
| 30 | Samsung Month, Oct 20 agenda Activity and RSVP filters PASS; iPhone Calendar month inspected. Reminder UI visible on Activity; no artificial reminder delivery claim. |
| 31 | iPhone existing Expense detail/list, Balance and empty Settlement history, Fund and one open collection read successfully. Expense 60.000 ₫, Owner receivable/Member payable 30.000 ₫; collection 100.000 ₫ / two members. No financial mutations. |
| 32 | Samsung Global Search opened and returned correctly for all four typed destinations: QA Admin public Profile, QA group, clean demo Activity, same conversation. |
| 33 | Samsung Notification Center readable; tapping one unread Chat entry opens exact conversation and reduces unread 17 → 16. System push deep link separately verified. |
| 34 | Real Android client config supplied locally and used; protected untracked file never printed/committed. |
| 35 | Real external Firebase Admin credential used by SDK; no dummy configuration used for final push claim; contents never printed or placed in Git. |
| 36 | Fresh canonical Android registration active, observed again after final app update/reopen; no token values printed. Historical invalid token was automatically deactivated by provider handling, not manually edited. |
| 37 | **Background FCM PASS:** Samsung backgrounded directly from Chat; actual Owner message recorded GATEWAY_ACCEPTED and appeared as a new Samsung system notification with exact rehearsal text. |
| 38 | Tapping that actual new notification opens weDO QA Team conversation with the correct message. |
| 39 | No remaining Firebase environment blocker. iPhone/APNs push intentionally excluded. |
| 40 | Paired timed-ish feature walkthrough completed around 22:36–22:47, roughly 10–11 minutes including automation snapshots; final extra realtime sanity followed. Technical setup/build/network recovery excluded. Clean teacher narrative targets 8–9 minutes, not a fabricated stopwatch result. |
| 41 | Recommended flow: Home/roles 1m → Activity/RSVP 1m → text/image/reopen 2m → Samsung background push/tap 1m → Poll/Task/Discussion 1.5m → Expense/Balance/Fund 1m → Search/Calendar/Home 1m. |
| 42 | One understandable future Activity/Poll/Task and existing Expense/Fund retained. Rehearsal messages are clearly labelled; no arbitrary deletion/renaming of existing records. |
| 43 | No demonstrated unresolved P0. |
| 44 | One genuine P1 discovered and fixed locally: invisible Chat subscription suppressed background push; focused red/green + actual fixed background delivery/tap PASS. No demonstrated unresolved P1. |
| 45 | Non-blocking feedback: English welcome marketing/buttons; Group Info back icon lacks an accessibility label (normal navigation works); queued actionable SnackBars can cover the composer during accessibility automation until opened/dismissed. Also investigate old past-Activity Search status versus derived list status before calling it a confirmed defect. No unsolicited redesign. |
| 46 | Product changes only `chat_screen.dart` + its lifecycle regression test. Observer releases subscription/typing when invisible, prevents background read marks, restores subscription and bounded REST catch-up on resume. No backend/API/schema change. Affected Chat suite **28 PASS**; full Flutter **726 PASS**; analyze clean. |
| 47 | Mac-local signing/bundle/ATS/Local Network files and generated SwiftPM resolution files remain local-only. Current IP supplied via build-time define, not hardcoded into Dart. Temporary helpers/USB UI runner/logs outside Git. |
| 48 | This acceptance report and dynamic handoff updated, intentionally unstaged. Older work log below retained as historical evidence, not current blockers. |
| 49 | Backend + all three weDO dependencies LEFT RUNNING; all three initially running unrelated Docker containers restored/running. Both candidate apps installed and handed off at Home. |
| 50 | User can pick up iPhone Owner and Samsung Member and test immediately on this Wi-Fi. Review local P1 diff and P2 feedback; any commit/push/dev merge still requires separate explicit authorization. |

### Final Runtime / Verification Boundaries

Final Git classification (all unstaged): **A** = Chat screen lifecycle source + regression test; intended documentation = this report/current handoff. **B** = two tracked iOS signing/LAN files + two untracked generated SwiftPM Package.resolved files, Mac-only/do not commit. **C** = protected untracked Android Firebase config, existing stash and protected local paths, untouched/out of commits. **D** = no unexpected paths. Index empty and diff check clean; base/feature/dev refs unchanged.

- No volume deletion, cache/build cleanup after user prohibition, database reset, stage, commit, push or M19 work.
- Backend standalone package reused; no new backend suite run because backend product code did not change.
- Final bounded Samsung sample: 730 app-process log lines, zero fatal/unhandled/RenderFlex/overflow/reconnect/refused matches. Backend latest sample: no ERROR; one expected historical invalid-token warning, followed by successful fresh delivery. iPhone USB snapshots/assertions and console connection succeeded; attaching to an already-running release app produced no new app stdout, so this is not a full iPhone runtime-log audit. External XCTest focus/transport retries are not app crash evidence.
- Fresh photo upload used only the repository logo after user Face ID. Temporary read-only fixture server stopped; no LAN device-control server was used.
- User changed Wi-Fi during earlier attempts; final IP is verified at handoff. If it changes, stop/restart helpers to update media bindings and rebuild iPhone with the new `WEDO_API_BASE_URL` define. Do not reuse stale IPs.

### Current Start / Stop Commands

Helpers are Mac-local under `/tmp` and may disappear after reboot. Start command was verified idempotent against the running stack; stop helper syntax/target validation checked without stopping the handed-off environment.

```sh
# Foreground startup; starts retained weDO containers, never deletes volumes.
bash /tmp/wedo-mac-demo-start.sh

# Stop only the verified recorded weDO backend process.
bash /tmp/wedo-mac-demo-stop.sh

# Stop backend and only weDO's three containers; unrelated workloads stay up.
bash /tmp/wedo-mac-demo-stop.sh --infra
```

Final backend log/PID: `/tmp/wedo-mac-demo-backend.log`, `/tmp/wedo-mac-demo-backend.pid`. Safe access logs contain method/path/status/address only, never query/body/token. Firebase credentials remain external/local-only; do not publish raw logs or local config.

## Historical Work Log — Superseded by Final Handoff Above

### Historical Retest — 22:36 Local

Final detected Mac LAN is **<QA_LAN_IP>** after user network changes (temporary hotspot was <QA_HOTSPOT_IP>; earlier <QA_LAN_IP> is stale). Dependencies are healthy and all six retained containers run. Current iPhone/Android builds include the unstaged genuine blocker fix below; candidate Git HEAD remains unchanged.

- iPhone QA Owner login and all five Home sections PASS. Actual Owner Vietnamese greeting and Samsung Member reply appeared on the other physical device without manual reload (durable seq7/8). Samsung fresh real FCM registration confirmed by platform/status/timestamps only.
- **MAC-01 / P1 — background push suppression:** Samsung backgrounded from open Chat remained subscribed; actual Owner message seq9 recorded `SUPPRESSED_OPEN_CONVERSATION`, so no fresh push was delivered. Narrow Chat lifecycle fix unsubscribes/stops typing when invisible, suppresses background read marks, resubscribes and catches up via existing bounded REST recovery on resume. No backend/API/schema change. Regression RED before fix; Chat screen suite GREEN 28, full Flutter GREEN **726**, analyze clean. Both updated builds and in-place installations PASS; real push/reconnect retest is still pending, not a push PASS.
- Samsung Task assignment/due date/status mutation to **Đang thực hiện** PASS; labelled Discussion comment and one-level reply render correctly; own edit/delete menu inspected without deletion.
- Fresh logo upload is NOT accepted yet: user changed network during the first send, no new attachment persisted. Only the repository's neutral logo was imported/selected after user Face ID; no personal photo was uploaded. Retry on final network is required. Temporary single-image read-only fixture server stopped.
- No staging, commit, push, M19, cache cleaning, data reset or volume deletion. Remaining Owner Activity/Poll/Task observation, image, interruption/reconnect, real Samsung background push/tap and timed rehearsal must finish before PASS.

### Historical Checkpoint — Infrastructure Blocked (15:00+ Local)

**22:00 local recovery update (supersedes infrastructure blocker):** User approved global Docker Desktop restart/restoration. Normal restart and quit stalled; only inspected hung Docker components were terminated, no files or volumes removed. All six retained containers are now running, including the three unrelated workloads. PostgreSQL actual query PASS, Redis PONG, AIStor readiness PASS, and restarted backend actuator health UP with DB/Redis UP. Free disk ~21 GiB; no build/cache cleaning. Earlier `/tmp` helpers disappeared; recreated startup helper and USB-only XCTest runner, using the existing backend JAR and installed candidate apps. Samsung USB forwarding restored. iPhone actual welcome screen captured; automated Owner login and remaining two-device acceptance are in progress. No two-device PASS claimed yet.

This section supersedes the earlier in-progress status below. User approved replacing Samsung's Windows-signed app; replacement, canonical real-Firebase launch, Member 1 login and fresh FCM token registration succeeded. Token values were never printed. Temporary `.macdemo` app remains installed but force-stopped. Its obsolete `/tmp` APK duplicate was removed only to permit handoff writes; canonical Firebase APK and all build/cache directories remain intact. Prototype APK is rebuildable through the external helper.

Agent-operated iPhone XCTest through Xcode/USB works without manual typing or a LAN control server. Safari on actual iPhone `<QA_LAN_IP>` reached Mac health endpoint HTTP 200, and weDO's **Mạng cục bộ** permission is ON. iPhone app Chat load error remains unaccepted while dependencies fail. No two-device/PUSH PASS is claimed. The separate Owner REST push diagnostic timed out at login; **no diagnostic Chat message was sent**.

Disk repeatedly filled again (ENOSPC, ~100 MiB free, despite temporary recovery to ~3 GiB). PostgreSQL accepts TCP 55432 but fails to respond to startup protocol within 4s. Hikari has zero connections and 30s acquisition timeouts; dependency-aware actuator health times out. Simple `/api/v1/health` is liveness only and can misleadingly say UP with DB unavailable. Storage readiness still returns 200. Docker read calls and the scoped PostgreSQL restart command hang. The verified backend was stopped to avoid repeated DB errors; retained infrastructure cannot be called healthy.

Global Docker Desktop restart awaits the pending explicit user choice because it would interrupt initially-running unrelated `englishflow-postgres`, `breast_cancer_web`, `breast_cancer_api`. No global reset/restart, volume deletion or QA reset performed. Enough stable disk and Docker/database recovery are required before actual Chat/image/reconnect/push and timed rehearsal. Both current apps remain installed. No product changes, stage, commit, push or M19 work. No further build/cache cleaning after user's instruction. See latest agent handoff for exact recovery context.

### Historical Environment and Git

- Workspace: `<REPO_ROOT>` on Apple Silicon, macOS 26.2.
- Previous branch: `feat/m16-media-search`, HEAD `a1e28a06d88199bb0ea3f3663596bd9a729819ff`.
- Acceptance branch: `feat/pre-m19-ui-polish`, HEAD and fetched remote `cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`.
- Fetched remote dev: `a3810701b747520cae25c8f3a0706c3296703c76`; no dev merge or branch update performed.
- Flutter 3.47.1, Dart 3.13.1, Java 21.0.5, Xcode 26.6, CocoaPods 1.16.2, Docker CLI 28.5.1, Compose 2.40.3.
- Current default interface: `en0`; LAN IPv4: `<QA_LAN_IP>`. Re-detect after network changes; rebuild the iPhone API define if it changes.
- Exact pre-existing tracked iOS diff exported to `/tmp/wedo-mac-local-before-pre-m19.patch`; two generated Package.resolved files backed up under `/tmp/wedo-mac-local-before-pre-m19/`. Branch switch carried compatible local modifications forward; no stale Dart/Java patch reapplied.
- Actual Mac stash: `On feat/m2-auth-security: local ios signing config`. Preserve it. The Windows protected stash is not present in this clone; none was created, applied, popped, or dropped.
- No staging, commit, push, merge, rebase, database reset, or volume deletion.

### Historical Runtime

The repository runner is Windows-specific. The old `/tmp/wedo-demo-compose.yml` no longer existed; existing container labels identified its historical Compose project and named volumes. A Mac-only replacement reuses those exact volumes. An unrelated application's PostgreSQL owns host port 5432 and was left running.

| Service | Mac acceptance configuration / evidence |
| --- | --- |
| PostgreSQL | Retained `wedo_wedo_postgres_data`, host loopback 55432; PostgreSQL 17.11; Flyway V0–V12 validated, schema current at 12 |
| Redis | Retained `wedo_wedo_redis_data`, loopback 6379; TCP reachable |
| AIStor | Retained `wedo_wedo_minio_data`; external license existence checked only; readiness HTTP 200 at loopback and LAN 9000 |
| Storage console | Loopback 9001 only; never reversed to a phone |
| Backend | Current checkout, `local` profile, supported QA seed enabled; port 8080; localhost and LAN `/api/v1/health` HTTP 200 / UP |
| Media signing | Backend internal endpoint loopback; public signing endpoint current Mac LAN port 9000, reachable by both phones on the same Wi-Fi |
| Samsung API | `WEDO_API_BASE_URL=http://127.0.0.1:8080`; ADB reverse only 8080 and 9000 |
| iPhone API | `WEDO_API_BASE_URL=http://<QA_LAN_IP>:8080`; same LAN required; existing local ATS/Local Network settings retained |

An initial disk-full condition caused Xcode error 74 and Gradle `No space left on device`. Space subsequently recovered; no user files or Docker volumes were deleted by this session. Retain several GB free for reliable operation. Later, completed build outputs (including the already-installed iPhone build's host artifact) and a Gradle transform entry disappeared while free space rose to about 15 GB. Cause was not established; a fresh Gradle process was required. Do not clean build/cache folders concurrently with acceptance builds. The successful iPhone build/install evidence predates the host artifact's disappearance.

Docker management commands later stalled while service ports remained reachable. Backend restart bypassed Compose through `WEDO_DEMO_SKIP_INFRA=true`. Do not restart Docker Desktop globally without considering unrelated running applications.

User subsequently confirmed manually removing old build outputs and Gradle/Xcode caches to free space; cleanup is finished. A live Home failure was traced to `NoClassDefFoundError: ExpenseService$PairKey` after compiled backend outputs disappeared. Rebuilt generated outputs with Maven `clean package` (tests skipped, no source edits), packaged successfully in 9.442s, and copied the standalone JAR outside build folders to `/tmp/wedo-pre-m19-backend.jar`. Restarting that JAR restored Home on API and physical Samsung. Helpers now prefer the standalone JAR. This was a local runtime recovery, not a product-code fix. Core API smoke and LAN media/private-read checks passed again after recovery.

### Historical QA Data and API Evidence

All five supported QA identities authenticated successfully. Intended physical roles: iPhone = Owner; Samsung = Member 1. Both are active members of the retained `weDO QA Team` with four active members.

Owner and Member 1 API reads returned HTTP 200 for Home (all five sections), group detail/members, Activities, Chat conversations, Calendar, Expense, Balance, Settlement list, Fund, Search, Notification Center and unread count. This is API evidence, not physical screen acceptance. Initial dataset: one existing Activity, one Expense, no Settlement records, existing Fund and one collection. The initial smoke helper's `fundExists=false` was a helper field-name error (`id` versus `fundId`), not absence of a Fund; direct supported response confirmed `Quỹ nhóm`.

Typed Search fixtures: People 4, Groups 1, Activities 2, Conversations 1. Existing Chat image signed read through current LAN endpoint returned HTTP 200 (518,915 bytes); unsigned access returned 403. Storage keys/signed URLs were not printed. This does not replace fresh upload/rendering acceptance on both phones.

Created through supported APIs, without deleting or renaming existing rows:

- One Activity: **Demo nhóm weDO — Cùng lên kế hoạch**, October 20, 2026, 10:00–11:30 local; capacity 10; ID `c81b9fff-ac99-4a97-957e-ebee6059e49d`.
- One single-choice Poll: **Chọn địa điểm**, options **Quán cà phê** / **Công viên**, public votes with immediate results. Member 1 subsequently voted **Quán cà phê** through the physical Samsung UI; server response displayed one vote.
- One Task: **Chuẩn bị đồ dùng**, assigned to QA Member 1, due October 20 at 09:30 local. Left ready for a device status change.
- Existing Expense, balances, Fund and collection retained. No new financial mutation or ownership change.
- Member 1 submitted **Tham gia** through Samsung on the prepared Activity; Activity detail then displayed the caller's participating status. Owner observation on physical iPhone remains pending.

### Historical Verification and Devices

| Gate | Current result |
| --- | --- |
| Flutter analysis | PASS, no issues |
| Complete Flutter suite on Mac | PASS, 725 tests, exit 0 |
| Backend tests | Not rerun; no backend product changes; prior candidate evidence remains historical |
| iPhone detection | Physical `QA iPhone`, iPhone 13 Pro Max, `<QA_IPHONE_UDID>`, iOS 27.0.1 |
| iPhone signing/build | PASS using preserved local signing; fresh release build with current LAN define, 23.7 MB app |
| iPhone installation | PASS, freshly built candidate installed after successful build |
| iPhone auto-launch | PASS after user unlocked it; fresh candidate launched at 14:34 local and console remains attached. Earlier Locked attempts are historical |
| iPhone login/Home/LAN/media UI | NOT VERIFIED; Mac LAN health does not prove phone access |
| Samsung detection | `<QA_ANDROID_SERIAL>`, SM_G975U1; initially unauthorized, subsequently authorized |
| Samsung build/install | Fresh non-push build PASS; canonical update rejected with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. Side-by-side `com.wedo.mobile.macdemo` rebuild PASS (3m51s), install PASS, launch PASS. New real-Firebase canonical APK also built PASS (42s); replacing Windows-signed installation awaits explicit user choice |

The first iPhone installation attempt used an old existing artifact after a failed build. It is not acceptance evidence; the later successful fresh build and install supersede it.

Android client configuration is absent: **ANDROID FIREBASE CLIENT CONFIG MISSING**. No replacement was invented. A local-only Gradle init script disables `processDebugGoogleServices` for a non-push build; the initial task-exclusion attempt failed Gradle provider dependency resolution, then task disabling succeeded. SDK 37.0 and SDK 35 installed through Gradle; a local `android-37` SDK path alias resolves the installed `android-37.0` directory. These are Mac environment changes, not product changes.

Samsung's installed `com.wedo.mobile` is signed with a different (Windows) key. No uninstall/data wipe was performed. The external Gradle init script now assigns `com.wedo.mobile.macdemo` to install the exact same candidate code alongside it. Only the demo package may be used for this Mac acceptance. Standard Firebase client config for `com.wedo.mobile` will not automatically enable push for this alternate package; proper matching registration/configuration or an explicitly authorized replacement of the original app is needed for push. The old app's Home error during failed update/launch is not evidence about the freshly built candidate.

Side-by-side artifact: `/tmp/wedo-pre-m19-macdemo.apk`, SHA-256 `16b47cd6828ff51eb1de57794cb467145d8381c0b60bc7eeb82264cd70ecd8e0`. Real-Firebase canonical artifact: `/tmp/wedo-pre-m19-firebase.apk`, SHA-256 `ca65da6210679e9e2048ed20c27a3fa0d01106cfb628576214a38a965965b88e`. The latter uses the actual supplied client configuration and no non-push task override; it is reviewable and ready for installation after resolving the signing mismatch. Existing app-local data will not be removed without the requested choice.

On the Mac demo package, restored reverse mappings resolved an initial login transport error. Member 1 login then passed. Home, Groups, Chat Home/group conversation, Calendar Month/filter controls, and Profile all opened with live data after backend recovery. Profile identified QA Member 1. Groups rendered the localized Member role and readable responsive action header. Search showed complete category labels; QA results opened QA Admin's public Profile with **Nhắn tin**; return navigation worked. Notification Center showed 12 unread items and readable header/action; tapping the prepared Poll notification opened the exact Activity. Poll selected/enabled state had a white label on purple after settling (`/tmp/wedo-samsung-poll.png`); submitted vote displayed one vote. Task list showed assigned **Chuẩn bị đồ dùng**, due 20/10 09:30, **Cần làm**; status mutation not performed. The welcome screen still has English marketing/button copy (**Squad up.**, **Create Account**, **Login**): P2 feedback, no redesign performed. This is a bounded physical sanity pass, not complete two-device acceptance or a large-font audit.

### Historical Physical Acceptance Ledger

| Flow | Current evidence / remaining check |
| --- | --- |
| Both-device Login/Home/Groups/Chat/Calendar/Profile | Samsung five roots and Member login PASS on demo package; iPhone launch PASS, user login/Home confirmation pending |
| Polished Groups/Invitations/Discussion/Chat/Search/Poll/Notifications/public Profile/Login | Prior Windows results are historical; current Mac physical recheck pending |
| iPhone → Samsung text | NOT EXERCISED |
| Samsung → iPhone text | NOT EXERCISED |
| Image transfer / persistence / rendering | NOT EXERCISED on this candidate/device pair |
| Interruption/reconnect/order/dedup | NOT EXERCISED on this candidate/device pair |
| Group owner identity / role action | API membership available; physical display pending |
| Activity / RSVP | Samsung Member RSVP PASS and caller status rendered; iPhone Owner observation pending |
| Poll vote/results/contrast | Samsung selected/enabled contrast and persisted one-vote result PASS; iPhone observation pending |
| Task status / Discussion comment / one-level reply and menu | Assigned Task list inspected; status/Discussion mutations pending |
| Calendar Month/Agenda/filters/reminder | Samsung Month/filter controls and Activity reminder UI inspected; Agenda/filter mutations/reminder scheduling pending |
| Finance Expense/Balance/Settlement/Fund | API reads PASS; physical formatting/navigation pending; Settlement list empty |
| Search all four categories/destinations/back | API all four nonempty sections PASS; Samsung category labels/People result/public Profile/back PASS; other physical destinations pending |
| Notification Center/read/unread/deep link | Samsung readable unread inbox and Poll → exact Activity deep link PASS; unread decrement/read-state recheck pending |
| Timed 7–10 minute two-device rehearsal | NOT PERFORMED |

### Historical Firebase Boundary

- Initial missing-file/dummy state is historical. User supplied the real Android client file at the expected local-only path and an external Admin credential; existence checked only, neither file printed or committed.
- Android real client build: PASS with canonical `com.wedo.mobile`. Token registration awaits installation/login on that package.
- Backend effective state: **REAL CONFIG AVAILABLE**; standalone backend restarted with the user-supplied real external Admin credential, Spring startup and localhost/LAN health PASS. No provider acceptance or physical delivery inferred from startup.
- Samsung background system push and exact notification tap: **PENDING / NOT EXERCISED** on the fresh real-config candidate. Canonical installation requires resolving the Windows/Mac signing mismatch. The original and side-by-side apps remain preserved pending user choice.
- iPhone/APNs push is outside this rehearsal scope.

### Earlier Proposed Teacher Demo (8–9 Minutes)

1. 0:00–1:00 — iPhone Owner Home → QA group → real members/roles.
2. 1:00–2:00 — Open prepared Activity; Samsung Member RSVPs; Owner refreshes participant state where required by current feature behavior.
3. 2:00–4:00 — Same group Chat, one message each direction and one image; confirm one copy, sender and order. Brief background/reopen for catch-up.
4. 4:00–5:00 — Samsung background, iPhone sends; demonstrate Android push and exact Chat tap only after real configuration and successful rehearsal. Otherwise explain push is unavailable in this local environment and continue.
5. 5:00–6:30 — Member votes on prepared Poll, changes assigned Task, adds a short Discussion/reply.
6. 6:30–7:30 — Existing Expense → Balance → Fund collection; keep financial state simple.
7. 7:30–9:00 — Search a known person/group/activity/conversation, return correctly, finish on Calendar or Home.

No new P0/P1 product defect has been demonstrated. P2 aesthetic feedback remains for the user's physical review; unexecuted flows are not evidence that no defect exists. No product fix was made.

### Historical Local Commands and Next Actions — Obsolete

These earlier helper variants/next actions are superseded. Use **Current Start / Stop Commands** above, not the historical fallback or obsolete non-push build helper below. Local helpers live under `/tmp`, are not committed, and may disappear after reboot:

```sh
# Start retained infrastructure and backend in a terminal (foreground).
bash /tmp/wedo-mac-demo-start.sh

# If infra is already reachable but Docker management stalls:
WEDO_DEMO_SKIP_INFRA=true bash /tmp/wedo-mac-demo-start.sh

# Stop only the verified recorded backend PID.
bash /tmp/wedo-mac-demo-stop.sh

# Stop backend plus weDO's three infra containers; preserve volumes.
bash /tmp/wedo-mac-demo-stop.sh --infra

# Rebuild/install/launch the local non-push side-by-side Android package.
bash /tmp/wedo-mac-android-build.sh
```

Backend output: `/tmp/wedo-mac-demo-backend.log`; build/test logs under `/tmp/wedo-*`. Do not publish unreviewed local logs. Use the external real Admin credential only when supplied; never put secret values in this document or Git.

Remaining user-assisted gates: iPhone Local Network/login/Home confirmation and requested Owner Chat message; approval/choice for canonical Samsung replacement; actual two-device interactions and real-config push. The iPhone is now unlocked/on the same Wi-Fi per user; Firebase files are now available. Current outcome cannot be PASS until required physical gates are exercised. Earlier dummy-runtime log counts are historical; standalone recovered runtime sampled zero fatal/uncaught/overflow markers. This does not erase the diagnosed temporary missing-class 500s before recovery.

### Historical Git Classification — See Final Audit

- A — Product changes due acceptance bug: none.
- B — Mac local-only: preserved `mobile/ios/Runner.xcodeproj/project.pbxproj`, `mobile/ios/Runner/Info.plist`; two untracked generated SwiftPM `Package.resolved` files. Do not include in a later product commit. External runtime helpers and SDK alias remain outside Git.
- C — Protected local-only: newly supplied untracked `mobile/android/app/google-services.json`, existing stash and all protected docs/design/runtime paths preserved; no manual edits to protected runtime/log directories. External Admin credential remains outside Git.
- Acceptance documentation: this report and current agent handoff, intentionally unstaged.
- D — Unexpected: none observed at preparation checkpoint; rerun final Git audit at handoff.
