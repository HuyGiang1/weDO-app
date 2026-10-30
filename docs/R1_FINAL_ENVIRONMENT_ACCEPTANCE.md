# R1 final environment and acceptance — 2026-10-25

R1 **READY FOR ACCEPTANCE, NOT COMPLETE**; R2 **IN PROGRESS**; R3–R9 **NOT STARTED**. This environment-only continuation does not supersede earlier test evidence outside its stated scope.

## Runtime and candidates

- Mac en0 `<QA_LAN_IP>`; Samsung WLAN `<QA_LAN_IP>`; QA iPhone observed backend peer `<QA_LAN_IP>`.
- Existing PostgreSQL ready, Redis PONG, backend local/LAN actuator UP. Same backend JAR, no rebuild. Runtime restarted with `WEDO_DEMO_LAN_IP=<QA_LAN_IP>` and `WEDO_MEDIA_PUBLIC_ENDPOINT=http://<QA_LAN_IP>:9000`, preserving the remaining settings. PID56114; log `/tmp/wedo-r1-env-backend.log`.
- MinIO recovered with **restart only**, same container `6403ab20cf4c09d2e1d7960655845702309af5f16eac5be52ecdcba940a9252f` and exact volume `wedo_wedo_minio_data` mounted `/data`; existing readonly license bind retained. No recreation, object or policy changes. Local and current LAN readiness pass. Read-only listing: 28 objects, 18,190,930 bytes, zero errors. Anonymous bucket access remains403.
- Current-IP media TCP relay PID56092, `/tmp/wedo-r1-env-media.py`, allowlist `/tmp/wedo-r1-env-media-allow.json`, log `/tmp/wedo-r1-env-media.log`. Forwards only `.110:9000` to loopback9000 for the Mac and the two observed device IPs; no authorization bypass/signature/header rewrite. **Keep this helper/config/process for the active demo.** Old relays untouched. If DHCP changes device IPs, revalidate the allowlist rather than opening access broadly.
- Samsung existing hotfix APK retained, API `http://<QA_LAN_IP>:8080`, SHA256 `5a62f3dae672524a0d2f09238207bb3d36444d7788996e8491314f015e800856`; no rebuild/reinstall this continuation.
- QA iPhone old `.33` candidate was stale. Necessary release build/install-in-place PASS, API `http://<QA_LAN_IP>:8080`, bundle `com.huygiang.wedo`, executable SHA256 `0e2cd7150dfbca30fabd95cc472193bfddeb1438be9592770f926b6bdfb3dbe5`. Signing/native configuration unchanged; sessions retained. No Secondary iPhone operation. Logs `/tmp/wedo-r1-env-ios-{build,install,launch}.log`.
- Unique Safari request on the actual QA iPhone reached backend and completed HTTP200 at17:55:35. Native app reopened. Authenticated app WebSocket upgrades101 observed in backend log; unauthenticated `/ws`401 is expected, not a connectivity failure. Per-device reconnect/subscription acceptance is not inferred from transport reachability.
- Disk about1.6GiB after necessary iOS build; no cleanup or additional build recommended without need.

## Actual physical evidence and pending boundary

| Check | Status | Exact evidence/boundary |
| --- | --- | --- |
| QA iPhone Home/connectivity | PASS | User reports recent groups, financial0/0, notifications and other Home sections load. No upcoming activity is an observed UI result, not proof of fixture completeness. |
| Existing chat image, QA iPhone | PASS | User directly confirms chat images now appear. Does not prove remount/flicker/scroll stability during messages. |
| Chat old-image stability, five texts each direction | CHƯA TEST | Samsung actual QA chat opened; five labelled Member messages sent through its UI and all five observed once in the final visible tree. iPhone receipt, reverse sends and visual/scroll observations require confirmation. Do not count terminal/API sends as two-device UI acceptance. |
| iPhone Chat reconnect | CHƯA TEST | No new physical reconnect observation. |
| Poll vote/change, two-device | CHƯA TEST | Earlier P0 physical evidence retained; not repeated on this current pair. |
| RSVP count/list, current pair | CHƯA TEST | Earlier functional evidence retained. Capacity Lab Member1 membership previously LEFT/GET404; no membership restoration or substitute fixture silently claimed. |
| Discussion | CHƯA TEST (current pair) | Historical Samsung cached/offline/automatic recovery PASS retained; no new iPhone offline observation. |
| Expense/Settlement | PASS (Samsung hotfix scope) | Prior same-APK/current-IP natural expired-token recovery and authoritative reads PASS, zero financial mutations; not unnecessarily repeated. iPhone offline/reconnect pending. |
| Poll/Task | CHƯA TEST (full current-pair smoke) | Earlier Samsung list/detail offline-cache/recovery subcases PASS; no new paired claim. |
| Chat/Auth | PASS (baseline only) | Existing sessions and authenticated chat readable on both; current-pair delivery/reconnect remains pending. |

No newly established product FAIL. The previous media/stale-iPhone connectivity blockers are resolved; missing physical evidence is not itself a new code defect. Reuse407 focused PASS/analyzer clean from the hotfix; no full-suite rerun.

## Remaining manual steps

1. In **Nhóm 74DCTT23** on QA iPhone, confirm receipt of `R1 FINAL Member 1`–`5`, observe old image/scroll stability, send five short replies for Samsung observation.
2. Keep iPhone chat open, briefly disconnect its network, send one labelled gap message from Samsung, restore iPhone networking: verify one automatic catch-up without Retry/navigation.
3. Observe Poll vote/change and participant count/list on the peer. RSVP needs an accessible, explicitly safe fixture; do not reenroll members or change roles without authorization.
4. On QA iPhone inspect loaded Discussion then offline/reconnect, Expense/Settlement offline/reconnect (no financial write), and Poll/Task list/detail smoke. Report PASS/FAIL with the visible outcome, not just API health.

## Preservation

No production source/test/signing/Firebase changes. Production inventory remains `3d44bdda2f911d32b7163429f5428725618461016a0c7fc0b4704be53c2622fc`. Large dirty worktree predates this continuation and is preserved, not attributed to it. Documentation additions only; runtime helpers outside repository. No commit/push/merge/reset/restore/stash/clean. Keep backend/media runtime running for user acceptance; do not mark R1 COMPLETE until the required physical gate is supported.
