# R1 Discussion realtime reliability hotfix — 2026-10-21

## Diagnosis and scope

The four Samsung errors recorded in [physical acceptance](RSVP_REALTIME_PHYSICAL_ACCEPTANCE.md) originate in `DiscussionApi.list` (`discussion_api.dart:20`), reached through `_ActivityDiscussionSectionState._refreshRealtime` → `reloadRealtime` → `RealtimeBinding._reload`. This is the targeted comments REST GET, not RSVP mutation or WebSocket parsing. The original log does not retain HTTP status/transport details: its exception name alone cannot establish a particular status. The timing correlates with intentional backend/relay interruptions; reconnect invalidates visible resources and causes this GET.

The callback caught the REST failure, checked `mounted` and previous future identity, then **created a separate immediately failed `Future<ActivityDiscussion>.error` inside setState**. FutureBuilder attaches to that new future on the next build; its error can escape before the listener attaches. The binding's catch only observes the awaited callback, which already completed normally, not the newly stored failed future. Reaching that assignment implies the widget passed its mounted guard. No evidence of a process/UI crash: the old app continued to Chat Home. This was an uncaught asynchronous error, sufficient to block acceptance.

The focused RED widget test reproduced both uncaught `ApiException` and loss of valid comment content on the pre-hotfix implementation (`/tmp/wedo-discussion-hotfix-red.log`).

## Minimal implementation

Only production file changed by this hotfix: `mobile/lib/features/discussion/presentation/widgets/activity_discussion_section.dart` (already dirty from the earlier realtime integration; its prior edits retained).

- Retain explicit last-good Discussion data and separate error feedback instead of transferring REST errors into unattached futures. Initial/local/realtime loads share immediate async error ownership.
- Typed API failures leave valid comments intact and visibly mark unsuccessful refresh; no fabricated successful empty response. Initial failure offers retry without an empty-list claim.
- 401/403 explicitly report login/access failure, hide protected cached comments and disable commenting. Existing HTTP auth interceptor remains authoritative; no custom login/socket policy.
- Unexpected parsing/programming failures go to `FlutterError.reportError`, not a connectivity message or silent binding catch.
- Mounted checks and monotonically increasing request identity reject late success/failure; resource/repository replacement clears old data and rebinds. Dispose invalidates pending requests.
- Existing invalidation, scope ACK and resync paths call the same authoritative REST loader. No new timer, retry loop, socket creation, dependency, backend/API/schema or shared-core change.

## Identical-pattern audit — not a broad fix

| Area | Finding / follow-up |
| --- | --- |
| Poll | SAME unsafe failed-future publication in list and detail `_refreshRealtime` (`poll_screens.dart:45,424`). Deadline callbacks also reach these methods. Deferred. |
| Task | SAME pattern in list and detail `_refreshRealtime` (`task_screens.dart:46,384`). Deferred. |
| Expense | SAME pattern in Expense detail `_reload` (`expense_screens.dart:209`). Deferred. |
| Settlement | SAME pattern in Settlement detail `_reload` (`expense_screens.dart:1165`). Deferred. |
| Activity | Controller-backed refetch catches typed failure, no newly failed future. Its resync replaces detail with failure-only state on network error, hiding the Discussion child; observed physically below. Separate last-good-state UX follow-up. |
| Group / admission | Controller-backed typed failure states, no identical failed-future publication in audited callbacks. Some admission/management controllers lack disposed/generation guards; separate lifecycle audit needed. |
| Friendship / profile | Controller/state refetch, no identical publication. Social list loaders can replace data with loading/error and lack consistent lifecycle/request guards. Profile relationship has generation/mounted checks. Separate follow-up. |
| Fund | `resync` catches to a failure-only state with default empty collections; not the same uncaught-future mechanism, but last-good-state preservation needs follow-up. |
| Expense/Settlement lists | Controller failure states can discard cached collections/balances; distinct follow-up. |
| Notification Center | Controller catches and retains inbox via copyWith with disposed/generation guards on inbox reload; no identical mechanism. Other mutation/badge lifecycle concerns not accepted here. |
| Home | Explicit value/error and generation/dispose guards, no failed-future publication. |
| Calendar | Explicit activity error/data/generation state; group future is awaited by reload as well as rendered. No identical catch→new-Future.error publication found. |

The shared binding cannot correctly repair a separately published failed future or decide feature-specific authorization/cache policy. Changing its global catch would not solve this cause; no shared rewrite or additional module edit performed. Its broad unexpected-error suppression remains a review follow-up; Discussion now explicitly reports genuine programming errors.

## Focused automated evidence

- `flutter test --no-pub test/features/discussion test/core/realtime test/features/activity/application/activity_controllers_test.dart test/features/activity/presentation/activity_runtime_screens_test.dart test/features/calendar/presentation/calendar_screen_test.dart --reporter expanded`: **53 PASS, 0 FAIL**. Log `/tmp/wedo-discussion-hotfix-focused.log`.
- New `discussion_realtime_test.dart`: successful invalidation visibly updates comments; network failure is handled and retains nonempty data; scope subscribe ACK recovers; timeout/503 recover via resync; no autonomous retry loop; disposed late success/error ignored; stale success/error cannot replace newer success; 401/403 distinct; programming StateError reported rather than hidden. These exercise the actual widget and RealtimeHost/Sync binding, not only a fake controller.
- `flutter analyze --no-pub`: **No issues found (2.9s)**, `/tmp/wedo-discussion-hotfix-analyze.log`.
- No full suite, backend test/build or repeat of physical RSVP A–E. Existing focused RSVP regression stays passing within the 53. Pre-existing `temp_test.dart` untouched.

## Samsung bounded physical check

- Mac freshly detected en0 `<QA_LAN_IP>`; Samsung <QA_ANDROID_SERIAL> `<QA_LAN_IP>`.
- `flutter build apk --debug --no-pub --dart-define=WEDO_API_BASE_URL=http://<QA_LAN_IP>:8080`: SUCCESS. In-place `adb install -r`: SUCCESS, session retained; new app PID26555. APK SHA256 `dafb328daa68fdf676677e501504ae2f4e330e64395adcde606be629d61d0ce4`.
- Existing isolated Capacity Lab Activity `3a09b926-2ba4-4f3c-b266-d729ed072053`. Created one clearly labelled QA Owner comment through terminal, ID`15c36abd-9f66-4c6d-8652-68a068486b9b`: `QA R1 Discussion recovery — baseline`. Already-open Samsung Discussion updated automatically; comments GET200 at22:23:58. No RSVP mutation.
- Disabled **Samsung Wi-Fi only**, retained USB/app process; remotely edited that same QA comment to `QA R1 Discussion recovery — current after reconnect` while offline. Restored Wi-Fi, confirmed same IP. No iPhone manipulation, backend restart or socket-specific source changes.
- Offline parent Activity showed its existing error-only detail state, unmounting/hiding Discussion. Consequently **physical continuous visibility of last-good Discussion content was not demonstrated**; focused widget tests prove that behavior independently. Do not conflate this parent behavior with successful empty Discussion data or claim a full offline UI acceptance.
- Automatic Samsung reconnection: access log shows WS101 and Activity/participants/comments GET200 at22:25:08. UI obtained the updated comment without tapping retry/refresh, navigation or relaunch. Later swipe only exposed the already-loaded content for screenshot verification. New-process bounded log has **zero matches** for Unhandled/ApiException/FATAL EXCEPTION/setState-after-dispose. This is bounded recovery evidence, not proof of every error path or end-to-end scope-ACK wire capture.
- Evidence `/tmp/wedo-discussion-hotfix-{online-ui,offline-ui,recovered-ui,final-ui}.log`, `/tmp/wedo-discussion-hotfix-samsung.log`, `/tmp/wedo-samsung-screen.png` visually inspected, `/tmp/wedo-accesslog/access_log.2026-10-21.log`. No log clearing. QA comment retained as test history; no bucket/DB reset or real finance/main-group mutations.

## Acceptance boundary / preservation

Discussion hotfix automated gate PASS; Samsung bounded remote-update/reconnect smoke PASS. Prior two-device RSVP A–E remain historical PASS. Overall R1/R2 remain **IN PROGRESS**, not global sign-off: identical-pattern follow-ups, parent offline UI and physical negative authorization remain unaccepted. iPhone remains the previous candidate and has **not received this hotfix**; no iPhone build/install/signing action.

Backend/runtime/containers/volumes untouched and left running. Only one production Dart file, one new focused test and affected documentation edited. All other dirty work retained. No stage/commit/push/merge/reset/restore/stash/clean.
