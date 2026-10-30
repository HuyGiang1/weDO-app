# P0 Poll + Chat media investigation — 2026-10-22

## Scope and outcome

Branch `feat/pre-m19-ui-polish`, HEAD `cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`.
Minimal corrections to two reproduced defects; no R2 expansion, R3, schema, transport, signing or Firebase changes. The large pre-existing dirty worktree is preserved and is **not** attributed to this task. R1 is **READY FOR ACCEPTANCE, NOT COMPLETE**; R2 IN PROGRESS; R3–R9 NOT STARTED.

Poll replacement and two-device synchronization passed bounded physical observations. Chat has passing measured five-text runs in **both directions**, each message saved once. Further physical testing exposed a first-reconnect catch-up defect, reproduced red and minimally corrected below. Remaining iOS/new-image/strict scroll and R1-wide checks are not silently marked PASS. After a long interruption both devices locked; iPhone automation subsequently recovered for the five Samsung texts, then USB command copies failed twice. These helper failures are not product failures or acceptance evidence.

## Evidence gate published before production edits

| Question | Reproduced evidence | Root cause / decision |
| --- | --- | --- |
| Poll update | Real Samsung PUT vote returned HTTP500; `uq_poll_vote_choices_vote_option` violation. Safe QA A/A/B/B replay returned 200/500/200/500 before the fix. Three isolated PostgreSQL regression cases failed with duplicate-choice errors. | Hibernate scheduled replacement INSERT before pending choice DELETE. Repeating or retaining a choice failed; disjoint A→B could succeed. Rollback preserved the original ballot. |
| Existing Chat images | Actual ChatScreen widget test: two decoded images + five incoming text events caused image authorization 2→12 and byte GET 2→12; history GET remained 1. Valid generated PNGs and actual NetworkImage HTTP counting, not a helper-call-only assertion. | Reverse ListView had stable message keys but no child-index callback. Insertion at index zero remounted existing image State; new authorization could rotate signed URLs/cache keys. |

Gate was communicated before implementing the four production-file changes. Early invalid-PNG/test-harness attempts are excluded from the valid red/green evidence. Pre-fix logs: `/tmp/wedo-p0-poll-red.log`, `/tmp/wedo-p0-chat-red.log`, `/tmp/wedo-p0-http-before.log`.

## Poll trace and correction

Flutter `PollDetailScreen` vote action → `PUT /api/v1/polls/{id}/vote` → authenticated voter/option/lifecycle validation → `PollService.vote` → locked Poll and transactional ballot/choices → existing AFTER_COMMIT invalidation → authorized scope subscribers → authoritative list/detail refetch.

The original user Poll `318b1af5-db90-4851-870f-6cd951a0b73b` (Ngủ ở đâu) was inspected read-only, not changed. The original backend log `/tmp/wedo-r1-last-gate-backend.log` correlated Samsung HTTP500 at 13:40:29/31 with the database constraint, not an authorization or socket failure. No tokens, credentials or signed URLs are reproduced here.

### Production delta

- `backend/src/main/java/com/wedo/backend/poll/service/PollService.java`: flush choice DELETEs before inserting replacements. Keep the same lock, transaction, validation and AFTER_COMMIT publication. Failed replacement still rolls back; no event escapes rollback.
- `mobile/lib/features/poll/presentation/screens/poll_screens.dart`: prevent concurrent submissions; disable vote controls while in flight; mounted/read-generation guards; explicit permission denial; typed expected errors and reporting of unexpected programming errors. No optimistic phantom vote.
- `mobile/lib/features/poll/data/poll_failure.dart`: distinguish network/timeout, permissions, closed/deadline, option/selection/lifecycle errors instead of one generic failure.

Vote replacement is supported by the canonical Poll API §12 and BA §13. Backend multiple-choice replacement is supported and tested; current consumer UI is explicitly single-choice, so a multi-select UI was **not** invented. Authorized option add/edit/delete/disable exists, with voted-option restrictions tested. A whole-Poll question/visibility edit endpoint is not currently supported: this is a separate product/API decision, not repaired by bypassing rules.

### Focused coverage and physical evidence

| Case | Evidence |
| --- | --- |
| First/repeated/disjoint/overlapping vote | Real PostgreSQL integration tests; safe post-fix HTTP A/A/B/B all200, exactly one ballot and correct choice counts. |
| Multiple-choice/max/selection/deselection, closed/lifecycle/outsider/anonymous privacy | Focused backend integration plus existing Poll tests; not extrapolated physical PASS. |
| Concurrency and rollback | Four concurrent identical votes retain one ballot/choice; forced rollback restores old choice and emits no event. |
| Editing options | Permission and voted-option restrictions, disable retaining historic vote covered by PostgreSQL test. No whole-Poll edit UI claim. |
| Flutter failures | Rapid-submit guard and late disposal; closed/deadline/401/403/network/503 feedback, no phantom successful vote. |
| iPhone→Samsung | Owner A appears automatically on already-open Samsung detail; later Owner A→B automatically produces A1/B1 there. No manual refresh. |
| Samsung→iPhone | Member B→A, after verifying the actual selected radio, produces A2/B0 automatically on iPhone. |
| Offline/reconnect | Samsung retains cached A1/B1 with stale feedback and no submitted phantom vote. Owner changes remotely while offline; Wi-Fi restoration automatically produces authoritative A2/B0 and clears stale feedback. |
| List/detail | Access logs show both phone IPs obtaining list and detail200 after vote200. Detail values physically observed; no claim every list-row field was visually asserted. |

Physical logs: `/tmp/wedo-p0-ios-vote-a.log`, `/tmp/wedo-p0-android-after-ios-vote.log`, `/tmp/wedo-p0-android-vote-a-confirmed.log`, `/tmp/wedo-p0-ios-remote-a.log`, `/tmp/wedo-p0-ios-vote-b-confirmed.log`, `/tmp/wedo-p0-android-remote-b-confirmed.log`, `/tmp/wedo-p0-poll-{offline,recovered}.log`. Generic row/center automation taps that did not visibly change the selected radio are excluded from changed-choice evidence. Their repeated submissions returned200 without double counting.

### Retained QA fixtures

- Shared group `a3ba5950-2fb4-47f5-8d97-82ce42927e42`, now named Nhóm74DCTT23; conversation `b8afdf53-5a00-427a-9036-065748addfd0`.
- Existing Activity `a00ffa5d-cc80-4b64-b9a2-aaccd58043c0`; its historical schedule/lifecycle was not altered.
- Labelled Poll `P0 Poll replacement QA 2026-10-22`, ID `888e24d1-8f03-43a7-a3df-2162cd4cdcb8`; A `520c2e98-61f8-454f-883b-ec136a30bd10`, B `9262110c-cbea-4c4b-ae1b-a7b6663647df`. Last observed both voters A, total2, not a promise of state after subsequent user actions.
- An initial labelled owner-only Lab Poll `bf785a62-1615-4c21-a0f7-919933c18a1a` is retained. Member1 was already LEFT in that group; its404 is correct authorization, not a regression. Membership was not restored or modified.
- No QA data, existing user Poll, conversation or bucket objects deleted; no financial mutations.

## Chat trace, rendering and media measurements

`MESSAGE_CREATED` already carries enough data for incremental merge by stable ID/sequence; own-send response merges the same message and duplicate echo is deduped. Neither path needs a history reload per text. The image correction adds `findChildIndexCallback` in `mobile/lib/features/chat/presentation/chat_screen.dart`, mapping the stable `chat-item-{messageId}` key to its current reverse-list index. A separately reproduced first-reconnect correction in the same file is recorded below; no broad refactor.

Parent/message-list rebuilding is still normal. The corrected invariant is preserving retained image State/ImageProvider across insertion, **not** preventing every build. Active decoded images retain their previously authorized provider/cache key. New mount, retry or resource replacement still authorizes. No public URL, indefinite protected disk cache, global cache busting, socket or history rewrite was added.

| Measurement | Before | After |
| --- | --- | --- |
| Two old decoded images, five incoming text events (widget test) | Authorization2→12; byte GET2→12 | Authorization2→2; byte GET2→2 |
| Same test history GET | Initial1, no additional history | Initial1, no additional history |
| State/provider identity | Remounted/recreated | Same identities, including five local sends and duplicate echo |
| Physical iPhone→Samsung, five unique text sends | No equivalent pre-fix physical count claimed | Zero GETs for both measured old images on both phone IPs; zero conversation-history GETs in the text window |
| Physical Samsung→iPhone | No equivalent pre-fix count claimed | Five uniquely labelled texts saved once and rendered on iPhone; zero old-image GETs/history refetch in the two valid text windows |

Physical fixture: two synthetic pre-existing app icons,32px and64px, posted as terminal QA Owner fixture preparation, **not** claimed as physical iPhone image selection. Messages `8e13051a-afff-4d95-b88b-7d742dd86202`/sequence58 and `e08b57bf-3d20-4428-b330-835a952c8d25`/sequence59. Existing earlier images remained untouched. Safe path hashes `2a0dfd8df1fdf441` and `b246f05a7aa18e79` distinguish old-image bytes without storing signed URL queries.

At 14:24–14:27 local, iPhone UI sent `P0 IPHONE text 1` through5. Each exists exactly once; Samsung rendered all five. `/tmp/wedo-p0-iphone-media-metrics.json` records the zero old-image/history counts; `/tmp/wedo-p0-ios-five-text-completed.log` and `/tmp/wedo-p0-android-five-received-final.log` record UI. The long iPhone command exceeded the client15s wait but completed server-side; no duplicate replay. Initial load/reopening requests were excluded from the send window, not hidden as failures.

Some avatar GETs remained; separately identified hash `e5c813096bcc89a0` is an avatar, not an old Chat attachment. This is a deferred avatar optimization, not evidence that every media request disappeared. `/tmp/wedo-p0-android-media-metrics.json` came from an aborted input batch and is **not** a physical PASS.

After unlocking, Samsung UI sent `P0 ANDROID text 1` through5. Read-only message counts show each exactly once; iPhone UI `/tmp/wedo-p0-ios-five-samsung-confirmed.log` contains all five. The first two and final three were measured separately because fixed-coordinate/Back automation lost focus and navigated away between batches; no blank form was submitted or QA Poll created in that failed batch. Valid counts: `/tmp/wedo-p0-android-first-two-metrics.json` (18:48:19–18:52:04) and `/tmp/wedo-p0-android-last-three-metrics.json` (18:53:57–18:56:15): zero old-image byte GETs and zero phone history GETs. Normal initial/reopen fetches are outside those windows. Final successful sends kept the keyboard open and used semantic Send lookup. No failed batch is represented as a five-text success.

One new synthetic app-icon image was sent by **terminal QA Owner**, not an iPhone/Samsung picker upload: `032fc431-5531-4803-bb5b-66d63767c503`, sequence70, `P0 QA synthetic image after texts`. Samsung rendered its image-open button and caption after scrolling back to recent messages (`/tmp/wedo-p0-android-new-image-visible.log`). While viewing the old images during its arrival, measured old-image GET/history counts remained zero (`/tmp/wedo-p0-new-image-metrics.json`). Scroll up/back down rendered old and recent image controls, but exact continuous pixel-offset/flicker acceptance is not claimed. iPhone picker/new-image observation remains pending after USB failures.

### Additional physical reconnect finding and bounded correction

Samsung Wi-Fi was disabled and confirmed disabled. Terminal Owner posted one labelled missed message `ca63e2d3-bd6f-4011-9c10-37492b6e3c09`, sequence71, `P0 QA reconnect gap 2026-10-22`; Wi-Fi was always restored in `finally`. WebSocket returned101, but the current Chat still ended at sequence70 even after later observation and scrolling to newest. This original reconnect attempt **FAILED**, not PASS.

Read-only trace identified `_wasConnectedOnce` initialized false per ChatScreen while `WebSocketChatRealtimeClient.connect()` returns immediately for an already-connected shared client. The broadcast CONNECTED frame is not replayed on mount. Consequently the first real reconnect after mounting skipped `_catchUpAfterReconnect`. The existing >100-message test artificially injected an initial CONNECTED frame after mount, masking this case.

The test was strengthened to mount on the already-connected fake without replaying that initial frame. It failed with actual history cursors `[null]`, expected `[null,null,6]` (`/tmp/wedo-p0-reconnect-red.log`). This new evidence/root-cause gate was communicated **before** the additional production edit. Minimal correction initializes `_wasConnectedOnce` from `realtimeClient.currentState == connected` before listening/connecting. Existing reconnect/resubscribe/bounded REST catch-up, no per-message history refresh, sockets and retry policy remain unchanged. The strengthened paginated/overlap/dedupe test now passes within the final244-case run.

**Final Samsung first-reconnect retest PASS**, final APK below: mounted Chat on the already-connected Home client, verified current sequence71; Wi-Fi confirmed disabled at19:06:13.817 local, terminal Owner created `8f97cd32-0dc5-42da-83dc-60651d7a159f`/sequence72, `P0 QA reconnect final 2026-10-22`; Wi-Fi restored19:06:14.129. Device remained Awake. With no refresh/navigation/background-resume intervention, wire showed WS101 → historyGET200 → read-state204; UI displayed sequence72's unique label. Logs `/tmp/wedo-p0-reconnect-final-{start.json,fixture.log}`, `/tmp/wedo-p0-android-final-reconnect-observed.log`; bounded final PID5558 log scan found no unhandled/fatal/framework/disposed-state patterns. A first immediate dump can precede network reassociation and is not the recovery verdict. This is a brief Wi-Fi-loss case, not long-outage/load/APNs acceptance.

### Cache/security and scroll limitations

Actual authorized synthetic-image GET returned200/image/png, ETag present, no Cache-Control header. Signed GET TTL remains5min. HEAD against a GET-signed URL returned403 because signing binds the method; corrected GET succeeded. No permission bypass or persistent/disk-cache behavior is inferred. A remount can produce a different signed URL/cache key; renewal on a new mount/expiry is legitimate. The fix preserves only children retained by the list, not images scrolled arbitrarily far out of its cache extent.

Existing tests cover pagination/reverse history, reconnect with >100 messages/REST–WS overlap, dedupe, foreground/background, typing/presence/read behavior, upload errors and private media. They are not substitutes for unobserved physical new-image/scroll/background/reconnect cases. Incoming insertion does not intentionally force scroll-to-bottom; own send does. Continuous physical scroll-offset/flicker measurement is still pending; no blanket visual-no-flicker claim from snapshots alone.

## Verification and changed files

Production files: the four paths listed above only. Test delta in three already-dirty files:

- `backend/src/test/java/com/wedo/backend/m8/M8MultiAccountIntegrationTest.java`: five `p0*` cases.
- `mobile/test/features/poll/presentation/poll_screens_test.dart`: seven cases.
- `mobile/test/features/chat/presentation/chat_screen_test.dart`: retained-state/provider and real byte-request-count regression, including received/local text and duplicate echo.

Backend focused: **31 PASS,0FAIL,0ERROR,0SKIP** = Poll/authorized realtime16 + private media15. Logs `/tmp/wedo-p0-poll-focused.log`, `/tmp/wedo-p0-media-focused.log`. Isolated Testcontainers PostgreSQL, no QA database reset. Firebase credential supplied by existing external path only, never printed.

Flutter affected Chat/Poll/media/core realtime/Discussion/Activity: initial **244 PASS,0FAIL**, `/tmp/wedo-p0-flutter-focused.log`; after strengthening the existing reconnect case and its minimal correction, final **244 PASS,0FAIL**, `/tmp/wedo-p0-flutter-final.log`. Final analyzer **No issues found,3.2s**, `/tmp/wedo-p0-analyze-final.log` (initial3.4s). No full suites; pre-existing scratch `mobile/test/temp_test.dart` untouched.

## Candidate/runtime identity

Fresh current Mac en0 `<QA_LAN_IP>`; Samsung `<QA_LAN_IP>`; iPhone observed `<QA_LAN_IP>`. Both candidates use `http://<QA_LAN_IP>:8080`. Existing PostgreSQL/Redis/MinIO and QA data retained. Instrumented backend PID97576/log `/tmp/wedo-p0-backend.log` was replaced at session end only to remove access-log diagnostic flags, reusing the same JAR/environment. **Final backend PID94784/session13578**, `/tmp/wedo-p0-backend-final.log`; **restored media-only relay PID94760/session13742**, `/tmp/wedo-p0-media-restored.log`. Local+LAN actuator UP (DB/Redis UP), local+LAN MinIO ready; Samsung Wi-Fi enabled. No recreated containers. About4.55GiB disk free at final health read; no cache/disk cleanup performed.

- Backend package `-DskipTests` after focused tests: SHA256 `951183dbf89aae2eafe125acfe8754747d38ca3c26988d5caa2d480ac9a9ee1b`.
- Android debug build/in-place install PASS: APK SHA256 `3e98ca21543a7d75073144b5802e65cfd9361fee8fdc1cdf0ebe529658e6dbef`.
- iOS release build/in-place install/launch PASS, existing local signing/session: executable SHA256 `d7ba223f7b5c5e9aa991634ec63f648a043d3227f42dd498ab6e6e1fe2d59ba2`.
- Initial production-source inventory fingerprint (sorted SHA256 of files under backend/src/main, mobile/lib, mobile/android/app/src/main and mobile/ios/Runner): `4beb3e61f360f3ca9e503f18736d7a9bd026147c484fba418e805832b3e6ac06`. Final after first-reconnect correction: `816c0ac8f5f9509fc26022795d212a514c8726516636f17a99ec550d430aed04`.
- Final Android debug build21.8s/install-r PASS, APK `9742911db447f6b4f21223391f10906252dc21c8de5313a552ad7caf178dce9d`; final iOS release build34.3s/install/launch PASS, executable `e6b52ca5a45fc39c3597edfe5d9b4d6b73e1641e58b800d38d378206c89b3eea`. Earlier five-text/image observations identify the initial candidate above; final change is only shared-socket initial-state recovery. Do not imply those observations were repeated on the final binaries.
- Existing native project SHA256 `ad773f3ca0646bfd2275f088c1b0eacefedc643e90c16249f05ccf4ce5c8c6b8`; Info.plist `cd88a3e2d1ee3b1c064d214026073303db8f11b2baa9e4dcc00811422ce8a8bd`, unchanged by this task. Secondary iPhone untouched.

## Remaining physical/manual gate

1. Do not replay either completed five-text batch. On final binaries, finish strict visual placeholder/flicker/scroll-offset acceptance with two retained decoded image bubbles; automated state/provider/byte-count evidence and initial-candidate two-way observations remain scoped evidence.
2. Finish a specifically identified synthetic-image picker send and iPhone receive/render observation. Samsung terminal-Owner new-image event/render passed as described above, not both physical picker upload paths. Never select personal photos for automation.
3. Complete final iOS scroll/background/reconnect checks once UI control is available. iPhone home/activate was exercised and a later stable Chat tree retained its data; the immediate resume tree was during transition, not a precise visual/performance assertion. Confirm authoritative recovery/no duplicates and no uncaught errors. An image remounted after leaving the retained viewport may legitimately reauthorize.
4. Finish the outstanding R1-wide checklist in `R1_LAST_GATE_MANUAL_ACCEPTANCE.md`; this scoped P0 result does not sign off every module, permission-loss, FCM or R2.

Temporary passive media request class/import/attachment were **removed** from the external relay script and its instrumented process97385 stopped; original functional media-only LAN forwarding restored. Backend resumed without task-only Tomcat access-log flags; collected sanitized historical logs retained, containing no auth headers/query/body. Identified iPhone runner/xcodebuild75051 stopped; no helper rebuild/signing change. Old hotspot relay25669 untouched. No commit/push/merge/reset/restore/stash/clean, staging or data cleanup. No claim of complete R1/R2 acceptance.
