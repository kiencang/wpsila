#!/bin/bash

# -----------------------------------------------------------
# MODULE: Khôi phục lại mật khẩu WordPress
# File: wp_reset_pass.sh
# -----------------------------------------------------------

set -euo pipefail

# Mau sac
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Kiểm tra quyền root & nâng quyền
if [[ $EUID -ne 0 ]]; then
   sudo -E "$0" "$@"
   exit $?
fi

echo -e "${GREEN}=== KHOI PHUC MAT KHAU ADMIN WORDPRESS ===${NC}"
echo "Cong cu nay su dung WP-CLI de doi mat khau ngay lap tuc."
echo "------------------------------------------------"

# 1. Nhập tên miền
read -r -p "Nhap ten mien (VD: example.com): " INPUT_DOMAIN

# 2. Chuẩn hóa tên miền
TEMP_DOMAIN=$(echo "$INPUT_DOMAIN" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
DOMAIN=$(echo "$TEMP_DOMAIN" | sed -E 's|^https?://||' | sed -E 's|/.*$||' | sed -E 's|:[0-9]+$||')

if [[ -z "$DOMAIN" ]]; then
     echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"
     exit 1
fi

WP_PATH="/var/www/$DOMAIN/public_html"
CONFIG_FILE="$WP_PATH/wp-config.php"

# 3. Kiểm tra sự tồn tại của website
if [[ ! -d "$WP_PATH" ]] || [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Loi: Khong tim thay ma nguon WordPress tai: $WP_PATH${NC}"
    exit 1
fi

echo -e "${YELLOW}Dang quet danh sach Quan tri vien (Administrator)...${NC}"

# 4. Liệt kê user Admin (Dùng WP-CLI)
# --skip-plugins --skip-themes: Tránh lỗi PHP từ plugin làm hỏng lệnh
if ! wp user list --role=administrator --fields=ID,user_login,user_email --format=table --allow-root --path="$WP_PATH" --skip-plugins --skip-themes; then
    echo -e "${RED}Loi: Khong the ket noi Database hoac chay WP-CLI.${NC}"
    exit 1
fi

echo "------------------------------------------------"
read -r -p "Nhap 'user_login' (Ten dang nhap) ban muon reset: " TARGET_USER

if [[ -z "$TARGET_USER" ]]; then
    echo -e "${RED}Loi: Ban chua nhap user.${NC}"
    exit 1
fi

# 5. Kiểm tra user có tồn tại không?
if ! wp user get "$TARGET_USER" --field=ID --allow-root --path="$WP_PATH" --skip-plugins --skip-themes > /dev/null 2>&1; then
    echo -e "${RED}Loi: User '$TARGET_USER' khong ton tai trong he thong.${NC}"
    exit 1
fi

# 6. Tạo mật khẩu mới ngẫu nhiên và mạnh
NEW_PASS="Res_$(openssl rand -hex 8)"

echo -e "${YELLOW}Dang thiet lap mat khau moi...${NC}"

# 7. Thực thi việc reset mật khẩu
if wp user update "$TARGET_USER" --user_pass="$NEW_PASS" --allow-root --path="$WP_PATH" --skip-plugins --skip-themes > /dev/null 2>&1; then
    echo ""
    echo -e "${GREEN}=== THANH CONG! ===${NC}"
    echo -e "Website:  ${YELLOW}https://$DOMAIN/wp-admin${NC}"
    echo -e "User:     ${YELLOW}$TARGET_USER${NC}"
    echo -e "New Pass: ${YELLOW}$NEW_PASS${NC}"
    echo "------------------------------------------------"
    echo "Hay luu lai mat khau nay ngay!"
else
    echo -e "${RED}Loi: Khong the cap nhat mat khau. Vui long kiem tra log.${NC}"
    exit 1
fi