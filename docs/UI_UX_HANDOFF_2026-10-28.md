# weDO — Bàn giao UI/UX từ Persistent Design System đến Home thu gọn

Ngày: 2026-10-28, Asia/Ho_Chi_Minh. Phạm vi bắt đầu từ yêu cầu **ADDITIONAL REQUIREMENT — PERSISTENT weDO DESIGN SYSTEM**, gồm Monochrome đang thực hiện tại thời điểm đó và các sửa tiếp theo. Không phải báo cáo triển khai lại toàn bộ R1–R10.

## 1. Trạng thái và nguyên tắc tiếp tục

- Repository: `<REPO_ROOT>`.
- Branch: `feat/pre-m19-ui-polish`; HEAD vẫn `cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`.
- Worktree có rất nhiều thay đổi chưa commit từ các milestone trước. Không quy toàn bộ `git diff` cho đợt UI này. Các snapshot/diff theo từng đợt nằm trong `/tmp`, được dẫn ở các báo cáo chi tiết.
- Không stage/commit/push/merge/reset/restore/stash/clean. Giữ stash hiện có, `.stitch/`, `.dev-runtime/`, `.dev-logs/`, các file local được bảo vệ, signing/Firebase và dữ liệu QA.
- Đọc theo thứ tự skill → AGENT_PROJECT_CONTEXT → AGENT_CURRENT_HANDOFF → AGENT_DECISION_LOG; kiểm tra Git trước sửa. Trước mọi UI Flutter phải đọc `docs/DESIGN_SYSTEM.md`.
- R1/R3/R4/R5/R6/R7 COMPLETE; R2/R10 IN PROGRESS; R8/R9 NOT STARTED. Các thay đổi UI này không tự đóng R10 hoặc R9.

## 2. Persistent Design System và Monochrome

- Tạo `docs/DESIGN_SYSTEM.md` làm nguồn chuẩn duy nhất cho UI: nguyên tắc, token light/dark hex thật, typography/Vietnamese fallback, spacing/radius/border, icon, controls, Home, navigation, module rules, accessibility, feedback states, anti-patterns và checklist.
- Cập nhật AGENTS.md bằng hướng dẫn bắt buộc đọc Design System, giữ nguyên startup/safety rules; không chép toàn bộ Design System vào AGENTS.
- Shared `AppTheme` dùng palette đơn sắc: light nền `#FFFFFF`, foreground/primary `#0A0A0A`; dark nền `#0A0A0A`, foreground/primary `#FAFAFA`. Thành phần đọc token thích ứng; success/warning/error vẫn có màu ngữ nghĩa khi cần.
- Chuẩn hóa shared controls/surfaces: input có viền, radius chính12px, neutral buttons/cards/dialogs, bỏ gradient/shadow trang trí. Giữ ảnh/avatar màu thật, media/native modal phù hợp nội dung. Không thêm font/icon package: dùng font nền tảng hỗ trợ tiếng Việt và Material icons hiện có; không giả định đã cài Inter/Geist/Lucide.
- Auth/Profile/Social/Group/Notification và các màn dùng theme được đồng bộ. Không thay validation, quyền hay logic nghiệp vụ để đổi giao diện.
- Giữ đúng5 tab: **Cộng đồng | Trang chủ | Tin nhắn | Lịch | Hồ sơ**. Dùng Community thật hiện có, không tạo feed/socket/controller thứ hai. Giữ Navigator1/typed routes/auth/deep links/retained tabs.
- Chính sách không animation khi đổi tab và detail fade120ms đã có từ công việc Navigation trước mốc báo cáo này; đợt này giữ nguyên, không phải một lần viết lại navigation.

## 3. Home và đường vào Nhóm — trạng thái cuối cùng

- Khôi phục phần **Nhóm của bạn**, **Xem tất cả**, **Tạo hoặc tham gia nhóm** ở vị trí dễ thấy. Tất cả dùng Group List/route/callback hiện có; vẫn vào được tạo nhóm, tham gia bằng mã, lời mời và chi tiết nhóm.
- Một nhóm dùng hàng gọn; nhiều nhóm dùng carousel ngang từ dữ liệu Home hiện có, không tạo nguồn dữ liệu mới.
- Sửa carousel mất/nhảy vị trí khi cuộn Home: đặt `PageStorageKey('home-group-previews')` riêng, tách khỏi cuộn dọc Home. Test giữ cả vị trí ban đầu và vị trí người dùng chọn sau khi phần tử bị lazy recycle.
- Bỏ hai dòng thừa **“Không gian của bạn”** và **“Kết nối với nhóm. Cùng thực hiện những điều quan trọng.”**.
- Thêm logo tròn cạnh chữ **weDO** ở app bar.
- Theo yêu cầu cuối, thứ tự hiện tại là:
  1. Nhóm của bạn.
  2. **Tài chính**, luôn hiển thị ngay dưới nhóm.
  3. **Cần xử lý**.
  4. **Hoạt động sắp tới**.
  5. **Cập nhật gần đây**.
- Ba mục cuối là ExpansionTile, mặc định thu gọn, có số lượng mục thực nhận và mũi tên. Mở/thu độc lập; giữ trạng thái khi refresh/tab return. Tôn trọng reduced motion. Không gọi API khi thu/mở.
- Giữ số tiền chính xác, callback vào số dư, IDs và các trạng thái empty/error/cached/refresh; không đổi công thức tài chính hoặc query.

## 4. Community Search và immersive scroll

- Header Search mở hub đến search hiện có cho People/Groups/Activities/Conversations và màn Recruitment discovery hiện có.
- Bổ sung truyền typed arguments đúng cho route search; sửa clear-query icon cập nhật theo text. Giữ controller/debounce/quyền hiện có.
- **Chưa có ordinary Community-post full-text search theo API hiện tại**. Không tạo kết quả giả hoặc tìm private Moments thay thế.
- Riêng Community feed chính: cuộn xuống thật24px sẽ ẩn cả header/filter và bottom navigation; cuộn lên/top sẽ hiện lại. Collapse chrome150ms, reduced-motion0ms; accessibleNavigation giữ controls hiện.
- Có nút **Hiện điều hướng** để phục hồi. Chuyển tab khôi phục chrome, giữ scroll/feed/card/image state. Programmatic restore không bị coi là thao tác cuộn người dùng.
- Dùng `TabChromeController/Scope/Region` cho state trình bày theo tab, không đổi realtime/store. Giữ pagination, refresh và privacy.

## 5. Recruitment, Chat camera, logo và logout

### Recruitment

Sửa ô Từ khóa tuyển thành viên/Sở thích/Khu vực đè nhau: thêm khoảng cách dọc16px; interest/location xếp dọc khi hẹp hoặc chữ lớn, dùng2 cột khi đủ rộng. Giữ giá trị bộ lọc và REST behavior.

### Chat camera

Nút **Ảnh và camera** mở sheet **Chọn từ thư viện / Chụp ảnh**, tái sử dụng ImagePicker và native permissions hiện có. Cả hai đi qua cùng preview/validation/upload: tối đa4 ảnh, JPEG/PNG/WebP10MiB. Hủy giữ draft; chỉ upload/gửi khi bấm Send, không tự gửi. Không thêm icon làm hẹp composer hoặc socket/API mới.

### Logo

Tạo shared `WeDoBrandMark`: biến thể vector đơn sắc gọn của dấu hiệu connected-people trong vòng tròn. Home dùng32px cạnh weDO;7 trang Auth dùng cùng component, đảo sáng/tối theo token. Không tuyên bố đã thay native launcher icons; bitmap logo tím gốc được giữ, không còn dùng ở các Auth screen đã thay.

### Logout

- Thêm nút có **cả icon và chữ Đăng xuất** trên header Hồ sơ, giữ hàng Đăng xuất bên dưới.
- Sửa nguyên nhân iPhone không hiện logout: bootstrap trước đây truyền null nếu push service không khả dụng. Nay luôn truyền callback logout hiện có; callback đã hỗ trợ optional/best-effort push cleanup. Không thay token/session rules.
- Cả hai entry mở cùng hộp thoại giữa màn hình: **“Bạn có chắc muốn đăng xuất không?”**, nút **Hủy / Đăng xuất**.
- Cancel/back/outside dismiss giữ session. Chỉ confirm mới gọi logout hiện có và về Login. Pending guard chặn nhiều dialog/logout cùng lúc.

## 6. Media + Minh chứng công việc / Chụp check-in

- HuyG đổi Wi-Fi IP từ `.112` sang **<QA_LAN_IP>**, nhưng temporary media relay vẫn allowlist IP cũ. Backend vẫn tới được trong khi signed media GET/PUT bị chặn.
- Xác minh bằng Bonjour `QA iPhone.local`; sửa đúng entry trong `/tmp/wedo-r10-resume-media.py` và restart **chỉ relay** PID25607→95800. Allowlist hiện: Mac<QA_LAN_IP>, Samsung<QA_LAN_IP>, QA iPhone<QA_LAN_IP>. Không mở toàn subnet, không bỏ private-media authorization, không xóa dữ liệu/container/volume.
- Existing JourneyApi đã dùng đúng Moment media access và EvidenceMediaApi đã dùng Task-scoped access, nên không sửa backend/API route vì lỗi IP này.
- Form dùng chung JourneyCapture thiếu khoảng cách giữa camera actions và caption: thêm separator16px + wrap run spacing8px. Sửa cùng lúc Task evidence và Stop check-in, giữ upload/commandUUID/retry/permissions.
- Samsung network: authorized image GET200, presign MOMENT_IMAGE200 và signedPUT200 qua chính kết nối Samsung. Có **1 ảnh PNG QA rất nhỏ + upload intent mới**, chưa gắn Task/check-in; metadata `/tmp/wedo-proof-upload-object.json`. Không xóa/ghi đè media cũ, không đổi Task status hoặc financial data. Không coi network test là physical Flutter camera-submit PASS.

## 7. Bằng chứng kiểm tra

Các đợt dưới là snapshot khác nhau và có overlap: **không cộng thành tổng số test duy nhất**.

| Đợt | Focused Flutter | Analyzer |
| --- | --- | --- |
| Monochrome ban đầu | 605 PASS | sạch |
| Home/Community + camera/branding | 353 PASS | sạch |
| Home copy + sửa logout wiring | 93 PASS | sạch |
| Logout confirmation | 69 PASS | sạch |
| Media/check-in/evidence spacing | 29 PASS | sạch |
| Home finance-first + folds cuối cùng | 180 PASS | sạch2.7s |

Có thêm các subset/screenshot test chồng lặp, không cộng vào các số trên. Actual-widget screenshots dùng widget production + fake API, light/dark,360/430px và chữ lớn; được mở xem. Chúng không phải physical-device evidence. Không chạy lại backend/full mobile suite cho các thay đổi UI nhỏ này.

### Người dùng đã xác nhận trực tiếp

- QA iPhone Monochrome: **“5 tab OK; giữ cuộn OK”**.
- Home/Community: **“Nhóm OK; Search OK; ẩn/hiện OK”**.
- Recruitment/Chat camera: **“Không chồng nữa, chat có chụp ảnh rồi”** — đúng phạm vi layout/entry, không tự suy ra camera gửi ảnh end-to-end.
- Logout trên QA iPhone: **“Có rồi”**, sau đó yêu cầu thêm xác nhận. Chưa có câu xác nhận physical riêng cho modal cancel/confirm; automated tests có kiểm tra.
- Sau media relay fix: **“Ảnh ok.”**, rồi **“Gửi OK”** khi được hỏi retry Gửi xác nhận ở mục Minh chứng/Check-in vừa lỗi. PASS đúng mục QA iPhone đã thử, không tự suy ra cả hai workflow được thử độc lập.
- Home finance-first/thu gọn cuối: **“Được rồi đó.”** Người dùng chấp nhận Home vừa giao; không suy ra toàn bộ native dark/accessibility/permission matrix đã PASS.

### Agent đã quan sát trên Samsung

Group access/route cũ còn hoạt động; header logout có chữ; capture form mới tách camera/caption rõ; signed media network GET/PUT200. Trong đợt Home cuối, Samsung đang ở Camera nên dừng navigation tránh ngắt người dùng: ảnh `/tmp/wedo-home-collapse-samsung.png` là Camera, **không phải** screenshot Home/PASS Home.

## 8. Candidate/runtime cuối — giá trị lần kiểm tra gần nhất

- API Mac: `http://<QA_LAN_IP>:8080`; media `http://<QA_LAN_IP>:9000`. PostgreSQL/Redis/MinIO/backend giữ nguyên dữ liệu/runtime; relay exact-device ở trên.
- Samsung <QA_ANDROID_SERIAL>: Android debug package `com.wedo.mobile`, build11.8s/install-r thành công; APK SHA256 `3c50fd5b7de79b8f1ef132fea9fab14072412af0d0033dd3907799fc86cd19e5`.
- QA iPhone<QA_IPHONE_UDID>: iOS **Profile**, bundle `com.huygiang.wedo`, build45.5s/35.6MB/install-in-place/launch thành công; Runner SHA256 `0ab8d90cece4dbbd2a85512aeeda4aa2c6c9c79913c1e098df158431b639bd1f`.
- Dùng Profile cho iPhone khi mở không có debugger; lỗi iOS14+ debug-direct-launch đã biết từ công việc trước, không lặp lại runner không hỗ trợ.
- Native signing hashes không đổi: pbxproj `ad773f3c…`, Info.plist `cd88a3e2…`. Firebase/certificates/provisioning untouched; không đụng iPhone Secondary iPhone.
- LAN IP/relay allowlist là trạng thái runtime, **phải detect lại khi đổi mạng**, không mặc định mãi dùng IP trên. Cùng tên Wi-Fi không chứng minh IP thiết bị không đổi.

## 9. Phần còn lại và hướng dẫn agent tiếp theo

- Không mở lại chu kỳ điều tra/build chỉ vì user đã PASS. Chỉ sửa khi có yêu cầu mới hoặc defect tái hiện.
- Giữ R2/R10 IN PROGRESS; đối chiếu DoD/evidence hiện có để tiếp tục, không đánh dấu complete vì UI được chấp nhận.
- Chưa có full R9 regression, native assistive/landscape/rare modal/all-module dark/permission matrix. Một số dev showcase/static palette/older icon còn migration; Register còn copy tiếng Anh cũ. Không tuyên bố global migration vật lý100%.
- Task evidence và check-in chưa có hai lần physical submit độc lập được định danh; Samsung full Flutter camera→submit không được claim PASS từ network test. Không thay permission/canSubmit=false của Task hiện hữu để ép kiểm thử.
- Logout modal cancel/confirm physical feedback riêng chưa có; automated route/session tests đã PASS.
- Không phát minh Community post-search API, ranking hoặc R2 parity mới ngoài scope.
- Không reset QA/volumes, cleanup rộng hoặc xóa ảnh test/ảnh cũ tự ý. Một object QA connectivity hiện vẫn chưa gắn entity.

## 10. Tài liệu cần đọc

- `docs/DESIGN_SYSTEM.md`: chuẩn UI bắt buộc.
- `docs/AGENT_CURRENT_HANDOFF.md`: trạng thái động và lịch sử đầy đủ.
- `docs/MODERN_MINIMALIST_MONOCHROME_REDESIGN.md`: inventory, giới hạn, từng đợt UI và bằng chứng.
- `docs/R10_MEDIA_PROOF_RECOVERY.md`: lỗi IP/media, form spacing, kết quả user và phạm vi test.
- `docs/PRODUCT_COMPLETION_ROADMAP.md`: milestone/DoD; không đổi scope để làm milestone pass.
- `docs/GLOBAL_NAVIGATION_UX_REPORT.md`, `docs/GLOBAL_UI_UX_POLISH.md`: công việc nền trước mốc báo cáo, giữ chính sách đang dùng.

Không chứa credential, mật mã thiết bị hay Firebase secret. Không có commit/push/merge trong các đợt được tổng hợp.


## Bổ sung sau báo cáo: form Tìm thành viên và QR nhóm

- Sửa chính RecruitmentComposer: khoảng cách16px giữa hướng dẫn/ô nhập/nút, tên nhóm/Activity dài không tràn; không thay điều kiện đăng tuyển.
- Group Info → **Mã QR & liên kết mời** (Owner/Admin theo API hiện có). QR chứa canonical invite URL, dùng scanner weDO mở lời mời; không tự tham gia hoặc bỏ duyệt. QR đen trên nền trắng cả light/dark. Personal QR không bị thay thế.
-154 focused testsPASS,13 final-copy subsetPASS (overlap), analyzer sạch3.6s; QR từ PNG widget thật đã được macOS Vision decode đúng opaque code. Chưa có physical scan hai máy PASS.
- Đã cài Android debug/iOS Profile mới nhất trên Samsung/QA iPhone. APK9c70b31805…; Runner3b8ec3f975… thay thế hash candidate ở mục8 của báo cáo. API<QA_LAN_IP>/signing/Firebase/QA giữ nguyên. Chi tiết hiện hành trong AGENT_CURRENT_HANDOFF.md. Không commit/push/merge.


## Bổ sung: sửa trạng thái người quét QR đã tham gia nhóm — đã user PASS

Người dùng xác nhận form/QR mở đúng nhóm nhưng POST yêu cầu bị lỗi khi tài khoản đã là thành viên. Reproduce409 ALREADY_GROUP_MEMBER; preview thiếu trạng thái viewer và Flutter dùng thông báo lỗi chung. Thêm2 flags read-only từ backend resolve (`alreadyMember`, `requestPending`), hiển thị thành viên + Vào nhóm hoặc đang chờ duyệt, không hiện yêu cầu trùng. Race409 đọc lại preview một lần, không tự retry mutation. Luật admission/usage/permission không đổi, không migration.

41 backend/162 Flutter focused testsPASS, analyzer sạch; backend PID35706 và cả hai candidate đã cập nhật. APKcac83ccaee…/Runner2766691878…/JAR7be937e40d… thay thế các hash candidate cũ. User Samsung xác nhận **“Có nhé luồng này đã ok rồi”** cho rescan nhóm đã tham gia → đúng thông báo + Vào nhóm → mở đúng nhóm. Không suy ra pending/newcomer/revocation đều physicalPASS; các nhánh đó giữ bằng chứng tự động đúng phạm vi. Chi tiết [GROUP_INVITE_VIEWER_STATE_HOTFIX.md](GROUP_INVITE_VIEWER_STATE_HOTFIX.md). Không commit/push/merge; R10 vẫn IN PROGRESS.
