#!/bin/bash

# -----------------------------------------------------------
# Lấy thông tin Database của website cụ thể 
# Sử dụng WP-CLI để lấy chính xác
# File: get_db_info.sh
# -----------------------------------------------------------

set -euo pipefail

# Mau sac
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Kiểm tra và nâng quyền
if [[ $EUID -ne 0 ]]; then
   sudo -E "$0" "$@"
   exit $?
fi

echo -e "${GREEN}=== LAY THONG TIN DATABASE (WP-CLI) ===${NC}"
echo "Cong cu nay trich xuat thong tin ket noi DB chinh xac tu wp-config.php"
echo "------------------------------------------------"

# 1. Nhập tên miền
read -r -p "Nhap ten mien website (VD: example.com): " INPUT_DOMAIN

# 2. Chuẩn hóa tên miền
TEMP_DOMAIN=$(echo "$INPUT_DOMAIN" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
DOMAIN=$(echo "$TEMP_DOMAIN" | sed -E 's|^https?://||' | sed -E 's|/.*$||' | sed -E 's|:[0-9]+$||')

if [[ -z "$DOMAIN" ]]; then
     echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"
     exit 1
fi

# Thư mục tên miền
WP_PATH="/var/www/$DOMAIN/public_html"

# File wp-config.php
CONFIG_FILE="$WP_PATH/wp-config.php"

# 3. Kiểm tra sự tồn tại của website
if [[ ! -d "$WP_PATH" ]] || [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Loi: Khong tim thay ma nguon WordPress tai: $WP_PATH${NC}"
    exit 1
fi

# 4. Kiểm tra WP-CLI
if ! command -v wp &> /dev/null; then
    echo -e "${RED}Loi: WP-CLI chua duoc cai dat.${NC}"
    exit 1
fi

echo -e "${YELLOW}Dang doc cau hinh...${NC}"

# 5. Lấy thông tin (sử dụng WP-CLI)
# --skip-plugins --skip-themes: Quan trọng để tránh lỗi từ plugin hoặc theme làm hỏng lệnh
# || true: Để script không bị dừng nếu giá trị nào đó thiếu
DB_NAME=$(wp config get DB_NAME --path="$WP_PATH" --allow-root --quiet --skip-plugins --skip-themes 2>/dev/null || echo "Khong tim thay")
DB_USER=$(wp config get DB_USER --path="$WP_PATH" --allow-root --quiet --skip-plugins --skip-themes 2>/dev/null || echo "Khong tim thay")
DB_PASS=$(wp config get DB_PASSWORD --path="$WP_PATH" --allow-root --quiet --skip-plugins --skip-themes 2>/dev/null || echo "Khong tim thay")
DB_HOST=$(wp config get DB_HOST --path="$WP_PATH" --allow-root --quiet --skip-plugins --skip-themes 2>/dev/null || echo "localhost")

# 6. Hiển thị kết quả cho người dùng
echo ""
echo "------------------------------------------------"
echo -e "Website:   ${GREEN}$DOMAIN${NC}"
echo "------------------------------------------------"
echo -e "Database:  ${YELLOW}$DB_NAME${NC}"
echo -e "Username:  ${YELLOW}$DB_USER${NC}"
echo -e "Password:  ${YELLOW}$DB_PASS${NC}"
echo -e "Host:      ${YELLOW}$DB_HOST${NC}"
echo "------------------------------------------------"