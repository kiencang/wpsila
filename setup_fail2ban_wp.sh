#!/bin/bash

# -----------------------------------------------------------
# MODULE: Fail2Ban WordPress Protection (Add-on)
# File: setup_fail2ban_wp.sh
# Muc dich: Bao ve /wp-login.php (Tuy chon theo Cloudflare)
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
set -euo pipefail
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Kiểm tra root
if [[ $EUID -ne 0 ]]; then
   # 2. Nếu không phải root, tự động chạy lại script này bằng sudo
   # -E để giữ lại biến môi trường
   sudo -E "$0" "$@"
   # 3. Thoát tiến trình cũ (không phải root) để tiến trình mới (có root) chạy
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- CAU HINH ---
# Ban co dung Cloudflare Proxy khong?
# true  = TAT Jail WP (An toan cho Cloudflare)
# false = BAT Jail WP (Dung cho IP truc tiep)
USING_CLOUDFLARE_PROXY="true" 
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
IGNORE_IPS="127.0.0.1/8 ::1"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Kiem tra Fail2Ban da cai chua (Phu thuoc Script Core)
if ! command -v fail2ban-client &> /dev/null; then
    echo -e "${RED}Loi: Fail2Ban chua duoc cai dat. Hay chay 'setup_fail2ban_core.sh' truoc.${NC}"
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo -e "${GREEN}>>> [WP-ADDON] Dang cau hinh bao ve WordPress...${NC}"
echo -e "${YELLOW}>>> Mode Cloudflare Proxy: $USING_CLOUDFLARE_PROXY${NC}"

# 1. Tao Filter
FILTER_FILE="/etc/fail2ban/filter.d/caddy-wp-login.conf"
cat > "$FILTER_FILE" <<EOF
[Definition]
failregex = ^.*"remote_ip":"<HOST>",.*"method":"POST",.*"uri":"/wp-login.php".*$
            ^.*"method":"POST",.*"uri":"/wp-login.php",.*"remote_ip":"<HOST>".*$
ignoreregex =
EOF
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 2. Xu ly Logic Jail
JAIL_WP_FILE="/etc/fail2ban/jail.d/99-wordpress-caddy.conf"
WP_LOG_PATH="/var/www/*/logs/access.log"
WP_JAIL_ENABLED="false"
MSG_REASON=""

if [[ "$USING_CLOUDFLARE_PROXY" == "true" ]]; then
    WP_JAIL_ENABLED="false"
    MSG_REASON="Disabled (Cloudflare Mode Active)"
    echo -e "${YELLOW}-> Cloudflare Mode: Jail WP se duoc TAT.${NC}"
else
    # Check log
    HAS_LOGS=$(ls $WP_LOG_PATH 2>/dev/null | head -n 1 || true)
    if [[ -z "$HAS_LOGS" ]]; then
        WP_JAIL_ENABLED="false"
        MSG_REASON="Disabled (No log files found yet)"
        echo -e "${YELLOW}-> Chua co website nao (Log 404). Jail WP tam tat.${NC}"
    else
        WP_JAIL_ENABLED="true"
        MSG_REASON="Enabled (Direct IP Mode)"
        echo -e "${GREEN}-> Direct IP Mode: Jail WP duoc BAT.${NC}"
    fi
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 3. Ghi file Jail
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
# 4. Reload
echo -e "${GREEN}>>> Reloading Fail2Ban...${NC}"
systemctl reload fail2ban

echo -e "Trang thai hien tai:"
echo -e "SSH Jail: [Giữ nguyên]"
if [[ "$WP_JAIL_ENABLED" == "true" ]]; then
     echo -e "WP Jail:  ${GREEN}[ON]${NC}"
else
     echo -e "WP Jail:  ${YELLOW}[OFF]${NC} ($MSG_REASON)"
fi
# -------------------------------------------------------------------------------------------------------------------------------