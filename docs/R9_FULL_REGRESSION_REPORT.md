# R9 — current signing audit correction

## Read-only signing discrepancy audit — 2026-10-30 (supersedes earlier team interpretation)

**There is no observed team mismatch and no paid-team migration is needed.** Earlier reports incorrectly parsed `<CERTIFICATE_CN_SUFFIX>` from certificate Common Name as its Team ID. This was an agent interpretation error, not evidence Xcode selected a different/old Personal Team. The actual certificate **OU=<APPLE_TEAM_ID>**, matching project, profile, signed artifact and Xcode paid-team cache. Do not change to<CERTIFICATE_CN_SUFFIX>.

| Read-only evidence | Actual value |
|---|---|
| Runner Debug / Profile / Release DEVELOPMENT_TEAM | All **<APPLE_TEAM_ID>**, no xcconfig team override found |
| Runner bundle ID, all three configurations | **com.huygiang.wedo** |
| Explicit profile specifier / CODE_SIGN_ENTITLEMENTS | Unset; no team/profile override pinned to5Z |
| Local public certificate CN | Apple Development: Giang Huy (**<CERTIFICATE_CN_SUFFIX>**) |
| Same certificate subject OU | **<APPLE_TEAM_ID>** — actual team; CN suffix is a different identity label |
| Signed app codesign TeamIdentifier | **<APPLE_TEAM_ID>** |
| Signed application-identifier | **<APPLE_TEAM_ID>.com.huygiang.wedo** |
| Embedded profile TeamIdentifier / entitlement team | **<APPLE_TEAM_ID>** / **<APPLE_TEAM_ID>** |
| Embedded profile name/application-identifier | iOS Team Provisioning Profile: * / **<APPLE_TEAM_ID>.*** |
| Embedded DeveloperCertificates OU | All inspected embedded certificates **<APPLE_TEAM_ID>**, including matching Apple Development CN |
| Current signed artifact / profile APNs entitlement | **aps-environment ABSENT** in both |
| Xcode account cache | One reference<XCODE_ACCOUNT_REFERENCE>, teamNameGiangHuy, teamID**<APPLE_TEAM_ID>**, teamTypeIndividual, **isFreeProvisioningTeam=false** |
| Installed QA iPhone app read-only metadata | Samebundlecom.huygiang.wedo,1.0.0(1); embedded signing inspected in retained build artifact, not remote executable extraction |

Xcode preferences `DVTDeveloperAccountManagerAppleIDLists.IDE.Identifiers.Prod` references the same cached account as `IDEProvisioningTeamByIdentifier`. The readable cache does not provide its Apple Account email; no password/token/keychain credential was retrieved to discover it. Account/team synchronization is supported by the cached paid Individual record, not a new online portal authentication. One GiangHuy entry is consistent with the examined cache; no evidence of a stale Personal Team or a second selected team. User-reported active membership remains accepted.

The remaining verified signing gap is **capability/profile scope**, not account membership/team identity: valid existing wildcard profile (created2026-09-07,expires2027-09-07) and current app have noAPS, project no push entitlement file. A generic wildcard profile is not by itself proof stale credentials or failed account sync. Whether an explicit App ID / Push capability already exists online remains UNVERIFIED; do not create a duplicate resource from local absence.

### Safest future capability upgrade (recommendation only, not executed)

1. Keep team **<APPLE_TEAM_ID>**, existing development certificate/private key, bundle **com.huygiang.wedo** and signed application identifier prefix unchanged. No team switch, account logout/re-add, certificate revocation/rotation or cache deletion is justified.
2. Read/check existing exact App ID on this same paid team and existing APNs/FirebaseApple configuration first. With explicit approval, enable Push for the exact App ID; only create a resource if confirmed absent and separately authorized. Apple documents that adding Push may require an explicit App ID and matching managed profile: [Apple Xcode Push capability](https://help.apple.com/xcode/mac/current/en.lproj/devdfd3d04a1.html).
3. After approval, obtain a **new separate push-capable profile** for this same team/bundle and QA iPhone, reusing the approved certificate. Preserve the current wildcard profile and every existing signing asset. Automatic signing must not be allowed to silently create/replace account resources before that review. Validate newprofileteam/AppID/aps before any build.
4. Only after additional authorization/config readiness: build with matching entitlement, inspect signed TeamIdentifier/application-identifier/keychain groups against current artifact (currently no explicit keychain-access-groups), and install **in place**, never uninstall/clear data. Same bundle/application-identifier and unchanged storage/session behavior are the preservation plan; session retention must be checked on device, not assumed from signing metadata.
5. Continue existing pending iOSFirebase/APNs token/backendIOS/foreground/background/tap gate. No push acceptance claimed here. R9 staysINPROGRESS.

**Audit execution:** public certificate subject/profile/codesign and local Xcode preference reads only; no private key export, credential retrieval, AppID/capability/Appleconsole change, profile regeneration, build, test, app launch/reinstall or signing/source change. Only additive documentation corrections preserve the handoff and prevent the earlier incorrect team recommendation. Redacted structured evidence `/tmp/wedo-signing-team-audit.json`.

---

# R9 — latest iOS push implementation checkpoint

## iOS push enablement — 2026-10-30, after membership confirmation

**R9 IN PROGRESS; one mandatory iOS physical push/tap gate remains.** User confirms active Individual Apple Developer Program membership through2027-01-21 and Xcode Admin role. **Membership is not the blocker.** This update supersedes earlier Android-only source findings: they are now corrected in source, not yet deployed.

### Verified environment / account-owned configuration boundary

- Existing project/built artifact uses team **<APPLE_TEAM_ID>**, bundle **com.huygiang.wedo**, embedded wildcard profile **<APPLE_TEAM_ID>.***. Signed artifact and profile have **no aps-environment**. This does not mean the user's paid membership is absent.
- Read-only keychain identity metadata shows a signing identity from team **<CERTIFICATE_CN_SUFFIX>**. This is not sufficient evidence to select that team automatically or claim an explicit App ID is registered to it. Pending user confirmation which paid team owns the exact bundle and push capability. No team/certificate/profile changed or overwritten, no -allowProvisioningUpdates, no Apple portal mutation performed.
- Existing Android Firebase project **wedo-3304c** matches external backend Admin credential project (boolean comparison only). iOS source/current artifact has no GoogleService-Info.plist. No matching external GoogleService plist or *.p8 in the designated `<PRIVATE_CONFIG_DIR>` directory at inspection. **This is not proof the Firebase/Apple portals have no existing Apple application/key.** Existing APNs key/app must be checked before creating anything.
- No connected browser/Apple/Firebase administration tool is available in this session. A single asynchronous request gives exact operator navigation: Apple Developer→Certificates, Identifiers & Profiles→Identifiers→com.huygiang.wedo→Push Notifications; Keys→inspect existing APNs key; FirebaseConsole→wedo-3304c→Projectsettings→General→matchingiOSapp; CloudMessaging→Appleappconfiguration→existingAPNscredential. No private key/token/password requested in chat. Requested nonsecret team/resource status and optional downloaded plist path `<PRIVATE_CONFIG_DIR>/wedo-ios-GoogleService-Info.plist`. Request pending, no assumption of approval/config completion.
- Automatic provisioning cannot safely be verified against an unconfirmed team/App-ID owner. Stop credential-sensitive/account-owned actions until confirmation/approval; reuse approved resources, do not create duplicate app/key. Preserve bundle/session; after correct configuration the signed artifact must actually include aps-environment before physical testing.

### Implemented minimal client slice — source, not installed candidate

Only2production Dart files, task-only **+46/-4**, baseline `/tmp/wedo-ios-push-baseline`:

- `mobile/lib/main.dart`(+15/-2): initializes existing Firebase/shared NotificationPushService on Android **and iOS**, excludes unsupported platforms/web, registers correct ANDROID/IOS platform. iOS foreground native alert/badge/sound disabled explicitly so existing onMessage SnackBar is the single foreground presenter; background/terminated notification remains OS-handled. Existing typed/authenticated notification resolver, mark-read, session generation, logout cleanup and background handler retained. No new transport or notification framework/UI.
- `mobile/lib/features/notification/application/notification_push_service.dart`(+31/-2): centralized platform mapping; Firebase adapter awaits getAPNSToken on iOS **before** getToken. Null/empty pending APNs returns no registration, avoids dependent FCM call; native FCM onTokenRefresh later feeds existing registration listener when APNs/FCM is ready. No polling/sleep/retry loop. Unsupported native platforms return null; Android calls FCM directly without touching APNs. Expected platform/Firebase failures stay at existing startup boundary; programming errors propagate. This event-driven recovery still needs actual iOS physical proof.
- No iOS project/Info.plist/signing/entitlement/Firebase file changed before prerequisites. No backend production changes. Android existing behavior preserved by targeted regression, not a claim a new Android candidate was physically retested.
- New6test cases(+84lines) in existing `notification_push_service_test.dart`: platform mapping; Android never calls APNs; pending/empty APNs never calls FCM; delayed APNs awaited then exactlyoneFCM; programming/platform errors propagate; unsupported platform no token calls. Existing cold-start tap/dedupe/auth/logout/token-refresh cases retained byte-for-byte except inserted tests. Removed only own unrelated formatter churn; no existing dirty edits discarded.

### Executed verification

- **38 focused Flutter PASS/0FAIL**, `/tmp/wedo-ios-push-focused-final.log`:
  `flutter test test/features/notification/notification_push_service_test.dart test/features/notification/notification_target_router_test.dart test/features/notification/notification_api_test.dart test/features/notification/notification_realtime_controller_test.dart --reporter expanded`.
- **Analyzer clean**,2.4s, `/tmp/wedo-ios-push-analyze-final.log`. Initial run exposed two formatting/import infos introduced by this edit; corrected, final clean. Earlier accidental relative-path cleanup script failed before touching files; rerun from correct absolute paths, no source lost.
- **1 targeted PostgreSQL backend PASS/0FAIL/0ERROR/0SKIP**, `/tmp/wedo-ios-push-backend-device.log`,15.8s:
  `JAVA_HOME=$(/usr/libexec/java_home -v 21) MAVEN_OPTS=-Xmx768m ./mvnw '-Dtest=NotificationServiceIntegrationTest#deviceTokenLifecycleSupportsMultiDeviceCrossUserTokenTransferDeactivationAndInvalidTokenCleanup' -DargLine=-Xmx1024m test`.
  Existing test verifies multi-device IOS/ANDROID registration, cross-user token transfer/deactivation and invalid cleanup in disposable test DB, not shared QA/provider physical delivery. No full backend suite rerun.
- No full product suite rerun after this bounded push patch; earlier supported1252PASS/0FAIL is prior-checkpoint evidence, not a new full-run result for current source. Preserved scratch file checksum still5d9651e4f08e5900440d7c08d9fe07c4e710977f26134b7f2359586758f73261, no scratch edit/deletion/exclusion change.
- No new mobile build/install: only build when Firebase/signing ready, sufficient disk, artifact APS verified. Installed two-device IP.100 candidates are **pre-push patch**, existing user sessions remain intact. QA backendHTTP200/current runtime/media retained; no user/group/financial mutations or extra QA push sent this task. No Secondary iPhone.

### Remaining precise gate / continuation

1. Confirm owning paid team, exact App ID+Push capability, existing Firebase Apple app/config and existing APNs credential status through the pending operator request. If resource creation or credential provisioning is necessary, explain exact action and obtain specific approval; don't rotate/delete/create blindly.
2. Reuse approved Apple/Firebase resources, minimally configure current iOS target capabilities/plist and appropriate profile. Do not treat team identity metadata or Profile build alone as APS readiness.
3. Run focused checks for any additional config/code edits; build/install **in place** on QA iPhone only with current LAN URL, verify signed aps-environment and provisioning, preserve bundle/session. No unrelated rebuilds or cache cleanup.
4. Actual QA iPhone permission/APNs token/FCM token/backendIOS registration, foreground, backgroundOSreceipt, tap→correctauthorizedChat/session/no-duplicates. Android physical push regression as applicable to deployed final source. No raw tokens/key contents in logs. Required gate stays open until real evidence or an explicit approved scope change.

**Physical result: BLOCKED_BY_UNVERIFIED_APPLE_FIREBASE_CONFIGURATION.** No new iOS permission/token/provider/presentation/tap PASS inferred from38+1tests. Previous reaction realtime/Samsung OS push evidence retained. Production distribution/TLS/secrets/backups/monitoring/privacy requirements remain separate.

---

# R9 full regression — latest two-gate checkpoint

## R9 final two-gate decision — 2026-10-30

**Scratch gate RESOLVED transparently; iOS push gate OPEN. R1–R8/R10 remain COMPLETE; R9 IN PROGRESS.** This dated decision supersedes earlier pending scratch-disposition notes without removing their evidence. The user explicitly authorized preserving a demonstrably scratch-only file and running an explicitly scoped supported suite; no silent exclusion or Definition-of-Done change.

### Gate B — preserved scratch classification / supported product tests

- Exact path: `mobile/test/temp_test.dart`, **untracked** (`git ls-files --error-unmatch` rejects it), no Git history returned by `git log --all -- ...`; it pre-existed R9. Its creator/date/intent cannot be proven from Git; classification is based on content, not invented attribution.
- **TEMPORARY_SCRATCH_TEST**: imports only Flutter Material and flutter_test; constructs SDK MaterialApp/Scaffold/GlobalKey and asserts `Navigator.of(key.currentState!.context)` throws. It imports no weDO code, calls no product navigation/route/session/repository, and is a standalone SDK lookup probe. Supported production navigation tests remain in the suite.
- Exact assertion at line11: `expect(() => Navigator.of(key.currentState!.context), throwsFlutterError);`. Reproduced separately, exit1: `Expected: throws <Instance of 'FlutterError'>; Actual: <Closure: () => NavigatorState>; Which: returned NavigatorState`. SDK `Navigator.of` explicitly accepts a StatefulElement whose state is NavigatorState, so this probe's expectation contradicts the installed SDK. It is not evidence of a weDO navigation bug or an environment failure.
- **Preserved byte-for-byte**, SHA256 `5d9651e4f08e5900440d7c08d9fe07c4e710977f26134b7f2359586758f73261` before/after. Not deleted, moved, skipped via annotation, renamed, ignored by config, or assertion-edited. No product/test source changes.
- User-authorized supported scope: **all128 files under mobile/test matching *_test.dart except exactly test/temp_test.dart**. Every other test remains included. **1252 PASS /0 FAIL, exit0**,70s, `/tmp/wedo-r9-supported-flutter.log`. Scratch separately **0 PASS/1 FAIL**, `/tmp/wedo-r9-scratch-classification.log`. Prior unrestricted full run remains **1252 PASS/1 FAIL**; do not claim unrestricted `flutter test` passes.
- Full path list, exact command and excluded file/hash/reason: `/tmp/wedo-r9-two-gate-test-scope.json`. Reproduce from `mobile/` with installed Flutter:

```python
from pathlib import Path
import subprocess
files = sorted(str(p) for p in Path('test').rglob('*_test.dart')
               if p != Path('test/temp_test.dart'))
subprocess.run(['flutter', 'test', '--reporter', 'expanded', *files], check=True)
```

The suite includes existing push service, notification API/router/realtime, authentication/navigation, media and permission regressions. No redundant backend/full-regression rerun. Analyzer not rerun because no production/test Dart source changed; last authoritative R9 analyzer remains clean.

### Gate A — iOS read-only diagnosis

| Layer | Exact finding | Classification / evidence limit |
|---|---|---|
| Device / bundle | QA iPhone available/paired; installed `com.huygiang.wedo`,1.0.0(1). Secondary iPhone not controlled. | Device app metadata confirmed; no new app installation. |
| Signed candidate | Retained `mobile/build/ios/iphoneos/Runner.app`: signed entitlement keys only application-identifier/team-identifier/get-task-allow; **aps-environment ABSENT**. | A: confirmed in the retained candidate artifact used for prior install; not a remote byte-for-byte dump of installed executable. |
| Embedded provisioning | Existing wildcard application identifier, get-task-allow=true; **aps-environment ABSENT**; expires2027-09-07. | A: current profile does not authorize APNs. No profile/certificate/team change. |
| Capabilities / background | No CODE_SIGN_ENTITLEMENTS/Push SystemCapability in examined Xcode config; no UIBackgroundModes/remote-notification in source or retained artifact. | Local configuration missing. Background mode is a separate capability, not proof ordinary visible alerts always require silent/background delivery. |
| Firebase Apple app config | No GoogleService-Info.plist in examined iOS source or artifact; no explicit iOS FirebaseOptions in bootstrap. Generated registrant includes Firebase plugins. | B: installed plugins alone do not configure Firebase. Cloud-console Apple app/APNs credential status **UNVERIFIED**, not asserted absent. No credential contents inspected/printed. |
| Bootstrap | `mobile/lib/main.dart:55` initializes Firebase and starts push only for TargetPlatform.android; registration closure uses literal platform 'ANDROID' at line377. | Confirmed missing iOS wiring, not merely an unperformed physical test. Enabling iOS unchanged would mislabel registration; preserve existing behavior until usable iOS configuration can be verified. |
| APNs / FCM token | Existing adapter calls getToken/onTokenRefresh but no iOS getAPNSToken readiness path; app's push service not started on iOS. | C: APNs/FCM token acquisition **not observed**, no fabricated token query/success. No raw tokens logged. |
| Backend device record | Prior R9 read-only query had0iOS rows,1activeAndroid/1inactiveAndroid. Current query failed because Docker daemon unavailable. | D: no new backend persistence failure proven; current row count NOT VERIFIED, historical0 not presented as fresh. No daemon restart/reset. |
| Provider | Existing FirebaseAdmin FcmPushGateway sends token-targeted notification/data plus AndroidConfig. | E: no eligible iOS send attempted; provider Apple credential validity unverified. AndroidConfig alone is not proof iOS sends are impossible; no backend defect reproduced/fixed. |
| Foreground | Generic onMessage callback/in-app handling exists but is gated by Android bootstrap; no explicit Apple foreground presentation configuration found. | F: actual iOS permission/presentation **CHƯA TEST**, not denied/failed by assumption. |
| Background / terminated | Generic plugin background handler/getInitialMessage/onMessageOpenedApp code exists, not wired to iOS initialization. | H: actual iOS OS receipt/resume/terminated behavior **CHƯA TEST**. |
| Tap / authorization | Shared notificationId resolver performs markReadForTap and authenticated/session-generation checks, then canonical router; supported tests cover this abstraction. | G/H: iOS physical tap/correct Chat/no duplicate/session/revoked-access test **CHƯA TEST**; Android physical receipt/tapPASS and older privacy tests do not substitute. |

**Physical gate: BLOCKED_BY_EXTERNAL_CONFIGURATION**, with additional confirmed client integration work above. Not characterized as a provider delivery defect or as a pure credentials-only problem. User instruction requires stopping this portion if Apple account/new credential action is needed; no speculative iOS bootstrap patch, credential creation, signing regeneration, Firebase change or app rebuild was performed.

### Precise prerequisites and bounded next steps

1. Authorized operator supplies/selects an Apple team/profile supporting Push Notifications for the **same explicit bundle ID com.huygiang.wedo**, with signed `aps-environment` and QA iPhone eligible for the selected development distribution. Current wildcard/no-APS profile is insufficient. Preserve bundle ID/session/app data; if existing team cannot supply this, operator approval/account action is required. Do not create/replace a key/certificate/profile without approval.
2. Confirm an Apple app for that exact bundle in the existing Firebase project, and its approved Apple client configuration (GoogleService-Info.plist or equivalent options). Confirm/reuse an approved valid APNs credential configured in Firebase. Console state has not been inspected; do not assume a new key is required or request secrets in chat.
3. With compatible prerequisites available and configuration changes authorized: enable Xcode push/background capabilities as applicable; extend the existing shared push bootstrap to iOS, register platform IOS, handle APNs readiness before FCM token APIs and choose explicit foreground presentation. Preserve Android flow, cold-start/session routing and current architecture; do not invent a second transport. Add focused platform/registration regression before installing a signed current candidate.
4. Verify notification permission, APNs token presence and eligible backend IOS registration without logging values; actual QA foreground/background/terminated receipt, tap→correct Chat, session retention/no duplicate and safe-fixture revoked-access denial. These remain the **one mandatory R9 gate**, not optional release-only work.

Reference setup requirements verified against [official Firebase Flutter FCM setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started): Apple capabilities, APNs credential configuration, swizzling and APNs token readiness. No external credential contents accessed.

### Current environment / unchanged scope

Disk before7.5GiB/final7.0GiB after supported Flutter checks; no app/backend builds run. Mac IP newly detected<QA_LAN_IP> (prior candidate/runtime IP<QA_LAN_IP> is historical). Docker daemon unavailable at read-only diagnostic, so current backend/PG/Redis/MinIO health was not reasserted. No runtime recovery/rebuild/IP migration was attempted in this two-gate request; restoring same-network runtime will be needed before eventual physical push acceptance. This environment observation does not invalidate the recorded prior accepted device evidence or introduce an invented third product gate.

No new QA message, payment, membership mutation, volume cleanup, second-iPhone action or credential exposure. Production/test source unchanged. Previous backend776PASS/1SKIP, upgradePASS, ranking162→6 and actual iPhone reaction/Samsung OS push acceptance retained. Only four requested documentation files changed this execution. **R9 IN PROGRESS — iOS push configuration/integration and actual OS receipt/tap acceptance remain required.**

---

# R9 full regression — active execution checkpoint

2026-10-29 Asia/Ho_Chi_Minh. **R9 IN PROGRESS**, R1–R8/R10 COMPLETE. Branch feat/pre-m19-ui-polish, HEADcdb0bd7e3ef564a0430e45b1db331b80cfbf10f0 unchanged. Pre-R9 dirty state269short entries preserved; baseline `/tmp/wedo-r9-baseline`, startstatus `/tmp/wedo-r9-start-status.txt`. No Git mutation, QA/data/volume cleanup, migration, signing/Firebase change, UI redesign or Secondary iPhone. User explicitly authorizes autonomous QA iPhone use and requests no more questions while busy; record unavailable physical gates honestly.

## Risk-based regression matrix

| Module / scenario | Existing evidence reused | Current coverage/risk | New test / physical required | Current result |
|---|---|---|---|---|
| Auth/session/redirect/logout | R1 token recovery, design/nav checks | Cross-module/high | Existing auth/refresh, admission/password concurrency; isolated lost-access; preserve phone sessions | Full backend PASS; full Flutter scratch gate open |
| Group/admission/role loss | R6 primary pair + isolation; R7 block/removal | Critical authorization/high | Existing PG concurrency, media denial/cache negative; no old QA kick/ban | Full backend PASS |
| Chat/Poll/shared socket | R1/R3 paired vote/change/history/image stability | High transport/privacy | Existing rollback/dedupe/out-of-order, Chat/Poll privacy; reuse physical unless affected | Full backend PASS |
| Activity/Task/R10 integrated review | R10 full pair reject/resubmit/approve→DONE/history/Stop/conversion/checkin PASS | High IDs/lifecycle | Existing Journey/M8 concurrency/security regression, no duplicate financial/task fixtures | Full backend PASS |
| Expense/Settlement/Fund | R2 primary pair including immutable ledger900/history/reversal | Critical financial/high | Deterministic PG atomicity/concurrency/isolation; current read model checks | Full backend PASS |
| Community/R8 ranking |65backend/305Flutter and physical ordering/stranger/reconnect/privacy | Confirmed N+1/moderate P2 | Reproduce query attribution, bulk hydrate with identical DTO/order/privacy;240/larger bounded data | FIXED:162→6queries; exact DTO/order/security equivalence PASS |
| Reaction while iPhone screen held | R8 reopening shows1, not live count evidence | Essential/high | Exact Samsung remove/add and reconnect while QA iPhone held; distinguish API/event/REST/visual | PASS: held iPhone1→0→1, repeated after Samsung Wi-Fi and backend restart |
| Moderation | R7 actual pair block/unblock/report/removal; isolated scopes | High privacy | Existing PG role/revocation/report/restore and R8 reader equivalence | Full backend PASS |
| Notifications/OS push | R2 in-app/read/reconnect PASS; prior Android Firebase setup | High/external | Separate canonical inbox/WS/provider/actual OS receipt and tap; no config changes | Android OS receipt/tap PASS. iOS no registered token/APNs evidence |
| Private media/evidence | R4/R10 pair photo/video/playback/checkin/history; R7 signed private reads | Critical privacy | Existing media upload/denial/expiry/rollback tests, sensitive-log inventory | Automated PASS; current log probe0JWT/0signed-signature fields |
| UI/navigation/accessibility | Accepted5tabs/fade/Home/group forms/retained scroll; R8 chrome on iPhone, Android AssistantMenu | Cross-module/medium | Full Flutter once +analyzer; no redesign/system setting changes |1252PASS/1scratchFAIL; analyzerclean |

## Verification executed (not a plan-only PASS)

- Read-only preflight: disk5.8GiB; Mac16GiB memory with inactive/reclaimable pages; networkMac<QA_LAN_IP>/Samsung<QA_LAN_IP>; QA iPhone paired/lockState passcodeRequired=false. Existing DockerPG/Redis/MinIO UP, actuatorUP. No services recreated or builds before disk check.
- Full Flutter **1252PASS/1FAIL**,80s, `/tmp/wedo-r9-flutter-full.log`; failure only pre-existing untracked `mobile/test/temp_test.dart` expecting Navigator.of(current Navigator context) to throw. It was included, not silently removed/excluded/modified. This is a test-harness/scratch disposition issue, not proof of an application navigation regression. Roadmap explicitly requires user approval for its disposition; user is busy, do not ask now or infer permission. **Full-suite gate is not PASS.**
- Analyzer **clean3.5s**, `/tmp/wedo-r9-flutter-analyze.log`.
- N+1 RED: new real-PG regression records **162total /160DTO /2candidate+eligibility**,130ms legacy vs83ms identical unoptimized feed. `/tmp/wedo-r9-ranking-red.log`. Target≤12queries, exact canonical Post DTO/order equality. Current small correction introduces bounded CommunityPostReader and bulk recruitment projection; unchanged R7 eligibility before batch, score/cursor/window unchanged. Not accepted until final tests and measurements.
- Existing old external iPhone USB helper is incomplete (only one test binary; runner/config/source missing). Recreated external USB-only runner under `/tmp/wedo-r9-ios-control` using locally installed xcodeproj/XCTest and existing acceptance wildcard signing. No network control server or weDO signing modification. Initial Ruby dependency path failed before project creation; local existing rexml path corrected, actual test build succeeded. One actual device startup attempt underway, logs `/tmp/wedo-r9-ios-control-{build,run}.log`; no physical PASS inferred from build.

## Open findings / blockers

- P2 performance: R8 per-post list hydration makes162JdbcTemplate executions for20normal posts. Candidate filtering only2; repeated authorized row/author/media/engagement/recruitment reads dominate. Preserve permissions rather than remove checks.
- P3/test gate: pre-existing scratch full-suite failure needs explicit disposition; no deletion or assertion edit authorized/attempted.
- Essential reaction live gate and OS push remain UNVERIFIED; no fabricating from API, tests or reopened data.
- Release-readiness review is separate, no production release/deployment authorized.

Full backend/security/media/financial batches, final optimization equivalence/scale measurements and physical device gates remain underway. No R9 closure from counts.

## Final executed checkpoint — 2026-10-29 22:56

R9 remains **IN PROGRESS**. No observed P0/P1 application regression in the executed matrix; an unavailable mandatory gate is not a PASS. Earlier “pending/under test” execution notes above are chronological, superseded by the final results below.

### Targeted production correction and exact scope

Four production paths, task-only delta **+126/-16** against pre-R9 snapshots (not the accumulated dirty Git diff):

| Path under backend/src/main/java/com/wedo/backend/community | R9 delta | Purpose |
|---|---:|---|
| CommunityPostReader.java (new) |+70/-0|Bounded≤100 authorized IDs; author/current group role + batch media/reactions/comments; only eligible IDs hydrate.|
| CommunityService.java |+5/-8|Reuse reader for For You/Friends/Profile/targeted refresh; canonical direct detail unchanged.|
| CommunityFeedRanking.java |+15/-8|Batch hydration callback; legacy single-post wrapper retained as equivalence oracle; ranking/cursor/window unchanged.|
| RecruitmentProjection.java |+36/-0|Bulk current recruitment projection, canonical permission/lifecycle/capacity semantics preserved.|

No Flutter production source, migration, API shape, schema, ranking score, socket architecture, ledger, signing or Firebase configuration change. Test-only FirebaseApp/FirebaseMessaging mocks prevent isolated suites contacting external ADC/provider; not a production configuration change.

Four test paths **+109/-1**: FeedRankingIntegrationTest(+63/-1), common/test/AbstractPostgresIntegrationTest(+5/-0), performance/ReadPerformanceIntegrationTest(+2/-0), new migration/MigrationUpgradeIntegrationTest(+39/-0). Baselines `/tmp/wedo-r9-baseline`. The 269 pre-existing short-status entries are not R9 changes. Five newly visible paths raise status to274, including R9 report/checklist and reader/migration-test directories; do not attribute all274 to this task.

### Backend / migration / ranking evidence

- Full Java21/PostgreSQL backend: **777 run,776 PASS,0 FAIL,0 ERROR,1 SKIP**, `/tmp/wedo-r9-backend-full.log`,3m05s. Command `JAVA_HOME=$(/usr/libexec/java_home -v 21) MAVEN_OPTS=-Xmx768m ./mvnw -DargLine=-Xmx1536m -Dspring.test.context.cache.maxSize=3 test`. Conditional e2e/OtpResolverTest requires explicit live-user property; skipped intentionally rather than touching QA auth. Required auth/permissions/concurrency/finance/media/realtime regressions ran. Full suite not repeated after adding the independent migration test.
- Additional isolated upgrade **1 PASS**, `/tmp/wedo-r9-migration-upgrade-final.log`, command `./mvnw -Dtest=MigrationUpgradeIntegrationTest test` with Java21. Fresh V0–V12 DB seeded with User/Group/Activity/Poll; V13–V20 applied/validated; original IDs/title/question retained and Poll.group_id backfilled. Initial new test assertion incorrectly counted20 migrations instead of21 includingV0; corrected test assertion only, then PASS. No shared QA migration/reset/repair performed.
- Full-suite fresh DB contexts validate V0–V20. Upgrade fixture represents pre-social Activity/Poll data, not a complete production-size restore test.
- Ranking full-run before **162queries/82ms** (160hydration,2selection/eligibility); after **6queries/9ms**. **1200-post isolated fixture:6first-page queries/13ms;60pages/1200unique IDs,445ms traversal**. JVM warmup/local sparse fixtures: timings illustrate this run, not a production SLA or arbitrary-scale claim.
- Exact canonical Post DTO equality/order, media ordering, blocked-actor counts, active ADMIN/archive/member-loss visibility, recruitment OPEN/CLOSED/FILLED/EXPIRED/past/PENDING/member/manager-block/archive and bounded query budget pass. No disabled authorization or private-data scoring. Single-node bounded snapshot/15min expiry contract remains unchanged.
- Focused66PASS before full run is overlapping, not additive to776. Full Flutter1252PASS/1scratchFAIL and analyzer clean remain the actual final mobile results; no rerun of unchanged code/full suite.

### Physical Community reaction — actual held-screen PASS

USB runner successfully controlled **QA iPhone**, existing Owner session. Opened own-post list and exact post649c81c6-2a47-4287-a465-6837d5856c7a detail, kept it visible. Samsung Member1 actual UI tapped existing reaction:

1. iPhone AX showed1; Samsung removed; same untouched iPhone detail automatically showed0.
2. Samsung restored; same iPhone detail automatically showed1.
3. Samsung Wi-Fi disabled (setting0/no wlan IPv4), restored FPT Telecom<QA_LAN_IP>; independent Samsung HTTP `/actuator/health` returned200. Repeated remove/add; same held iPhone detail automatically0/1.
4. Verified R9 backend package restarted (socket connections dropped), both phones recovered; another actual Samsung remove/add automatically changed unchanged iPhone detail0/1. This verifies receiver transport recovery after server interruption. It is not a claim iPhone Wi-Fi toggle was executed.

Evidence matching USB command IDs/trees `/tmp/wedo-r9-iphone-held-{before,remove,add}.json`, `...reconnected-{remove,add}.json`, `...new-backend-{remove,add}.json`; screenshot `/tmp/wedo-r9-iphone-live-reaction-final.png` visually inspected. Actual display, not reopening/API alone. Original1 Member1 reaction restored; no duplicate post/comment created. External runner under `/tmp/wedo-r9-ios-control`, successful coordinate-run XCTest result; first global-swipe attempt failed AX server, corrected once to bounded coordinate navigation. Runner stopped normally after gate; no repeated unsupported automation or weDO signing change.

Initial real screen already had PENDING stranger recruitment request; no R9 join/cancel performed, preserve it. Earlier R8 NOT_REQUESTED is historical, not current.

### Runtime/candidate and limited QA writes

- Mac<QA_LAN_IP>, Samsung<QA_LAN_IP>; backend local/LAN UP, PG/Redis/MinIO healthy, media relay retained exact device allowlist. Existing QA/database/volumes/objects/sessions preserved.
- Backend `./mvnw -DskipTests package` **PASS** `/tmp/wedo-r9-backend-package.log`; stopped only PID26451 and started **PID79864**, `/tmp/wedo-r9-backend-runtime.log`, same existing external credential/runtime environment. JAR SHA256 `3474030f26c2517aca826e1735b33a996a594a794b91bf95f7b6da611c9d1be0`. No business mutations or seed/reset at startup.
- R8 final Samsung debug/QA iPhone Profile artifacts retained, API<QA_LAN_IP>. **No new Android/iOS app build/install**: no Flutter production change, existing artifacts/candidates already current. New USB XCTest helper build is tooling, not an iOS app build.
- No R9 finance/admission mutations. Single labeled QA Chat message “R9 QA OS push 29-10” sent as Owner by explicit POST201 to existing QA conversationb8afdf53-5a00-427a-9036-065748addfd0; its normal committed inbox records retained. An earlier HTTP200 was GET history (no message), not a duplicate send.
- Runtime log inventory:0JWT-shaped matches/0X-Amz-Signature fields; scoped probe is not proof every logging path is secret-free.

### Notification evidence / remaining mandatory gates

- In-app/read/realtime/deep-link evidence from R2 remains scoped PASS; backend/full Flutter notification regressions PASS.
- New Android background QA send: Member1 notification **GATEWAY_ACCEPTED**, two other no-device recipients **NO_ACTIVE_DEVICES**. Android system NotificationRecord explicitly contains weDO title and `QA Owner: R9 QA OS push 29-10`: **actual Android OS receipt PASS**, not merely provider acceptance. Exact QA notification became visible after shade scroll; tapped its text and real Samsung UI opened “Nhóm 74DCTT23” with “R9 QA OS push 29-10”. **Android OS receipt/tap/deep-link PASS**, `/tmp/wedo-r9-push-tap-final.txt`. No personal notification opened.
- Read-only user_devices count:1 active Android,1 inactive Android, **0 iOS registrations**. Current PersonalTeam Profile build has no repository APNs entitlement/configuration evidence. **iOS OS push/tap UNVERIFIED**, requires an APNs-capable signed candidate/configuration; no signing/Firebase change authorized/attempted. Do not claim no-token condition is a confirmed new application bug.
- **Full Flutter scratch gate** remains: untracked pre-existing temp_test.dart assertion failure; roadmap explicitly requires disposition approval. No removal/exclusion/assertion rewrite; user busy, do not ask again.
- Physical negative revocation, upload interruption, platform accessibility/dark/light permutations are automated/reused where supported, not newly claimed physical PASS. New batch reader equivalence includes revocation; destructive negatives stay in disposable fixtures.

### Release assessment and next runnable work

[Release checklist](RELEASE_READINESS_CHECKLIST.md) separates local QA from production. Android release still debug-signed; iOS distribution/APNs and production TLS/secrets/backups/restore/MinIO retention/monitoring/account deletion remain not-ready/not-verified. These production operations do not redefine R9 scope.

Android QA push tap completed; preserve all other notifications. Next complete iOS push prerequisite/evidence only under compatible signing authorization; resolve scratch disposition only when user available/approves. Continue any still-required platform matrix rather than infer completion. R1–R8/R10 remain COMPLETE; R9 IN PROGRESS. No commit/push/merge/reset/restore/stash/clean, no Secondary iPhone.

Final Android notification tap result supersedes the earlier pending entry: actual notification selected after shade scroll, authorized Chat destination and unique QA message observed. iOS push remains the platform prerequisite gap. Final disk5.6GiB; scoped diff whitespace check clean; branch/HEAD/stash unchanged.

Final deployed read-only smoke: Owner and Member1 feed HTTP200,20items/20unique IDs each; target detail HTTP200/reactionCount1 each; LAN MinIO HTTP200 and backendUP. Existing QA state retained.
