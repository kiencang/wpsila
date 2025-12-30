#!/bin/bash

# -----------------------------------------------------------
# MODULE: Fail2Ban WordPress Protection (Add-on)
# File: setup_fail2ban_wp.sh
# Mục đích: Bảo vệ wp-login.php (Tùy chọn Bật/Tắt theo Cloudflare)
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# A. CẤU HÌNH NGƯỜI DÙNG
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# [QUAN TRONG] Ban co dung Cloudflare Proxy (Dam may vang) khong?
# true  = Co dung -> Script se TAT Jail WordPress (De Cloudflare WAF lo), chi bao ve SSH.
# false = Khong dung (IP truc tiep) -> Script se BAT Jail WordPress (bao ve bang UFW).
USING_CLOUDFLARE_PROXY="false"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# B. Kiểm tra quyền root & Dependency
if [[ $EUID -ne 0 ]]; then
   sudo -E "$0" "$@"
   exit $?
fi

# Kiểm tra xem Core đã cài chưa (Fail2Ban Client phải tồn tại)
if ! command -v fail2ban-client &> /dev/null; then
    echo -e "${RED}Loi: Fail2Ban chua duoc cai dat.${NC}"
    echo -e "${YELLOW}Vui long chay script 'setup_fail2ban_core.sh' truoc.${NC}"
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# C. CẤU HÌNH FILTER (Luôn tạo)
echo -e "${GREEN}>>> [WP-ADDON] Dang cau hinh bao ve WordPress...${NC}"
echo -e "${YELLOW}>>> Mode Cloudflare Proxy: $USING_CLOUDFLARE_PROXY${NC}"

# Tạo Filter nhận diện log JSON của Caddy
FILTER_FILE="/etc/fail2ban/filter.d/caddy-wp-login.conf"

cat > "$FILTER_FILE" <<EOF
[Definition]
# Regex bat JSON log cua Caddy v2
failregex = ^.*"remote_ip":"<HOST>",.*"method":"POST",.*"uri":"/wp-login.php".*$
            ^.*"method":"POST",.*"uri":"/wp-login.php",.*"remote_ip":"<HOST>".*$
ignoreregex =
EOF
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# D. XỬ LÝ LOGIC JAIL (Dựa trên Cloudflare & Log)
JAIL_WP_FILE="/etc/fail2ban/jail.d/99-wordpress-caddy.conf"
WP_LOG_PATH="/var/www/*/logs/access.log"
WP_JAIL_ENABLED="false"
MSG_REASON=""

if [[ "$USING_CLOUDFLARE_PROXY" == "true" ]]; then
    # Trường hợp 1: Dùng Cloudflare -> Tắt Jail WP
    WP_JAIL_ENABLED="false"
    MSG_REASON="Disabled (do Cloudflare Mode Active)"
    echo -e "${YELLOW}-> Cloudflare Mode: Jail WP se duoc TAT de tranh conflict IP.${NC}"
else
    # Trường hợp 2: Không dùng Cloudflare -> Kiểm tra Log
    HAS_LOGS=$(ls $WP_LOG_PATH 2>/dev/null | head -n 1 || true)
    
    if [[ -z "$HAS_LOGS" ]]; then
        WP_JAIL_ENABLED="false"
        MSG_REASON="Disabled (No log files found yet)"
        echo -e "${YELLOW}-> Chua co website nao (Log 404). Jail WP se tam tat.${NC}"
    else
        WP_JAIL_ENABLED="true"
        MSG_REASON="Enabled (Direct IP Mode)"
        echo -e "${GREEN}-> Direct IP Mode: Jail WP duoc BAT.${NC}"
    fi
fi

# Ghi file cấu hình Jail
# Luu y: Khong can khai bao 'banaction', 'backend', 'ignoreip' vi da ke thua tu Core
cat > "$JAIL_WP_FILE" <<EOF
[caddy-wp-login]
# Trang thai: $MSG_REASON
enabled = $WP_JAIL_ENABLED
port    = 80,443
filter  = caddy-wp-login
logpath = $WP_LOG_PATH
# Cac thong so khac se tu dong lay tu jail.local (Core)
EOF
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# E. RELOAD FAIL2BAN
echo -e "${GREEN}>>> Reloading Fail2Ban...${NC}"

systemctl reload fail2ban

echo -e "Trang thai hien tai:"
echo -e "SSH Jail: [Giữ nguyên]"
if [[ "$WP_JAIL_ENABLED" == "true" ]]; then
     echo -e "WP Jail:  ${GREEN}[ON]${NC}"
else
     echo -e "WP Jail:  ${YELLOW}[OFF]${NC} ($MSG_REASON)"
fi
echo "--------------------------------------------------------"
# -------------------------------------------------------------------------------------------------------------------------------