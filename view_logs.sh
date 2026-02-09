#!/bin/bash

# -----------------------------------------------------------
# MODULE: Xem Log thoi gian thuc
# File: view_logs.sh
# -----------------------------------------------------------

set -euo pipefail

# Mau sac
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Kiem tra quyen root
if [[ $EUID -ne 0 ]]; then
   sudo -E "$0" "$@"
   exit $?
fi

echo -e "${GREEN}=== XEM LOG THOI GIAN THUC (LIVE LOGS) ===${NC}"
echo -e "Cong cu nay giup ban xem loi Website hoac PHP ngay lap tuc."
echo "------------------------------------------------"

# 1. Nhap ten mien
read -r -p "Nhap ten mien (VD: example.com): " INPUT_DOMAIN

# 2. Chuan hoa ten mien
TEMP_DOMAIN=$(echo "$INPUT_DOMAIN" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
DOMAIN=$(echo "$TEMP_DOMAIN" | sed -E 's|^https?://||' | sed -E 's|/.*$||' | sed -E 's|:[0-9]+$||')

if [[ -z "$DOMAIN" ]]; then
     echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"
     exit 1
fi

# 3. Xac dinh cac file log quan trong
ACCESS_LOG="/var/www/$DOMAIN/logs/access.log"
PHP_LOG=$(find /var/log -name "php*-fpm.log" | head -n 1)

echo "------------------------------------------------"
echo "Chon loai Log muon xem:"
echo "1. Xem Access/Error Log cua Website ($DOMAIN)"
echo "   -> Xem ai dang truy cap, loi 403, 404, 500 tu Web Server."
echo "2. Xem PHP System Log (Global)"
echo "   -> Xem loi he thong PHP, loi 502 Bad Gateway, PHP Crash."
echo "------------------------------------------------"
read -r -p "Nhap lua chon (1/2): " LOG_CHOICE

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

# 4. Thuc thi xem log
if [[ -f "$TARGET_LOG" ]]; then
    echo -e "${GREEN}>> DANG MO LOG TAI: $TARGET_LOG${NC}"
    echo -e "${YELLOW}!!! NHAN TO HOP PHIM [Ctrl + C] DE THOAT KHOI MAN HINH LOG !!!${NC}"
    echo "..."
    sleep 2
    
    # Bay tin hieu SIGINT de khong thoat luon menu chinh khi bam Ctrl+C
    trap : SIGINT

    tail -f -n 50 "$TARGET_LOG"
    
    trap - SIGINT
    
    echo -e "\n${GREEN}>> Da thoat che do xem Log.${NC}"
else
    echo -e "${RED}Loi: Khong tim thay file log!${NC}"
    echo "Duong dan: $TARGET_LOG"
    echo "Co the Website chua duoc cai dat hoac chua co truy cap nao."
fi