# Attack–Defense CTF Demo (ForcAD + blitz-ad)

Bộ demo Attack/Defense CTF chạy trên một máy bằng Docker, phục vụ môn **An ninh mạng (ANM)**.

- 2 dịch vụ cố ý chứa lỗ hổng: `bouquets` (Python/Flask) và `otkritki` (Go + MySQL).
- Hệ thống chấm điểm tự động **ForcAD** (scoreboard, checker, điểm Attack/Defense/SLA).
- 2 đội tấn công & phòng thủ lẫn nhau trên mạng docker dùng chung.

## Bắt đầu nhanh

**Cách nhanh nhất — một lệnh** (cần Docker Desktop đang chạy + Python 3):
```bash
./setup.sh
```
Sau đó mở http://localhost:8080. Muốn làm thủ công từng bước thì theo bên dưới.


```bash
# 1) Bật dịch vụ cho 2 đội
cd range && ./up.sh

# 2) Khởi tạo & chạy ForcAD
cd ../forcad
python3 -m venv .venv && .venv/bin/pip install click PyYAML 'pydantic>=2.5,<3'
.venv/bin/python control.py setup        # ghi lại mật khẩu admin in ra
.venv/bin/python control.py start -w 2

# 3) Mở scoreboard
open http://localhost:8080
```

👉 **Hướng dẫn chi tiết (tấn công, phòng thủ, nộp flag, xử lý sự cố): [HUONG_DAN.md](HUONG_DAN.md)**

## Cấu trúc

| Thư mục | Nội dung |
|---|---|
| `blitz-ad/` | Source 2 service + checker + writeup lỗ hổng (`sploits/`) |
| `forcad/` | Hệ thống chấm điểm ForcAD (đã cấu hình: 2 đội, 2 task) |
| `range/` | Stack dịch vụ mỗi đội + gateway nginx + script `up.sh`/`down.sh` |

## Nguồn (upstream)

- Dịch vụ & checker: [dtlhub/blitz-ad-14-11-2024](https://github.com/dtlhub/blitz-ad-14-11-2024)
- Checksystem: [pomo-mondreganto/ForcAD](https://github.com/pomo-mondreganto/ForcAD)

Phần tích hợp (mạng `adrange`, gateway mỗi đội, cấu hình `config.yml`, script) được thêm cho mục đích học tập. Giữ nguyên license gốc của mỗi dự án.
