## Tiếp nối: thiết kế giao diện toàn ứng dụng —2026-10-28

Xem [GLOBAL_UI_UX_POLISH.md](GLOBAL_UI_UX_POLISH.md) để chuyển tiếp cho ChatGPT/agent: theme sáng/tối, ô nhập viền12px, màu trạng thái, hub Thông tin nhóm, danh mục46 chủ sở hữu form/widget trong31file, ảnh kiểm tra12 màn bắt buộc,538 focused PASS/analyzer sạch và các giới hạn nghiệm thu. Các thay đổi R10/điều hướng kể dưới đây được giữ nguyên. Bản Android đã cài đè; iOS debug gặp hạn chế khởi chạy trực tiếp nên đã build/cài/mở Profile cùng source/signing (người dùng đã xác nhận “Home OK; giao diện nhóm OK”; không suy rộng mọi màn); trạng thái cuối nằm trong AGENT_CURRENT_HANDOFF.md. Không nhận vơ tất cả file dirty là thay đổi của công việc UI này; không commit/push/merge. R10 chưa hoàn tất.

# weDO — Bàn giao R10 và Global Navigation UX (28/10/2026)

Tài liệu này để gửi sang cuộc chat/agent tiếp theo. Đọc cùng
[handoff hiện tại](AGENT_CURRENT_HANDOFF.md),
[chi tiết R10](R10_ACTIVITY_JOURNEY_CHECKIN_POLL_ACTION_DELIVERY.md) và
[báo cáo navigation](GLOBAL_NAVIGATION_UX_REPORT.md). Worktree thực tế là nguồn
quyết định; không bắt đầu lại hay ghi đè những phần đã làm.

## Trạng thái và an toàn

Repo `<REPO_ROOT>`, branch `feat/pre-m19-ui-polish`,
HEAD `cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`.
R1/R3/R4/R5/R6/R7 COMPLETE; R2/R10 IN PROGRESS; R8/R9 NOT STARTED.
Không đánh dấu R10 COMPLETE chỉ vì code/test/build đã qua.

Toàn bộ worktree đang dirty từ nhiều milestone, có nhiều file untracked hợp lệ;
không được nhận tất cả là thay đổi của một task. Không stage/commit/push/merge,
reset/restore/stash/clean; giữ stash, `.dev-*`, `.stitch`, signing/Firebase,
QA database, Docker volumes và MinIO. Không chạm iPhone Secondary iPhone.
Không paste mật khẩu, token, credential, signed URL hoặc file backup ra chat.

## 1. R10 đã triển khai

- Activity có các Stop con: tên, thời gian dự kiến, vị trí dạng nhãn, người phụ
  trách, thứ tự, chi phí ước tính không tác động ledger, trạng thái và xóa mềm.
  Không tạo RSVP riêng cho Stop. Quyền dựa trên membership/manager/organizer.
- Timeline và tổng quan Activity hiện tiến độ, điểm tiếp theo/đang diễn ra.
  Kế hoạch thời gian không chặn bắt đầu/check-in/hoàn thành sớm. Trạng thái thực
  hiện được người dùng xác nhận, không tự suy ra từ đồng hồ.
- Camera Check-in tạo một Moment chuẩn liên kết Stop, dùng chung media với
  Khoảnh khắc Group/Activity và Album khi chọn thêm; không sao chép ảnh hay tự
  đăng Community. Camera client-declared không chứng minh GPS/đã đến; thời gian
  nhận trên server là dữ liệu đáng tin cậy.
- Viewer dùng chung cho ảnh liên quan: fit-contain, zoom/pan/double-tap/swipe,
  kiểm tra quyền và URL riêng tư. Camera/picker native được tái sử dụng.
- Task evidence: NONE cho việc cũ; DIRECT_COMPLETE hoặc REQUIRE_REVIEW cho việc
  cần ảnh. Người được giao nộp; duyệt bởi người khác có quyền; giữ lịch sử từ
  chối/thay thế, chống duyệt minh chứng cũ sau đổi phân công/membership/nội dung.
  Không bypass minh chứng bằng endpoint DONE cũ; không tự chia sẻ bằng chứng.
- Poll→Task/Stop: chọn phương án và xác nhận rõ, không tự thực thi phương án thắng;
  UUID và khóa option/kind/Activity chống tạo trùng. Giữ snapshot nguồn khi Poll
  bị xóa. Không thêm socket, polling hay artificial aggregate version.
- V19/V20 đã test PostgreSQL độc lập, backup rồi áp dụng QA thành công; dữ liệu
  cũ không đổi tại thời điểm migration. Không sửa các migration đã áp dụng V13–V20.

## 2. Các sửa lỗi/UX trong phiên vừa rồi

### Runtime và media

Mac đổi IP `.109`→`.116`; cập nhật backend/media runtime và build lại app vì URL
cũ không dùng được. Dữ liệu và phiên đăng nhập được giữ, reseeding OFF.
Relay chỉ cho đúng Mac/Samsung/QA iPhone, không mở cả subnet hay bỏ kiểm tra S3.

Lỗi Check-in “Không thể tải media” trên cả hai máy đã tìm đúng nguyên nhân:
JourneyApi kế thừa nhầm CommunityApi.mediaUrl, nên gọi Community cho ID Moment.
Sửa override sang `/moment-media/{id}/access`; Task evidence vẫn qua quyền Task,
Community vẫn qua quyền Community. Ảnh cũ không hỏng/mất, không tạo lại dữ liệu.
User xác nhận **“Ảnh Ok cả hai”**: PASS tải ảnh Check-in trên cặp máy.
Không suy diễn thành PASS toàn bộ camera/zoom/video/privacy.

### Activity và trạng thái lịch trình

Bỏ card “Công cụ hoạt động” trùng và bỏ mount/subscription Thảo luận khỏi route
chi tiết Activity; không xóa module/backend/dữ liệu Discussion. Bốn nút Lịch trình
& Check-in/Công việc/Khoảnh khắc/Bình chọn cùng kiểu viền, sau đó thu gọn54px,
icon18px, chữ13px. Header/capacity wrap để tránh tràn màn hẹp.

Timeline có icon/huy hiệu riêng, điểm đang diễn ra nổi bật, tiến độ hoàn thành;
chi tiết ghi “Dự kiến” và thao tác “Bắt đầu điểm này”/“Đánh dấu hoàn thành”.
Backend vốn cho phép thao tác sớm; bổ sung regression xác nhận, không nới quyền.

User không tìm thấy nút hoàn thành vì Activity QA cũ đã COMPLETED, trong khi Stop
đầu IN_PROGRESS. Đây là khóa lifecycle của parent, không phải khóa theo giờ.
Giữ nguyên Activity cũ/ảnh/history và tạo fixture mới đang mở bằng API chuẩn.
User nói **“Đã được rồi”** sau hướng dẫn: ghi nhận luồng dùng được, chưa đủ bằng
chứng để nhận PASS đầy đủ badge/count realtime trên cả hai máy.

### Poll conversion và phản hồi thành công

Entry hiện có: Chat Poll→**Xem chi tiết**→**Tạo công việc / lịch trình**.
Chọn option/Activity/loại, xác nhận giờ/ngày/vị trí nếu tạo Stop.
Không tự đoán thời gian/địa điểm từ text Poll. Task/Stop có link nguồn.

User đã thực hiện conversion; API độc lập thấy một TASK và một STOP durable.
Ban đầu thiếu phản hồi. Đã thêm, rồi theo yêu cầu đổi từ SnackBar dưới màn hình
thành **AlertDialog ở giữa**, có **Đóng/Xem**, chỉ hiện khi POST thành công.
User chấp nhận hộp thoại giữa. Lỗi/timeout không báo thành công; retry không trùng.

Theo yêu cầu tiếp theo, **Xem sau tạo TASK mở danh sách Công việc của Activity**,
không nhảy vào detail. Link lịch sử nguồn vẫn mở detail; STOP vẫn mở đúng điểm.
Thêm trường **Tên công việc** chỉnh được, mặc định lấy câu hỏi Poll. API Convert
có optional `taskTitle`≤255; TASK không truyền tên thì dùng câu hỏi. Phương án
“Ở chợ/Ở siêu thị” giữ trong mô tả và nguồn. STOP vẫn mang tên option.
Ví dụ Poll “Mua hoa quả” → tên việc “Mua hoa quả”, có thể sửa “Đi mua hoa quả”.
Các việc cũ giữ nguyên, sửa bằng UI Chỉnh sửa; retry không đổi tên target cũ.
**Tên mới và Task-list View còn chờ physical retest**, không nhận PASS từ build.

## 3. Navigation global trong task mới nhất

Navigator1.0/MaterialApp và typed/auth-guarded routes giữ nguyên. Policy chung:
page push/pop fade120ms, không slide ngang/dọc hoặc scale; reduced motion không
có visual animation. Tab root0ms, giữ lazy widget/state/scroll bằng IndexedStack,
không thêm nested Navigator/GlobalKey. Back iOS vẫn qua edge detector Flutter với
slide cố định; Android predictive back dùng public route hooks cho fade/cancel/
commit. Dialog/bottom sheet và camera hệ thống giữ modal animation riêng.

Toàn bộ MaterialPageRoute, gồm Group/Activity/Task/Poll/Chat/Moments/Album/
Community/Recruitment/Moderation/Journey/check-in/auth dùng policy. Hai developer
entrypoints cũng dùng cùng theme. Chi tiết kỹ thuật và giới hạn trong báo cáo nav.

## 4. Bằng chứng kiểm thử — không cộng dồn thành số test toàn suite

- R10 ban đầu:59 backend và360 Flutter focused PASS/analyzer clean.
- Media/Activity UI hotfix:164 Flutter affected PASS/analyzer clean.
- Explicit trạng thái/early action:12 Journey PostgreSQL và98 Flutter focused PASS.
- Dialog conversion:22 Journey focused PASS/analyzer clean.
- Task naming/list refinement:13 Journey PostgreSQL và28 Journey+Task Flutter PASS,
  analyzer clean4.9s; backend đã package/restart, cả hai app đã cài trước task nav.
- Navigation hiện tại:266 focused Flutter PASS15s/analyzer clean3.6s; gồm platform
  geometry, back/predictive cancel+commit, tabs/scroll/disposal, auth/cold-start/
  deep link, Chat image/state và các module ảnh/R10. Không chạy backend suite cho
  navigation; không đổi backend/API/DB/QA trong task nav.
- Logs giữ ngoài repo `/tmp/wedo-r10-*.log`, `/tmp/wedo-nav-*.log`. Không coi test
  harness screenshot hoặc test route-label là actual-device acceptance.

## 5. Runtime và fixture để tiếp tục

Mac en0 `<QA_LAN_IP>`, Samsung `<QA_LAN_IP>`, QA iPhone gần nhất `.112`.
API `http://<QA_LAN_IP>:8080`, media `http://<QA_LAN_IP>:9000`.
Backend PID69223/session46625, `/tmp/wedo-r10-task-title-runtime.log`, local profile,
reseeding OFF. Docker/volumes giữ nguyên, media relay exact-device
`/tmp/wedo-r10-resume-media.py` PID25607/session62113. Phải detect IP lại nếu đổi mạng.

Samsung serial `<QA_ANDROID_SERIAL>`; QA iPhone `<QA_IPHONE_UDID>`.
Không lặp unsupported iOS UI runner. User là người nghiệm thu chính, trước đây
đang dùng Samsung; tránh bấm đồng thời. Không cần user gửi credential.

Nhóm **R6 QA Recruitment 27-10**:
- Activity cũ **R10 QA Đi Ba Vì 28-10** đã COMPLETED, có ảnh Check-in user đã xác
  nhận. Không mở lại/reset/xóa để làm lại test.
- Activity mới **R10 QA Lịch trình mở 28-10**, ba Stop tương tự; giữ parent mở khi
  nghiệm thu child. Poll **R10 QA Chốt lịch trình 28-10** liên kết Activity này,
  đã có một Task và một Stop conversion. Metadata `/tmp/wedo-r10-open-fixture.json`
  mode0600. ID cụ thể lấy từ metadata/API, không đoán.
- Original Task **R10 QA Mua rau** REQUIRE_REVIEW nằm Activity cũ; chứng cứ/review
  physical chưa hoàn tất. Nếu cần fixture mới để test, tạo bằng API đúng quyền,
  không sửa SQL/status hoặc clone ảnh cá nhân. Cần scoped acceptance tiếp theo.

## 6. Các bước còn lại

1. Ghi nhận build/install mới nhất và physical nav trên Samsung/QA iPhone; kiểm tra fade,
   back iOS commit/cancel, tab scroll, Chat ảnh, các đường trong report nav.
2. User xác nhận Task title chỉnh được, giữ option trong mô tả và View vào list.
3. Hoàn tất Task ảnh→review→DONE/history, Poll nguồn/navigation/idempotency và
   paired state/reconnect/privacy còn thiếu đúng phạm vi R10.
4. Cập nhật handoff/roadmap bằng bằng chứng thật; không đánh dấu COMPLETE từ test.
5. Giữ R2 ongoing/R8–R9 not started; R9 phải test policy navigation global này.

Không commit/push/merge; không tự triển khai milestone khác. Candidate nav và kết
quả physical mới nhất được bổ sung vào handoff/report trước khi kết thúc phiên.

## 7. Chốt candidate và nghiệm thu navigation

Cả hai máy đã cài đè/mở thành công: Android17.5s, iOS46.0s.
APK255601c41099576e867029e22b08e6bf7b743c15b5cfc053fafc380bfde5b4c2;
Runnerbf018e8a83f02a43fca7eb71dc9ce4c93d9a771c9444591f6534fde6ca50fc19.
Signing/Firebase/session giữ nguyên, backend UP và Samsung để lại Home.

User QA iPhone xác nhận **“fade OK; back OK; giữ cuộn OK”** cho checklist core đã hỏi.
Samsung đã thao tác thật các đường Group→Activity→Journey→Stop/system-back;
Chat→Poll detail/back; Community→Post/back; Moments→Album→fullscreen logo/back.
Cuộn Home rồi đổi Groups/Home giữ nguyên bounds các mục nhìn thấy.
Ảnh Stop và logo fullscreen hiển thị trên bản mới. Ảnh bằng chứng ở
`/tmp/wedo-nav-stop.png`, `/tmp/wedo-nav-gallery.png`; không coi screenshot tĩnh là
đo animation120ms hay coi đó là test gửi tin/ảnh hai chiều.

Chưa lặp riêng trên bản nav: paired gửi text/ảnh cũ, đầy đủ module trên iPhone,
reduced-motion setting trên máy thật và predictive gesture Android mới. Các ca
này còn checklist R9; chưa có lỗi navigation blocking được tái hiện. R10 vẫn
IN PROGRESS, task naming/list mới nhất và evidence/review/cross-device còn phải
được ghi nhận theo bằng chứng thật. Không tự nhận user đã PASS những ca chưa hỏi.

Agent tiếp theo không cần rebuild/rerun suite nếu chỉ tiếp tục nghiệm thu và
runtime/IP không đổi. Nếu có bug mới: tái hiện nhỏ nhất→sửa nhỏ→test liên quan.
Đọc `GLOBAL_NAVIGATION_UX_REPORT.md` và handoff động trước khi thao tác.

Tất cả kiểm tra Samsung ở task navigation là mở/xem/back/đổi tab, không gửi tin,
đổi phiếu, thả cảm xúc, đăng ảnh hay giao dịch. Việc mở Chat có thể cập nhật trạng
thái đã đọc theo hành vi chuẩn; không reset/chỉnh fixture. Báo cáo không nhận mọi
thay đổi dirty hiện có là của task navigation. Các file runtime/backup/credential
ngoài repo chỉ dùng tại Mac hiện tại; agent khác phải kiểm tra tồn tại, không in
nội dung bí mật khi phục hồi runtime.
