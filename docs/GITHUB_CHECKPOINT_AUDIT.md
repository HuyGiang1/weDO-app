# Current checkpoint status — approved rotation validated; preparing source commit

User approved the previously documented QA rotation/session impact. Three new
independent keys now live outside Git; current source requires explicit values.
After51focusedtests/package validation, only backend restarted. Old access token
is rejected; fresh Owner/Member login is signed by the new key and can read old
groups/chat. Persistent user/message/expense counts match; no refresh rows were
deleted/revoked. Physical phones were locked, so device UI re-login is pending,
not claimed PASS. No new install/signing/Firebase/storage change.

New integration branch was created from the original HEAD. All intended source
will be reviewed/staged explicitly, including untracked Moment/Realtime/migration
code and Windows onboarding. No blindgitadd, merge, forcepush or history rewrite.
Original machine-specific documents remain in ignored local preservation; shared
versions are redacted. Local owner Xcode signing remains in worktree only; staged
project is portable. Historical keys remain in ancestors and must not be reused.
QA account passwords were not rotated in this3-key approval and are not included
in new source/docs. Broader production exposure was not established.

The detailed earlier blocked audit below is retained for chronology and is
superseded by this approval/validation status. Actual remote push verification
is recorded after push, not inferred here.

---

# GitHub checkpoint — verified active-QA secret blocker

## Runtime classification confirmed — 2026-10-30

Latest user request24fd319b authorizes checkpoint remediation/commit/push **only after security classification passes**, and explicitly requires stopping if values protect non-disposable environments or usage cannot be verified. **Gate fails: these are active persistent QA authentication secrets, not merely unused synthetic test constants.** No branch creation, staging, source/config edit, commit/push, rotation, session revocation, history rewrite or QA restart performed in this follow-up.

### Read-only proof, values withheld

- Exact existingQAbackendlistener **PID4203**, expectedverifiedJAR; activeprofile **local**. Packagedlocalconfigcontainsall3fallbackliteralsidenticaltocommittedHEAD.
- Processenvironmenthas **no overrides** for WEDO_JWT_SECRET_BASE64, WEDO_AUTH_TOKEN_PEPPER_BASE64 or WEDO_PROFILE_COMPLETION_TOKEN_SECRET_BASE64, and no directSECURITY_* overrides. NoJVM-Dproperties/SPRING_APPLICATION_JSON/SPRING_CONFIG_LOCATION/additionalconfigurationoverride; no standardexternalapplication/profilefiles found. Active startupscript doesnotsetauthsecrets. These observations establish the runningprocessresolvespackagedfallbacks without displayingrawvalues.
- Databaseaggregates: **5users, all5reserved@wedo.local**,528refreshsessionrows/**269currentlyvalidrows**,124storedChatmessages,5storedexpenses. These are persistent manualQA records/sessions; sessionrows do not mean269devices/users and are not evidence of compromise. No actualcustomeraccount established bythesechecks. User-suppliedQAcontentisnotclaimeddisposableormigratable.
- Samevaluesalreadyinoriginhistory (firstcommitslistedbelow). Repoaccessibility/productiondeploymentsnotverified; no evidence warrantsclaimingproductionhasnouseofdefaultsorprivatecustomersareconfirmedcompromised. Trackedrepo has no configureddeploymentpipeline beyondworkflowplaceholder; externalstaging/productionsettingscannotbeestablishedfromlocalGit.
- No additionalFirebaseAdmin/APNs/privatekeyexposurewasconfirmed bypriorpatternaudit, **not** a blanketsecret-freecertification. Broaderper-filepublicationreviewisstillpendingbecauseuserrequiresSTOPattheactive-secretgate.

### Required approval and session-impact plan (not executed)

1. Agree on a short QA maintenance/relogin window. Save/confirm current sessions are expected to change; do not silently rotate while usertests. Preserve databasevolumes, financialhistory, mediaobjects andsigningassets; noQAreset/dumpupload.
2. Generate3independentnew256bitsecrets **outsideGit** in external/privateenvironmentconfig, not copied fromhistory and notprinted. Configure theQA launcher to load them and remove committed auth fallback values from future source, using requiredvariables/safegenerationtemplates. Existing teammate setupalreadygeneratesseparatefreshkeys; itdoesnotfixactiveQAexposure.
3. Rotationimpact: changingJWTsigningkeymakesexistingaccessJWTsignaturesinvalid. CurrentFlutterAuthInterceptor handles AUTH_TOKEN_INVALID by sessioninvalidation; expired-onlyrefreshdoesnotguaranteetransparentsurvival. **ExpectOwner/Memberphones to needloginagain.** Passwordhashes/Chat/finance/mediaarenotchangedbykeyrotation.
4. AuthTokenHasher pepper protects **email-verification/password-reset codes**; outstandingcodesmustbereissuedafterrotation. Profilecompletionsecret rotation invalidatespendingonboarding/profilecompletiontokens. **Opaque refreshtokens are hashed separately with plainSHA256** in RefreshTokenService, notwiththese3keys; rotationalonedoesnotrevoke269validrefreshrows. Decide separatelywhetherapprovedQArefreshsessionrevocation isneeded; do not issue blanketDBrevocationwithoutapproval.
5. Afterapprovalonly: narrowbackend/configtests, controlledrestartwithnewenv, freshOwner/Memberlogin andtargetedsession/media/Chathealthchecks. Do notmodifyledger/businesssemanticsoraddanunreviewedold-keyacceptancepathjusttoavoidrelogin.
6. ExistingGit history stillcontainsoldvaluesafternewsourcecommit. Do notrewrite/forcepush; separatelyassesswhohadrepoaccessandwhetherthosekeyswereusedelsewhere. Rotateanyotherverifiedaffecteddeploymentunderitsownmaintenanceapproval. Historicalcleanuprequiresseparateexplicitapproval, notassumedfromcommit/pushauthorization.
7. Onceactiveusageisremediatedandclassificationgatepasses, completeexplicitfilemanifestreviewincludingMomentController/MomentDtos/MomentsServiceandallRealtimecoordinator/event/publisher/fanout/scopefiles; sanitizeprivatedocpaths/deviceIDswithlocalpreservation; includealllegitimateproduction/migrations/Flutter/onboarding. OnlythencreateintegrationbranchfromcurrentHEAD, stage reviewedpaths, commit/pushnonforceandverifyremotetree. No fileswereaccidentallyleftoutofacommit: **thereisnocommit**yet.

### Current deliverable state

Branchremainsfeat/pre-m19-ui-polish/HEADcdb0bd7e3ef564a0430e45b1db331b80cfbf10f0; indexempty. SourcechangesforpreviousWindows/onboarding/iOSworkremainintact. Windowscore9backend/38Flutter/analyzerclean/noFirebaseAPKPASS retained; actualWindows/MinIOlicenseexternalacceptancepending. No fulltests/builds neededforreadonlyclassification. R9iOSPushpaused, stillINPROGRESS. **GITHUB CHECKPOINT BLOCKED — committed auth fallbacks are actively used by persistent QA; rotation/session-impact approval required.**

---

# GitHub checkpoint audit — blocked before staging

2026-10-30. User authorizes a new integration checkpoint commit/push but explicitly requires stopping if a secret is already committed. R9 iOS push is paused by this request. No staging/branch creation/commit/push/merge/history rewrite performed.

## Actual Git state

- Branch: feat/pre-m19-ui-polish
- HEAD: cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0
- Remote: https://github.com/HuyGiang1/weDO-app.git
- Current HEAD matches origin/feat/pre-m19-ui-polish; no local-only commits on current branch.
- origin/dev...HEAD: 0 left /1 right. Local dev/main refs are older; not switched/updated.
- R1–R10 changes are accumulated uncommitted on current branch; no separate R1–R10 branch history exists in fetched local/remote refs. M1–M18 legacy milestone branches are a different roadmap.
- 894tracked +154untracked files inventoried;339modified/new file paths (short status collapses directories).25,485ignored artifacts inventoried. No tracked/untracked file >1MiB; largest candidate existinglogo720,097bytes. Repo .git26MiB; mobile6.3GiB mainly ignoredbuild/cache; disk4.9GiB.

### Local branches

- `dev c96c043e6643a4cb8b94d64f33b34f19d6a82391`
- `feat/m16-media-search a1e28a06d88199bb0ea3f3663596bd9a729819ff`
- `feat/m2-auth-security 8997bcfe53d9f3f36a724ebf62fa4921074c4f81`
- `feat/pre-m19-ui-polish cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`
- `main c96c043e6643a4cb8b94d64f33b34f19d6a82391`

### Actual remote heads (git ls-remote)

- `dev` — `a3810701b747520cae25c8f3a0706c3296703c76`
- `feat/m1-database-foundation` — `a61be94ec106a747775e0bbe55bfadf27419a720`
- `feat/m10-chat-realtime` — `93d8d63476a0ef8023c9a799840a62b2882ee9be`
- `feat/m11-expense-balance` — `3d762afbda95bd9b155a586891b33abb0b057f41`
- `feat/m12-settlement` — `95a5874d65879f9a5a2d53ad7c9fb642a5118854`
- `feat/m13-group-fund` — `d6d374da8bc9a5395701facbf50a40d0bce7101d`
- `feat/m14-notification-fcm` — `d4fc8571959d92e17b139be936669f64c459b6d8`
- `feat/m15-calendar-reminder` — `09fd2614007bb117d13d99fe3b6c23efbe74d727`
- `feat/m16-media-search` — `a1e28a06d88199bb0ea3f3663596bd9a729819ff`
- `feat/m17-home-product-completion` — `6020cfd6a4fa174d1cae3ff670e2662132d6f029`
- `feat/m18-hardening` — `3cb4c332dd3f09df78d6e6b097778f729bf88b55`
- `feat/m2-auth-security` — `856ddec8bc16f9c4a73214e17a53287ead68d3cc`
- `feat/m3-user-profile-privacy` — `9e9c09a704fac5b9e5559341da2fad81a4015df7`
- `feat/m4-social` — `276888490110237b847172359aad6a2009e88290`
- `feat/m5-group-core-membership-permission` — `8418c6ec8f73c5e47e87eae494cbbc3b2aa4df5f`
- `feat/m6-group-invitations-join-ban-lifecycle` — `23a1d86c749f49f142cdc7b4b51f5c6407813111`
- `feat/m8-poll-task-discussion` — `0c997fa6846e30c0d51f231677f5df9eb850bd5e`
- `feat/m9-chat-rest` — `8d88e693cb909d19df317913678febfa571f3ad5`
- `feat/pre-m19-ui-polish` — `cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`
- `fix/m3-stitch-parity` — `2347e26a25d0b446668a390d500e4383dd583ccf`
- `main` — `186fe597d2ee233503836cd8f24c0649bb7f3dfe`

## Confirmed tracked security material in existing remote history

File: `backend/src/main/resources/application-local.yml`. Three hardcoded32-byte cryptographic fallback values are present in currentHEAD and existing origin branch history. Values intentionally not reproduced here. These are local-development defaults; production use/exposure is not established. Any environment using these committed defaults has publicly/repository-known signing/pepper material. They are not Firebase service-account/APNs private-key findings.

| Setting | First commit containing current literal on origin branch |
|---|---|
| `WEDO_JWT_SECRET_BASE64` | `f65959a208bf327f2daf5bb2fbe9e3c7bd1eabeb` |
| `WEDO_AUTH_TOKEN_PEPPER_BASE64` | `a84dd20e943f57818be8a385d1aa8095a23ef9f1` |
| `WEDO_PROFILE_COMPLETION_TOKEN_SECRET_BASE64` | `e1ca32b8feca016490b1efa9b48333f5b8b29d9d` |

The initial high-confidence pattern scan of1,048workingfiles/4,232branch+remotehistoryobjects found no private-key/GitHub/AWS/Slack/service-account-private-key/JWT-pattern matches. This does not certify absence of all secrets: manual config review caught the cryptographic defaults above. Protected stash was not inspected or changed.

Other review findings retained locally: untracked realAndroidFirebaseclientconfig; originalscratchtest; project-specificiOSteam identifiers; numerousmachinepaths/deviceIDs andruntime details in handoff/acceptancereports. These require an explicit safe clientsetup and sanitized source/documentation plan before staging. No candidate credential contents are included in this audit. Existing local-only/protected files and allbuild/caches remain untouched.

## Required remediation / approval boundary

1. Determine where committed local defaults are actually used. Supply newly generated secret values via ignored external environment/secret management, not committed config. Test fixtures may use clearly synthetic values; do not label all test literals as production credential exposure.
2. Agree on rotation/session impact before changing live QA secrets: signing/pepper rotation may invalidate sessions or outstanding tokens. Do not reset data, rotate secrets or break current QA sessions as part of this stopped checkpoint.
3. Replace committed runtime fallbacks with required environment settings/safe templates under a separately reviewed change; add safeignore rules for privatekeys/keystores/localdeviceconfigs/scratch and team onboarding instructions. No such code/config change executed here.
4. Deleting literals in a new commit does not remove ancestor history. Any history rewrite requires separate explicit approval and coordinated teammate remediation; no rewrite, force push or branch deletion authorized/executed. GitHub exposure/visibility and deployment scope need assessment; do not claim private production credentials are confirmed exposed.
5. Once user reviews this finding and authorizes the remediation/accepted-development-default policy, resume completefile review, sanitize localmachine details while retaining originals locally, create collision-free integration/r9-qa-checkpoint from the actualHEAD, stage explicit reviewedmanifest, verify and push only that branch. The existing commit/push authorization is preserved, but stop-on-secret rule takes precedence now.

## Final state

No checkpoint branch/commit/push exists from this task. No teardown or QA environment changes. No fullregression/builds run. Existing38focusedFlutter+1backendpushPASS/analyzerclean and priorR9evidence retained; R9 remainsINPROGRESS on iOSAPNs/FCMconfiguration+physicalreceipt/tap. Onboarding/setup and reproducibility are not claimed complete.

## Additional Windows onboarding requirement — 2026-10-30

Independent onboarding work is now prepared under explicit subsequent user authorization: [Windows + Emulator guide](TEAMMATE_WINDOWS_ANDROID.md), safe env generator/template, isolated Compose/profile, optional push mode and configurable synthetic seed.9uniquebackendchecks/38Flutter/analyzerclean and isolatednoFirebase x86_64APKPASS; actualWindows/PowerShell/emulator/media-license acceptance remains honest pending. No existingQAenvironment/credentials/data changed. This does not waive the original stop-on-committed-secret condition: **no checkpoint branch/staging/commit/push yet**, historicaldefaultpolicy/remediation and remainingpublicationreview stillrequired. A fully credential-free MinIO environment is not claimed; currentAIStorlicense or independentapprovedS3endpoint is explicitly required for media.
