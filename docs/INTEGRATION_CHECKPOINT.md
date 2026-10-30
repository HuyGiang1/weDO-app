# Integration QA source checkpoint

Branch: `integration/r9-qa-checkpoint` from `cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`.
One coherent source checkpoint captures accumulatedR1–R8/R10, R9ranking/read
performance and the pending iOSpushclient slice; these were not separateR branches.
R9 remains **IN PROGRESS**. This is not a production release or APNs acceptance.

## Included and excluded

Include reviewedproductionJava/Flutter, schemasV0–V20, tests, safeinfrastructure,
lockfiles, docs/designsystem/roadmap/handoff and Windowssetup. Mandatory surfaces:
`moment/MomentController.java`, `MomentDtos.java`, `MomentService.java` (actual
class name); realtimeDomainRealtimeCoordinator/Event, RealtimePublisher,
RealtimeReadModelFanout and RealtimeScopeAccess. No duplicateMomentsService added.

Exclude privateprovider/secrets/signingkeys, clientFirebaseJSON/plist,
ignoredtemp_test.dart, QAdata/media, APK/IPA/JARoutputs/caches and originalunredacted
localnotes. Existinglocalclientconfig/scratch untouched. Originalpendingversions
are retained in ignored `.local-checkpoint-preserved/`; never upload that archive.
The staged iOSproject omits ownerDEVELOPMENT_TEAM but includes actualprojectchanges;
the owner's unchangedlocalproject remains an intentional signingoverride.

## Authentication/security

Approved QArotation3new256bitkeys outsideGit, no staticruntimeauthfallbacks.
Unitfixtures use independentlygeneratedtestkeys. Optinseed requires developer's
own generatedpassword. QApassword, DB/media credentials and signing/provider
assets were not rotated. Currenttree must not contain those livevalues.
ExistingGitancestors still contain historicaldevelopmentdefaults; nohistoryrewrite
orclaimthatremovingcurrentliteralscleanshistory. Neverreusehistoricalvalues.

Validated51focusedauth/startup checks and42overlappingunitchecks afterfixture
cleanup, oldJWTrejected/newOwner+MemberJWTverified and existinggroups/chatread.
Data/sessionrows retained. Bothphoneslocked: APIverificationisnotdeviceUIlogin.
Unchangedsourceuses earlier776backendPASS/1conditionalSKIP, migrationupgradePASS,
38focusedFlutter/analyzerclean and isolatednoFirebaseEmulatorAPKPASS as scoped
evidence; no fabricated currentfull-suite or iOSphysicalPASS.

## Teammate commands (once remote branch verification succeeds)

```powershell
git clone https://github.com/HuyGiang1/weDO-app.git
Set-Location weDO-app
git fetch origin
git switch --track origin/integration/r9-qa-checkpoint
git switch -c feat/yourname-your-task
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\teammate-env.ps1 -Initialize
docker compose --project-name wedo-teammate --env-file .env.teammate -f infra/compose.teammate.yml up -d postgres redis
Set-Location backend
.\mvnw.cmd spring-boot:run
```

In a secondterminal, startAndroidEmulator then:

```powershell
Set-Location weDO-app\mobile
flutter pub get
flutter devices
flutter run -d emulator-5554 --dart-define=WEDO_API_BASE_URL=http://10.0.2.2:8080 --dart-define=WEDO_PUSH_ENABLED=false
```

UseactualemulatorID. See [completeWindowsguide](TEAMMATE_WINDOWS_ANDROID.md) for
JDK21/Flutter3.47.1/Dart3.13.1/API37, privateenv, syntheticseedlogin, mediaandFCM.
Coremode needsnoFirebasecredentials; media needsindependentAIStorlicense/approvedS3,
andactualWindowsPowerShell/Emulator/mediaacceptance remains unverified here.

Pushyourfeaturebranch and openPR withbaseintegration/r9-qa-checkpoint. No direct
main/devpush, merge or rewritingotherpeople'sbranches. RemoteSHA/completeness
willbeverified explicitly afterpush; a pushsuccessalone is not sufficient.
