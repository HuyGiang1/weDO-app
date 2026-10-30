# weDO design system

**Single source of truth for Flutter UI/UX.** Adopted2026-10-28. Product: weDO, Flutter iOS/Android. Direction: **Modern Minimalist Monochrome**, inspired by Linear, Vercel Dashboard and Notion, adapted to mobile rather than copied desktop layouts.

This document supersedes older purple/decorative visual instructions and the visual aspects of historical Stitch references. It does not supersede canonical product/API/schema rules or authorization. Actual code is the implementation evidence; any mismatch below is a migration gap, not permission to claim completion. Do not change backend, state ownership, repositories, subscriptions, payloads, permissions or workflows to implement a visual requirement.

## 1. Philosophy

Content and useful actions come first. Use precise alignment, modest type weight, whitespace and lightweight separators. Neutral surfaces establish hierarchy; decoration must carry information. Use a small number of containers, not a card around every row. Keep media/avatar content in its original colors. The interface stays monochrome; semantic error/warning/success colors are reserved for actual states with text/icon, never decoration. Do not invent counts, location claims, progress, greetings or statuses unsupported by existing view models.

## 2. Implemented color tokens

Runtime authority: `mobile/lib/app/theme/app_theme.dart`, `AppTheme.build(Brightness)`, `AppSemanticColors`. All three MaterialApp entrypoints use shared light/dark themes and system appearance. New widgets read `Theme.of(context).colorScheme`; `AppColors` is only a light-theme compatibility palette for older code, not a second system.

| Meaning / Flutter role | Light | Dark |
| --- | --- | --- |
| Page background (`scaffoldBackgroundColor`) | `#FFFFFF` | `#0A0A0A` |
| Foreground / `onSurface` | `#0A0A0A` | `#FAFAFA` |
| Primary / focused field / selected navigation | `#0A0A0A` | `#FAFAFA` |
| On primary | `#FFFFFF` | `#0A0A0A` |
| Surface / lowest container | `#FFFFFF` | `#111111` |
| Secondary surface / low container | `#FAFAFA` | `#171717` |
| Container / primary, secondary, tertiary containers | `#F5F5F5` | `#262626` for accent containers; standard container `#1F1F1F` |
| High container | `#E5E5E5` | `#262626` |
| Highest container | `#D4D4D4` | `#333333` |
| Muted foreground / `onSurfaceVariant` | `#737373` | `#A3A3A3` |
| Border / `outlineVariant` | `#E5E5E5` | `#2E2E2E` |
| Strong control outline / `outline` | `#737373` | `#737373` |
| Secondary/tertiary foreground | `#525252` | `#D4D4D4` |
| Inverse/dark surface | `#111111` | `#FAFAFA` |
| On inverse surface | `#FAFAFA` | `#0A0A0A` |
| Error/danger | `#B91C1C` | `#FCA5A5` |
| On error | `#FFFFFF` | `#450A0A` |
| Error container | `#FEF2F2` | `#450A0A` |
| On error container | `#7F1D1D` | `#FECACA` |
| Actual success (`AppSemanticColors.success`) | `#246B45` | `#8BD8AE` |
| Actual warning (`AppSemanticColors.warning`) | `#865B13` | `#F0CA79` |

Additional implemented roles: surfaceBright `#FFFFFF`/`#262626`; surfaceDim `#FAFAFA`/`#0A0A0A`. All fixed accent families are neutral in both modes: fixed `#F5F5F5`, fixedDim `#E5E5E5`, onFixed `#0A0A0A`, onFixedVariant `#525252`. Surface tint and decorative shadows are transparent. Text selection uses primary at16% opacity. Semantic label backgrounds may use their foreground at10%; no status is conveyed by color alone. Overlay scrims and fullscreen media may use black appropriately.

## 3. Typography and Vietnamese

No new font dependency or downloaded/bundled Inter/Geist asset. Use the existing Flutter/platform font defaults and Unicode fallback with complete Vietnamese diacritics. Do not describe Inter or Geist as installed. Visual test screenshots may load a local readable Arial font; that is test tooling, not the shipped font.

Implemented `TextTheme`: titleLarge22/600, titleMedium16/600, bodyMedium14/400 with1.45 line height. Standard Material bodyLarge16/bodySmall12/label styles remain available. Home keeps its compact brand app bar; do not insert a separate promotional heading or tagline above groups. Use400 for body/metadata,600 for headings/actions; avoid blanket700/800. Do not shrink long Vietnamese text to force it onto one line.

`AppTextStyles.of(context)` adapts legacy colors while preserving its existing scale: brand40/800, headline28/700, subtitle18/400, bodyMedium16/400, bodySmall14/400, label/button/link14/600, input15/400. These are compatibility styles, especially Auth; prefer TextTheme for new work. Their larger brand treatment is not the default for content screens. Retiring every legacy heavy weight is pending migration, not an implemented global claim.

## 4. Spacing, geometry, borders, shadows

Use existing `AppSpacing`: xxs4, xs8, compact12, sm16, md20, lg24, xl32, xxl48. Existing auth maxContentWidth448 and control heights52/56 remain for compatibility. Standard mobile horizontal inset16–20, section spacing24, row gaps8–12; adapt to available width.

Implemented `AppUi`: fieldRadius12, cardRadius12, touchTarget48. Use6–8 for compact icon containers/status labels;12 for form/card/dialog surfaces. Border1px; focused/error-focused field1.8px. Thin separators may be0.6px. Shadows/elevation0; default container hierarchy comes from neutral tone, spacing or a border. Avatars stay circular. Existing Chat bubble/gallery/media/modal shapes may differ for content/gesture reasons; do not rewrite message widgets just to normalize radius.

## 5. Icons

Use existing Material **outlined/line** icons; Lucide is not installed. No icon package added. Theme icon22; bottom navigation24; row icons20–22; compact metadata/status15–18;48px minimum interactive target. Reuse the same semantic icon for the same action. Neutral foreground by default, danger only for destructive actions. Preserve native camera/picker icons and real media. Avoid random colored circles and mixed decorative icon sets. Some older rounded/filled icons are pending normalization; do not claim all legacy glyphs have changed.

## 6. Reusable components

| Component | Implemented behavior / use |
| --- | --- |
| `AppTheme` | Both brightness variants, monochrome ColorScheme, input/button/card/list/dialog/navigation/selection defaults. |
| `AppTextField` | Existing typed controller/FocusNode/validator API; external label, inherited12px outline; no underline. |
| `AppPasswordField` | Same field contract, obscuring and accessible reveal/hide toggle. |
| `PrimaryButton` | Existing callback/loading/height API, shared themed ElevatedButton; no pill or shadow. |
| Standard TextFormField/TextField | Shared outlined decoration; semantic keyboard, validators, initial value and focus preserved. |
| Standard DropdownButtonFormField | Same outline; expanded text for long labels where needed; no alternate visual system. |
| `AppSurface` | Theme Card with12px border, zero elevation; use for a coherent section, not each line. |
| `AppSectionHeader` | Shared section title/subtitle spacing. |
| `AppManagementRow` | Consistent icon/title/subtitle/status/chevron; optional avatar;64px minimum row; disabled when no callback. |
| `AppStatusLabel` / `AppTone` | Text and optional icon with neutral/accent/success/warning/danger semantics. |
| `AppNotice` | Shared informational/warning/error banner. |
| `AppBottomNavigation` | Canonical five destinations; retained-tab selection and existing typed-route fallback. |
| `TabChromeController` / `TabChromeScope` / `TabChromeRegion` | Per-tab, presentation-only Community header/bottom-bar visibility,150ms collapse, accessible/reduced-motion behavior. |
| `GroupsBottomNavigation` | Compatibility adapter for existing callback indices; renders the canonical bar, not a second tab system. |

Buttons: primary dark neutral in light mode/light neutral in dark mode; secondary outlined or quiet neutral surface; danger uses error color + explicit verb. Minimum48px target. Inputs: label above text, helpful hint where useful, multiline allowed, error below, disabled/read-only clear; retain values on keyboard dismissal. OTP remains boxed8px cells, an explicit exception to12px fields.

Dialogs/sheets retain native modal motion, concise heading, specific confirmation and clear cancel/confirm actions. Destructive confirmations name the target when possible. Success is shown only after authoritative success, never merely on tap. Do not add sleep/timer feedback hacks.

## 7. Home information hierarchy

Implemented layout uses the **same** HomeController/HomeResponse and callbacks: compact circular-mark + weDO + notifications header; no separate “Không gian của bạn” heading or promotional tagline; prominent **Nhóm của bạn** immediately near the top with **Xem tất cả** and **Tạo hoặc tham gia nhóm**; exact finance balances/actions immediately below groups; then independently collapsible pending actions, upcoming activities and recent updates. Groups use existing Home group previews, never another data source: one group is a compact avatar/name row, multiple groups a horizontally scrollable preview. The single inverse-neutral group section is the restrained high-contrast emphasis area. Both entry actions remain available when there are no groups.

**Xem tất cả** and **Tạo hoặc tham gia nhóm** open the existing full Group List route, which retains its existing Create Group, join-by-code, invitations and authorized management paths. Individual previews open the existing Group Detail. Do not hide these entry points below a long action list or add a sixth tab. No fabricated metrics/greeting, new query, sorting/filtering or business transformation.

Use date/time metadata already returned by the server; do not invent a lifecycle status the Home model does not expose. Preserve every Home action, refresh, error and cached-data state. Finance values remain exact formatted server-derived money, never calculated by widgets.

## 8. Five-tab navigation

**Exact order: Cộng đồng | Trang chủ | Tin nhắn | Lịch | Hồ sơ.**

Runtime routes: `/community`, `/home`, `/chat`, `/calendar`, `/profile`. App starts on Home after existing auth restoration/login. Community is the existing `CommunityScreen`/API/read state with a root-tab flag, not a WebView, cloned feed or second controller. Author-post screens remain details without a root bar.

`MainTabRoute` + Navigator-scoped lazy retained IndexedStack/TickerMode preserve tab widget/scroll state. No parallel navigator/GlobalKey/store/socket. New tab entry uses existing app typed-argument/auth enrichment. Main-tab selection reuses the retained host and removes only details above it. Groups are now a normal Home destination; opening Groups must retain the tab host underneath. Explicit deep links/auth/notifications keep their existing guarded destination semantics.

### Community-only immersive chrome

Actual implementation: `TabChromeController` owned by the retained tab host; `TabChromeScope` exposes it to that tab, `TabChromeRegion` coordinates header layout and the shell's `AppBottomNavigation`. This is presentation state only, not a feed/store/realtime signal. A local presentation fallback supports standalone rendering. No global scroll listeners, new navigator or network subscription.

Main Community feed only (`rootTab` + no author filter): actual drag/gesture scroll down hides header/filter controls and bottom bar together after24px accumulated movement; reverse direction resets accumulation,24px upward reveals them; user scroll reaching top reveals both. Programmatic jumps/restoration do not count as user direction.150ms restrained size collapse reclaims viewport space, zero duration with reduced motion. Accessibility navigation retains visible chrome. Hidden elements lose hit testing/semantics; visible **Hiện điều hướng** recovery action always restores bars without moving feed position. Loading/unavailable/empty feed keeps navigation visible.

Switching tabs normalizes both previous/next chrome, preserving cached feed offset/state; returning to a scrolled feed shows controls without jumpTo/reset/refetch. Other tabs, Group/Chat/details/native media/modals retain their existing bars/semantics. Bottom content padding includes the safe-area view inset; hiding bars must not reserve a bar-sized blank strip. Existing posts/card/media identities are preserved; newly exposed lazy cards may perform their existing initial reads, not a wholesale feed refresh. Pull-to-refresh uses the existing authoritative refresh method; pagination remains its existing cursor action.

### Community Search: actual supported scope

Header **Tìm kiếm Cộng đồng** opens a presentation-only hub. **Mọi người và nội dung của bạn** reuses existing `/search` screen, controller/repositories and `GET /api/v1/search`: PEOPLE/GROUPS/ACTIVITIES/CONVERSATIONS only, with existing discoverability, membership and block enforcement. **Tin tuyển thành viên** opens existing Recruitment discovery with keyword/tag/location/from/to/cursor parameters at `GET /api/v1/community/recruitments`. No new backend/API/local feed filtering. Global search field autofocuses; its existing clear action now updates reactively with query text, with the same debounce/controller semantics.

**Ordinary Community post full-text search is not implemented by current contracts.** Do not invent results or search private Group Moments. Search navigation/back retains the original feed widget/offset; typing never refetches the Community feed. Record this unsupported target as a product follow-up, not a completed search feature.

## 9. Motion and back

Implemented shared `appPageTransitions`: detail push/pop120ms opacity fade, no horizontal/vertical slide, zoom or scale. Main tab content switching0ms. Reduced-motion/accessibility renders no visual fade. Preserve Android system/predictive-back and iOS edge commit/cancel behavior, typed route stack and existing deep links. Do not duplicate PageRouteBuilder implementations per feature. Native camera/media picker, dialogs/sheets and useful fullscreen/Hero/content gestures keep appropriate behavior.

## 10. Module rules

| Module | Required presentation policy / preserved contract |
| --- | --- |
| Group | One management hub, true member/owner/role metadata, shared rows, separated danger; existing permission gating and admission unchanged. |
| Chat | Neutral bubble chrome/readable contrast, stable attachment/message keys, Poll cards/activity messages; preserve image caching, scroll, composer and timeline semantics. Presence colors may remain semantic, with labels. |
| Activity/Journey | Compact coherent actions, explicit actual status, schedule guidance; preserve Stops/check-in/early actions/evidence and Poll-to-Action. |
| Task | Clear title/assignee/due/status and authoritative permissions; no workflow/status/evidence changes for design. |
| Poll | Compact question/options/results/closed state; retain first/change vote, anonymous privacy, durable Chat activity and canonical entity. |
| Moments/Albums | Media-first, quiet metadata; preserve IDs, private authorization, upload/playback/gallery and associations. |
| Community/Recruitment | Same existing feed/filter/search/compose/pagination/post/detail/admission flow; monochrome chrome does not alter ranking, visibility, block/report/moderation. |
| Finance | Neutral rows, precise formatted amounts, visible actual offline/stale state; no invented balances, mutation replay, ledger/calculation changes or new queries. |
| Profile/Auth/Settings | Consistent fields/rows with honest disabled/error states; preserve session/cold start, personal data and all existing callbacks. |

## 11. Responsive layout and accessibility

Required acceptance: Android-sized360px and iPhone-sized430px widths, narrow layouts, landscape where supported, light/dark, long Vietnamese labels and text scaling at least1.5×. Use Wrap/Flexible/Expanded and scrollable forms, avoid fixed height text blocks. Use existing SafeArea/Scaffold keyboard resizing; hide keyboard without losing text; bottom navigation must remain safely positioned. Do not disable text scaling to hide overflow.

Normal text contrast target4.5:1, large text3:1; actionable icons/focus3:1. Muted text is for secondary content, not low-contrast disabled-looking primary data. Never place white text on a light primary button in dark mode. Keep semantic labels/icons, tooltips, logical focus and screen-reader names. Test screen reader and native large-text settings physically; widget tests alone do not prove their acceptance.

## 12. Feedback states

- Loading: existing bounded progress/skeleton, preserve valid cached content when existing state supports it; no new polling or endless fake loading.
- Empty: accurate contextual message and an existing permitted action; empty is not the same as failed/unloaded.
- Error: clear Vietnamese text, existing retry, keep programming/auth errors distinguishable according to existing architecture.
- Offline/stale: visible existing notice, preserve only data existing authorization/state permits; never bypass membership revocation or label failure as successful empty data.
- Success: concise confirmation after server success, no false optimistic financial success. Existing Poll action centered confirmation stays unchanged.
- Disabled/read-only: render actual capability flags and disabled callback state; do not invent permission.

## 13. Anti-patterns

No decorative gradients/glass/glow, arbitrary accent palettes, colored statistic tiles, card-in-card stacks, heavy shadows, oversized blank headers, default underline-only forms, unreadable muted text, inconsistent action icons, six tabs or another navigation system. No per-feature socket/polling, extra business read merely for decoration, made-up counters, hidden autofocus/scroll resets or media remounts. Do not use presentation work to refactor business logic.

## 14. Evidence, references and migration status

Implementation inventory, edited paths, screenshot filenames, focused test/build/device evidence and pending screens belong in [Monochrome delivery report](MODERN_MINIMALIST_MONOCHROME_REDESIGN.md). Historical [Global UI polish](GLOBAL_UI_UX_POLISH.md) and [navigation report](GLOBAL_NAVIGATION_UX_REPORT.md) retain their scoped evidence; older purple screenshots are historical, not the new visual target.

Implemented standards: current shared tokens/components, exact five-tab wiring, Home composition and adaptive default forms. Migration is **not globally physically accepted** merely because theme/tests pass. Remaining legacy showcase/static palette helpers, one-off visual layouts, older glyph/weight choices and every-device/full-feature accessibility checks must be explicitly inventoried in the delivery report. No external Linear/Vercel/Notion screenshot is claimed as inspected or copied.

Widget-rendered screenshots use real production widgets with fake APIs; they must be labeled separately from physical phone screenshots. Do not claim real QA data, motion or physical PASS from static widget screenshots. Reference images should show Home light/dark, Community, Messages, Calendar, Profile, Group Info, Activity and a form at realistic sizes. Keep generated artifacts outside source unless intentionally reviewed for inclusion.

## 15. Acceptance checklist for every future UI feature

- [ ] Read this document and current handoff; inspect dirty worktree; preserve prior edits.
- [ ] Use existing tokens/components; no conflicting palette, icon package or navigation system.
- [ ] Keep backend/API/schema/domain/repository/realtime/auth/business contracts unchanged unless separately authorized.
- [ ] Exact five-tab policy; deep link/auth/notification routing and back remain valid.
- [ ] Preserve controller identity, drafts, scroll, media/message keys and lifecycle.
- [ ] No extra reads or image reloads caused solely by switching tabs.
- [ ] Outline/focus/error/disabled/multiline/dropdown/numeric/date-time values remain correct.
- [ ] Honest loading/empty/error/offline/success and existing permission behavior.
- [ ] Readable light/dark, long Vietnamese labels,360/430px widths,1.5× text, keyboard and safe areas.
- [ ] 48px targets, semantic names/tooltips, text/icon contrast, reduced motion; physical assistive checks scoped honestly.
- [ ] Open actual screenshots; record and fix observed overflow/contrast/layout defects.
- [ ] Run affected focused Flutter/widget/navigation tests + analyzer; no unrelated backend suite.
- [ ] Build/install only when needed and disk safe; preserve signing, sessions and QA data.
- [ ] Distinguish automated/rendered/physical evidence and pending migrations in report/handoff.
- [ ] No milestone closure without its evidence; no commit/push/merge without separate authorization.


## Home/Community follow-up standards — 2026-10-28

- `WeDoBrandMark` (`core/ui/widgets/wedo_brand_mark.dart`) is the implemented compact, code-drawn connected-people mark in a circle, using `onSurface`/`surface` (black/white in light mode, inverse in dark). Home places it at32px beside “weDO”; the seven existing Auth screens use it instead of the purple bitmap. This is a simplified monochrome rendition, not a claim that the original raster asset or native launcher icons were replaced. The unused purple source asset remains intact.
- Profile exposes the existing authenticated logout callback through an visible header action with icon, text and tooltip “Đăng xuất”, plus the existing body row. The authentication/session implementation is unchanged. Never log out a physical QA device merely to review Auth styling.
- Home's horizontal group previews have their own `PageStorageKey('home-group-previews')`, separate from vertical Home storage. Preserve both offsets across vertical lazy-list recycling and tab returns.
- Recruitment discovery outlined filters have16px vertical separation. Under400px available width or enlarged text, interest and location stack; wider standard-text layouts use two columns. Preserve existing filter values and REST behavior.
- Chat's image action opens a standard modal sheet with “Chọn từ thư viện” and “Chụp ảnh”. Capture uses the existing native ImagePicker/camera permissions. Both feed the existing4-image/10MiB JPEG/PNG/WebP preview and explicit Send upload path. Cancelling retains the draft; capture never automatically sends. No extra inline icon squeezes the composer.

- Logout is a session capability, independent of Firebase/push availability. Production bootstrap always passes the existing logout callback; optional push-token deactivation remains best-effort inside the existing session flow. Do not hide logout when notifications are unavailable.

- Both Profile logout controls must open the same centered confirmation: “Bạn có chắc muốn đăng xuất không?”, with “Hủy” and “Đăng xuất”. Cancel, outside dismiss or system back keeps the session intact; call the existing session logout only after explicit confirmation. Coalesce repeated taps into one pending dialog/logout.

- Shared JourneyCapture (Task evidence and check-in) must leave16px between camera action Wrap and optional-caption outlined field, with8px wrap run spacing. Floating labels must not touch the preceding action row, including narrow widths and enlarged text. Keep camera/media/draft/submit semantics unchanged for spacing fixes.

- Home order: compact brand bar → Nhóm của bạn → Tài chính → Cần xử lý → Hoạt động sắp tới → Cập nhật gần đây. Keep finance visible. The final three sections use standard ExpansionTile, collapsed initially, with actual returned-item count and expand/collapse affordance. Each has its own PageStorageKey; toggles never request/refetch data, and refresh/tab return retains expansion state. Respect reduced motion. Expanded rows keep original IDs, callbacks and empty states; no financial calculation or query changes.

- RecruitmentComposer:16px separation between visible top-level guidance/fields/actions; full Vietnamese role guidance, expanded dropdowns with bounded selected labels. Preserve current eligibility/visibility/admission APIs and form values.
- Group invitation QR: “Thông tin nhóm → Mã QR & liên kết mời” reuses the existing Owner/Admin invitation-management route. Encode exactly `WeDoLinkConfig.groupInviteUrl(inviteCode)` with case-sensitive opaque code, never group ID or personal-profile URL. Render black QR modules on white with16px quiet padding in both themes, constrained to available width≤240px and a Vietnamese image semantics label. Existing scanner opens the canonical invitation preview/flow; QR does not automatically join, bypass approval, create RSVP or change permissions. Member access is not broadened beyond the existing invite-management API.

- Invite preview must render server-projected viewer state: existing member → “Bạn đã ở trong nhóm này” + “Vào nhóm”; pending applicant → waiting state without another request action; otherwise retain canonical direct-join/request choice. Never infer membership from cached group names, display a request for a known member, or retry admission automatically after a race. Refresh authoritative preview on ALREADY_GROUP_MEMBER/JOIN_REQUEST_ALREADY_PENDING. Keep expired/revoked/banned/auth errors distinct.


### R10 final form correction — 2026-10-29 (implemented; scoped acceptance)

StopComposer keeps16px vertical separation before the coordinator dropdown and before the notes outlined field. Geometry regression uses the actual light/dark theme at320px with1.5× text. Poll→Stop creation exposes an editable outlined “Tên điểm dừng” field, prefilled from the explicitly selected option; preserve the existing source link and centered success dialog. This is an R10 form correction, not a new global visual style. Final candidates installed in place. User QA iPhone confirms “form OK; lịch sử còn”; converted Stop name field present and default-title creation/View accepted. Custom-name persistence has focused automated evidence; no physical custom-name edit was claimed. See `R10_FINAL_ACCEPTANCE.md` for exact scope.
