#!/bin/bash

# -----------------------------------------------------------
# MODULE: Xem Log thời gian thực
# File: view_logs.sh
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
set -euo pipefail
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   sudo -E "$0" "$@"
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo -e "${GREEN}=== XEM LOG THOI GIAN THUC (LIVE LOGS) ===${NC}"
echo -e "Cong cu nay giup ban xem loi Website hoac PHP ngay lap tuc."
echo "------------------------------------------------"

# 1. Nhập tên miền
read -r -p "Nhap ten mien (VD: example.com): " INPUT_DOMAIN < /dev/tty

# 2. Chuẩn hóa tên miền
TEMP_DOMAIN=$(echo "$INPUT_DOMAIN" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
DOMAIN=$(echo "$TEMP_DOMAIN" | sed -E 's|^https?://||' | sed -E 's|/.*$||' | sed -E 's|:[0-9]+$||')

if [[ -z "$DOMAIN" ]]; then
     echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"
     exit 1
fi

if [[ ! "$DOMAIN" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*\.[a-z]{2,}$ ]]; then
     echo -e "${RED}Loi: Dia chi website '$DOMAIN' chua ky tu khong hop le hoac sai dinh dang.${NC}"
     exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 3. Xác định các file log quan trọng
SCRIPT_WPSILA_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [[ -f "$SCRIPT_WPSILA_DIR/wpsila.conf" ]]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_WPSILA_DIR/wpsila.conf"
fi

ACCESS_LOG="/var/www/$DOMAIN/logs/access.log"
if [[ -n "${PHP_VER:-}" && -f "/var/log/php${PHP_VER}-fpm.log" ]]; then
    PHP_LOG="/var/log/php${PHP_VER}-fpm.log"
else
    PHP_LOG=$(find /var/log -maxdepth 1 -name "php*-fpm.log" 2>/dev/null | head -n 1 || true)
fi

echo "------------------------------------------------"
echo "Chon loai Log muon xem:"
echo "1. Xem Access/Error Log cua Website ($DOMAIN)"
echo "   => Xem ai dang truy cap, loi 403, 404, 500 tu Web Server."
echo "2. Xem PHP System Log (Global)"
echo "   => Xem loi he thong PHP, loi 502 Bad Gateway, PHP Crash."
echo "------------------------------------------------"
read -r -p "Nhap lua chon (1/2): " LOG_CHOICE < /dev/tty

TARGET_LOG=""

if [[ "$LOG_CHOICE" == "1" ]]; then
    TARGET_LOG="$ACCESS_LOG"
elif [[ "$LOG_CHOICE" == "2" ]]; then
    if [[ -z "$PHP_LOG" ]]; then
        echo -e "${RED}Loi: Khong tim thay file log cua PHP-FPM!${NC}"
        exit 1
    fi
    TARGET_LOG="$PHP_LOG"
else
    echo -e "${YELLOW}Lua chon khong hop le.${NC}"
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 4. Thực thi xem log
if [[ -f "$TARGET_LOG" ]]; then
    echo -e "${GREEN}>> DANG MO LOG TAI: $TARGET_LOG${NC}"
    echo -e "${YELLOW}!!! NHAN TO HOP PHIM [Ctrl + C] DE THOAT KHOI MAN HINH LOG !!!${NC}"
    echo "..."
    sleep 2
    
    # Bẫy tín hiệu SIGINT để không thoát luôn menu chính khi bấm Ctrl+C
    trap : SIGINT

    tail -f -n 50 "$TARGET_LOG" || true
    
    trap - SIGINT
    
    echo -e "\n${GREEN}>> Da thoat che do xem Log.${NC}"
else
    echo -e "${RED}Loi: Khong tim thay file log!${NC}"
    echo "Duong dan: $TARGET_LOG"
    echo "Co the Website chua duoc cai dat hoac chua co truy cap nao."
fi
# -------------------------------------------------------------------------------------------------------------------------------