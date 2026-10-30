# Global Navigation UX — 2026-10-28

Status: READY FOR ACCEPTANCE; installed both phones, core physical evidence recorded below.
Branch `feat/pre-m19-ui-polish`; existing R1–R10 worktree preserved.

## Routing audit and implementation

- Production uses `WeDoApp`/MaterialApp, Navigator1.0, guarded/typed `AppRoutes`
  and local MaterialPageRoute pushes. No GoRouter, explicit CupertinoPageRoute,
  custom PageRouteBuilder or nested Navigator was found in production source.
- All three MaterialApp entrypoints (production, social demo, developer showcase)
  share `appPageTransitions` from `app/navigation/page_transitions.dart`.
  Every platform uses120ms forward/reverse opacity-only page transitions.
  Secondary page geometry is static; no page translation, zoom, snapshot remount
  or extra route key. Native camera/picker presentation is outside Flutter.
- iOS/macOS preserve Flutter's Cupertino edge-pop detector with its outer slide
  animations pinned to complete/dismissed constants; the actual route animation
  drives only inner opacity. No copied private gesture recognizer.
- Android uses a scoped WidgetsBindingObserver calling public PageRoute predictive
  back hooks, respecting route.isCurrent/popGestureEnabled and button-event
  fallback. Interactive progress/cancel/commit animate opacity, not scale/slide.
  Ordinary system back continues through Navigator/PopScope.
- Reduced motion (`disableAnimations` or accessible navigation) renders content
  without a visual fade. Back gesture wiring remains. The route controller still
  has nominal120ms; no visual animation is shown. This is not a claim of0ms engine
  scheduling or gesture duration.
- DialogRoute, modal bottom sheets and system camera retain native modal motion.
  Existing Hero behavior is not replaced; no production Hero was found.

## Main tabs

Old `_openTabRoot` replaced the full root with pushNamedAndRemoveUntil on every
selection, destroying previous tab state/scroll. Central `MainTabRoute` now retains
lazy root widgets in an IndexedStack with inactive TickerMode. Main-tab route
forward/reverse durations are0; tab switching does not push a route. State,
controllers, input text and scroll survive, initialized once per visited tab.
Keyboard focus is released on switch without discarding text.

A Navigator-identity Expando registry lets existing global-tab callbacks from
pushed details return to the retained root; detail routes still belong to the
same Navigator. No extra GlobalKey, nested navigator, new socket, or per-feature
routing was introduced. Registered hosts are removed on disposal; existing auth
boundary destroys all retained state on session reset. Existing argument
enrichment/auth guards still construct first-visit roots. Direct named/deep-link
pushes preserve their explicit stack semantics; this is not a new per-tab detail
stack architecture. Returning from a pushed detail follows its normal back fade.

## Coverage and evidence

-266 focused Flutter PASS,0FAIL in15s: new cross-platform push/pop geometry and
  duration, reduced-motion rendering, iOS edge commit/cancel, Android predictive
  progress/cancel/commit, system back, modal exceptions, lazy tabs/scroll/disposal;
  existing production auth/cold-start/deep-link/five-tab routes, auth integration,
  Chat/Poll/image viewer, Journey, Moments/Album and Community regressions.
- The named nested-route harness verifies shared route mechanics for Group→Activity
  →Stop→Camera, Chat/Poll, Community/Post, Moments/Album/fullscreen. It is not physical
  UI proof of every feature. Existing feature tests supplement it.
- Analyzer clean3.6s. Logs `/tmp/wedo-nav-focused.log`,
  `/tmp/wedo-nav-analyze-final.log`. No backend suites/build/schema/API/QA changes.
- New tests initially needed an explicit Cupertino builder import and correction
  of test-only platform reset/first offstage route frame; final checks pass.
- Existing dirty diff statistics include earlier milestones; do not attribute
  the full repository diff to this UI task.

## Files touched by this task

Production policy/retention: `mobile/lib/app/navigation/page_transitions.dart`,
`mobile/lib/app/navigation/main_tabs.dart`, `mobile/lib/app/app.dart`,
`mobile/lib/app/routes.dart`. Standalone entrypoint wiring:
`mobile/lib/main_social_demo.dart`, `mobile/lib/main_dev_showcase.dart`.
Tests: `mobile/test/app/navigation_transitions_test.dart`,
`mobile/test/app/routes_test.dart` (retained real Home State assertion).
Documentation: this report, session handoff, current handoff, decision log,
roadmap and R10 delivery reference. Previous edits in these files remain intact.

## Physical acceptance checklist / limits

Samsung and QA iPhone: Home→Group→Activity→Journey→Stop, back; Group→Chat→Poll details,
back; Community→Post, back; Moments→Album→image, back. Switch all main tabs and
return to a scrolled root. Check no horizontal slide/zoom/blank flash, correct
back stack, unchanged Chat images/scroll. On QA iPhone, also test short canceled and
committed left-edge back gestures. Test accessibility reduced motion on each
phone where feasible. Do not repeatedly initialize unsupported iOS automation.

Current Android/iOS build/install and actual device results will be recorded
below. Automated gesture/geometry evidence does not become physical PASS.
R10 remains IN PROGRESS; R9 must include this cross-cutting acceptance matrix.
No commit/push/merge/reset/restore/stash/clean.

## Final candidate / physical evidence

- Android17.5s and iOS46.0s buildPASS, install-in-place/launchPASS both devices,
  API `http://<QA_LAN_IP>:8080`. APK SHA256
  `255601c41099576e867029e22b08e6bf7b743c15b5cfc053fafc380bfde5b4c2`;
  Runner `bf018e8a83f02a43fca7eb71dc9ce4c93d9a771c9444591f6534fde6ca50fc19`.
  `/tmp/wedo-nav-{android,ios}{,-install,-launch}.log`.
  Native project/Info.plist signing hashes unchanged; no Firebase/session edits.
- QA iPhone: user explicitly reports **“fade OK; back OK; giữ cuộn OK”** in response to
  Home→Group→Activity→Journey→Stop, back, committed/short-canceled left-edge gesture
  and tab scroll checklist. Physical PASS for that exact reported scope. No claim
  of every module or iOS accessibility-setting acceptance.
- Samsung: actual navigation-only ADB/UI-tree interaction verified Home→QA Group
  →Activity→Journey→completed Stop; system back to Journey/Activity/list/group/Home.
  Existing check-in image visible, completed badge/progress shown. Then actual
  Home scroll→Groups→Home yielded identical visible semantic text/bounds (retention
  PASS). ChatHome→QA Chat→“Đi mua rau” Poll detail and back PASS. Community→existing
  recruitment post detail and back PASS. Group74→Moments→Album→R4 QA Member Album
  →fullscreen logo and back to Album/Moments/group/Home PASS. No votes/messages/
  reactions/financial/camera submissions performed; no fixtures reset/edited.
  Opening Chat can advance ordinary read receipts as part of normal app viewing.
- Actual screenshots reviewed `/tmp/wedo-nav-stop.png`, `/tmp/wedo-nav-gallery.png`;
  UI helper/read snapshots `/tmp/wedo-nav-ui.py`, `/tmp/wedo-nav-ui.xml`,
  `/tmp/wedo-nav-home-scrolled.xml`. Screenshots prove final rendering, not120ms
  motion timing. Six-platform geometry/duration tests provide automated no-slide
  evidence; user provides actual iPhone visual judgment. No fabricated Samsung
  frame-by-frame timing/video claim.
- Remaining: actual newer-Android predictive gesture/reduced-motion settings,
  iPhone adjacent module matrix, and a fresh cross-device text-send/Chat-old-image
  check on this exact candidate were not separately repeated. Existing focused
  image identity regression passed; earlier user physical image evidence remains
  scoped to earlier tests. No reproduced blocking navigation defect.
- Backend healthUP after physical checks, runtime left running, Samsung returned
  to retained Home. QA schema/API/backend/data unchanged by this navigation task.
  R10 remains IN PROGRESS; R9 includes the remaining cross-cutting checks.
