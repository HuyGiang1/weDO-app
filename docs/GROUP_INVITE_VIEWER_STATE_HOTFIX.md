# Group invite QR: viewer membership/pending-state hotfix — 2026-10-28

## Reproduction and cause

User confirms Recruitment form OK and QR via external Samsung Camera opens the correct Group. Requesting admission for an existing member returned generic failure. Reproduced using existing QA Member1: Group GET200, invite preview200 with no viewer flags, duplicate join POST409 `ALREADY_GROUP_MEMBER`. No new membership/request created. Flutter already mapped that code to an enum but its Vietnamese message fell through to generic text; preview always offered admission based only on join policy.

## Minimal correction

- Backend invite summary adds read-only `alreadyMember` and `requestPending`, projected for authenticated caller only. ACTIVE membership includes Owner/Admin/Member; pending flag is for a nonmember PENDING request under APPROVAL_REQUIRED. No schema/migration, new endpoint, membership side effect or artificial state/version.
- Existing POST locks and validation for revoked/expired/limited links, archived groups, bans, capacity, direct join/approval and usage are unchanged. Preview does not consume usage. Legacy Java6-arg constructor and Flutter absent-field defaults preserve compatibility.
- Member screen: “Bạn đã ở trong nhóm này.” + “Vào nhóm”, existing typed GroupInfo route; no admission button. Pending screen: waiting state, no repeated request button. Newcomer retains existing direct join/request flow.
- If membership/pending changes after preview,409 triggers one authoritative refetch, never a mutation retry. Specific Vietnamese fallback messages, duplicate in-flight guard and stale/disposed result protection added to scoped JoinByCodeController.
- Canonical API specification and Design System updated. No cached-group-name inference or permission weakening.

## Verification and acceptance

-41 backend testsPASS,0fail/error/skip:13unit,18MVC,10isolated PostgreSQL admission/concurrency/projection. Tests include existing Owner/Member, pending/newcomer flags and rejected duplicate mutations without usage consumption. FirebaseApp/Messaging mocked only in this integration test class, no external credentials/push. Initial test-class ADC startup failure was resolved through test isolation, not production configuration changes.
-162 Flutter Groups/routes/links testsPASS17s; analyzer clean5.3s. New cases cover existing member open-group callback/noPOST, pending/noPOST, eligible request, both409 races/refetch once/no replay, stale/disposed reads. `/tmp/wedo-invite-state-{backend-tests,flutter-tests,analyze}.log`.
- Backend packagePASS2.942s/restartPASS PID35706, existing environment/local/LAN/media preserved, QA seedingOFF. Local+LAN healthUP; runtime Owner/Member1 resolve both return alreadyMember=true/requestPending=false. Newcomer/pending SQL evidence is isolated-test evidence, not a claim of new physical tests for those branches.
- Android debug12.2s/build/install-r/launchPASS, APK `cac83ccaee2d26988235fabe58bd5dde370fc9447f813cab759f1faf62e49acc`; iOS Profile40.5s/35.6MB/build/install-in-place/launchPASS, Runner `27666918788c86c05f15423b9587142d1f4c74e04b47ade9a8ea77becf299425`. JAR `7be937e40dd9578595d0e462f2207e4899aba8ece76d279a53eb459137590fe8`. `/tmp/wedo-invite-state-{runtime,package,android,ios}{,-install,-launch}.log` as applicable.
- **User physical PASS: “Có nhé luồng này đã ok rồi.”** In response to Samsung rescan of a group already joined → member message and Vào nhóm → correct group opens. Preserve exact scope; not full R9 or all pending/revoked/unauthorized physical scenarios.

## Scope and preservation

Production: backend GroupInviteSummaryResponse + GroupAdmissionService; Flutter group_models/group_failure/group_admission_controllers/group_admission_screens/routes. Tests:2 backend paths +1new Flutter invite_viewer_state_test. API/design/current handoff/shareable report docs updated.

No existing QA membership/Task/financial mutation, DB/volume reset, signing/Firebase config change, second-iPhone interaction, new socket or polling. Media relay exact .116/.110/.101 untouched. CurrentAPI<QA_LAN_IP>. Full prior dirty worktree/stash retained; no stage/commit/push/merge/reset/restore/stash/clean. R10 remains IN PROGRESS; do not reopen accepted flow absent a new defect.
