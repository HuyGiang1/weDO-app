# Global UI/UX design system polish — 2026-10-28

Status: implementation, focused regression and candidate builds delivered; physical acceptance is scoped below. This is a cross-cutting R10/R9 requirement, not closure of R10 or R9. Preserve all pre-existing R1–R10 source, runtime and acceptance evidence.

## Shared design policy

`AppTheme.light/dark` is used by all three MaterialApp entrypoints, system brightness selected. Neutral white/gray/near-black surfaces, existing brand purple for actions/focus, theme error for danger, `AppSemanticColors` for success/warning. Status also has readable text/icon. Existing typography scale is retained; `AppTextStyles.of(context)` adapts former hardcoded foreground colors to brightness. No styling dependency added.

- Fields: 12px outline in normal/focused/error/disabled states; focus 1.8px, normal 1px; fill follows theme; padding16 horizontal/15 vertical; labels always float above input text; helper/error below, wrapping up to3 lines. AppTextField retains its separate external label and controller/focus/validator APIs. Password toggles/obscuring preserved.
- Cards16px, common controls12px, spacings8/12/16/24, 48px action minimums and comfortable row targets. Some existing content-specific modal/media layouts retain their intentional shapes; no all-screens pixel identity claim.
- Shared `AppSurface`, `AppSectionHeader`, `AppManagementRow`, `AppStatusLabel`, `AppNotice`, `AppTone`. Reuse standard themed multiline/search/select/numeric controls rather than creating duplicate wrappers for every input type.
- AppSemanticColors adapts success/warning in light/dark. R10 Stop status uses actual backend status + semantic label/icon. No lifecycle/date gate/business behavior changed.
- No new route infrastructure: existing 120ms global fade, immediate retained tabs, reduced motion, platform back, typed routes/auth guards/deep links and fullscreen/media/modal behavior retained. Only braces were corrected in the previous page-transition file for analyzer compliance.

## Group management hub and permission boundaries

Group Info has header/avatar/name/description + current role/status, truthful member-content label, actual Owner name, existing member avatar preview and count, grouped content, access/management, and separated destructive actions. No public/private field is invented from missing API data. Missing owner/count metadata uses an honest fallback.

Owner/Admin see invite/join/ban/member-management entries; ownership transfer is Owner-only for active groups. Edit is permitted for active managers or the actual existing `memberModifyInfoAllowed` setting. GroupInfo's controller reuses its member read and optionally reads existing group settings (`readSettings:true` only on this route); generation/disposal safeguards apply. For Owner/Admin only, it also reads the existing PENDING-only admission endpoint with size1 and renders authoritative totalElements as the join-request count. A failed metadata read leaves the count unknown (no fabricated zero); Members make no admission read. Resync refreshes the count; no new API or permission grant. Other existing controller callers retain their previous request contract. This is presentation metadata, not a permission grant; backend remains authoritative.

Members and transfer targets reuse shared management rows. Permissions, Invite Links, Join Requests, Bans and Edit use the same adaptive palette/outlined form theme. New leave/transfer confirmations preserve canonical callbacks; transfer names its target. Leave failures now have visible SnackBar feedback at the current scroll position as well as retained error state. Delete/archive/restore confirmation/role behavior preserved. No memberships were mutated in physical review.

Advanced Invite Links heading/actions now wrap on narrow layouts (confirmed11px overflow fixed); displayed long invite codes ellipsize while full copy/share code remains unchanged. Expiry/revocation status uses text/icon. Pending admission uses warning semantics; ban/remove actions use danger. Expense receipt button copy is Vietnamese; receipt/payer/split/money payload unchanged.

## Full form-source inventory

Source scan: **46 form/widget owners across31 files,120 input construction sites**, including two shared component implementation owners, dialog inputs and reusable screens. Counts are construction sites, not120 different screens. `FIXED` below means inherited outlined implementation verified by source; it does **not** mean every flow was physically exercised. Visual evidence is separately enumerated below.

| Source | Widget / form owner | Inputs | State |
| --- | --- | ---: | --- |
| `core/ui/widgets/app_password_field.dart` | `_AppPasswordFieldState` | 1 | FIXED — shared outlined theme |
| `core/ui/widgets/app_text_field.dart` | `_AppTextFieldState` | 1 | FIXED — shared outlined theme |
| `features/activity/presentation/screens/activity_runtime_screens.dart` | `_ActivityCreateRuntimeScreenState` | 8 | FIXED — shared outlined theme |
| `features/activity/presentation/screens/activity_runtime_screens.dart` | `_ActivityDetailRuntimeScreenState` | 1 | FIXED — shared outlined theme |
| `features/activity/presentation/screens/activity_runtime_screens.dart` | `_ActivityEditRuntimeScreenState` | 6 | FIXED — shared outlined theme |
| `features/activity/presentation/screens/activity_screens.dart` | `_ActivityFormScreenState` | 11 | FIXED — shared outlined theme |
| `features/auth/presentation/screens/complete_profile_screen.dart` | `_ProfileFieldState` | 1 | FIXED — shared outlined theme |
| `features/auth/presentation/screens/create_username_screen.dart` | `_CreateUsernameScreenState` | 1 | FIXED — shared outlined theme |
| `features/auth/presentation/screens/forgot_password_screen.dart` | `_ForgotPasswordEmailFieldState` | 1 | FIXED — shared outlined theme |
| `features/auth/presentation/screens/login_screen.dart` | `_LoginFieldState` | 1 | FIXED — shared outlined theme |
| `features/auth/presentation/screens/register_screen.dart` | `_RegisterScreenState` | 3 | FIXED — shared outlined theme |
| `features/auth/presentation/screens/reset_password_screen.dart` | `_ResetFieldState` | 1 | FIXED — shared outlined theme |
| `features/auth/presentation/widgets/otp_code_field.dart` | `OtpCodeFieldState` | 1 | EXCEPTION — boxed OTP cells (8px) |
| `features/chat/presentation/chat_screen.dart` | `_ChatScreenState` | 2 | FIXED — shared outlined theme |
| `features/community/presentation/community_screen.dart` | `_CommunityComposerState` | 3 | FIXED — shared outlined theme |
| `features/community/presentation/community_screen.dart` | `_CommunityCardState` | 1 | FIXED — shared outlined theme |
| `features/community/presentation/moderation_screen.dart` | `_ModerationReviewState` | 1 | FIXED — shared outlined theme |
| `features/community/presentation/recruitment_screen.dart` | `_RecruitmentComposerState` | 7 | FIXED — shared outlined theme |
| `features/community/presentation/recruitment_screen.dart` | `_RecruitmentDiscoveryState` | 3 | FIXED — shared outlined theme |
| `features/discussion/presentation/widgets/activity_discussion_section.dart` | `_ActivityDiscussionSectionState` | 3 | FIXED — shared outlined theme |
| `features/expense/presentation/expense_screens.dart` | `_ExpenseFormScreenState` | 5 | FIXED — shared outlined theme |
| `features/expense/presentation/expense_screens.dart` | `_ExpenseBalanceScreenState` | 1 | FIXED — shared outlined theme |
| `features/fund/presentation/fund_screens.dart` | `_GroupFundScreenState` | 12 | FIXED — shared outlined theme |
| `features/groups/presentation/screens/create_group_screen.dart` | `_CreateGroupScreenState` | 2 | FIXED — shared outlined theme |
| `features/groups/presentation/screens/group_admission_screens.dart` | `_JoinByInviteCodeScreenState` | 1 | FIXED — shared outlined theme |
| `features/groups/presentation/screens/group_admission_screens.dart` | `_GroupInviteLinksScreenState` | 1 | FIXED — shared outlined theme |
| `features/groups/presentation/screens/group_management_screens.dart` | `_EditGroupScreenState` | 2 | FIXED — shared outlined theme |
| `features/groups/presentation/screens/group_management_screens.dart` | `_MemberManagementScreenState` | 1 | FIXED — shared outlined theme |
| `features/groups/presentation/screens/group_management_screens.dart` | `_GroupPermissionsScreenState` | 2 | FIXED — shared outlined theme |
| `features/journey/presentation/journey_screens.dart` | `_StopComposerState` | 5 | FIXED — shared outlined theme |
| `features/journey/presentation/journey_screens.dart` | `_JourneyCaptureState` | 1 | FIXED — shared outlined theme |
| `features/journey/presentation/journey_screens.dart` | `_TaskEvidenceState` | 3 | FIXED — shared outlined theme |
| `features/journey/presentation/poll_action_screen.dart` | `_PollActionState` | 5 | FIXED — shared outlined theme |
| `features/moments/presentation/memories_screen.dart` | `_MomentComposerState` | 1 | FIXED — shared outlined theme |
| `features/moments/presentation/memories_screen.dart` | `_ActivityChoice` | 1 | FIXED — shared outlined theme |
| `features/moments/presentation/memories_screen.dart` | `_MomentViewState` | 1 | FIXED — shared outlined theme |
| `features/moments/presentation/memories_screen.dart` | `_AlbumEditorState` | 2 | FIXED — shared outlined theme |
| `features/poll/presentation/screens/poll_screens.dart` | `_CreatePollScreenState` | 2 | FIXED — shared outlined theme |
| `features/poll/presentation/screens/poll_screens.dart` | `_PollDetailScreenState` | 2 | FIXED — shared outlined theme |
| `features/privacy/presentation/screens/privacy_settings_screen.dart` | `_PrivacySettingsScreenState` | 2 | FIXED — shared outlined theme |
| `features/profile/presentation/screens/change_password_screen.dart` | `_ChangePasswordScreenState` | 3 | FIXED — shared outlined theme |
| `features/profile/presentation/screens/change_username_screen.dart` | `_ChangeUsernameScreenState` | 1 | FIXED — shared outlined theme |
| `features/profile/presentation/screens/edit_profile_screen.dart` | `_EditProfileScreenState` | 3 | FIXED — shared outlined theme |
| `features/search/presentation/search_screen.dart` | `_SearchScreenState` | 1 | FIXED — shared outlined theme |
| `features/task/presentation/screens/task_screens.dart` | `_TaskListScreenState` | 1 | FIXED — shared outlined theme |
| `features/task/presentation/screens/task_screens.dart` | `_CreateTaskScreenState` | 2 | FIXED — shared outlined theme |

Additional destinations without their own direct input constructor:

| Destination | State | Explanation / evidence boundary |
| --- | --- | --- |
| Chat Poll composer | ALREADY CONSISTENT | Reuses CreatePollScreen; no duplicate Poll implementation. |
| Poll results/voters/close | ALREADY CONSISTENT | Existing controls inherit theme; results/privacy business logic untouched. |
| Task assignment/status | ALREADY CONSISTENT | Existing picker/sheet controls inherit theme; no free-text edit control added. |
| Task edit | PENDING | No standalone edit form in current task screen source; not invented as part of UI polish. Existing detail status/assignee flow retained. |
| Poll edit | PENDING | No standalone full-edit form added; current option/close contract retained. |
| Group Info | FIXED | New shared management hierarchy; light/dark top and scrolled screenshots. |
| Members / Transfer ownership | FIXED | Shared rows, existing identities/actions retained; light/dark screenshots and confirmation regressions. |
| Join Requests / Bans | FIXED | Adaptive surfaces/text/status; light/dark long-name screenshots. |
| Group Settings / Permissions | FIXED | Existing switches/dropdowns adapt; light/dark screenshot and role regressions. |
| Admin management | FIXED | Existing role list adapts; source/focused tests, no separate physical action. |
| Settlement entry | FIXED | Amount/note controls are in ExpenseBalance screen; standard dialog outline, financial submit unchanged. |
| Fund collection / contribution / fund expense / reimbursement / reversal | FIXED | All12 existing dialog inputs inherit shared theme; focused existing execution tests, no live money operations. |
| RSVP | ALREADY CONSISTENT | Existing actions/confirmation controls, no new RSVP form invented. |
| Stop edit/planning | FIXED | Same StopComposer as create with existing values; date/time and early-action behavior retained. |
| Native camera / system media picker / fullscreen viewers | EXCEPTION | Native transitions and intentionally dark fullscreen media preserved. |
| OTP cells | EXCEPTION | Existing8px boxed digit grid remains outlined; not an underline field. |
| Production-only visual acceptance across every form | PENDING | Representative screenshots+focused tests do not equal every-device/every-flow physical PASS. |

## Rendered visual review

`test/design/global_ui_test.dart` mounts **actual production widgets**, with isolated fake APIs, readable font and real Material icons.40 design cases pass:18 screen/scroll positions in each brightness, two field-state/keyboard cases, Member capability visibility and one authoritative admission-count/resync role test. These are widget-rendered screenshots, **not physical phone screenshots**.360px viewport/long Vietnamese text; no overflow in checked positions. Capture flag `--dart-define=WEDO_CAPTURE_DESIGN=true`; `/tmp/wedo-design-<name>-<light|dark>.png`. Screenshot contact sheets `/tmp/wedo-design-review-1.png` through9 were opened and inspected.

Required12 reviewed in both modes: Create Group, Edit Group, Group Info, Invite Links, Join Requests, Bans, Create Activity, Create Task, Create Poll, Create Expense, Community composer, R10 Stop form. Additional: Members, Member Management, Permissions, Ownership Transfer, expanded invite links, scrolled Group Info. Dedicated tests cover focus/error/multiline/dropdown/disabled and280px keyboard insets.

Confirmed visual defects corrected: legacy light card/body surfaces with nearly white text in dark Activity/Task/Poll/Expense, undersized floating labels, narrow advanced-invite overflow, wrong pending status tone, and invisible leave-error feedback while scrolled. Neutral colors in adjacent Auth/Profile/Social/Home/Calendar/Chat were adapted because enabling system dark mode exposed existing light-only palette assumptions. Domain/API behavior was not migrated or rewritten.

Physical evidence and final logs are recorded in the closeout below. Dark-mode screenshots do not imply actual device dark-mode acceptance. Native keyboard, large accessibility text and every rare error modal remain R9 checks.

## Regression evidence

-538 focused Flutter PASS,0 FAIL (`/tmp/wedo-design-regression-final.log`,31s): Auth presentation, Group application/presentation, Activity presentation/application, Task/Poll, Expense/Fund, Community/recruitment/moderation, Moments, Journey, app routes/navigation, Chat/Poll/images.
- Final scoped116 PASS,0 FAIL (`/tmp/wedo-design-last-scope.log`,7s), after final braces/composer outline cleanup. These overlap the538; do not add them into a fabricated unique654 count.
- Final Group/application/route/design regression162 PASS0FAIL (`/tmp/wedo-design-count-tests.log`,7s), including40 design cases (39 widget +1 count/role unit). Captured updated light/dark management badge screenshots were opened/reviewed. These overlap the538; counts are not additive.
- Final analyzer clean3.3s (`/tmp/wedo-design-count-analyze.log`). No backend suites: no backend code/API/schema change for this task.
- Existing submission/validation tests retain exact request IDs and form values. GroupInfo route expectation explicitly adds the existing settings GET and manager-only pending-admission GET. Confirmation tests now exercise explicit confirmation, not bypass it. Permission tests preserve Owner/Admin/Member restrictions and member-granted edit capability. No test removed to make UI pass.

## Scoped source manifest

- `mobile/lib/app/app.dart`
- `mobile/lib/app/navigation/page_transitions.dart`
- `mobile/lib/app/routes.dart`
- `mobile/lib/app/theme/app_text_styles.dart`
- `mobile/lib/app/theme/app_theme.dart`
- `mobile/lib/core/ui/widgets/app_management.dart`
- `mobile/lib/core/ui/widgets/app_password_field.dart`
- `mobile/lib/core/ui/widgets/app_text_field.dart`
- `mobile/lib/features/activity/presentation/screens/activity_runtime_screens.dart`
- `mobile/lib/features/activity/presentation/screens/activity_screens.dart`
- `mobile/lib/features/auth/presentation/screens/complete_profile_screen.dart`
- `mobile/lib/features/auth/presentation/screens/create_username_screen.dart`
- `mobile/lib/features/auth/presentation/screens/forgot_password_screen.dart`
- `mobile/lib/features/auth/presentation/screens/login_screen.dart`
- `mobile/lib/features/auth/presentation/screens/register_screen.dart`
- `mobile/lib/features/auth/presentation/screens/reset_password_screen.dart`
- `mobile/lib/features/auth/presentation/screens/verify_email_screen.dart`
- `mobile/lib/features/auth/presentation/screens/welcome_screen.dart`
- `mobile/lib/features/auth/presentation/widgets/otp_code_field.dart`
- `mobile/lib/features/calendar/presentation/activity_reminder_panel.dart`
- `mobile/lib/features/calendar/presentation/calendar_screen.dart`
- `mobile/lib/features/chat/presentation/chat_home_screen.dart`
- `mobile/lib/features/chat/presentation/chat_requests_screen.dart`
- `mobile/lib/features/chat/presentation/chat_screen.dart`
- `mobile/lib/features/community/presentation/community_screen.dart`
- `mobile/lib/features/discussion/presentation/widgets/activity_discussion_section.dart`
- `mobile/lib/features/expense/presentation/expense_screens.dart`
- `mobile/lib/features/fund/presentation/fund_screens.dart`
- `mobile/lib/features/groups/application/group_detail_controller.dart`
- `mobile/lib/features/groups/presentation/screens/group_activity_log_screen.dart`
- `mobile/lib/features/groups/presentation/screens/group_admission_screens.dart`
- `mobile/lib/features/groups/presentation/screens/group_info_screen.dart`
- `mobile/lib/features/groups/presentation/screens/group_management_screens.dart`
- `mobile/lib/features/groups/presentation/screens/my_groups_screen.dart`
- `mobile/lib/features/groups/presentation/widgets/group_widgets.dart`
- `mobile/lib/features/home/presentation/home_screen.dart`
- `mobile/lib/features/journey/presentation/journey_screens.dart`
- `mobile/lib/features/moments/presentation/memories_screen.dart`
- `mobile/lib/features/poll/presentation/screens/poll_screens.dart`
- `mobile/lib/features/privacy/presentation/screens/privacy_settings_screen.dart`
- `mobile/lib/features/profile/presentation/screens/change_password_screen.dart`
- `mobile/lib/features/profile/presentation/screens/change_username_screen.dart`
- `mobile/lib/features/profile/presentation/screens/edit_profile_screen.dart`
- `mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- `mobile/lib/features/profile/presentation/screens/public_user_profile_screen.dart`
- `mobile/lib/features/profile/presentation/widgets/profile_ui.dart`
- `mobile/lib/features/qr/presentation/screens/personal_qr_screen.dart`
- `mobile/lib/features/search/presentation/search_screen.dart`
- `mobile/lib/features/social/presentation/screens/blocked_users_screen.dart`
- `mobile/lib/features/social/presentation/screens/friend_requests_screen.dart`
- `mobile/lib/features/social/presentation/screens/friends_screen.dart`
- `mobile/lib/features/social/presentation/widgets/social_action_button.dart`
- `mobile/lib/features/social/presentation/widgets/social_empty_state.dart`
- `mobile/lib/features/social/presentation/widgets/social_error_view.dart`
- `mobile/lib/features/social/presentation/widgets/user_avatar.dart`
- `mobile/lib/features/task/presentation/screens/task_screens.dart`
- `mobile/lib/main_dev_showcase.dart`
- `mobile/lib/main_social_demo.dart`

This manifest describes files touched for the design work; many already had prior milestone edits. The complete `git diff` includes substantial pre-existing backend/mobile/docs changes, **not all attributable to this UI task**. Tests additionally: `mobile/test/design/global_ui_test.dart` (new), existing Group final E2E and route tests (focused expectation/confirmation updates). No native signing/Firebase or dependencies modified in this task. Generated artifacts stay local.

## Remaining acceptance

On QA iPhone: open Group Info→Edit (do not save), Invite Links, Join Requests, Bans; verify readable outlined forms/scroll/back. Then one Task/Poll/Expense/Stop form (do not submit). Confirm dark mode and keyboard dismissal/scroll where convenient. Samsung actual RO smoke is scoped in closeout. No previous milestone physical PASS is extrapolated to these new design screens. R10/R9 retain complete form/device regression gates.

## Candidate/runtime closeout

- Android debug buildPASS9.8s, install-rPASS; API `http://<QA_LAN_IP>:8080`, package com.wedo.mobile. APK SHA256 `4e231725f4100a13f5ae0dac3049c6bc59f077bdc542be1476dca5911dd6d365`. No uninstall/data removal. Logs `/tmp/wedo-design-android{,-install}.log`.
- iOS Debug buildPASS43.2s/installPASS; user twice observed iOS14+ Debug launch restriction. Flutter run briefly launched Dart VM then lost connection. **This is not physical UI PASS.** Same-source Profile buildPASS54.1s/35.6MB, install-in-placePASS/devicectl launchPASS, standalone-launchable candidate, unchanged `com.huygiang.wedo`/Personal Team/signing. Final Runner SHA256 `29e9b2e8dbc0b72ac5fbc2762cb6a1f6e8fa1d7a8c6f20599c42a1b3638da9f7`. Logs `/tmp/wedo-design-ios-profile{,-install,-launch}.log`. No Secondary iPhone interaction. User confirmation that Profile opens Home/new Group forms remains pending.
- Native signing files match before/after hashes: pbxproj `ad773f3ca0646bfd2275f088c1b0eacefedc643e90c16249f05ccf4ce5c8c6b8`; Info.plist `cd88a3e2d1ee3b1c064d214026073303db8f11b2baa9e4dcc00811422ce8a8bd`.
- Samsung actual screenshots reviewed: `/tmp/wedo-design-samsung-{start,group,members,create-group,keyboard-settled,create-activity}.png`. Existing signed-in Member Home/GroupInfo/member avatars and roles render; manager actions absent. Blank CreateGroup outline/focus and real keyboard visible; CreateActivity neutral cards/fields render, scrolling exposes submit (`...create-activity-scrolled.png`, UI bounds verified). No form submitted, group/member/financial data untouched. No physical whole-app/dark-mode PASS implied.
- Backend, PostgreSQL, Redis and MinIO remain UP; LAN backend health+MinIO HTTP200 after installs. Mac en0 `.116`, Samsung `.110`; existing exact-device media relay unchanged. Disk7.9GiB free after Profile build. Runtime credentials not printed.
- Git HEAD/branch/stash preserved, index empty. Current UI whitespace fixed; full diff-check retains only2 pre-existing blank-EOF warnings in older Group/Profile tests. No commit/push/merge/reset/restore/stash/clean. Complete dirty diff is not this task's change count.

### User physical confirmation and last count addition

User on QA iPhone explicitly confirmed **“Home OK; giao diện nhóm OK”** after Profile launch and the requested read-only Home/GroupInfo→Edit/InviteLinks checklist. This closes the observed debug-launch blocker and confirms exactly that scope; no claim that every management destination/dark mode/keyboard was physically accepted. A final small admission-count addition followed that confirmation: manager-only size1 GET, authoritative totalElements, unknown on failure, no Member reads.162 focused tests + clean analyzer and updated light/dark screenshot evidence cover it; final candidate packaging logs supersede earlier hashes below when recorded. No need to repeat prior paired business acceptance merely for this badge.

### Final packaged snapshot (supersedes earlier candidate hashes)

- Manager-count addition:162 focused PASS, analyzer clean3.3s.39 widget screenshot cases +1 count/role unit, including Member no-read and Owner/Admin totalElements/resync.
- Android final build11.4s/install-r/launchPASS; SHA256 `1c48b64812e0b4a587581ab274a1a3b9a9341a2b67581f2b82cc819d31a6bce1`; `/tmp/wedo-design-android-final{,-install}.log`.
- iOS final Profile build42.4s/35.6MB/install-in-place/launchPASS; Runner SHA256 `e5edeafea5c47bcfefe8ebc7b8ea059d32d3361c0e9abe921f5143e13a86ca5d`; `/tmp/wedo-design-ios-profile-final{,-install,-launch}.log`. Signing hashes unchanged. Source/user session/QA preserved. Disk8.1GiB after final builds.
- User physical Home/GroupInfo PASS was observed immediately before this badge-only addition, not a fabricated new physical count PASS. Remaining acceptance: inspect manager badge on device, broader form/dark-mode/keyboard visual acceptance in R9. No reproduced current UI blocker, no claim of GLOBAL UI completion or R10 closure.
