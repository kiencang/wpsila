#!/bin/bash

# -----------------------------------------------------------
# MODULE: Cài đặt Fail2Ban (Chống Brute-force) - ENHANCED
# File: setup_fail2ban.sh
# Tối ưu: Whitelist Localhost, Auto-check Log path, UFW Check
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# A. Màu sắc & Cấu hình
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Whitelist các dải mạng an toàn (Localhost và mạng nội bộ nếu cần)
IGNORE_IPS="127.0.0.1/8 ::1"
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

apt-get update -qq
apt-get install -y fail2ban ufw

# Kiểm tra UFW có đang chạy không (Fail2Ban cần UFW để ban)
if ! ufw status | grep -q "Status: active"; then
    echo -e "${YELLOW}Canh bao: UFW chua duoc bat. Fail2Ban se khong the Ban IP.${NC}"
    echo -e "${YELLOW}Vui long bat UFW sau khi script chay xong (ufw enable).${NC}"
fi

# Tạo cấu hình local
if [[ ! -f /etc/fail2ban/jail.local ]]; then
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
fi

# Cấu hình Whitelist toàn cục (Tránh tự Ban chính mình)
# Dùng sed để chèn vào phần [DEFAULT] nếu chưa có
if ! grep -q "^ignoreip =" /etc/fail2ban/jail.local; then
    sed -i "/^\[DEFAULT\]/a ignoreip = $IGNORE_IPS" /etc/fail2ban/jail.local
    echo -e "${GREEN}Da them Whitelist cho Localhost.${NC}"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# D. CẤU HÌNH SSH JAIL (SMART DETECT)
echo -e "${GREEN}>>> Dang cau hinh bao ve SSH...${NC}"

# Logic tìm port SSH (Giữ nguyên vì đã rất tốt)
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
# E. CẤU HÌNH WORDPRESS (CADDY)
echo -e "${GREEN}>>> Dang cau hinh bao ve WordPress Login...${NC}"

# 1. Filter Regex (Giữ nguyên logic nhưng thêm comment rõ ràng)
FILTER_FILE="/etc/fail2ban/filter.d/caddy-wp-login.conf"
cat > "$FILTER_FILE" <<EOF
[Definition]
# Regex match JSON logs from Caddy.
# Case 1: IP appeared before URI/Method
# Case 2: IP appeared after URI/Method (Just in case JSON order changes)
failregex = ^.*"remote_ip":"<HOST>",.*"method":"POST",.*"uri":"/wp-login.php".*$
            ^.*"method":"POST",.*"uri":"/wp-login.php",.*"remote_ip":"<HOST>".*$
ignoreregex =
EOF

# 2. Xử lý đường dẫn Log (QUAN TRỌNG)
# Fail2Ban sẽ chết nếu logpath chứa wildcard (*) mà không tìm thấy file nào.
# Ta kiểm tra xem có log file nào tồn tại chưa.
WP_LOG_PATH="/var/www/*/logs/access.log"
HAS_LOGS=$(ls $WP_LOG_PATH 2>/dev/null | head -n 1 || true)

if [[ -z "$HAS_LOGS" ]]; then
    echo -e "${YELLOW}Canh bao: Chua tim thay file log nao tai $WP_LOG_PATH${NC}"
    echo -e "${YELLOW}Jail 'caddy-wp-login' se duoc tao nhung o trang thai DISABLED de tranh loi.${NC}"
    WP_JAIL_ENABLED="false"
else
    WP_JAIL_ENABLED="true"
fi

JAIL_WP_FILE="/etc/fail2ban/jail.d/99-wordpress-caddy.conf"
cat > "$JAIL_WP_FILE" <<EOF
[caddy-wp-login]
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

if [[ "$WP_JAIL_ENABLED" == "false" ]]; then
    echo -e "${GREEN}Sau khi ban tao website, $JAIL_WP_FILE se tu enabled va restart Fail2Ban.${NC}"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# F. KHỞI ĐỘNG VÀ TEST
echo -e "${GREEN}>>> Dang khoi dong lai Fail2Ban...${NC}"

# Unmask service đề phòng trường hợp bị mask trước đó
systemctl unmask fail2ban > /dev/null 2>&1 || true

if systemctl restart fail2ban; then
    if systemctl is-active --quiet fail2ban; then
        echo -e "${GREEN}FAIL2BAN CAI DAT THANH CONG!${NC}"
        echo "--------------------------------------------------------"
        fail2ban-client status
        echo "--------------------------------------------------------"
    else
        echo -e "${RED}Service Start Failed. Logs:${NC}"
        journalctl -u fail2ban -n 20 --no-pager
        exit 1
    fi
else
    echo -e "${RED}Restart Loi. Kiem tra Config:${NC}"
    fail2ban-client -d # Chạy debug để xem lỗi cú pháp
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------