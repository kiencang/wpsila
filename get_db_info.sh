#!/bin/bash

# -----------------------------------------------------------
# Lấy thông tin Database của website cụ thể 
# Sử dụng WP-CLI để lấy chính xác
# File: get_db_info.sh
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
# Kiểm tra và nâng quyền
if [[ $EUID -ne 0 ]]; then
   sudo -E "$0" "$@"
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 0. Kiểm tra WP-CLI
# Kiểm tra sớm để thoát ngay nếu không có WP-CLI
if ! command -v wp &> /dev/null; then
    echo -e "${RED}Loi: WP-CLI chua duoc cai dat.${NC}"
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo -e "${GREEN}=== LAY THONG TIN DATABASE (WP-CLI) ===${NC}"
echo "Cong cu nay trich xuat thong tin ket noi DB chinh xac tu wp-config.php"
echo "------------------------------------------------"

# 1. Nhập tên miền
read -r -p "Nhap ten mien website (VD: example.com): " INPUT_DOMAIN < /dev/tty

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
# Thư mục tên miền
WP_PATH="/var/www/$DOMAIN/public_html"

# File wp-config.php
CONFIG_FILE="$WP_PATH/wp-config.php"

# 3. Kiểm tra sự tồn tại của website
if [[ ! -d "$WP_PATH" ]] || [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Loi: Khong tim thay ma nguon WordPress tai: $WP_PATH${NC}"
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo -e "${YELLOW}Dang doc cau hinh...${NC}"

# 4. Lấy thông tin (Ưu tiên đọc tĩnh an toàn từ wp-config.php, dự phòng WP-CLI dưới user www-data)
extract_wp_const() {
    local key="$1"
    local val=""
    val=$(grep -E "^[[:space:]]*define\(\s*['\"]${key}['\"]" "$CONFIG_FILE" 2>/dev/null | sed -E "s/.*['\"]${key}['\"]\s*,\s*['\"]([^'\"]*)['\"].*/\1/" | head -n 1 | tr -d '\r\n' || true)
    if [[ -z "$val" ]] && command -v wp &>/dev/null; then
        val=$(runuser -u www-data -- wp config get "$key" --path="$WP_PATH" --quiet --skip-plugins --skip-themes 2>/dev/null | tr -d '\r\n' || true)
    fi
    echo "$val"
}

DB_NAME=$(extract_wp_const "DB_NAME")
DB_USER=$(extract_wp_const "DB_USER")
DB_PASS=$(extract_wp_const "DB_PASSWORD")
DB_HOST=$(extract_wp_const "DB_HOST")

DB_NAME="${DB_NAME:-Khong tim thay}"
DB_USER="${DB_USER:-Khong tim thay}"
DB_PASS="${DB_PASS:-Khong tim thay}"
DB_HOST="${DB_HOST:-localhost}"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 5. Hiển thị kết quả cho người dùng
echo ""
echo "------------------------------------------------"
echo -e "Website: ${GREEN}$DOMAIN${NC}" # Tên miền
echo "------------------------------------------------"
echo -e "Database: ${YELLOW}$DB_NAME${NC}" # Tên database
echo -e "Username: ${YELLOW}$DB_USER${NC}" # Tên user
echo -e "Password: ${YELLOW}$DB_PASS${NC}" # Pass
echo -e "Host: ${YELLOW}$DB_HOST${NC}" # host, localhost hoặc 127.0.0.1
echo "------------------------------------------------"
# -------------------------------------------------------------------------------------------------------------------------------