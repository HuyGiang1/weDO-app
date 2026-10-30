# Modern Minimalist Monochrome redesign — 2026-10-28

## Authority and change boundary

[DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) is the single source of truth for actual tokens/components, navigation and accessibility. This file records delivery/migration/evidence, not an independent competing design system. AGENTS.md now explicitly requires reading it before Flutter UI work and retains the complete startup, source-authority and safety protocol.

User authorizes presentation/layout/theme/navigation placement only. Existing branch `feat/pre-m19-ui-polish`, HEAD `cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`, dirty worktree and stash preserved. No backend/API/schema/domain/model/repository/service/business/auth/privacy/realtime/notification/media behavior changes in this task. No QA operations/reset, volume deletion or Secondary iPhone interaction. Existing permission checks, callbacks/controllers, source IDs, form values and money formatting remain.

A pre-edit snapshot of Flutter sources/tests and AGENTS.md exists outside repo at `/tmp/wedo-mono-baseline/`, hashes `/tmp/wedo-mono-baseline-hashes.json`. Task-only diff `/tmp/wedo-mono-task-only.diff` distinguishes this work from hundreds of older dirty changes. Do not attribute the entire git diff to Monochrome.29 production Flutter files and5 tests currently changed; every production path is theme, visual presentation or expressly authorized shell/navigation wiring. No dependency added.

## Delivered batches

### A — Theme, five destinations and Home

One shared adaptive monochrome ColorScheme, neutral fixed accent roles,12px fields/cards/dialogs/buttons, restrained title weights, no decorative gradients/shadows. Light page white/foreground#0A0A0A/secondary#FAFAFA/border#E5E5E5/muted#737373; dark page#0A0A0A, elevated neutral surfaces and readable off-white. Exact palette is in DESIGN_SYSTEM and AppTheme, not generated purple defaults. Semantic success/warning/error remain only for actual states.

Exact order: **Cộng đồng | Trang chủ | Tin nhắn | Lịch | Hồ sơ**. New shared AppBottomNavigation uses existing retained MainTabRoute host. GroupsBottomNavigation remains a compatibility adapter for old callback indices, not a second bar/system. Existing group pages select Home's position and remain reachable through Home's explicit “Tất cả nhóm” action/recent groups and all existing typed routes.

Community is the existing CommunityScreen/API/read/filter/pagination/composer/post/recruitment implementation with a root-tab presentation flag. No second feed state/store/socket. Bare Community/Chat/Calendar tab routes get their existing typed arguments through WeDoApp; existing explicit arguments/auth guards remain valid. Group list is a normal detail destination now; its helper pushes without removing the retained tab host. No Navigator replacement, duplicate GlobalKeys or new nested stack architecture.

Home's same controller and state are composed as: compact weDO+notifications header → existing pending actions → upcoming activities → groups + All Groups → exact finance summary/links → recent updates. Existing group/activity/balance/action/update callbacks, load/error/cached state and pull-to-refresh retained. Removed only redundant top Community shortcut, replaced by genuine tab. No invented greeting, status, totals, query, ranking/sorting/filtering or data transformation; date/time remains presentation formatting of existing model values.

### B — Root coherence

Community root uses the canonical bar and outlined compose icon, existing filters/actions/posts. Messages/Calendar inherit shared monochrome surfaces/controls and keep existing lifecycle/data. Profile header made smaller, reduces redundant spacing/heavy heading and uses12px themed CTA; all actions/identity fallbacks retained. Shared bar fits narrow Vietnamese labels and keeps existing keyboard unfocus behavior.

### C/D — Shared components and consistency sweep

PrimaryButton now uses shared theme/12px shape with its exact callback/loading API (no pill/shadow). Auth buttons/containers use restrained radii, OTP boxed8px, welcome gradient removed. Removed decoration-only shadow lists from existing Auth/Profile/Social/Group/Fund/Discussion visual components. Notification category palette becomes neutral and fixed colorful surfaces use adaptive tokens; category/event/actions remain unchanged. Group activity log uses theme neutral/danger color choices with exact existing messages/actions. Group invitation surfaces/radii align. All current12px outlined form/controllers/validation remain from prior polish.

Chat bubbles/media/Poll cards, Activity/Journey/Stop/evidence/Poll-to-Action, financial state/calculations, membership/admission and Community privacy are untouched functionally. Root placement naturally retains existing widget subscriptions; no subscription/transport source changed.

## Screens coverage / pending migration

| Area | Implementation state | Evidence / limits |
| --- | --- | --- |
| Home | IMPLEMENTED | Actual production widget screenshots in both themes/two sizes/1.5×; existing callbacks/empty/error tests. |
| Five-tab shell | IMPLEMENTED | Exact5/order/selection, real Community state+scroll identity, feed read count1 across returns, typed args, Group detail/back retained host, auth/deep links/back/reduced motion focused tests. |
| Community | IMPLEMENTED | Same loaded feed/cards/filters/actions, root bar, no second state. Widget fixtures are isolated, not real QA posts. |
| Messages / Calendar | IMPLEMENTED shared visual policy | Both themes/two sizes rendered; existing roots/routes/data tests. No conversation/calendar behavior changes. |
| Profile | IMPLEMENTED | Compact header/CTA, preserved settings/social/privacy/profile/logout actions; both themes/two sizes. |
| Group list / Info / management | IMPLEMENTED shared policy | Previous hub retained, palette/radii/bar adapted, role/request/controller tests retained. GroupInfo both themes/two sizes, prior form snapshots recaptured. |
| Activity / Itinerary / Task / Poll | IMPLEMENTED shared policy | Actual Activity overview plus existing Stop/Task/Poll form screenshots; focused existing presentation suites. No workflow redesign. |
| Moments / Album / Chat media | ALREADY compatible with shared theme | Stable keys/state/private media kept; focused widget regression, native/fullscreen media colors intentionally exempt. |
| Expense / Fund / Settlement | IMPLEMENTED shared policy | Default form palette/buttons, Fund shadows removed; existing financial presentation tests, no real money operations. |
| Recruitment / Moderation / Settings | ALREADY shared Material inputs/surfaces | Existing authorization/compose/review tests run; no ranking/privacy/request logic edits. |
| Auth / Social / supporting notifications | IMPLEMENTED visual sweep | No gradient/shadows, neutral palette/CTA, Vietnamese-capable existing font fallback. Existing validation/session/callback tests. |
| Legacy nonproduction dev showcase + static M7 sample RSVP palette | PENDING migration | No domain/model/data changes authorized; example-only color helpers and demo dashboard palettes remain inventoried, not claimed redesigned. |
| Older icon variants/content-specific layouts | PENDING selective normalization | No large icon package or functional-widget rewrite. Semantic online/success/warning/danger colors and native media/modal shapes are intentional exceptions. |
| Every-feature/device accessibility + large landscape/rare modal | PENDING physical acceptance | Render tests/representative smoke do not prove every assistive/native edge. R9 retains full gate. |

No milestone completion status changed: R1/R3–R7 COMPLETE, R2/R10 IN PROGRESS, R8/R9 NOT STARTED.

## Focused regression and rendered visual evidence

Pre-edit relevant baseline **155 PASS0FAIL** (`/tmp/wedo-mono-baseline.log`). Intermediate failures exposed changed label expectations and a real missing typed-argument path Community→Chat/Calendar; fixed centrally in app navigation enrichment. Group access needed normal push to avoid removing cached roots; focused test now proves retained Home/Community after Group back. Tests were not removed and business assertions were not weakened.

Final affected presentation/navigation regression **605 PASS0FAIL**,50s (`/tmp/wedo-mono-regression-final.log`). Final Home/Group/design correction subset **127 PASS0FAIL**,7s (`/tmp/wedo-mono-visual-final.log`); overlapping counts, not732 unique tests. Analyzer clean2.8s (`/tmp/wedo-mono-analyze-final.log`). No backend suite/build needed or run for this task.

`test/design/global_ui_test.dart`: **76 design cases** including previous management/form coverage and new actual Home/Community/Messages/Calendar/Profile/GroupInfo/Activity/form renders at360×780 Android and430×932 iPhone, both themes, plus1.5× Home text. Isolated fake APIs/readable local test font; production components, not mocked visual screenshots. Initial incomplete post-detail fixture showed proper error states; fixed the test fixture to render successfully loaded Community cards, not production error handling. Initial large-text date badge clipped by ListTile leading constraints; replaced decorative stacked date badge with neutral calendar icon, keeping full authoritative time in subtitle. Latest images confirm correction.

Images `/tmp/wedo-design-mono-<home|community|messages|calendar|profile|group|activity|form|home-large-text>-<android|iphone>-<light|dark>.png`; contact sheets `/tmp/wedo-mono-review-{android,iphone}-[1-5].png`. Opened and inspected actual required Home light/dark, Community loaded posts, Messages, Calendar, Profile, Group Info, Activity, form and large-text screenshots at both representative sizes. Static screenshots do not prove transition timing or physical device PASS; navigation gesture behavior has separate focused tests/previous scoped physical evidence.

## Exact shell/navigation edits

- `app/navigation/app_bottom_navigation.dart`: canonical labels/routes/line icons, retained selection, typed-route fallback, keyboard unfocus.
- `groups/presentation/widgets/group_widgets.dart`: compatibility adapter mapping legacy callback positions; Groups is no longer a separate tab.
- `app/app.dart`: existing guarded Community/Chat/Calendar typed-argument enrichment for bare tab routes.
- `app/routes.dart`: existing Community screen as root-tab presentation; retained root set swaps Groups for Community; Groups normal detail push keeps host below it. Existing destinations/guards/notification resolution unchanged.
- `community/presentation/community_screen.dart`: rootTab flag/bar and compose icon only; read/mutation/privacy/realtime methods unchanged.
- Home presentation removes top Community shortcut, exposes All Groups, retains all data/actions. `main_tabs.dart` and `page_transitions.dart` are unchanged in this task; existing0ms tabs/120ms fade/platform back/reduced motion preserved.

## Production files touched relative to task snapshot

- `mobile/lib/app/app.dart`
- `mobile/lib/app/navigation/app_bottom_navigation.dart`
- `mobile/lib/app/routes.dart`
- `mobile/lib/app/theme/app_colors.dart`
- `mobile/lib/app/theme/app_spacing.dart`
- `mobile/lib/app/theme/app_theme.dart`
- `mobile/lib/core/ui/widgets/primary_button.dart`
- `mobile/lib/features/auth/presentation/screens/complete_profile_screen.dart`
- `mobile/lib/features/auth/presentation/screens/create_username_screen.dart`
- `mobile/lib/features/auth/presentation/screens/forgot_password_screen.dart`
- `mobile/lib/features/auth/presentation/screens/login_screen.dart`
- `mobile/lib/features/auth/presentation/screens/register_screen.dart`
- `mobile/lib/features/auth/presentation/screens/reset_password_screen.dart`
- `mobile/lib/features/auth/presentation/screens/verify_email_screen.dart`
- `mobile/lib/features/auth/presentation/screens/welcome_screen.dart`
- `mobile/lib/features/auth/presentation/widgets/otp_code_field.dart`
- `mobile/lib/features/community/presentation/community_screen.dart`
- `mobile/lib/features/discussion/presentation/widgets/activity_discussion_section.dart`
- `mobile/lib/features/fund/presentation/fund_screens.dart`
- `mobile/lib/features/groups/presentation/screens/group_activity_log_screen.dart`
- `mobile/lib/features/groups/presentation/screens/group_admission_screens.dart`
- `mobile/lib/features/groups/presentation/widgets/group_widgets.dart`
- `mobile/lib/features/home/presentation/home_screen.dart`
- `mobile/lib/features/notification/presentation/notification_screens.dart`
- `mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- `mobile/lib/features/profile/presentation/widgets/profile_ui.dart`
- `mobile/lib/features/social/presentation/screens/blocked_users_screen.dart`
- `mobile/lib/features/social/presentation/screens/friend_requests_screen.dart`
- `mobile/lib/features/social/presentation/screens/friends_screen.dart`

Tests: `mobile/test/design/global_ui_test.dart`, `mobile/test/app/routes_test.dart`, `mobile/test/app/navigation_transitions_test.dart`, `mobile/test/features/home/home_test.dart`, `mobile/test/features/groups/presentation/group_widgets_test.dart`. AGENTS.md gets only the required brief design-system guidance, no full duplicate. DESIGN_SYSTEM.md and this delivery report created; handoff updated with current evidence and exact pending acceptance.

## Build/runtime/physical closeout

Candidate build/install/device results will be appended only after actual completion. Use current detected LAN, preserve sessions/signing/Firebase/QA; no second iPhone. Physical review is read-only navigation/forms, not another R1–R10 business acceptance matrix. User checklist when iPhone automation unavailable: five tab labels/order → Community real posts → Home/back preserving feed scroll → Messages/Calendar/Profile → existing Group/Activity → one form/keyboard; dark mode where convenient. Mark pending honestly.

### Verified closeout

- Final added app-only assertions: **78 PASS0FAIL**,2s (`/tmp/wedo-mono-navigation-last.log`): nonzero Community scroll offset retained, exactly one Community instance including offstage widgets, same Home/Community state after Group back, one feed/viewer read across tab returns, retained text draft after keyboard settles. These overlap the605 and127; do not add the counts. Analyzer clean3.2s (`/tmp/wedo-mono-analyze-last.log`). No production changes after the built snapshot except trailing whitespace removal.
- Android debug build11.1s/install-r/launchPASS; package com.wedo.mobile, existing session retained. APK SHA256 `6cacf9d3722ac0f77197ba152b58d2aaffb190309c62ef1f00ba4813be52253e`. `/tmp/wedo-mono-android{,-install}.log`.
- iOS Profile build40.0s/35.6MB/install-in-place/launchPASS on **QA iPhone only**. Existing com.huygiang.wedo/Personal Team configuration retained. Runner SHA256 `c4f33e178669c5105b4b2fe5500b86249a080b718828f4d999ddfb11dc9ebc0a`. `/tmp/wedo-mono-ios{,-install,-launch}.log`. Signing file hashes still pbxproj `ad773f3ca0646bfd2275f088c1b0eacefedc643e90c16249f05ccf4ce5c8c6b8`, Info.plist `cd88a3e2d1ee3b1c064d214026073303db8f11b2baa9e4dcc00811422ce8a8bd`.
- Mac en0/currentAPI `<QA_LAN_IP>:8080`, backend healthUP and MinIO LAN readinessHTTP200; existing runtime/relay preserved. Disk8.1GiB after builds. No Docker/data/credentials mutation.
- Samsung actual Home with current QA tasks/groups and exact5 tab labels observed; neutral fields/post/recruitment content also observed. `/tmp/wedo-mono-samsung-home-light.png` and `...community.png` (the latter actually shows Recruitment discovery after a user navigation, **not** a Community-root PASS). Device moved into Recruitment while read-only inspection was in progress, so automation stopped to avoid conflicting with a manual tester. Original night mode `no`; display mode never changed. Full actual5-tab/scroll/dark/form smoke pending coordination, not claimed PASS from widget fixtures.
- **QA iPhone user-reported physical PASS (2026-10-28): “5 tab OK; giữ cuộn OK”.** This answers the current-candidate checklist: exact5 labels/order, existing Community posts, scroll→Home→Community return and Messages/Calendar/Profile roots. Record precisely this checklist as accepted; do not infer dark-mode, Group/Activity/form/keyboard, native gesture or assistive acceptance from the short reply. Prior “Home OK; giao diện nhóm OK” remains separate earlier-candidate evidence. No unsupported UI automation runner repeatedly attempted.
- **Samsung user-controlled:** user explicitly answers “Tôi đang tự kiểm tra”. Agent automation remains stopped; preserve candidate/runtime/session and wait for their PASS/FAIL observations. This is not a Samsung full visual PASS or a defect. No new implementation/build/tests are justified by these successful observations.
- Source boundary: no Flutter data/domain/application file changed relative to pre-task snapshot; no production lifecycle/async/read/mutation/subscription methods changed. Navigation-only argument/placement wiring is explicitly authorized and enumerated above. Full dirty worktree, all QA/session/media/signing/Firebase/stash retained. Index empty. Diff-check only2 pre-existing blank-EOF warnings in older Group polish/Profile tests, preserved.
- DESIGN_SYSTEM.md created, existing AGENTS.md appended with exact required instruction, this report and handoff link the canonical standard. No commit/push/merge/reset/restore/stash/clean; R2/R8/R9/R10 statuses unchanged. Ready for scoped visual acceptance; not a claim that every legacy/example/native assistive path is fully migrated or physically accepted.


## Home access + immersive Community correction and user follow-ups — 2026-10-28

This section supersedes the earlier Home hierarchy/physical-candidate notes only. All prior changes and milestone evidence remain preserved. Scope is Flutter presentation/navigation and existing camera selection, with no backend/domain/API/schema/authentication implementation changes.

### Delivered behavior

- Exact5 tabs retained. Home now prioritizes “Nhóm của bạn”, authoritative recent groups, “Xem tất cả” and Create/Join entry through the existing Group List. One group is a compact row; multiple groups form a horizontal preview. Existing pending actions, upcoming activities, balances and updates/callbacks remain.
- Community Search opens a small hub to existing people/groups/activities/conversations search and Recruitment discovery. Bare root Search receives existing configured typed arguments; the clear-query icon now updates correctly. Ordinary Community-post full-text search has no existing endpoint and remains unsupported, not simulated.
- Main Community alone hides header/filter chrome and bottom navigation after24px actual user scroll, and restores upward/top or via “Hiện điều hướng”.150ms chrome layout collapse reclaims actual height; reduced-motion uses0ms and accessibleNavigation keeps bars visible. Per-tab UI controller normalizes on exit and rejects disposed/deferred old requests. Existing feed/controller/keyed cards/pagination/realtime/privacy logic remain. Nested Community screens and modal animations keep their prior behavior.
- User then physically confirmed on QA iPhone: **“Nhóm OK; Search OK; ẩn/hiện OK”**, while reporting two new defects. Regression tests reproduced missing vertical filter spacing and independent group-scroll restoration failure. Fixed Recruitment filters with16px spacing/narrow-text stacking and Home preview storage with a distinct PageStorageKey. The Home regression verifies initial position and a user-selected120px offset survive vertical recycling; canonical data is fetched once.
- Requested Chat camera is now available through the existing image action → standard sheet → “Chụp ảnh” / “Chọn từ thư viện”. Existing native permissions and ImagePicker are reused. Same validation, draft preview and explicit Send → authorized CHAT_IMAGE/conversation upload. No auto-send, backend or transport changes. Focused tests cover capture, cancellation, picker failure, draft preservation and no upload before Send; existing gallery/limit/request-permission/image-state tests retained.
- Follow-up request: Profile now exposes “Đăng xuất” in its header, wired to the same existing logout callback/login stack replacement as the body row. Physical sessions are deliberately retained. Home has32px circular `WeDoBrandMark` beside “weDO”; seven Auth screens use the same simplified monochrome connected-people vector mark. Theme tokens invert it in dark mode. Purple raster source/native launcher icon assets are not rewritten. Login/Register callbacks/validation remain unchanged.

### Evidence and boundaries

- Prior first-candidate326 focused PASS,107 visual/home PASS and59 route PASS are overlapping historical runs, not additive totals. Latest complete affected set: **353 PASS0FAIL19s**, `/tmp/wedo-home-final-regression.log`; analyzer clean2.6s `/tmp/wedo-home-final-analyze.log`. Includes Home/recruitment/chrome/chat/profile/logout/Auth screen/app/navigation/search/design tests. No backend suite or full mobile suite run.
-20 targeted actual-widget screenshot cases PASS, `/tmp/wedo-home-followup-visual.log`, two viewports/light+dark for Home/Profile/Login/Register/Recruitment. `/tmp/wedo-design-mono-*.png`; reviewed latest Login iPhone light, Recruitment Android light and Home Android dark directly. Recruitment screenshot intentionally renders its fake API error state and is layout evidence, not production connectivity evidence. Earlier Home empty/Community hidden/restored/Search/Group List screenshot contact sheets reviewed separately.
- Earlier Samsung RO navigation observed Home → existing Group List → Create form (no submission) → existing Group Info. `/tmp/wedo-home-samsung-{home,groups,create-group}.png`; only observed screens count. Earlier iPhone current first-candidate userPASS above does not prove the newer camera/filter/logo candidate.
- Build/install/physical results for the final follow-up snapshot are recorded in the current handoff after commands finish. No physical QA logout, photo upload, membership or financial mutation is performed for styling validation. New camera end-to-end native capture/send and newer-candidate user visual approval remain explicit acceptance items until observed.

### Task-only Dart manifest

Baseline `/tmp/wedo-home-baseline/` captures the entire prior dirty Dart content. The following list is relative to that baseline and must not be confused with the repository's much larger pre-existing dirty diff:

- `mobile/lib/app/app.dart`
- `mobile/lib/app/navigation/app_bottom_navigation.dart`
- `mobile/lib/app/navigation/main_tabs.dart`
- `mobile/lib/features/auth/presentation/screens/complete_profile_screen.dart`
- `mobile/lib/features/auth/presentation/screens/forgot_password_screen.dart`
- `mobile/lib/features/auth/presentation/screens/login_screen.dart`
- `mobile/lib/features/auth/presentation/screens/register_screen.dart`
- `mobile/lib/features/auth/presentation/screens/reset_password_screen.dart`
- `mobile/lib/features/auth/presentation/screens/verify_email_screen.dart`
- `mobile/lib/features/auth/presentation/screens/welcome_screen.dart`
- `mobile/lib/features/chat/presentation/chat_screen.dart`
- `mobile/lib/features/community/presentation/community_screen.dart`
- `mobile/lib/features/community/presentation/recruitment_screen.dart`
- `mobile/lib/features/home/presentation/home_screen.dart`
- `mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- `mobile/lib/features/search/presentation/search_screen.dart`
- `mobile/test/app/routes_test.dart`
- `mobile/test/design/global_ui_test.dart`
- `mobile/test/features/auth/presentation/screens/complete_profile_screen_test.dart`
- `mobile/test/features/auth/presentation/screens/forgot_password_screen_test.dart`
- `mobile/test/features/auth/presentation/screens/login_screen_test.dart`
- `mobile/test/features/auth/presentation/screens/register_screen_test.dart`
- `mobile/test/features/auth/presentation/screens/reset_password_screen_test.dart`
- `mobile/test/features/auth/presentation/screens/verify_email_screen_test.dart`
- `mobile/test/features/auth/presentation/screens/welcome_screen_test.dart`
- `mobile/test/features/chat/presentation/chat_screen_test.dart`
- `mobile/test/features/community/recruitment_test.dart`
- `mobile/test/features/home/home_test.dart`
- `mobile/test/features/profile/presentation/screens/profile_screen_test.dart`
- `mobile/test/features/search/presentation/search_screen_test.dart`
- `mobile/lib/app/navigation/tab_chrome.dart`
- `mobile/lib/core/ui/widgets/wedo_brand_mark.dart`
- `mobile/test/features/community/community_chrome_test.dart`

Documentation: existing AGENTS.md guidance appended briefly; DESIGN_SYSTEM.md updated as visual authority; this report and AGENT_CURRENT_HANDOFF.md updated without replacing old history. R1/R3–R7 COMPLETE; R2/R10 IN PROGRESS; R8/R9 NOT STARTED. No commit/push/merge or destructive Git operation.

### Final follow-up candidate checkpoint

- Android debug25.2s/buildPASS/install-rPASS; APK `ac6e423e698eb6c68f6a7fafb96736b15b2ee0064097e40e9672003fb5fcbf8a`. Samsung is PIN/fingerprint locked after installation; delivered launch intent is not UI evidence. Asked user to unlock, never requested PIN.
- iOS Profile41.6s/buildPASS35.6MB, Runner `a20700cb45978523e8fb368efe9fe5a5c54f986a5c979a0aab855fd13586e00b`. QA iPhone subsequently reconnected; final Profile installed in place and launched successfully (`/tmp/wedo-home-final-ios-{install,launch}.log`). No second iPhone touched. Signing file hashes unchanged, disk9.9GiB.
- Final task-only manifest:18 production Dart paths +15 test paths, including2 new presentation/navigation widgets and1 new chrome test. `/tmp/wedo-home-task-only.diff` separates this task from all prior dirty work. No backend/data/domain/application changes. Git diff-check reports only2 older unrelated blank-EOF warnings, left intact; branch/stash preserved.
- Additional screenshots directly reviewed: Register/Profile iPhone light and Login Android dark. Existing English Register copy remains an older localization gap; not changed in this UI correction. Physical logo/camera/logout/new filter/carousel acceptance is pending, not fabricated from screenshots/tests.
- Manual check after reconnect/unlock: (1) Home → scroll bottom/back: group carousel stays at chosen group; (2) Community Search → Recruitment: labels/boxes separated, filter values retained; (3) Chat → “Ảnh và camera” → “Chụp ảnh”: native camera opens; cancel returns with text draft intact; (4) Profile header logout visible. Only if the user elects to end their session: logout → Login → Create account to inspect monochrome branding; agent does not log out QA devices or submit registration.


### HOME + COMMUNITY UX CORRECTION REPORT — final evidence

| Item | Result |
| --- | --- |
| Five tabs preserved | YES, exact order unchanged; focused navigation/tab-state tests PASS |
| Group entry restored | YES, prominent Home section plus empty-state access |
| Group List existing route reused | YES; existing Create/Join/invitation/group-detail callbacks preserved |
| Home redesign | Same authoritative data/hierarchy polish; separate horizontal group storage; circular monochrome mark |
| Community Search | Existing supported search scopes reused; ordinary post full-text remains unsupported |
| Community immersive scroll | Main feed only, real user direction/threshold and recovery control |
| Header hide/show | Implemented/tested; user physically accepted first candidate on QA iPhone |
| Bottom navigation hide/show | Implemented/tested with actual reclaimed viewport; same user scope |
| Feed scroll/state preserved | Focused retained-state/keyed-image/no duplicate read tests PASS; no claim of new physical image regression testing |
| Dark mode | Actual widget screenshots reviewed; current physical dark-mode review pending |
| Accessibility | Reduced motion/accessibility chrome behavior and large-text layout tested; native assistive acceptance pending |
| Files changed | Task-only18 production Dart +15 test Dart +4 documentation/guidance paths; full dirty worktree includes much older work |
| Flutter tests | Latest353PASS0FAIL; additional overlapping20 visual capture PASS |
| Analyzer | Clean2.6s |
| Android build | PASS25.2s; install-rPASS, session/data retained |
| iOS build | ProfilePASS41.6s; final install-in-place/launchPASS on QA iPhone |
| Samsung physical | Earlier Group routes observed; newer candidate installed but locked at final inspection; new camera/filter/logo smoke pending |
| iPhone physical | User first-candidate “Nhóm OK; Search OK; ẩn/hiện OK”; newer candidate launched, follow-up checklist sent, results pending |
| Actual screenshot evidence | Actual Flutter widgets/fake API, two viewports/light+dark, paths/logs above; not physical PASS substitutes |
| Functional regressions | No regression in affected automated checks; final native capture/user visual checks pending |
| Non-presentation changes | Requested camera entry uses existing ImagePicker/upload; no backend/domain/data/schema/auth/session/transport implementation change |
| Remaining UI gaps | Final follow-up physical checks; older English Register copy; no ordinary Community-post full-text endpoint |
| DESIGN_SYSTEM.md updated | YES, exact implemented components/policies and pending boundaries |
| AGENTS.md guidance | Existing guidance preserved, brief Home/Community rule appended |
| Handoff updated | YES, current task supersedes older candidate notes while retaining all history |
| Git commit / push / merge | NO / NO / NO |

New user-specific controls: Profile top-right logout action is immediately visible, existing lower row remains; login/register have a shared monochrome circular mark. QA devices have not been logged out. User can choose logout to inspect the Auth screens; screenshots/tests already cover their visual rendering without ending QA sessions.


## Home copy and actual iPhone logout wiring correction — 2026-10-28

User confirms Recruitment inputs no longer overlap and Chat camera entry is present. They request removing Home's redundant “Không gian của bạn / Kết nối với nhóm…” text and report logout absent from iPhone Profile. Exact evidence scope: camera entry present, not a fabricated native capture/upload PASS.

- Removed those two Home text blocks/gaps; compact circular-logo app bar and immediate Group section remain, same data/callbacks/scroll storage.
- Root cause was not merely visual: production `main.dart` made logout conditional on push service availability. iOS without Firebase push received null and hid both controls. Always pass the existing logout callback; existing session logout already supports absent/best-effort push cleanup. No token/session/backend rule change. Header action now shows explicit “Đăng xuất” text + icon; lower body row retained.
-3 production Dart paths: `mobile/lib/main.dart`, `mobile/lib/features/home/presentation/home_screen.dart`, `mobile/lib/features/profile/presentation/screens/profile_screen.dart`.2 existing test paths: Home test and app routes test. Design system/current handoff/this report updated. No broad refactor or attribution of older dirty work. Task snapshot/diff `/tmp/wedo-home-logout-baseline/`, `/tmp/wedo-home-logout-task-only.diff`.
-93 focused testsPASS3s, analyzer clean3.1s (`/tmp/wedo-home-logout-{tests,analyze}.log`), including actual WeDoApp no-push Profile logout → session invalidation → Login → disposed authenticated tab host, retained Home scroll checks and Profile callback tests. No backend/full-suite run.
- Android debug12.0s/build/install-rPASS, APK7bbf3fa1b0…; iOS Profile42.2s/build35.6MB/install-in-place/launchPASS, Runner0c55f75f56…. `/tmp/wedo-home-logout-{android,ios}{,-install,-launch}.log` (Android launch observed via adb). Current API<QA_LAN_IP>. Signing hashes unchanged ad773f3c…/cd88a3e2…. No Firebase/QA/database/backend/runtime changes.
- Actual Samsung Profile screenshot reviewed `/tmp/wedo-home-logout-samsung-profile.png`: clearly visible top-right text+icon logout with authenticated QA Member1. Agent never pressed logout. Subsequent device read showed Register while user was testing, so agent stopped Samsung taps. `...samsung-home.png` is actually the subsequent Register capture, NOT physical Home acceptance; initial capture caught a white launch frame. Auth logout flow correctness is automated evidence until user confirmation, not inferred from that screen change.
- Final QA iPhone candidate installed/launched; precise manual check sent for visible logout text and removed Home copy. Pending user response. All prior dirty changes/stash preserved; no commit/push/merge/reset/restore/stash/clean; R10 remains IN PROGRESS.


## Explicit logout confirmation — 2026-10-28

User physically confirms the preceding QA iPhone logout button fix (“Có rồi”), then requests a confirmation prompt. Both existing Profile controls now open one shared centered `AlertDialog`: **“Bạn có chắc muốn đăng xuất không?”**, actions **Hủy / Đăng xuất**. Cancel, system back or outside dismissal never invokes logout; only explicit confirm reaches the existing session callback/login navigation. Local pending guard prevents duplicate dialogs/logout. No auth repository, token, backend, Firebase or QA behavior changed.

Scope:1 existing production Profile screen,2 existing Profile/routes tests, DESIGN_SYSTEM.md/current handoff/this report.69 focused testsPASS4s; analyzer clean2.5s (`/tmp/wedo-logout-confirm-{tests,analyze}.log`). Tests cover header/body entry, cancel/system back, callback once on confirmation and real-app session/route transition. Existing main.dart unconditional logout wiring preserved. No full or backend suites.

Android debug buildPASS12.4s (`/tmp/wedo-logout-confirm-android.log`); final install and iOS Profile build results recorded in current handoff when complete. Agent does not press final confirmation or alter physical QA sessions just to validate the modal. New-candidate user physical acceptance remains pending; previous button-visibility acceptance is not modal acceptance. Dirty worktree preserved; no commit/push/merge/reset/restore/stash/clean.

Final logout-confirm candidate: Android debug12.4s/install-r/launchPASS, APK0d9f8425d3…; iOS Profile44.0s/35.6MB/install-in-place/launchPASS, Runner60123e9a5b…. SameAPI<QA_LAN_IP> and native signing hashes ad773f3c…/cd88a3e2… unchanged. No physical logout performed or modal physical PASS inferred. Both candidates ready for user confirmation/cancel check. Logs `/tmp/wedo-logout-confirm-{android,ios}{,-install,-launch}.log`.


## Compact Home hierarchy and independent folds — 2026-10-28

User asks to move Finance directly below groups and shorten Home with collapsible sections. Same authoritative HomeResponse now renders Nhóm của bạn → Tài chính (always visible) → Cần xử lý → Hoạt động sắp tới → Cập nhật gần đây. Last3 use standard ExpansionTile, initially collapsed, actual returned-item count and chevron. Each has an independent PageStorageKey; retained tab/refresh preserves open state. Reduced motion uses no expansion animation. Expanded rows retain existing empty states, IDs/callbacks and exact financial values. No extra fetch, second controller, business/ledger/privacy change.

Scope1 production Home screen +existing Home test; pre-edit `/tmp/wedo-home-collapse-before.dart`.180 affected Home/routes/design testsPASS7s;8 overlapping actual-widget screenshot casesPASS1s, reviewed Android light and iPhone large-text dark. Logs `/tmp/wedo-home-collapse-{tests,visual,analyze}.log`; screenshots `/tmp/wedo-design-mono-home*.png`. Existing group offset regression and item routing PASS; new check proves financial ordering, initially hidden rows, independent folds, no fetch on toggle and retained state after authoritative refresh. Build/install and physical results in current handoff once complete. No backend/full-suite work or financial mutation. All older dirty work preserved, no Git commit/push/merge.

Compact Home final delivery: analyzer clean2.7s; Android debug11.8s/build/install-rPASS (APK3c50fd5b7d…), iOS Profile45.5s/35.6MB/build/install-in-place/launchPASS (Runner0ab8d90cec…). `/tmp/wedo-home-collapse-{android,ios}{,-install,-launch}.log`. Signing unchanged ad773f3c…/cd88a3e2…. Samsung actual screen after launch was native Camera; automation stopped to avoid interrupting user. `...samsung.png` is Camera, not a fabricated Home PASS. Actual Home widget screenshots reviewed as noted; user physical new Home/fold acceptance pending. Existing accepted media relay configuration preserved. No data/backend/business change or Git staging/commit/push/merge. Handoff accurate, R10 IN PROGRESS.


2026-10-28 user follow-up: **“Được rồi đó.”** Accepts the delivered finance-first/collapsible Home. This is scoped user physical acceptance, not full R9/native accessibility acceptance. [Complete Vietnamese UI/UX recap from Persistent Design System](UI_UX_HANDOFF_2026-10-28.md) is available for the next ChatGPT/agent; no implementation/build/test restarted for that recap.


## Recruitment composer / Group invitation QR — 2026-10-28

User reports overlap in RecruitmentComposer (not the already-fixed discovery filters), and asks for Group QR similar to personal QR. Composer now has consistent16px spacing between visible guidance/controls/actions, readable Vietnamese role guidance and expanded/bounded long-name dropdowns. Same eligibility, controllers, source IDs, datetime/visibility, submit and UUID retry contracts remain.

Owner/Admin Group Info entry now **Mã QR & liên kết mời**, same existing callback/route/API. Default invitation is rendered as black-on-white responsive QR (≤240px,16px quiet zone), using exact canonical invite URL and opaque case-sensitive code. Existing scanner/parser opens canonical preview/join/request, never auto-membership/approval bypass/RSVP. API still requires Owner/Admin for invite management; Member scope not broadened. Corrected old subtitle that implied automatic admission. No backend/schema/config/dependency changes.

154 affected Recruitment/Group/links/design testsPASS10s, then13 overlapping final-copy Group/invite testsPASS1s; analyzer clean3.6s. Narrow320px/1.5×/light+dark geometry and existing retry/idempotency/role/opaque-link assertions retained. Actual Flutter QR PNG decoded using macOS Vision to exact mixed-case fixture invitation URL. Light/dark invite screenshots directly reviewed; this is automated decode/render evidence, not two-device physical scan PASS. `/tmp/wedo-recruit-qr-{tests,final-tests,analyze}.log`, `/tmp/wedo-group-qr-{test.png,decode.swift}`.

Android debug12.0s/build/install-r/launchPASS, APK9c70b31805…; iOS Profile50.0s/35.6MB/build/install-in-place/launchPASS, Runner3b8ec3f975…. SameAPI<QA_LAN_IP>/signing hashes ad773f3c…/cd88a3e2… unchanged. Source scope3 production presentation files +4 test paths (1new), scoped docs; baseline/diff `/tmp/wedo-recruit-qr-baseline/`, `/tmp/wedo-recruit-qr-task-only.diff`. User checklist sent; form physical approval and two-device scan preview pending. No physical post/join/approve/financial mutation. Existing data/worktree/media relay retained, no commit/push/merge; milestones unchanged.
