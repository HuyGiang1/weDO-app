# weDO release readiness — R9 assessment

2026-10-29. Assessment only; **no production build signing, store upload, deployment or infrastructure change authorized**. Debug/Profile/local QA readiness is not App/Play Store readiness.

| Area | Status | Evidence / remaining requirement |
|---|---|---|
| Local QA backend/PG/Redis/MinIO | NOT VERIFIED currently | Prior2026-10-29 checks passed.2026-10-30 Docker daemon unavailable; MacIP now<QA_LAN_IP>. No service/reset/IP change in two-gate task. |
| Android release signing/distribution | NOT READY | build.gradle.kts release uses debug signingConfig/TODO production key. No signing change made. |
| iOS distribution/APNs | NOT READY | Retained candidate+wildcard profile have no aps-environment; Firebase Apple client config absent locally, source bootstrap/platformIOS/APNs gate now implemented; existing installed candidate remains prepatch. Prior0iOS rows; currentDBread unavailable. APNs/team/config+minimal iOS integration and physical receipt/tap required; credentials preserved. |
| Production API/TLS/media endpoints | NOT READY | Current candidates use local LAN HTTP; no production endpoint deployment verified. |
| Secrets | NOT VERIFIED | Existing external Firebase path retained; no plaintext printed; production secret management/injection/rotation review pending. |
| PostgreSQL backup/restore | NOT VERIFIED | No shared QA reset/destructive recovery; inspect documented backup/isolated restore procedure. |
| MinIO backup/retention | NOT VERIFIED | Existing objects/private signing preserved; production backup policy pending. |
| Monitoring/crash reporting | NOT VERIFIED | Inspect shipped configuration/alerting; local logs not production observability. |
| Privacy policy/account deletion | NOT VERIFIED | Inspect existing product docs/routes; no legal compliance certification or new feature implied. |
| Ranking deployment/resource limits | NOT READY for arbitrary multi-instance routing | V1 bounded local snapshots require sticky routing/shared reviewed store; current single-node QA is supported, R9 bounded1200post test passes; not a multi-instance/load SLA. |
| Supported product automated gate | READY with explicit scope | User-approved2026-10-30 classification: all128product test files1252PASS/0FAIL; preserved SDK-only scratch separately1FAIL, unrestricted suite not green. Backend776PASS/1conditionalSKIP, upgrade1PASS, analyzerclean retained; no silent exclusion. |
| Physical release gate | NOT READY | Held-screen iPhone reaction/reconnectPASS; Android actualOSreceipt/tapPASS; iOSOSpush/tap unverified. Prior accepted flows reused accurately. |

R1–R8/R10 remain COMPLETE. R9 IN PROGRESS. Do not claim production/store readiness or deploy merely because local tests/builds pass.

Read-only repository review found no backup/pg_dump/restore runbook in scripts or LOCAL_DEVELOPMENT and no Sentry/Crashlytics declaration in the examined mobile/backend configuration. No account-deletion endpoint/runbook was identified in scoped source search; privacy policy/account erasure still need explicit product/legal assessment. These are NOT VERIFIED findings, not claims a missing search hit proves an external service/policy does not exist. No secret contents copied, production keystore/APNs configuration changed, backup restored, release published or QA reset.

Current local R9 backend is packaged/running and validated (report includesSHA). Android/iOS app artifacts reused because no Flutter source changed. Full backend776PASS plus upgrade1PASS, analyzer clean; scratch disposition now resolved by explicit preserved-file classification and supported-suite PASS; unrestricted flutter test still includes the failing scratch. R9 remainsINPROGRESS independently of production readiness.

## Two-gate update — 2026-10-30

Scratch classification/resolution is accepted within the user's explicit instruction: TEMPORARY_SCRATCH_TEST preserved exactly, supported128-file suite1252PASS, scratch separatelyFAIL. Manifest/hash/reproducible command and exact assertion in R9 report. Do not present unrestricted flutter test as passing.

iOS push remains a mandatory **R9** functional gate, not deferred as a production-only nicety: BLOCKED_BY_EXTERNAL_CONFIGURATION plus confirmed Android-only client integration. Existing signed artifact/profile noAPS; localFirebaseAppleconfig absent; cloudconsoleAPNscredential statusUNVERIFIED. Need approved same-explicit-bundle Push-capable profile/team and FirebaseApple/APNs setup, then minimalIOSbootstrap/platform/APNsreadiness configuration+focusedtests+physicalreceipt/tap. No account/key/signing/Firebase mutation or appbuild performed. [Official Firebase setup requirements](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).

Production distribution/TLS/secrets/backups/storage retention/monitoring/privacy-erasure remain separatelyNOTREADY/NOTVERIFIED; no release/deployment authorized. CurrentDockerunavailable/newMacIP means restore same-networkQA environment before physicaltest, not a claimed software regression. ExistingPASS evidence retained.

## iOS implementation update — 2026-10-30

Paid Individual membership/Admin is user-confirmed through2027-01-21; membership is **not** a blocker. Current configured project/team<APPLE_TEAM_ID>/wildcardprofile lacksAPS, availableidentityteam<CERTIFICATE_CN_SUFFIX> does not prove exactAppIDownership. Pending operator check/reuse of exactAppID push capability, approved FirebaseAppleconfig forwedo-3304c/com.huygiang.wedo and existingAPNskey. Noportalkey/appcreation, rotation, profileoverwrite or automaticteamchange. No keycontents/tokens exposed.

Client source ready for configuration verification: iOSFirebase/sharedpush enablement, IOSregistration, awaitedAPNsbeforeFCM, singleforegroundSnackBar withnativeforegroundalertsdisabled.38focusedFlutterPASS+1isolatedbackenddeviceLifecyclePASS, analyzerclean; no newbuild/install/physicaliOSPASS. Existing two-deviceQA runtime remainsrunning. R9 remainsINPROGRESS untilconfigurationverified/signedAPSartifact+actualiOSreceipt/tap; productionreadiness remains separate. Full earlier1252supportedPASS is prepatch evidence; no fullrerunclaimed.

## Signing audit correction — 2026-10-30

Earlier identification of<CERTIFICATE_CN_SUFFIX> as a separate signing **team** was wrong. PubliccertificateCNcontains5Z but **OU=<APPLE_TEAM_ID>**. ProjectDebug/Profile/Release, codesignTeamIdentifier, embeddedprofileTeamIdentifier and Xcodecache all<APPLE_TEAM_ID>; cacheGiangHuyIndividual **isFreeProvisioningTeam=false**. No oldPersonalTeam/paidteam mismatch demonstrated. Do not change teams or replacecertificates. RemainingAPSgap is wildcardprofile/currentartifact lacking aps-environment and unverified explicitAppID/Push/Firebase/APNs setup. See latestR9audittable. Latestuserinstruction prohibits changes/build/reinstall until read-only investigation reviewed; no such actionperformed. Existing signingassets, app/session anddirtysourcepreserved; onlydoccorrections.
