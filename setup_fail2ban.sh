#!/bin/bash

# -----------------------------------------------------------
# MODULE: Cài đặt Fail2Ban (Chống Brute-force) - FINAL PRO
# File: setup_fail2ban.sh
# Tối ưu: Tự động xử lý logic Cloudflare Proxy vs Direct IP
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# A. CẤU HÌNH NGƯỜI DÙNG (USER CONFIG)
# -------------------------------------------------------------------------------------------------------------------------------

# [QUAN TRONG] Ban co dung Cloudflare Proxy (Dam may vang) khong?
# true  = Co dung -> Script se TAT Jail WordPress (De Cloudflare WAF lo), chi bao ve SSH.
# false = Khong dung (IP truc tiep) -> Script se BAT Jail WordPress (bao ve bang UFW).
USING_CLOUDFLARE_PROXY="true"

# Whitelist các dải mạng an toàn (Localhost và mạng nội bộ)
IGNORE_IPS="127.0.0.1/8 ::1"

# Màu sắc
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# B. Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Loi: Script nay can chay duoi quyen Root.${NC}"
   exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# C. CÀI ĐẶT CƠ BẢN
echo -e "${GREEN}>>> Dang cai dat Fail2Ban & Kiem tra moi truong...${NC}"
echo -e "${YELLOW}>>> Che do hoat dong: Cloudflare Proxy = $USING_CLOUDFLARE_PROXY${NC}"

apt-get update -qq
apt-get install -y fail2ban ufw

# Kiểm tra UFW
if ! ufw status | grep -q "Status: active"; then
    echo -e "${YELLOW}Canh bao: UFW chua duoc bat. Fail2Ban se khong the Ban IP.${NC}"
    echo -e "${YELLOW}Vui long bat UFW sau khi script chay xong (ufw enable).${NC}"
fi

# Tạo cấu hình local
if [[ ! -f /etc/fail2ban/jail.local ]]; then
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
fi

# Cấu hình Whitelist toàn cục
if ! grep -q "^ignoreip =" /etc/fail2ban/jail.local; then
    sed -i "/^\[DEFAULT\]/a ignoreip = $IGNORE_IPS" /etc/fail2ban/jail.local
    echo -e "${GREEN}Da them Whitelist cho Localhost.${NC}"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# D. CẤU HÌNH SSH JAIL (LUÔN BẬT)
# SSH không đi qua Cloudflare Proxy nên luôn cần bảo vệ
echo -e "${GREEN}>>> Dang cau hinh bao ve SSH...${NC}"

DETECTED_PORT=$(sshd -T 2>/dev/null | grep "^port " | head -n 1 | awk '{print $2}' || true)
if [[ -z "$DETECTED_PORT" ]]; then
    DETECTED_PORT=$(grep -i "^[[:space:]]*Port" /etc/ssh/sshd_config | head -n 1 | awk '{print $2}' || true)
fi
SSH_PORT=${DETECTED_PORT:-22}
echo -e "${YELLOW}SSH Port Detected: ${SSH_PORT}${NC}"

cat > /etc/fail2ban/jail.d/99-ssh-wpsila.conf <<EOF
[sshd]
enabled = true
port    = $SSH_PORT
logpath = %(sshd_log)s
backend = systemd
maxretry = 3
findtime = 600
bantime  = 3600
banaction = ufw
ignoreip = $IGNORE_IPS
EOF
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# E. CẤU HÌNH WORDPRESS (TÙY CHỌN THEO CLOUDFLARE)
echo -e "${GREEN}>>> Dang cau hinh bao ve WordPress Login...${NC}"

# 1. Tạo Filter (Luôn tạo để sẵn sàng)
FILTER_FILE="/etc/fail2ban/filter.d/caddy-wp-login.conf"
cat > "$FILTER_FILE" <<EOF
[Definition]
failregex = ^.*"remote_ip":"<HOST>",.*"method":"POST",.*"uri":"/wp-login.php".*$
            ^.*"method":"POST",.*"uri":"/wp-login.php",.*"remote_ip":"<HOST>".*$
ignoreregex =
EOF

# 2. Xử lý Logic Bật/Tắt Jail
JAIL_WP_FILE="/etc/fail2ban/jail.d/99-wordpress-caddy.conf"
WP_LOG_PATH="/var/www/*/logs/access.log"

# Mặc định tắt
WP_JAIL_ENABLED="false"
MSG_REASON=""

if [[ "$USING_CLOUDFLARE_PROXY" == "true" ]]; then
    # Trường hợp 1: Dùng Cloudflare -> Tắt Jail WP
    WP_JAIL_ENABLED="false"
    MSG_REASON="Disabled (Cloudflare Mode Active)"
    echo -e "${YELLOW}Phat hien Cloudflare Mode: Jail WP se duoc TAT de tranh conflict IP.${NC}"
else
    # Trường hợp 2: Không dùng Cloudflare -> Kiểm tra Log để Bật
    HAS_LOGS=$(ls $WP_LOG_PATH 2>/dev/null | head -n 1 || true)
    
    if [[ -z "$HAS_LOGS" ]]; then
        WP_JAIL_ENABLED="false"
        MSG_REASON="Disabled (No log files found yet)"
        echo -e "${YELLOW}Khong tim thay log web. Jail WP se tam tat cho den khi co website.${NC}"
    else
        WP_JAIL_ENABLED="true"
        MSG_REASON="Enabled (Direct IP Mode)"
        echo -e "${GREEN}Da tim thay log. Kich hoat bao ve WordPress.${NC}"
    fi
fi

# 3. Ghi file cấu hình Jail
cat > "$JAIL_WP_FILE" <<EOF
[caddy-wp-login]
# Trang thai: $MSG_REASON
enabled = $WP_JAIL_ENABLED
port    = 80,443
filter  = caddy-wp-login
logpath = $WP_LOG_PATH
backend = auto
maxretry = 5
findtime = 300
bantime  = 86400
banaction = ufw
ignoreip = $IGNORE_IPS
EOF
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# F. KHỞI ĐỘNG VÀ TEST
echo -e "${GREEN}>>> Dang khoi dong lai Fail2Ban...${NC}"

systemctl unmask fail2ban > /dev/null 2>&1 || true

if systemctl restart fail2ban; then
    if systemctl is-active --quiet fail2ban; then
        echo -e "${GREEN}FAIL2BAN CAI DAT THANH CONG!${NC}"
        echo "--------------------------------------------------------"
        echo "Trang thai hien tai:"
        fail2ban-client status
        echo "--------------------------------------------------------"
        echo -e "Che do Cloudflare: ${YELLOW}$USING_CLOUDFLARE_PROXY${NC}"
        echo -e "SSH Protection:    ${GREEN}ACTIVE${NC}"
        if [[ "$WP_JAIL_ENABLED" == "true" ]]; then
             echo -e "WP Protection:     ${GREEN}ACTIVE${NC}"
        else
             echo -e "WP Protection:     ${YELLOW}DISABLED${NC} ($MSG_REASON)"
        fi
        echo "--------------------------------------------------------"
    else
        echo -e "${RED}Service Start Failed. Logs:${NC}"
        journalctl -u fail2ban -n 20 --no-pager
        exit 1
    fi
else
    echo -e "${RED}Restart Loi. Kiem tra Config:${NC}"
    fail2ban-client -d
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------