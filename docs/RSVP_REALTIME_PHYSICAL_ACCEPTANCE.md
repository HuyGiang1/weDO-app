# RSVP Physical Two-Device Acceptance — 2026-10-21

Follow-up: the original attempt below remains historical and was not rewritten as a full PASS. A separately authorized [Discussion reliability hotfix](DISCUSSION_REALTIME_RELIABILITY_HOTFIX.md) now has 53 focused Flutter passes, clean analyzer and a bounded Samsung remote-update/network-recovery PASS. No repeat of A–E or iPhone hotfix installation; parent Activity offline error state limited physical last-good Discussion visibility. R1/R2 remain IN PROGRESS.

## Outcome

**Acceptance stopped / not signed off.** Physical RSVP behaviors A–E passed, but bounded final diagnostics exposed unhandled `ApiException` in the embedded Discussion realtime refresh during intentional backend/relay outages. The user's stop-on-issue rule was followed: capture evidence, do not fix source or expand testing. This is not global realtime acceptance and does not complete R1/R2.

## Candidate and scope

- Branch: `feat/pre-m19-ui-polish`; HEAD: `cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0` plus preserved uncommitted snapshot.
- No application source modification, full automated suites, analysis run, migration/schema edit, data reset, `temp_test.dart` removal, commit/push/merge/reset/restore/stash/clean.
- User explicitly approved packaging/building/installing the current snapshot after preflight identified old artifacts without realtime classes. Initial interrupted build used<QA_LAN_IP>; resume freshly detected<QA_LAN_IP> and rebuilt both mobile candidates for that URL. No duplicate unfinished build was reused as acceptance evidence.
- Tracked `backend`/`mobile` diff SHA256 before and after: `c5802709f97c0678d6eb80dfe785e2c290004c730d53f7aa84f0e63c30bed7a8`. Existing untracked realtime source files were not edited. Personal Team/native signing and existing sessions retained; both installations were in place, not uninstalls.
- Backend package: `bash mvnw -DskipTests package`, SUCCESS. No clean/test. APK debug and iOS release current-IP builds SUCCESS. API URL on both: `http://<QA_LAN_IP>:8080`.

Artifact SHA256:

| Artifact | SHA256 |
| --- | --- |
| backend JAR | `47697393e6ebf966be16bcc70f7a9c1b05c6a80b082c8345a98ac532fb790220` |
| Android APK | `4a0ab9e5fa6a5654b1ad8fc3dd5e2dfa204008d6c84432616a89687830b365c9` |
| iOS Runner binary | `ab4424928ee19e4e496771491d8c18e0206c15d1a178576c01aa4825aef9b739` |

## Runtime/devices/fixture

- Mac: en0,<QA_LAN_IP>. Samsung <QA_ANDROID_SERIAL>:<QA_LAN_IP>, physical QA Member1 profile confirmed. iPhone QA iPhone `<QA_IPHONE_UDID>`:<QA_LAN_IP> from access logs, physical QA Owner profile confirmed.
- Existing PostgreSQL ready, Redis PONG, MinIO readiness200. Backend actuatorUP including DB/Redis, current LAN healthUP. No container or volume recreation/reset.
- Final direct backend PID55791 on8080, log `/tmp/wedo-rsvp-physical-backend-final.log`. Current media endpoint `http://<QA_LAN_IP>:9000`; temporary allowlisted media-only relay PID55833 forwards to existing localhost9000, log `/tmp/wedo-rsvp-media-relay.log`. Console not exposed. Allowlist is only current two phone IPs/Mac/loopback. Previous<QA_HOTSPOT_IP> relayPID25669 left untouched; it is not current-network evidence.
- Existing isolated group `PRE-M19 Acceptance Lab 2026-10-17`, ID`a3c7a9d6-32dd-4a5c-b5d0-804cc5636002`; Activity `PRE-M19 Capacity Lab`, ID`3a09b926-2ba4-4f3c-b266-d729ed072053`, PLANNING/unscheduled/capacity1. Initial Owner+Member NOT_GOING, going0/waitlist0/participants empty.
- No new fixture/group, main-group or financial changes. Only normal physical RSVP mutations in this lab, plus read-only API evidence. Histories retained. Final fixture: Member GOING, Owner NOT_GOING, going1/waitlist0; no further cleanup mutation after stop.

## Physical results

Times below are local UTC+07:00. Event timestamps in raw logs use UTC. No manual iPhone refresh/pull-to-refresh, relaunch or navigation reload was used to produce remote updates. Opening the controller-backed participant child view after the first count update was an inspection action, not a REST reload; it stayed open for B/C. Scrolling does not refetch.

| Test | Result and evidence |
| --- | --- |
| A — JOIN | PASS. Both detail screens started0. Samsung physically tapped GOING at21:36:54. iPhone automatically showed1/1 and1 registration; participant view showed exactly one QA Member1 row. Event `78af1ba1-1b68-4772-b820-8b6ec58cd815`; iPhone IP GET detail+participants200 in the same second. |
| B — LEAVE | PASS. Samsung physically selected NOT_GOING at21:38:00. Already-open iPhone participant view automatically removed Member and showed the empty message. Authoritative going0/participants empty; iPhone detail+participants refetch200. Event `49c5f97f-af9d-45e6-82a9-2df3afbe3255`. |
| C — REJOIN | PASS. Samsung physically selected GOING at21:38:46. Same open iPhone participant view automatically showed QA Member1 once, not duplicated; authoritative going1. Event `23dc1490-c7b6-4f86-a97e-df393d041218`. |
| D — WAITLIST/FIFO | PASS for a single-waiter FIFO promotion, not a multi-waiter ordering stress test. Samsung occupied capacity1. Owner physically requested GOING at21:39:40 and became WAITLIST; both UIs showed1 going/1 waiting/2 registrations. Existing historical sequence counter issued ticket#2 (not a reset-to1 ordinal); Owner was the sole and earliest active waiter. Samsung physically left at21:40:50; iPhone automatically removed the waitlist card and showed1 going/0 waiting/1 registration, with Owner GOING in authoritative state. Promotion event `8397c9c2-a47a-46a1-a99d-8b8b49171b33`, one RSVP invalidation for the full mutation; existing separate promotion Notification event also occurred. Roles are reversed from the request's illustrative example so the promoted user's iPhone is the remote observer. |
| E — RECONNECT/RESYNC | PASS. Owner was first physically set NOT_GOING, establishing0/1. A temporary transport relay blocked only iPhone's app connections for20s at21:46:27.872; Samsung stayed connected and physically changed RSVP once at21:46:30. Event `6b2b6ef3-94f5-40af-b80f-42ccaca93233` reached Samsung, not disconnected iPhone. iPhone showed the expected network-error state during outage, not an auth route. After automatic unblock, iPhone WS101 at21:46:50.501, Activity `SUBSCRIBE_SCOPE` at.511, `SCOPE_SUBSCRIBED` at.547, detail GET at.645 and participants200 in the same second. It automatically converged to1/1, no refresh/activation/navigation/force-stop. Later screenshot visually confirms1/1 and1 registration. |
| F — AUTHORIZATION | Physical minimum PASS: wire metadata correlates authenticated Owner UUID`dec15f3c-9392-4a39-a935-3b08536f54f3` and Member UUID`d78a1d06-2d51-4ca5-914f-b0d33b0e4f98` with successful handshakes and authorized Activity subscribe ACKs. No physical membership removal/revocation test: preserved existing membership/history rather than repurposing the retained two-member lab into a destructive permission fixture. Prior focused coordinator/scope/PostgreSQL authorization and revocation tests remain automated-only evidence, not rerun or upgraded to physical PASS. |

## Transport observation and bounded fault injection

- A–D used direct backend8080 and a read-only Redis subscription plus safe path-only Tomcat access logs. Redis event observation is not claimed as direct iPhone wire capture for those tests.
- For E/F only, an external `/tmp/wedo-rsvp-network-probe.py` relayed the same API URL to unchanged backend on loopback8081, allowing only Mac/QA phone IPs. It decoded compressed WS metadata and logged only subject IDs, scope/control/event IDs and safe paths, never tokens/headers/content. SIGUSR1 closed/rejected only iPhone app connections for20s, automatically restoring access; no phone Wi-Fi setting or app lifecycle was changed.
- Relay setup initially mishandled POST/PUT request body forwarding, causing a noncommitted Owner setup attempt/login diagnostic to time out. This was a harness defect, excluded from product results. Only the external helper was corrected; original fixture state was read-only verified before the valid action. Setup/restart reconnects are not counted as E's intentional single iPhone outage.
- Stable final relay interval (from21:45:27): no duplicate event IDs per recipient. After the E block, exactly one successful iPhone handshake and no new Samsung handshake were observed. Event+ACK produced bounded reload bursts, not a repeating loop. Quiet log tail remained at the completed recovery time until later read-only diagnostics.
- Full API relay/fault injection was stopped after E; direct backend8080 restored. Only the media-only relay remains. Temporary Redis observer and iPhone UI acceptance runner stopped. No LAN-accessible device-control service was created.

## Regression observations and stop reason

- Screenshots/semantics showed no red screen, duplicate participant rows or Login/Welcome leak. Samsung subsequently opened Chat Home with real conversation rows after direct runtime restoration; no message/push/other-module acceptance was attempted.
- **Stop-on-issue triggered by bounded Samsung logcat:** four `Unhandled Exception: Instance of 'ApiException'` entries at21:42:26.879,21:43:48.793,21:45:24.608,21:49:04.392, corresponding to intentional whole-backend/relay setup/restoration interruptions, not the iPhone-only E interval.
- Exact stack: `DiscussionApi.list` (`discussion_api.dart:20`) → `_ActivityDiscussionSectionState._refreshRealtime` (`activity_discussion_section.dart:36`) → `reloadRealtime` (line31) → `RealtimeBinding._reload` (line129). The Discussion widget is embedded in Activity detail and its broad R2 integration remained present in this candidate. No source fix, refactor, extra module testing or assertion suppression performed. Do not claim all network failures are handled or all regressions absent merely because the RSVP UI converges.
- The issue is a current-candidate acceptance blocker requiring a separately authorized bounded fix/review; attribution to a clean baseline was not tested. RSVP A–E functional results remain recorded rather than relabeled as failures of count/promotion/resync.
- No full automated suites/analyzer rerun. Previous40 backend/33 Flutter focused passes are historical automated evidence only.

## Evidence locations

- Raw events: `/tmp/wedo-rsvp-physical-events.log`; safe HTTP paths: `/tmp/wedo-accesslog/access_log.2026-10-21.log`; E/F safe wire metadata: `/tmp/wedo-rsvp-network-probe.log`.
- UI captures: `/tmp/wedo-rsvp-iphone-initial.json`, `test-a-iphone.json`, `test-a-participants.json`, `test-b-iphone.json`, `test-c-iphone.json`, `test-d-waitlist-iphone.json`, `test-d-promoted-iphone.json`, `test-e-zero-iphone.json`, `test-e-disconnected-iphone.json`, `test-e-final-iphone.json` (test files share `/tmp/wedo-rsvp-` prefix). Final visible state `/tmp/wedo-rsvp-visible-final.json`.
- Visually inspected screenshots: `/tmp/wedo-rsvp-a-iphone.png`, `/tmp/wedo-rsvp-recovered-final.png`. Other QA screenshots remain in the external helper container under `Documents/wedo-usb/`, referenced by the JSON responses. No personal media used.
- Regression stack: `/tmp/wedo-rsvp-unhandled-network-errors.log`; Chat sanity `/tmp/wedo-rsvp-chat-regression-samsung.log`.
- External helper files/logs can disappear after reboot; do not treat their runtime PIDs/IPs as permanent configuration.

## Next authority boundary

R1/R2 remain IN PROGRESS. Review the captured Discussion network-error handling issue and authorize a bounded fix or isolation before rerunning affected acceptance. Do not start R3/Poll-in-Chat, Moments, Community or any broad module completion from this attempt. No commit/push/merge authorization.
