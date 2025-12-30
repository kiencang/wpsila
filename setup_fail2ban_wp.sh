#!/bin/bash

# -----------------------------------------------------------
# MODULE: Fail2Ban WordPress Protection (Final Caddy Version)
# File: setup_fail2ban_wp.sh
# -----------------------------------------------------------

set -euo pipefail

# A. CẤU HÌNH NGƯỜI DÙNG
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# [QUAN TRONG] Cau hinh Cloudflare
# true  = Dung Cloudflare (Script se TAT Jail WP de tranh ban nham IP Cloudflare)
# false = IP Truc tiep (Script se BAT Jail WP)
USING_CLOUDFLARE_PROXY="false"

# B. KIỂM TRA MÔI TRƯỜNG
if [[ $EUID -ne 0 ]]; then
   sudo -E "$0" "$@"
   exit $?
fi

if ! command -v fail2ban-client &> /dev/null; then
    echo -e "${RED}Loi: Fail2Ban chua duoc cai dat. Hay cai Core truoc.${NC}"
    exit 1
fi

# C. CẤU HÌNH FILTER (REGEX CHUẨN CADDY)
echo -e "${GREEN}>>> [WP-ADDON] Dang cau hinh Filter cho Caddy Log...${NC}"
FILTER_FILE="/etc/fail2ban/filter.d/caddy-wp-login.conf"

cat > "$FILTER_FILE" <<EOF
[Definition]
# Regex nay da duoc test thanh cong: Tim IP truoc, roi den POST, roi den wp-login.php
failregex = ^.*"remote_ip":"<HOST>".*"method":"POST".*"uri":"/wp-login\.php"
ignoreregex =
EOF

# D. CẤU HÌNH JAIL (LOGIC & DATEPATTERN)
JAIL_WP_FILE="/etc/fail2ban/jail.d/99-wordpress-caddy.conf"
# Tim tat ca access log trong thu muc /var/www
WP_LOG_PATH="/var/www/*/logs/access.log"

WP_JAIL_ENABLED="false"
MSG_REASON=""

if [[ "$USING_CLOUDFLARE_PROXY" == "true" ]]; then
    WP_JAIL_ENABLED="false"
    MSG_REASON="Disabled (Cloudflare Mode)"
    echo -e "${YELLOW}-> Cloudflare Mode: Jail WP da duoc TAT.${NC}"
else
    # Kiem tra xem co file log nao ton tai khong
    HAS_LOGS=$(ls $WP_LOG_PATH 2>/dev/null | head -n 1 || true)
    
    if [[ -z "$HAS_LOGS" ]]; then
        WP_JAIL_ENABLED="false"
        MSG_REASON="Disabled (No logs found)"
        echo -e "${YELLOW}-> Khong tim thay Log Web. Jail WP tam tat.${NC}"
    else
        WP_JAIL_ENABLED="true"
        MSG_REASON="Enabled (Direct Mode)"
        echo -e "${GREEN}-> Phat hien Log Web. Jail WP da duoc BAT.${NC}"
    fi
fi

# Ghi file cau hinh Jail (Gop chung 1 lenh cat cho gon)
cat > "$JAIL_WP_FILE" <<EOF
[caddy-wp-login]
# Trang thai: $MSG_REASON
enabled = $WP_JAIL_ENABLED
port    = 80,443,443/udp
filter  = caddy-wp-login
logpath = $WP_LOG_PATH

# [QUAN TRONG] Datepattern cho Caddy
# Giup Fail2Ban doc duoc timestamp dang Unix Epoch (Vi du: 1767093193.048)
# Neu khong co dong nay, Fail2Ban se bao "0 failed" du Regex dung.
datepattern = {EPOCH}

# Thoi gian cam (Thua huong tu Core nhung co the ghi de tai day neu muon)
maxretry = 5
EOF

# E. ÁP DỤNG
echo -e "${GREEN}>>> Reloading Fail2Ban...${NC}"
systemctl reload fail2ban

echo -e "--------------------------------------------------------"
echo -e "Trang thai bao ve WordPress (Caddy):"
if [[ "$WP_JAIL_ENABLED" == "true" ]]; then
     echo -e "Jail Status: ${GREEN}[ACTIVE]${NC}"
     echo -e "Log Path:    $WP_LOG_PATH"
     echo -e "Kiem tra:    fail2ban-client status caddy-wp-login"
else
     echo -e "Jail Status: ${YELLOW}[INACTIVE]${NC} - Reason: $MSG_REASON"
fi
echo "--------------------------------------------------------"