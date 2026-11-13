#!/bin/bash

# -----------------------------------------------------------
# MODULE: Quản lý quyền ghi wp-config.php
# File: manage_wp_config.sh
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
echo -e "${GREEN}=== QUAN LY QUYEN GHI FILE WP-CONFIG.PHP ===${NC}"
read -r -p "Nhap ten mien (VD: example.com): " INPUT_DOMAIN < /dev/tty

# 1. Chuẩn hóa tên miền
TEMP_DOMAIN=$(echo "$INPUT_DOMAIN" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
DOMAIN=$(echo "$TEMP_DOMAIN" | sed -E 's|^https?://||' | sed -E 's|/.*$||' | sed -E 's|:[0-9]+$||')

# 2. Kiểm tra rỗng và định dạng tên miền
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
CONFIG_FILE="/var/www/$DOMAIN/public_html/wp-config.php" # Cấu trúc chuẩn của wpsila

# 3. Kiểm tra sự tồn tại
if [[ -f "$CONFIG_FILE" ]]; then
    # Lấy quyền hiện tại
    CURRENT_PERM=$(stat -c '%a' "$CONFIG_FILE")
    echo -e "Trang thai hien tai: ${YELLOW}${CURRENT_PERM}${NC} (640=Khoa, 660=Mo)"
    echo "------------------------------------------------"
    echo "1. MO KHOA (Chmod 660 & chattr -i)"
    echo "   => Cho phep plugin ghi file, cho phep sua qua sFTP."
    echo "2. KHOA LAI (Chmod 640 & chattr +i) - KHUYEN DUNG"
    echo "   => Bao mat cao: Plugin va sFTP chi duoc doc, khong the sua hoac xoa."
    echo "------------------------------------------------"
    read -r -p "Chon thao tac (1/2): " ACTION < /dev/tty

    # Gỡ cờ bất biến trước khi thay đổi chủ sở hữu và quyền
    chattr -i "$CONFIG_FILE" 2>/dev/null || true

    # [QUAN TRONG] Reset chủ sở hữu
    chown root:www-data "$CONFIG_FILE"

    if [[ "$ACTION" == "1" ]]; then
        chmod 660 "$CONFIG_FILE"
        echo -e "${RED}>> DA MO KHOA (UNLOCKED)!${NC}"
        echo "Hien tai: Plugin va sFTP co the sua file wp-config.php."
        echo "LUU Y: Hay thuc hien cong viec cua ban, sau do KHOA LAI NGAY."
    elif [[ "$ACTION" == "2" ]]; then
        chmod 640 "$CONFIG_FILE"
        chattr +i "$CONFIG_FILE" 2>/dev/null || true
        echo -e "${GREEN}>> DA KHOA LAI (LOCKED)!${NC}"
        echo "Hien tai: Plugin va sFTP chi co quyen DOC, khong the sua hay xoa."
        echo "File wp-config.php da duoc bao ve (chmod 640 + immutable)."
    else
        # Khôi phục lại cờ khóa nếu trước đó đang ở trạng thái 640/440
        if [[ "$CURRENT_PERM" == "640" || "$CURRENT_PERM" == "440" ]]; then
            chattr +i "$CONFIG_FILE" 2>/dev/null || true
        fi
        echo -e "${YELLOW}Huy thao tac.${NC}"
    fi
else
    echo -e "${RED}Loi: Khong tim thay file wp-config.php tai:${NC}"
    echo "$CONFIG_FILE"
    echo "Vui long kiem tra lai ten mien da nhap."
fi
# -------------------------------------------------------------------------------------------------------------------------------