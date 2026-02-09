#!/bin/bash

# -----------------------------------------------------------
# MODULE: Quan ly quyen ghi wp-config.php
# File: manage_wp_config.sh
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

echo -e "${GREEN}=== QUAN LY QUYEN GHI FILE WP-CONFIG.PHP ===${NC}"
read -r -p "Nhap ten mien (VD: example.com): " INPUT_DOMAIN

# 1. Chuan hoa ten mien
TEMP_DOMAIN=$(echo "$INPUT_DOMAIN" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
DOMAIN=$(echo "$TEMP_DOMAIN" | sed -E 's|^https?://||' | sed -E 's|/.*$||' | sed -E 's|:[0-9]+$||')

# 2. Kiem tra rong
if [[ -z "$DOMAIN" ]]; then
     echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"
     exit 1
fi 

CONFIG_FILE="/var/www/$DOMAIN/public_html/wp-config.php"

# 3. Kiem tra file ton tai
if [[ -f "$CONFIG_FILE" ]]; then
    # Lay quyen hien tai
    CURRENT_PERM=$(stat -c '%a' "$CONFIG_FILE")
    echo -e "Trang thai hien tai: ${YELLOW}${CURRENT_PERM}${NC} (640=Khoa, 660=Mo)"
    echo "------------------------------------------------"
    echo "1. MO KHOA (Chmod 660)"
    echo "   => Cho phep plugin ghi file, cho phep sua qua sFTP."
    echo "2. KHOA LAI (Chmod 640) - KHUYEN DUNG"
    echo "   => Bao mat tuyet doi. Plugin va sFTP chi duoc doc."
    echo "------------------------------------------------"
    read -r -p "Chon thao tac (1/2): " ACTION

    # [QUAN TRONG] Reset chu so huu
    chown root:www-data "$CONFIG_FILE"

    if [[ "$ACTION" == "1" ]]; then
        chmod 660 "$CONFIG_FILE"
        echo -e "${RED}>> DA MO KHOA (UNLOCKED)!${NC}"
        echo "Hien tai: Plugin va sFTP co the sua file wp-config.php."
        echo "LUU Y: Hay thuc hien cong viec cua ban, sau do KHOA LAI NGAY."
    elif [[ "$ACTION" == "2" ]]; then
        chmod 640 "$CONFIG_FILE"
        echo -e "${GREEN}>> DA KHOA LAI (LOCKED)!${NC}"
        echo "Hien tai: Plugin va sFTP chi co quyen DOC, khong the sua."
        echo "File wp-config.php da an toan tuyet doi."
    else
        echo -e "${YELLOW}Huy thao tac.${NC}"
    fi
else
    echo -e "${RED}Loi: Khong tim thay file wp-config.php tai:${NC}"
    echo "$CONFIG_FILE"
    echo "Vui long kiem tra lai ten mien da nhap."
fi