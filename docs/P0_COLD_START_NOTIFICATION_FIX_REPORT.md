# P0 COLD-START NOTIFICATION FIX REPORT

Date: 2026-10-20. Sender override explicitly approved by user: iPhone disconnected, send as QA Owner from terminal. Physical proof concerns real Samsung receipt/tap/navigation, not an iPhone send.

Branch: `feat/pre-m19-ui-polish`
HEAD: `cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`
Dirty worktree preserved: YES; Gemini source edits and existing PRE-M19 changes untouched except the additional narrow fix below. No migration, DB reset, volume deletion, clean, signing change or iPhone rebuild.

## ROOT CAUSE

FCM data contains `route` (current Chat producer uses `/chat/conversation`); Android FlutterActivity also treats the intent extra named `route` as its initial route. Flutter WidgetsApp prioritizes the platform default route over MaterialApp.initialRoute. The previous custom onGenerateInitialRoutes used that supplied name, which may be unsupported or lack the typed arguments required for a protected Chat/Activity route, so its route builder returned null and the null assertion broke the root tree. `_elements.contains(element)` and the later deactivated-Navigator/Theme lookup were downstream symptoms. Supplying NavigatorState or scheduling a later push cannot repair an already-failed root bootstrap.

Evidence: `/tmp/wedo-p0-platform-route-before.log` reproduces null assertion in app.dart followed by the exact `_elements.contains(element)` assertion with simulated platform `/groups/chat`. Fresh actual FCM on the installed Gemini APK produced `/tmp/wedo-p0-run-a-flutter.log`: Theme.of → MaterialRouteTransitionMixin → NavigatorState.pushNamed → NotificationTargetRouter.open:132 → main.openPushNotification:311. Installed Gemini APK update timestamp was 2026-10-20 00:31:19; no rebuild was done before reproducing.

## GEMINI FIXES RETAINED

- main.dart: session restoration/validation, scheduler-aware safeNavigate, target resolution and current-generation checks retained.
- notification_target_router.dart: direct NavigatorState support retained; no return to ancestor lookup from Navigator's own context.
- notification_push_service.dart: tap-key dedupe and readiness/authentication gates retained.
- Existing target-router regression and `mobile/test/temp_test.dart` preserved.

## ADDITIONAL CODEX CHANGES

YES — `mobile/lib/app/app.dart`: compute the session-derived root once and always use it in onGenerateInitialRoutes, ignoring platform-provided target names during bootstrap. Existing queued notification/link handlers resolve protected targets after root installation. No arbitrary sleeps or assertion suppression.

`mobile/test/app/routes_test.dart`: regression injects a non-default platform Chat route, verifies authenticated Home is the sole root, then pushes/pops a resolved target and returns Home without error. It failed before the fix with both reported assertions and passes afterward.

## TESTS

- Existing Gemini notification code baseline reverified: 27 notification feature tests PASS; targeted analyze clean. Recent Gemini output files were not available, so no unsupported prior-test claim.
- After narrow root fix: **86 focused route + notification tests PASS**, `/tmp/wedo-p0-platform-route-after.log`.
- `flutter analyze`: **No issues found**, `/tmp/wedo-p0-final-analyze.log`.
- Full 769-test suite not repeated; change is limited to root initial-route selection.

## CANDIDATE

Mac IP: `<QA_LAN_IP>`
Samsung IP: `<QA_LAN_IP>`
Backend health: local and LAN `/api/v1/health` UP; no backend restart/change for this P0.
APK build: PASS with `WEDO_API_BASE_URL=http://<QA_LAN_IP>:8080`; `/tmp/wedo-p0-fixed-apk-build.log`.
APK install: in-place `adb install -r` SUCCESS; device lastUpdateTime `2026-10-20 01:00:10`, version1.0.0/code1.
APK SHA256: `4a66cdf7dc2c4b9b4b30e3f98f0a506141e0223d8213ac7888ba197e77646b13`.

## PHYSICAL RUN A

Terminated: confirmed PID ABSENT before send via `am kill --user 0`, no force-stop.
Real FCM: exact `P0 VERIFIED A 20-10 OWNER TERMINAL`, durable sequence46.
Tap: exact matching SystemUI body tapped, not an API/deep-link shortcut.
Correct chat: weDO QA Team, exact fresh message visible, PID5932.
Red screen: NO; Flutter logs show one dispatch/resolve and no exception/assertion.
Back → Home: YES, one Android Back; authenticated Trang chủ/Tab1 verified.
PASS. `/tmp/wedo-p0-verified-run-a.log`, `...-a-back.log`, `...-a-flutter.log`.
Harness note: initial helper used an incorrect composer-label predicate and reported CHAT NOT OPEN despite the correct chat title and exact message in its own UI capture. This was corrected in the external helper only; the independent one-Back Home and no-error log checks completed this run. No product change followed.

## PHYSICAL RUN B

PASS — PID ABSENT before send, exact fresh FCM `P0 VERIFIED B 20-10 OWNER TERMINAL`, sequence47, correct QA chat + exact message, PID6537, no Flutter exception/assertion, one Back → authenticated Home. `/tmp/wedo-p0-verified-run-b.log`.

## PHYSICAL RUN C

PASS — PID ABSENT before send, exact fresh FCM `P0 VERIFIED C 20-10 OWNER TERMINAL`, sequence48, correct QA chat + exact message, PID6905, no Flutter exception/assertion, one Back → authenticated Home. `/tmp/wedo-p0-verified-run-c.log`.

## NORMAL COLD LAUNCH

PASS — normal background process termination (not force-stop), then Android launcher-icon intent; new PID7499 restores authenticated Home, all five root tabs visible, no Login/Welcome. `/tmp/wedo-p0-verified-normal.log`.

## BACKGROUND NOTIFICATION TAP

PASS — PID7499 retained in background; real FCM `P0 VERIFIED BACKGROUND 20-10 OWNER TERMINAL`, sequence49, actual notification body tapped, correct QA chat + exact message. One opened-app event, one dispatch and one target resolution; no Flutter error. One Back → Home proves no duplicate Chat route above the root. `/tmp/wedo-p0-verified-background.log`.

LOGIN/WELCOME LEAK: NO in the final verified runs. No further product changes after installing the accepted APK. Initial failed reproduction on Gemini APK remains recorded separately, not counted among the final A/B/C.

IPHONE REBUILD NEEDED: NO for this Android-only acceptance; iPhone disconnected and not rebuilt/claimed tested. Shared app.dart fix will naturally be included in the next synchronized iOS candidate. Owner sending was terminal/API by explicit latest user instruction; device-side FCM receipt/tap/launch/Back was physical throughout.

Final device state: profile identity freshly verified as QA Member 1, then returned to authenticated Home/Tab1, PID7499; LAN backend health freshly UP. No iPhone connected or touched. Only QA chat messages added (including bounded reproduction attempts); no finance/membership/RSVP data modified.

## GIT SAFETY

No stage/commit/push/merge/M19. Existing two blank-EOF diff-check warnings preserved (group-polish/public-profile tests); stash unchanged. No credentials/tokens/passcodes printed or copied into new helper/report. QA Owner uses existing local fixture in memory and real chat endpoint; no synthetic push payload injection.

P0 COLD-START NOTIFICATION FIX READY FOR USER RETEST
