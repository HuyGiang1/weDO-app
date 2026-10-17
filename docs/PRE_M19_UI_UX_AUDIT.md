# Pre-M19 UI/UX Audit

## Environment

- Date: 2026-10-13; physical Samsung continuation after the initial keyguard blocker was resolved.
- Workspace: `D:/weDO-app`; branch: `feat/pre-m19-ui-polish`.
- Unchanged HEAD/base/local dev/origin dev: `a3810701b747520cae25c8f3a0706c3296703c76`.
- M18 CLOSED; M19 NOT STARTED. Audit only: no application changes, staging, commit, push or deployment.
- Samsung `R58M36JQYVY`, SM_G975U1, authorized and unlocked. Physical display 1440x3040, override 1080x2280.
- Repository Windows runner started the retained PostgreSQL/Redis/AIStor data and fresh backend; actuator health UP. ADB reverse only TCP 8080/9000.
- Current debug APK built, installed and auto-launched with `WEDO_API_BASE_URL=http://127.0.0.1:8080`; latest build completed in 29.3 seconds, install in 7.2 seconds.
- Artifact: `mobile/build/app/outputs/flutter-apk/app-debug.apk` (163496052 bytes). This was a local debug-device audit, not production deployment.
- Baseline Android font scale 1.1; temporarily tested 1.5 on Home, Groups, Search and Calendar; restored and reverified 1.1. Temporary USB keep-awake disabled at cleanup.
- Audit Flutter runner exited normally; repository stop script stopped backend and all three infrastructure containers. Final check: zero 8080 listeners and no running Docker containers. No volumes removed.
- No credential, Firebase Admin JSON or external AIStor license contents inspected or recorded.

## Summary

Pass 1 inventory is complete for the reachable existing QA surfaces below and ready for a scoped UI fix plan, **not a claim of exhaustive product acceptance**. Fixture-dependent variants and unexecuted mutations remain explicitly listed.

**61 distinct screen/sheet/interaction surfaces inspected**, grouped by the counting convention below; repeated screenshots, repeated openings, font variants and different records on the same surface do not increase this count. This is not 61 independent navigation routes.

Confirmed inventory: **P0 0; P1 3; P2 10; P3 1**. No audit-blocking crash was observed. Findings combine rendered Samsung evidence with targeted source confirmation; source-only candidates are not counted.

Top ten, in recommended order: UI-01 header layout, UI-02 reply controls, UI-03 invitation identity, UI-07 Chat entry position, UI-09 Search labels, UI-10 Poll enabled-state contrast, UI-13 corrupted Vietnamese, UI-06 owner identity, UI-08 Notification header, UI-04 mixed language.

## Coverage Ledger

Evidence filenames are in the temporary directory identified under Physical Samsung Evidence. Some early filenames were captured before navigation settled; the table describes their actual content, not assumptions from their names.

| Domain | Count | Inspected surfaces and states | Evidence |
| --- | ---: | --- | --- |
| Auth | 1 | Login: blank validation, filled fields, masked password/dummy visibility toggle, keyboard, network error during interrupted backend, successful login; logout and authenticated restore exercised as flows on this surface | 54-61 |
| Home | 1 | All five canonical sections; populated Groups/Finance/Actions/Updates, empty Upcoming; group/Poll/Chat destinations, long updates, fractional money, 1.5 font | 01-03, 24, 48, 61, 108-109 |
| Groups | 13 | Root, overview, members, edit, permissions, admin, transfer selection, invitations, join-code form, invite links, join requests, bans, create form; owner controls and four role-labelled members; empty requests/bans, five pending invitations, keyboard/back, destructive action styles | 04-14, 23, 62, 95-101, 112 (actual create form), 116 |
| Chat | 6 | Home, group conversation, DM, message-request list, message-action sheet, Android attachment picker; three conversations, text/image/history/read avatars/reactions, five-line unsent composer, keyboard, old edited/unsent messages, empty request list; picker cancelled | 15-19, 47, 91-93, 119-120 |
| Activity | 6 | List, create form, detail, edit form, participants/waitlist, date picker; long titles, scheduled/unscheduled, capacity/unlimited and empty waitlist, lifecycle controls, dates/timezone, cancel/back | 25-26, 29-30, 65-66, 78, 85-89 |
| Poll | 3 | List, detail, results; empty list and populated two-option Poll, no selection/selected option, disabled/enabled submit appearance, zero votes/percentages | 27, 49-52 |
| Task | 4 | List, detail, status sheet, delete confirmation; empty/populated, assigned owner, In Progress, history, three status choices, red destructive confirmation cancelled | 28, 67-70 |
| Discussion | 3 | Parent comment composer/post flow, reply composer/post flow, parent action menu; empty/populated, author identity, long text, indentation, keyboard-safe reply submission; missing reply menu | 29, 79-83 |
| Finance | 6 | Fund overview, collection detail sheet, Expense list/detail, Balance, Settlement detail; exact fractional amounts, contribution progress/obligations, payer/shares/private receipt preview, empty and populated settlement histories, pending/completed labels and caller cancellation affordance | 31 (actual Fund), 32, 34-36, 110-111 |
| Calendar | 4 | Month, agenda, filter-menu flow, Activity reminder panel; empty October and populated September, selected date/dots, group/status combined filters retained after return, long event names, expired/unscheduled disabled reminders, 1.5 font | 20-22, 26, 66, 72-77, 89-90 |
| Search | 5 | All, People, Groups, Activities, Conversations; short-query prompt, populated/no-result lists, keyboard, long names/titles, selected categories, 1.5 font; each of four destination categories opened correctly | 40-44, 64-65, 71 (actual Search at 1.5), 113-119 |
| Notifications | 2 | Inbox and preferences; read/unread styling, long body/timestamp, category switches, exact Chat deep link | 45-47 |
| Profile | 7 | Root, edit, privacy, username, password, personal QR, public profile; private avatar loaded, public fallback, unsaved long-name input, account/logout and back | 37-39, 53, 102-107, 114 |
| **Total** | **61** | Screen/sheet/flow counting, not route count | |

### Acceptance Limits / Follow-up Fixtures

- Main session was QA Owner. Owner/admin/member badges and owner controls were reviewed; separate authenticated admin/member/banned/removed UI visibility was **not** re-exercised. Do not reuse M18 backend authorization tests as new physical role-matrix acceptance.
- No archive/delete/transfer/join/accept/ban, RSVP/lifecycle transition, Poll vote, Task status/delete or financial mutation was performed. Form inspection and cancellation are not submission acceptance.
- Discussion completed/cancelled/archived read-only variants were not physically exercised. Parent menu permissions were visible for the owner; moderator-only menu behavior remains a targeted follow-up.
- No new Chat message/image was sent. Picker entry, existing image rendering, historical edits/unsends and action sheet were inspected; recent own-message edit/unsend, live reconnect and fresh image upload were not repeated. Two identical seeded texts are not evidence of duplicate delivery.
- Fund overview/collection and existing Finance media were inspected; separate contribution/proof, fund-expense and reimbursement create/approve variants, Expense create validation and full-screen receipt inspection were not exercised.
- Future reminder configuration had no suitable current fixture: inspected records were past or unscheduled. No due reminder or Firebase cloud delivery test was performed in this UI audit.
- No upcoming Home Activity fixture, empty Notification inbox, populated join-request/ban/message-request fixture, anonymous Poll or nonzero Poll result was exercised.
- Search pagination was not forced beyond available rows. Long person input was an unsaved draft, not a persisted long-name header fixture. Money up to 300000 and 0.01 fractions was inspected, not PostgreSQL NUMERIC maximum-boundary stress.
- No FPS benchmark, screen-reader walkthrough, contrast-ratio measurement or minimum tap-target measurement was performed. Qualitative observation is not accessibility certification.
- Audit inventory can proceed to approval despite these limits; fixes require focused regression plus the specifically affected missing fixtures before claiming product acceptance.

## P0

**0 observed.** No fix made. Backend interruption briefly produced visible connection errors; restoring the runner recovered the same source/data. This was environment recovery, not a newly demonstrated product crash.

## P1

### UI-01: Groups header breaks words at increased font scale

- Screen/severity: Groups root; P1 accessibility/layout.
- Reproduce: open Groups; change Android font scale from 1.1 to 1.5; reopen. Header action row leaves a very narrow title column.
- Expected: brand and page heading remain intelligible, with actions wrapping/repositioning without squeezing words.
- Actual: brand splits into `WeD / o`, heading into `Nhó / m`; baseline is already cramped. Controls remain tappable, but the primary header is broken.
- Evidence: `04-groups.png`, `23-groups-font150.png`, `62-groups.png`.
- Likely source: `mobile/lib/features/groups/presentation/screens/my_groups_screen.dart:106` (Expanded title beside a fixed-width action Row).
- Recommended fix: responsive header/action arrangement using existing components; preserve all navigation. Widget tests at baseline/1.5 text scales plus Samsung recheck.

### UI-02: Own Discussion replies have no edit/delete control

- Screen/severity: Activity detail Discussion; P1 hidden functionality.
- Reproduce: post a parent comment and one reply as QA Owner in active `M15_Device_Reminder_QA_20260929`; compare parent and reply.
- Expected: each eligible comment/reply exposes actions from its server permissions; no client role inference.
- Actual: parent has edit/delete popup; own newly posted reply has only avatar, author, time and content. No reply action menu.
- Evidence: `82-discussion-reply.png`, `83-discussion-actions.png`.
- Likely source: `mobile/lib/features/discussion/presentation/widgets/activity_discussion_section.dart:345`; replies render plain Rows with no action callbacks, unlike parent callbacks at lines 227/230.
- Recommended fix: wire per-reply edit/delete/moderation from existing projected permissions; gate each parent menu entry independently as well. Verify author/moderator/read-only variants with focused widget tests and device cases. No separate Discussion screen.

### UI-03: Pending invitations cannot be identified by human names

- Screen/severity: Groups invitations; P1 interaction target ambiguity.
- Reproduce: Groups -> invitations with existing pending records.
- Expected: group name and inviter display identity available before accepting/declining.
- Actual: cards show group UUID and inviter UUID; five pending cards provide no usable human identity for the decision.
- Evidence: `95-invitations.png`.
- Likely source: `mobile/lib/features/groups/presentation/screens/group_admission_screens.dart:172` and `:194` render `inv.groupId` / `inv.inviterUserId`.
- Recommended fix: inspect existing invitation projection first; render authorized human display metadata, extending that projection only if necessary. Keep IDs for requests, not consumer headings; do not bypass private-group access with unrestricted lookups.

## P2

### UI-04: Consumer copy switches between English and Vietnamese

- Screens: Login/Profile/Calendar/Group admin/join/bans/reminders and root tab captions.
- Reproduce: navigate from Vietnamese Home/Activity/Finance to those screens.
- Expected: natural, consistent Vietnamese consumer copy.
- Actual: `Welcome Back`, `Edit Profile`, `Sign out`, `Ban List`, `All groups`, English validation and date-picker buttons appear alongside Vietnamese.
- Evidence: 12-14, 20-21, 39, 54-60, 77, 89, 96, 100-105.
- Likely sources: Auth/Profile screens; `calendar/presentation/calendar_screen.dart`; group management/admission screens; reminder widgets; shared strings/navigation.
- Fix: scoped display-copy/localization pass including date-picker locale; no API or enum changes.

### UI-05: Technical enums/roles remain consumer labels

- Screens: Group members, Privacy, Search results, Calendar filters/statuses.
- Reproduce: inspect member badges/privacy choices and populated Search/Calendar.
- Expected: localized descriptive roles/status/participation labels.
- Actual: `OWNER/ADMIN/MEMBER`, `EVERYONE`, `active/planning`, `PLANNING`, `All RSVP` exposed.
- Evidence: 07, 39, 43, 74, 77, 115.
- Likely sources: `groups/presentation/widgets/group_widgets.dart`; Profile privacy presentation; Search screen; Calendar screen.
- Fix: shared display mappings, retaining canonical role/state values and permission flags. Distinct from UI-04's ordinary untranslated prose.

### UI-06: Group owner card shows placeholder identity

- Screen: Group overview.
- Reproduce: open weDO QA Team; compare owner card with members/account.
- Expected: actual owner identity, or an honest role-only display if the projection lacks it.
- Actual: owner card says `Group Admin` rather than QA Owner.
- Evidence: 05, 98, `116-search-group-destination.png`.
- Likely source: `mobile/lib/features/groups/presentation/screens/group_info_screen.dart:340` hardcoded text.
- Fix: use authoritative owner display data; preserve ownership and message destination rules.

### UI-07: Chat entry opens old messages instead of the recent conversation end

- Screen: group conversation from Chat Home, Notification and Search.
- Reproduce: open weDO QA Team with September and October history.
- Expected: deliberate recent/unread entry position; latest messages easily reachable. Search is not required to anchor to a hit by current contract.
- Actual: entry shows September 28; October 13 messages require several upward swipes; no jump-to-latest control visible.
- Evidence: 16, 18, 47, 91, `119-search-chat-destination.png`.
- Likely source: `mobile/lib/features/chat/presentation/chat_screen.dart` initial load/ScrollController and ascending ListView; automatic bottom scroll currently occurs after own send.
- Fix: intentional initial positioning/jump-to-latest affordance while preserving older-page prepend position and not stealing scroll during reading. Keep existing no-search-anchor contract.

### UI-08: Notification title/count is squeezed by the header action

- Screen: Notification center.
- Reproduce: open populated inbox; inspect heading beside mark-all-read.
- Expected: heading/count and command both readable.
- Actual: long mark-all-read action consumes the row, leaving title/count a cramped narrow column.
- Evidence: `45-notifications.png`.
- Likely source: `mobile/lib/features/notification/presentation/notification_screens.dart:351` / `:398`.
- Fix: responsive action placement or a familiar icon with tooltip; maintain accessibility label and mutation behavior.

### UI-09: Selected Search categories lose their full labels

- Screen: global Search.
- Reproduce: select People/Activities/Conversations; repeat at font scale 1.5.
- Expected: selected mode remains explicitly identifiable.
- Actual: check icon plus five fixed tracks truncates selected label to `Mọi`, `Hoạt`, `Trò`; All becomes `Tất` at 1.5.
- Evidence: 43, 71, 113, 117-118.
- Likely source: `mobile/lib/features/search/presentation/search_screen.dart` category selector.
- Fix: fit full selected labels with established tabs/scrolling or responsive sizing; no reduced query scope.

### UI-10: Enabled Poll submit has disabled-looking foreground contrast

- Screen: Poll detail.
- Reproduce: select One on M14 MUTE ACCEPT; compare disabled and enabled submit.
- Expected: enabled action readable and visually distinct from disabled state.
- Actual: button becomes purple while label/icon foreground remains gray and visually low-contrast.
- Evidence: `49-poll-populated.png`, `50-poll-selection.png`.
- Likely sources: `mobile/lib/features/poll/presentation/screens/poll_screens.dart:635` and shared FilledButton/theme state colors.
- Fix: inspect resolved enabled/disabled foreground states, then adjust existing theme or local style. Contrast was visually assessed, not instrumentally certified. No vote was submitted.

### UI-11: Login required errors stay after the fields are filled

- Screen: Login.
- Reproduce: submit blank form; fill email and dummy password without resubmitting.
- Expected: stale required errors clear/revalidate on interaction.
- Actual: required messages persist beside filled fields until another submission.
- Evidence: `55-login-validation.png`, `56-login-keyboard.png`, `57-login-keyboard.png`.
- Likely source: `mobile/lib/features/auth/presentation/screens/login_screen.dart` validators/form interaction.
- Fix: use existing form validation with appropriate on-user-interaction behavior, keeping server errors distinct. No live credential was exposed in screenshots.

### UI-12: Decorative surfaces hide ListTile ink/background feedback

- Screen: Profile action rows; corresponding decorated ListTile surfaces warrant targeted inspection.
- Reproduce: navigate/tap decorated rows under the current debug runner.
- Expected: Material feedback remains visible and no framework diagnostic.
- Actual: runner emitted `ListTile background color or ink splashes may be invisible`, explicitly identifying ListTile inside a background DecoratedBox. App remained usable.
- Evidence: current runner diagnostic captured during navigation; rendered Profile surfaces 102-106.
- Likely source: `mobile/lib/features/profile/presentation/widgets/profile_ui.dart:105` places ListTile inside ProfileSurface decoration.
- Fix: correctly place Material/Ink for the existing shape; verify exact emitting surfaces rather than assuming every row is affected. This is a feedback/diagnostic finding, not a crash or measured persistent layout defect.

### UI-13: Public Profile message button has corrupted Vietnamese

- Screen: public Profile opened from People Search.
- Reproduce: search QA -> QA Member 1.
- Expected: correctly encoded Vietnamese message action.
- Actual: displayed text is mojibake rather than natural Vietnamese.
- Evidence: `114-search-person-destination.png`.
- Likely source: `mobile/lib/features/profile/presentation/screens/public_user_profile_screen.dart:93` contains a corrupted literal.
- Fix: UTF-8-correct copy and focused literal/widget assertion. Inspect related source literals separately; do not equate PowerShell's legacy display decoding with an actual app defect.

## P3

### UI-14: Duplicate Activity creation affordances

- Screen: Activity list.
- Reproduce: inspect top create action and lower floating add button.
- Expected/actual: both are usable but lead to the same form, competing for emphasis.
- Evidence: `25-activities.png`; source `mobile/lib/features/activity/presentation/screens/activity_runtime_screens.dart`.
- Optional fix: choose one primary affordance after review; not an authorization to remove a workflow. No palette/radius preference counted as a defect.

## Domain Conclusions / Cross-screen Consistency

- Home: all five sections remain intact; no removal recommended. Owed/receivable headings and fractional values readable. Empty Upcoming is explicit.
- Groups: prioritize header and invitation identity; owner identity/roles/copy follow. Archive/delete/leave use distinct destructive colors; no destructive action executed.
- Chat: keyboard does not cover tested multiline composer/send; existing image bubbles, read avatars and reaction badges fit. Current entry position is friction. Repeated seeded content is not a proven duplicate-render bug.
- Activity: long titles/details wrap, scheduled timezone/date is explicit, unscheduled state has no invented date. Participant chips intentionally scroll horizontally; do not classify that as accidental overflow.
- Poll/Task/Discussion: Task detail/status/delete dialog fit; Poll enabled contrast needs attention; own reply controls are missing. Long replies themselves wrap and indent correctly.
- Finance: fractional 0.01 values preserved, 300000 expense amount and pending/completed settlement labels readable; receipt preview loads. Collection progress 19999.99 remaining reflects its existing obligations, not a rounding defect. Do not simplify decimal semantics.
- Calendar: month/agenda/dots/selection work; combined group/status filters retained after navigating away/back. A fresh 1.5-font recheck at screenshot 72 showed controls fully present: **no Calendar toolbar overflow finding**. English labels/raw status copy remain.
- Search: People, Group, Activity and Conversation destinations were correct; selected-label compression is independent of destination correctness.
- Notifications: read/unread appearance and Chat target work; header/copy need polish. Category controls visible; push policy/cloud delivery not retested.
- Profile: avatar, edit/account/QR/privacy screens reachable. Long unsaved name scrolls inside its input; no persisted name changed. Public message copy is corrupted.
- Cross-screen: Vietnamese Home/Activity/Finance versus English Profile/Auth/admin is the major consistency gap. Shared role/status mappings, typography within constrained headers, enabled/disabled action contrast and Material tap feedback are bounded reuse opportunities.
- Root navigation order/selected destination remained Home / Groups / Chat / Calendar / Profile. Ordinary back/navigation worked in exercised routes; Search can refocus its field and reopen the keyboard on return, but query/category persisted in the checked People/Group flow.
- No measured minimum-size or contrast certification. No broad AppBar, spacing, card-radius, palette or icon-system rewrite justified merely by aesthetic difference.
- No persistent loading failure after healthy responses. Backend stop/recovery caused connection errors that were visible and recovered. Debug screen transitions/images were observed qualitatively, not profiled; no backend performance rework proposed.
- Samsung accessibility floating menu/temporary device edge highlight are OS overlays, not app controls or Flutter overflow.

## Proposed Fix Batches

1. **Functional/accessibility blockers**: UI-01/02/03. Preserve Group and Discussion authorization; obtain missing invitation display data through the canonical projection if needed. Add targeted widget/projection tests, reply author/moderator/read-only fixtures, baseline/1.5 font checks and physical regression.
2. **Navigation/state/readability**: UI-07/08/09/10/11/12. Initial Chat positioning, responsive Notification/Search controls, button states, validation and Material feedback. Verify scroll retention, keyboard/back and disabled/loading states; no API expansion except proven necessity.
3. **Identity/copy consistency**: UI-04/05/06/13, optional UI-14 after approval. Correct real identities, UTF-8 Vietnamese and role/status/participation mappings using existing helpers. Keep financial precision, canonical Home sections and backend enums unchanged.

Each batch requires separate user authorization to implement. This pass made no P0/code fix. Follow focused verification with affected full suites and a fresh Samsung build when implementation changes; do not claim previous M18 results verify future polish.

## Deferred Design Ideas

No new product features, design-system replacement, M19 deployment, backend optimization, financial rule change, schema migration or canonical-section removal. Untested variants listed above are acceptance follow-ups, not newly invented product scope.

## Physical Samsung Evidence

- Host-only screenshots: `C:/Users/truon/AppData/Local/Temp/wedo-pre-m19-audit/`; files 01-120 (120 captures, not 120 unique screens). Not staged or committed.
- Source inspection was targeted to reproduced symptoms. Exact top-priority reproduction/source/fix is above.
- Final PID 9388 bounded device logcat sample: **1270 lines; 0 FATAL EXCEPTION; 0 Unhandled Exception; 0 RenderFlex/overflow matches**. The bounded native logcat did not retain the separate Flutter runner ListTile diagnostic; therefore this is **not** a claim of zero framework warnings throughout the audit.
- Earlier sampled process windows were also crash/overflow-free, but they do not extend bounded sampling into a complete-device log audit.
- Known Firebase registration-unavailable startup behavior did not prevent session restore or screen navigation; no new cloud push acceptance claim.
- QA-only persistent data change: one parent comment plus one nested reply under `M15_Device_Reminder_QA_20260929`, prefixed `UI_AUDIT_20261013` and `UI_AUDIT_REPLY`. They were posted through Flutter to test wrapping/identity. Retained as evidence; reply cannot be cleaned through its missing UI controls. No financial, membership or activity lifecycle data was changed. Unsaved Chat/Profile drafts discarded.
- Repository checks: HEAD/base unchanged; index empty; protected stash OID `f6d2c8029dd5a9a2549bead7d67a61d29e0cab1a` retained. Intended document changes only: this new audit and current handoff. Protected handbook, Stitch inventory and google-services.json remain untracked; no manual protected runtime/design file changes.
- No full backend/Flutter suite rerun for documentation-only audit. M18's historical verified regression is recorded in its handoff, not presented as a newly executed Pre-M19 suite.

## Next Action

Review and approve the bounded three-batch fix plan, beginning with UI-01/02/03. Continue the same branch/worktree; no implementation, staging, commit or push is authorized by this audit completion alone.

## Fix Batch 1 Result

2026-10-13: user authorized all P1 and selected low-risk P2 fixes on the same
`feat/pre-m19-ui-polish` worktree, base/HEAD
`a3810701b747520cae25c8f3a0706c3296703c76`. Original findings and evidence above
are retained; this section supersedes their unresolved status only.

| Issue | Implementation | Physical result / after evidence |
| --- | --- | --- |
| UI-01 (P1) | Groups title uses full width; actions wrap independently, without shrinking text. | FIXED - VERIFIED ON SAMSUNG: font 1.1 and 1.5, short/long existing group labels, reachable actions. `03-groups.png`, `04-groups-large.png`. |
| UI-02 (P1) | Replies reuse comment controls gated individually by server `canEdit`/`canDelete`; no reply-to-reply action. Delete-only menus no longer contain inert edit. | FIXED - VERIFIED ON SAMSUNG: existing long QA reply menu, populated edit dialog/save unchanged content, delete confirmation cancelled, parent reply composer opened/discarded. `11-reply.png` through `15-parent-reply-dialog.png`. |
| UI-03 (P1) | Decode existing API `groupName`, `groupAvatarStorageKey`, `inviterDisplayName`; render human identity/avatar, neutral fallback rather than UUID. | FIXED - VERIFIED ON SAMSUNG: five pending invitations show group names and QA Member 1. No accept/decline. `05-invites.png`. |

No backend production, API, schema, migration or authorization changes. Missing
mobile decoding, not a missing backend projection, caused UI-03. Role/lifecycle
variants remain covered by automated projections; this device pass primarily
used QA Owner and does not claim fresh multi-account acceptance.

## Fix Batch 2 Result

| Issue | Implementation | Physical result / after evidence |
| --- | --- | --- |
| UI-07 | Bottom-anchored reverse Chat list, reversed builder indexing and send-to-offset-zero. REST sequence ordering, grouping, catch-up and dedup unchanged. | FIXED - VERIFIED ON SAMSUNG: latest M18_RECOVER_1013_3 visible on open/reopen after real images load; historical scrolling and keyboard checked. `37-final-chat-loaded.png`, `38-chat-keyboard.png`, `39-chat-reopen.png`, `40-chat-older.png`. |
| UI-08 | Full-size mark-all-read icon with tooltip, preserving callback and disabled states. | FIXED - VERIFIED ON SAMSUNG: readable title/count/body/action, inbox opens. `22-notifications.png`. Mark-all mutation not executed. |
| UI-09 | Wrapping category chips retain complete labels instead of narrow fixed tracks. | FIXED - VERIFIED ON SAMSUNG: 1.1/1.5 text, selected conversation/activity labels and people/activity destinations. `06-search.png`, `07-search-large.png`, `09-activity-results.png`, `23-people-results.png`. |
| UI-10 | Local Poll enabled button uses existing primary/onPrimary colors; disabled theme behavior retained. | FIXED - VERIFIED ON SAMSUNG: selected/unselected options and enabled white label vs disabled state. `20-poll.png`, `21-poll-enabled.png`. No vote submitted; result/closed states covered by existing suite, not newly re-exercised on device. |
| UI-11 | Login revalidates after user interaction. | FIXED - VERIFIED ON SAMSUNG: empty-submit required errors clear when valid inputs entered, QA Owner login restored. `33-login-required.png`, `34-login-valid.png` (masked password). |
| UI-12 | White clipped Material wraps the decorated invite-links ExpansionTile. | FIXED - VERIFIED ON SAMSUNG: advanced row opens with feedback, no ListTile diagnostic in runner or bounded logcat. `29-links.png`, `30-links-expanded.png`. Exact warning root was invite links, not ProfileSurface (which already contains Material). |
| UI-13 | Correct actual malformed public-profile message literal to valid Vietnamese. | FIXED - VERIFIED ON SAMSUNG: QA Member 1 displays `Nhắn tin`. `24-public-profile.png`; callback additionally covered by widget test. No broad encoding rewrite. |

The first single-jump Chat approach, then extent-settling approach, were rejected
by Samsung's image-heavy history; neither is the final implementation. Final
change is the small bottom-anchor list correction. Reconnect test now scrolls to
old/new rows explicitly; old anchor and 105 recovered messages remain asserted.
The 120-message reopen/pagination test includes variable-height long messages.

### Final Verification

- Final affected-feature focused suite: **209 passed, 0 failed**, exited 0 at
  00:25 after the final Chat correction/test formatting. Chat-only focused suite:
  38 passed, 0 failed, exited 0.
- Final complete Flutter suite: **714 passed, 0 failed**, final `All tests passed!`
  at 01:05; command exited 0. Previous M18 count was 704.
- Final `flutter analyze`: **No issues found**, exited 0 (8.0 seconds).
- Final loopback debug APK: build exited 0 (20.6 seconds), confirmed at
  `mobile/build/app/outputs/flutter-apk/app-debug.apk`; installed successfully
  and auto-launched on Samsung R58M36JQYVY / SM-G975U1.
- All five root tabs and back navigation exercised. Chat composer remains above
  keyboard; temporary 8080 reverse interruption/restoration and refresh/reopen
  recovered. This is transport/navigation sanity, not a fresh two-account live
  catch-up acceptance; automated reconnect remains authoritative for dedup/pages.
- Device history fixture had no additional older-page button at its oldest row;
  actual older-page loading is covered by the 120-message widget fixture.
- Bounded final app PID 16651 logcat: 292 lines, 0 fatal, 0 unhandled, 0
  RenderFlex/overflow, 0 ListTile/Material matches. Previous runner window also
  had 0 Flutter exceptions and 0 Material diagnostics. Not an exhaustive log audit.
- Known Firebase Installations registration-unavailable startup diagnostic
  persists; app startup/navigation remains usable. No new cloud-push claim.
- No backend changes or backend tests rerun. No new P0/P1 observed in this bounded
  regression. No Finance, membership or Activity lifecycle mutations. Existing
  reply saved unchanged; delete cancelled; drafts discarded; inbox read state may
  update through existing navigation. Original QA evidence remains present.
- Font restored to 1.1, temporary USB keep-awake disabled. Flutter runners exited;
  repository stop script stopped backend and PostgreSQL/Redis/AIStor, preserving
  volumes. Debug candidate remains installed; use `scripts/dev-run.cmd` for testing.
- After screenshots are host-only at
  `C:/Users/truon/AppData/Local/Temp/wedo-pre-m19-fixes/` (01-40, including interim
  captures; 37/39 show final Chat). No screenshots or credentials added to Git.

## Remaining Issues

- P1 unresolved: 0; observed new P0: 0; observed new P1: 0.
- Remaining known P2: **3**, intentionally deferred: UI-04 general language
  consistency, UI-05 raw technical enums, UI-06 placeholder Group owner identity.
- Remaining P3: **1**, UI-14 duplicate Activity create affordances.
- Other account/permission/lifecycle variants and full 61-surface audit are not
  repeated here; previous audit limitations remain. No redesign or M19 work.

## User Physical Test Candidate

**YES**: all P1 and seven selected P2 fixes physically exercised; final full
Flutter/analyze/build green. User visual acceptance is still required before any
staging/commit. Test Groups at normal/large font, invitations, Activity Discussion
reply menus, image-heavy Chat open/reopen/older history/keyboard, all Search
categories, Poll selection, Notifications, public Profile message button, Login
validation, and invite-link advanced expansion. Check all five tab roots/back.

Git classification: A = ten intended Flutter implementation files, seven test
files (one new), this audit and current handoff. B = protected local-only handbook,
Stitch inventory, Google Services JSON and ignored runtime/design files. C = none.
Index empty; HEAD unchanged; stash `codex-m7-foundation-pre-m6-sync` retained with
OID `f6d2c8029dd5a9a2549bead7d67a61d29e0cab1a`. No commit/push/merge/rebase.

## Final Batch 3 Result (2026-10-14)

This final record supersedes the historical remaining-issues/candidate sections
above; original findings and evidence are preserved. Same branch/base, all Batch
1/2 work retained, no backend changes and no staging/commit/push.

| Issue | Exact correction / current verification |
| --- | --- |
| UI-04 (P2) | Mixed English/Vietnamese on audited Login/Profile/Calendar/Group admin/admission/reminder/root navigation normalized to Vietnamese. SDK localization makes date/time pickers Vietnamese. Device: Login/Profile/Privacy/Calendar/Group/Requests/Bans and date picker; error/reminder variants covered by focused tests. FIXED — VERIFIED ON SAMSUNG for reachable states. |
| UI-05 (P2) | Members badges, Privacy policies, Search Group/Activity status, Calendar status/participation labels mapped for display, not by changing wire/API values. FIXED — VERIFIED ON SAMSUNG; complete mappings and unchanged serialization/filter queries asserted automatically. |
| UI-06 (P2) | Removed fake Group Admin and caller-role-derived owner title. Existing `ownerUserId` matches members' authoritative name/avatar; honest fallback when unavailable. FIXED — VERIFIED ON SAMSUNG with QA Owner and real stored avatar; OWNER/ADMIN/MEMBER caller and missing-owner variants verified by widget tests. |
| UI-14 (P3) | Identical AppBar add and empty CTA removed; persistent create FAB is the sole action for populated/empty lists. FIXED — VERIFIED ON SAMSUNG (populated list and create form navigation); empty-list uniqueness asserted by widget test. |

Narrow sweeps corrected three Chat attachment notices, four Notification router
literals and one Notification repository fallback. Prior public-profile `Nhắn tin`
repair remains. Mobile UI corruption-pattern search has no remaining matches for
the audited mojibake patterns; this is not a repository-wide encoding conversion.
JoinRequest and Ban mobile models now decode existing backend display/avatar
fields. Cards use those identities or honest unavailable text, not UUIDs or fake
Admin names. Device fixtures have no pending requests/bans: empty states checked
physically, populated identity/avatar and fallback states asserted in widget tests.
No backend contract gap, API/migration or permission changes were necessary.

No additional accidental duplicate CTA was found on the scoped screens. Useful
contextual actions remain. Cross-screen sanity found Search disappearing after
Chat -> Group -> Groups because Search args were lost. Root Home/Groups now use
the existing app Search configuration only when omitted. Focused navigation test
and Samsung Chat -> Group -> Groups -> Search both pass; no new repository or
authorization behavior introduced.

### Final UI-01..UI-14 Status

| ID | Final result | This-pass evidence / limit |
| --- | --- | --- |
| UI-01 | FIXED — VERIFIED ON SAMSUNG | 02/05 Groups 1.1/1.5; translated role badge moved below name to avoid real large-font overflow. |
| UI-02 | FIXED — VERIFIED ON SAMSUNG | 24/26 existing parent/reply identity and own reply edit/delete menu; no destructive action this pass. |
| UI-03 | FIXED — VERIFIED ON SAMSUNG | 27 five human-readable invitations; no accept/decline. |
| UI-04 | FIXED — VERIFIED ON SAMSUNG | 07/08/22/36/37/40/41/44/46/47; rare error/reminder variants automated. |
| UI-05 | FIXED — VERIFIED ON SAMSUNG | 05/08/10/15/44; complete enum mappings automated. |
| UI-06 | FIXED — VERIFIED ON SAMSUNG | 03/04 and 34 real owner/avatar, caller-role variants automated. |
| UI-07 | FIXED — VERIFIED ON SAMSUNG | 13/45 latest image-heavy Chat bottom, pagination/reconnect fixture remains automated. |
| UI-08 | FIXED — VERIFIED ON SAMSUNG | 11 Notification title/count/mark-all icon at 1.5; mutation not executed. |
| UI-09 | FIXED — VERIFIED ON SAMSUNG | 09/10 large-font Search, 32 normal keyboard/results, 48 restored Search route. |
| UI-10 | FIXED — VERIFIED ON SAMSUNG | 30 disabled, 35 settled enabled white foreground; no vote sent. Immediate animation capture 31 is not final contrast evidence. |
| UI-11 | FIXED — VERIFIED ON SAMSUNG | 37 empty errors, 40 email error cleared, 41 password error cleared, successful Owner login/root restored. |
| UI-12 | FIXED — VERIFIED ON SAMSUNG | 17 advanced invite-links expansion; no Material assertion. |
| UI-13 | FIXED — VERIFIED ON SAMSUNG | 33 QA Member 1 public Profile `Nhắn tin`. |
| UI-14 | FIXED — VERIFIED ON SAMSUNG | 19 sole FAB, 20 create destination; empty-list case automated. |

Evidence lives only under
`C:/Users/truon/AppData/Local/Temp/wedo-pre-m19-batch3/` (01-48 including intermediate
captures). Not every filename describes a successful tap; only the mappings above
are acceptance evidence. Normal and large font 1.1/1.5 checked on Groups, Search,
Notifications, owner/Profile/Privacy/Calendar. Font restored to 1.1 and USB
keep-awake disabled. Final candidate rebuilt/installed/auto-launched after last
code edit; final root/tab/back, Poll/Login/public Profile/Chat/Calendar and restored
Search navigation revisited. Other unchanged Batch 3 surfaces were exercised
before the final small identity/copy/root-route additions. No fresh 61-surface,
multi-account or cloud-push acceptance claimed. No QA database reset or finance,
membership, Activity lifecycle writes; local drafts cancelled, normal inbox taps
may update read state. Requests/Bans populated states are fixture-only evidence.

## Final Agent UI Regression

- Remaining known audit **P0 = 0, P1 = 0, P2 = 0, P3 = 0**, within this scoped audit.
- Affected-feature focused: **242 passed, 0 failed**, exit 0. Final additional
  route/Chat navigation focused: **61 passed, 0 failed**, exit 0 (overlapping tests;
  these counts must not be summed as unique coverage).
- Final complete `flutter test --reporter compact`: **725 passed, 0 failed**,
  `All tests passed!` at 01:08, command exited 0.
- Final `flutter analyze`: **No issues found**, exit 0, 9.7s.
- Final loopback debug build: **PASS**, exit 0, 18.8s; artifact
  `D:/weDO-app/mobile/build/app/outputs/flutter-apk/app-debug.apk`; successful
  Samsung installation and auto-launch. Existing firebase_core KGP future
  compatibility warning remains nonblocking; no upgrade attempted.
- Bounded final PID **21392** logcat: **979 lines**, Flutter fatal **0**, unhandled
  exception **0**, Android crash **0**, RenderFlex/overflow **0**, Material/widget
  assertion **0**. Known Firebase registration-unavailable diagnostic persists;
  not a new UI regression or a cloud-push acceptance claim.
- Backend unchanged; no backend tests rerun. Runner exited; repository stop
  script stopped backend/PostgreSQL/Redis/AIStor without deleting volumes.

### Batch 3 Implementation Manifest

Paths below are relative to `mobile/`; earlier Batch 1/2 changes are retained.

```text
lib/app/app.dart
lib/core/l10n/domain_labels.dart (new)
lib/features/activity/presentation/screens/activity_runtime_screens.dart
lib/features/auth/presentation/screens/login_screen.dart
lib/features/calendar/presentation/activity_reminder_panel.dart
lib/features/calendar/presentation/calendar_screen.dart
lib/features/chat/presentation/chat_screen.dart
lib/features/groups/application/group_detail_controller.dart
lib/features/groups/data/models/group_models.dart
lib/features/groups/presentation/screens/group_admission_screens.dart
lib/features/groups/presentation/screens/group_info_screen.dart
lib/features/groups/presentation/screens/group_management_screens.dart
lib/features/groups/presentation/screens/my_groups_screen.dart
lib/features/groups/presentation/widgets/group_widgets.dart
lib/features/notification/data/notification_repository.dart
lib/features/notification/presentation/notification_target_router.dart
lib/features/privacy/presentation/screens/privacy_settings_screen.dart
lib/features/profile/presentation/screens/change_password_screen.dart
lib/features/profile/presentation/screens/change_username_screen.dart
lib/features/profile/presentation/screens/edit_profile_screen.dart
lib/features/profile/presentation/screens/profile_screen.dart
lib/features/profile/presentation/screens/public_user_profile_screen.dart
lib/features/search/presentation/search_screen.dart
pubspec.yaml
pubspec.lock
```

New Batch 3 coverage: `test/core/l10n/domain_labels_test.dart` (2 tests), owner
projection/missing data tests in `group_widgets_test.dart` (4), requests/bans
projection/fallback tests in existing `pre_m19_group_polish_test.dart` (4), root
Search-context test in `test/app/routes_test.dart` (1), and single Activity create
assertions/navigation in `activity_runtime_screens_test.dart`. Existing Calendar,
Privacy, Profile, Login, auth navigation, Chat navigation, Groups, Home and root
widget tests update display locators/labels only, retaining serialization, query,
permission and callback assertions. Total suite increased from 714 to 725.

## Ready for User Acceptance

**READY FOR USER ACCEPTANCE**. USER PHYSICAL ACCEPTANCE: **PENDING**, not accepted.
Candidate is installed; start `scripts/dev-run.cmd` to restore local runtime.
Recommended flows: five root tabs/back; Groups roles/owner/member/invitation/join
and ban views; Calendar combined filters/date picker/reminder; Discussion reply
menus; image-heavy Chat open/reopen/history/keyboard; Search categories and result
destinations then return to Groups; Poll select/unselect; Notification header/tap;
Profile/Privacy/public Profile message label; Login empty -> valid validation.
Repeat Groups/Search/Notifications/owner at large font, then restore font.

Final Git classification: A = 50 tracked modified UI/docs/test/dependency files
and four intended new files (this audit, domain labels, domain label test, existing
Pre-M19 group fixture); B = untracked handbook, Stitch inventory, Google Services
JSON and ignored design/runtime paths; C = none. No staged files; `git diff --check`
clean; HEAD unchanged. Protected stash name/OID unchanged. No commit, push, merge,
rebase or destructive Git operation. M18 CLOSED; M19 NOT STARTED.
