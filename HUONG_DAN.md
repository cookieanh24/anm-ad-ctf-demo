# Hướng dẫn dựng & chơi Attack–Defense (ForcAD + blitz-ad)

Bộ demo **Attack/Defense (A/D) CTF** hoàn chỉnh chạy trên 1 máy bằng Docker:

- **2 dịch vụ có lỗ hổng** (từ giải `blitz-ad-14-11-2024`): `bouquets` (Python/Flask) và `otkritki` (Go + MySQL).
- **Hệ thống chấm điểm ForcAD**: tự động cắm flag, kiểm tra service mỗi vòng (round), tính điểm Attack/Defense/SLA, hiển thị scoreboard.
- **2 đội** (`team1`, `team2`), mỗi đội có bản service riêng để tấn công/phòng thủ lẫn nhau.

> ⚠️ Chỉ dùng trong môi trường học tập/lab của bạn. Đây là các service **cố ý chứa lỗ hổng**.

---

## 0. Yêu cầu

- Docker Desktop đang chạy (đã test với Docker 27 / Compose v2).
- Python 3 trên máy (để chạy `control.py` của ForcAD).
- RAM cho Docker nên ≥ 6 GB (2 đội × MySQL + stack ForcAD).

---

## 1. Kiến trúc

```
                      ┌──────────────────────── ForcAD ───────────────────────┐
                      │  postgres · redis · rabbitmq · celery(checker workers) │
                      │  ticker · client-api · admin-api · http-receiver        │
                      │  nginx  →  Scoreboard :8080                             │
                      └───────────────┬────────────────────────────────────────┘
                                      │  (mạng docker dùng chung: adrange)
              ┌───────────────────────┴───────────────────────┐
              │                                                │
     ┌────────┴─────────┐                            ┌─────────┴────────┐
     │   gateway team1  │ alias = team1              │  gateway team2   │ alias = team2
     │   (nginx stream) │                            │  (nginx stream)  │
     │  :5000  :8083    │                            │  :5000  :8083    │
     └───┬─────────┬────┘                            └───┬─────────┬────┘
         │         │                                     │         │
   bouquets   otkritki(backend+db)              bouquets   otkritki(backend+db)
```

- Checker của ForcAD (chạy trong các container `celery`) gọi tới đội qua tên `team1` / `team2` trên mạng `adrange`.
- Mỗi đội có **1 gateway nginx** gom 2 cổng dịch vụ (`5000` cho bouquets, `8083` cho otkritki) về chung một "IP" (chính là alias của đội) — đúng mô hình A/D: 1 đội = 1 IP chạy tất cả service.

Thư mục:

```
ad-demo/
├── blitz-ad/           # Source 2 service + checker + writeup lỗ hổng (sploits/)
├── forcad/             # Hệ thống chấm điểm ForcAD (đã cấu hình sẵn)
│   ├── config.yml      # Cấu hình giải: 2 đội, 2 task, round 30s
│   └── checkers/       # Checker đã nhúng (bouquets/, otkritki/)
└── range/              # Stack dịch vụ cho từng đội + gateway
    ├── docker-compose.team.yml
    ├── nginx.conf
    ├── up.sh           # Bật cả 2 đội
    └── down.sh         # Tắt cả 2 đội
```

---

## 2. Khởi động (lần đầu)

### Bước 1 — Bật dịch vụ cho 2 đội

```bash
cd ad-demo/range
./up.sh
```

Kết quả: mỗi đội có 4 container (`bouquets`, `db`, `backend`, `gateway`) trên mạng `adrange`.

### Bước 2 — Khởi tạo & chạy ForcAD

```bash
cd ad-demo/forcad
python3 -m venv .venv            # chỉ cần lần đầu
.venv/bin/pip install click PyYAML 'pydantic>=2.5,<3'

.venv/bin/python control.py setup      # sinh mật khẩu admin + file cấu hình
.venv/bin/python control.py start -w 2  # build & chạy (lần đầu mất vài phút)
```

- Lệnh `setup` in ra dòng: `Created new admin credentials: forcad:XXXXXXXX` → **ghi lại mật khẩu admin này**.
- `-w 2` = 2 worker checker chạy song song.

### Bước 3 — Mở scoreboard

- Scoreboard: <http://localhost:8080/>
- Trang admin: <http://localhost:8080/admin/> (user `forcad` + mật khẩu ở Bước 2)
- Giám sát checker (Flower): <http://localhost:8080/flower/>

Sau khoảng 1–2 vòng, scoreboard sẽ hiển thị trạng thái service (UP/DOWN) và điểm của 2 đội.

---

## 3. Lấy token để nộp flag

Mỗi đội có 1 **token bí mật** để nộp flag:

```bash
cd ad-demo/forcad
.venv/bin/python control.py print_tokens
```

---

## 4. Cách tấn công (Attack)

Mục tiêu: khai thác lỗ hổng trên service của **đội đối phương**, lấy **flag** mà checker vừa cắm, rồi **nộp** cho ForcAD để ăn điểm Attack.

### 4.1 Nộp flag

```bash
curl -X PUT http://localhost:8080/flags \
  -H "X-Team-Token: <TOKEN_CUA_DOI_BAN>" \
  -H "Content-Type: application/json" \
  -d '["FLAG1DÀI31KÝTỰ=", "FLAG2..."]'
```

Body là **mảng JSON** các flag (tối đa 100). Flag hợp lệ trong `flag_lifetime` = 5 vòng.

### 4.2 Các lỗ hổng để khai thác (writeup đầy đủ trong `blitz-ad/sploits/`)

**bouquets** (`blitz-ad/sploits/bouquets/WRITEUPS.md`):
1. **SQL Injection** — tham số `field` ở `/bouquet/filter` ghép thẳng vào câu SQL.
2. **IDOR** — `/bouquet/given?user_from=<nạn_nhân>&user_to=default` xem hoa chưa gửi của người khác.
3. **Lỗi logic NaN/phân số** — gửi `periods=nan` để qua kiểm tra thanh toán.

**otkritki** (`blitz-ad/sploits/otrkitki/*/README.md`):
4. **Insecure Login** — đăng nhập chỉ cần đúng username, không cần đúng mật khẩu.
5. **Backdoor RCE** — route ẩn `/api/nothingtoseehere?cmd=...` với header `Host: nothing.to.see.here`.
6. **So sánh username không chặt** — `strings.Contains` cho phép user tên ngắn xem thiệp của user tên dài hơn.

> Trong giải thật, checker cắm flag vào dữ liệu của service (ví dụ nội dung thiệp, mô tả bó hoa). Dùng lỗ hổng tương ứng để đọc được dữ liệu đó.

### 4.3 Nhắm đúng đội

Từ máy host, các đội **không** publish cổng ra ngoài (chỉ nội bộ mạng `adrange`). Để tấn công thủ công, chạy công cụ trong một container gắn vào `adrange`:

```bash
# ví dụ: gọi tới bouquets của team2
docker run --rm -it --network adrange curlimages/curl \
  curl -s http://team2:5000/login

# gọi tới otkritki của team2
docker run --rm -it --network adrange curlimages/curl \
  curl -s http://team2:8083/api/...
```

Hoặc tạm publish cổng của một đội ra host để test bằng trình duyệt (xem mục 7).

---

## 5. Cách phòng thủ (Defense)

Mục tiêu: **vá lỗ hổng** trong service của đội mình mà vẫn giữ service **UP** (checker vẫn PUT/GET flag thành công), nếu không sẽ mất điểm SLA.

Cách vá cho từng lỗ hổng có sẵn trong các file `README.md` trong `blitz-ad/sploits/`. Tóm tắt:

| Lỗ hổng | Vá |
|---|---|
| SQLi (`field`) | Whitelist tên cột, không nối chuỗi |
| IDOR | Ép `user_to = current_user.username` |
| NaN logic | Chặn `math.isnan()` và `parts < 1` |
| Insecure login | So sánh `user.Password == LoginRequest.Password` |
| Backdoor | Xóa route `nothingtoseehere` |
| So sánh lỏng | Dùng `==` thay cho `strings.Contains` |

Quy trình vá cho một đội (ví dụ team1):

```bash
# 1) Sửa code trong blitz-ad/services/... (bouquets hoặc otkritki)
# 2) Build lại riêng đội đó:
cd ad-demo/range
TEAM=team1 docker compose -p team1 -f docker-compose.team.yml up -d --build
```

Sau đó thử lại đòn tấn công — nếu đã chặn, service vẫn UP trên scoreboard là bạn vá đúng.

> Lưu ý: 2 đội dùng chung thư mục source `blitz-ad/`. Nếu muốn mỗi đội vá độc lập, nhân bản thư mục source cho từng đội rồi chỉnh `build:` trong compose trỏ về bản riêng.

---

## 6. Lệnh quản lý thường dùng

```bash
# --- Dịch vụ các đội ---
cd ad-demo/range
./up.sh                 # bật cả 2 đội
./down.sh               # tắt cả 2 đội
TEAM=team1 docker compose -p team1 -f docker-compose.team.yml logs -f   # xem log 1 đội

# --- ForcAD ---
cd ad-demo/forcad
.venv/bin/python control.py print_tokens   # in token các đội
.venv/bin/python control.py pause           # tạm dừng game
.venv/bin/python control.py resume          # tiếp tục
.venv/bin/python control.py reset           # reset điểm/round
docker compose -f docker-compose-base.yml logs -f celery   # log checker
docker compose -f docker-compose-base.yml down             # tắt ForcAD
```

---

## 7. (Tuỳ chọn) Mở cổng một đội ra host để test bằng trình duyệt

Thêm `ports` vào gateway khi bật đội:

```bash
cd ad-demo/range
TEAM=team1 docker compose -p team1 -f docker-compose.team.yml \
  run -d --service-ports gateway
```

Hoặc sửa `docker-compose.team.yml` thêm `ports: ["5000:5000","8083:8083"]` cho service `gateway` (chú ý tránh trùng cổng giữa 2 đội và với các app khác trên máy — cổng 5000 trên macOS hay bị AirPlay chiếm).

---

## 8. Cấu hình giải (`forcad/config.yml`)

- `round_time: 30` — mỗi vòng 30 giây (có thể tăng để dễ quan sát).
- `flag_lifetime: 5` — flag sống 5 vòng.
- `teams` — danh sách đội (mỗi `ip` là một alias docker trên `adrange`).
- `tasks` — 2 service + đường dẫn checker.

Sau khi đổi `config.yml`, chạy lại `control.py setup` rồi `control.py start`.

---

## 9. Sự cố thường gặp

- **Scoreboard báo service DOWN hết**: kiểm tra đội đã chạy (`docker ps`), và checker có tới được đội không:
  `docker run --rm --network adrange curlimages/curl curl -s http://team1:5000/login`
- **Checker lỗi (CHECKER ERROR màu xám)**: xem log `celery` để biết lỗi Python.
- **Cổng 5000 bận trên macOS**: do AirPlay Receiver — tắt trong System Settings → General → AirDrop & Handoff, hoặc đổi cổng publish.
- **Postgres báo `port 5432 already in use`**: máy đã có PostgreSQL cài sẵn. ForcAD không cần publish postgres ra host (các service gọi nội bộ qua `postgres:5432`), nên compose đã bỏ mapping cổng này.
- **`control.py start` rất lâu / treo khi tải image**: mạng tới Docker Hub/ghcr có thể bị bóp. Kiểm tra bằng `docker pull hello-world`. Nếu dùng chế độ `--fast` mà treo ở `ghcr.io/.../forcad_base`, hãy bỏ `--fast` để build từ `python:3.11` (Docker Hub).
- **Checker báo GET CHECK_FAILED / non-hexadecimal**: `checker_type` phải là `hackerdom_pfr` (không phải `hackerdom`) để ForcAD trả đúng `flag_id` private cho checker. Sửa trong `config.yml` rồi `control.py reset` + `start`.
