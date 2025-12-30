#!/bin/bash

# -----------------------------------------------------------
# MODULE: Fail2Ban Core & SSH Protection (Minimal Config)
# File: setup_fail2ban_core.sh
# Mục đích: Cài đặt nền tảng, cấu hình Ban cấp số nhân & Bảo vệ SSH
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# A. Màu sắc & Cấu hình Global
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Whitelist các dải mạng an toàn (Localhost & IP quản trị nếu có)
IGNORE_IPS="127.0.0.1/8 ::1"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# B. Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   sudo -E "$0" "$@"
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# C. CÀI ĐẶT FAIL2BAN & UFW
echo -e "${GREEN}>>> [CORE] Dang cai dat Fail2Ban & UFW...${NC}"

# Đã cài ở file install_caddyserver.sh nên không cần cài lại
# apt-get update -qq
# apt-get install -y fail2ban ufw

# Kiểm tra trạng thái UFW (Tường lửa)
# Fail2Ban cần UFW để thực thi lệnh chặn IP
if ! ufw status | grep -q "Status: active"; then
    echo -e "${YELLOW}Canh bao: UFW chua duoc bat. Fail2Ban can UFW de hoat dong.${NC}"
    echo -e "${YELLOW}Vui long bat UFW sau khi script chay xong (lenh: ufw enable).${NC}"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# D. CẤU HÌNH GLOBAL (MINIMAL & SMART)
# Thay vì copy toàn bộ file jail.conf (dễ lỗi thời), ta tạo file jail.local tối giản.
# File này chứa các cài đặt mặc định áp dụng cho TOÀN BỘ các Jail (SSH, Web...).
echo -e "${GREEN}>>> [CORE] Tao cau hinh Global (Chuan Minimal)...${NC}"

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
# 1. Danh sach IP bo qua (Whitelist)
ignoreip = $IGNORE_IPS

# 2. Hanh dong chan mac dinh
# Su dung UFW de chan IP (Nhe va dong bo voi he thong)
banaction = ufw

# 3. Backend xu ly log
# Ubuntu 20.04/22.04/24.04 dung Systemd Journald, khong phai file log text thuan
backend = systemd

# 4. Thoi gian mac dinh
# Mac dinh ban 1 gio (3600s), tim loi trong 10 phut, sai 3 lan la ban
bantime  = 1h
findtime = 10m
maxretry = 3

# 5. TINH NANG QUAN TRONG: Ban theo cap so nhan (Incremental Ban)
# Hacker thu lai cang nhieu, thoi gian ban cang lau (1h -> 2h -> 4h -> 8h...)
# Giup giam tai cho Server khi bi tan cong dai dang
bantime.increment = true
bantime.factor = 1
bantime.formula = ban.Time * (1<<(ban.Count if ban.Count<20 else 20)) * banFactor
EOF

echo "Da tao file jail.local voi tinh nang Incremental Ban."
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# E. CẤU HÌNH BẢO VỆ SSH
echo -e "${GREEN}>>> [CORE] Dang cau hinh bao ve SSH...${NC}"

# 1. Tự động tìm cổng SSH (Logic chuẩn)
DETECTED_PORT=$(sshd -T 2>/dev/null | grep "^port " | head -n 1 | awk '{print $2}' || true)
if [[ -z "$DETECTED_PORT" ]]; then
    DETECTED_PORT=$(grep -i "^[[:space:]]*Port" /etc/ssh/sshd_config | head -n 1 | awk '{print $2}' || true)
fi
SSH_PORT=${DETECTED_PORT:-22}
echo -e "${YELLOW}Phat hien SSH Port: ${SSH_PORT}${NC}"

# 2. Tạo file cấu hình SSH Jail
# Vi da co [DEFAULT] trong jail.local, file nay gio rat gon nhe
cat > /etc/fail2ban/jail.d/99-ssh-wpsila.conf <<EOF
[sshd]
enabled = true
port    = $SSH_PORT
# logpath van can khai bao du backend=systemd de dam bao tuong thich
logpath = %(sshd_log)s
EOF
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# F. KHỞI ĐỘNG VÀ KIỂM TRA
echo -e "${GREEN}>>> [CORE] Khoi dong Fail2Ban...${NC}"

# Unmask service đề phòng trường hợp bị khóa
systemctl unmask fail2ban > /dev/null 2>&1 || true

if systemctl restart fail2ban; then
    echo -e "${GREEN}SUCCESS: Fail2Ban Core (SSH) da hoat dong!${NC}"
    echo "--------------------------------------------------------"
    echo "Trang thai SSH Jail:"
    fail2ban-client status sshd
    echo "--------------------------------------------------------"
else
    echo -e "${RED}ERROR: Khong the khoi dong Fail2Ban.${NC}"
    echo "Kiem tra loi cu phap:"
    fail2ban-client -d
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------