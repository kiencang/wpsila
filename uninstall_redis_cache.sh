#!/bin/bash

# -------------------------------------------------------------------------------------------------------------------------------
# MODULE: Gỡ bỏ & Dọn dẹp Redis Object Cache (Clean Uninstall - Deep Clean).
# File: uninstall_redis_cache.sh
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Dừng script ngay nếu gặp lỗi (trừ khi được xử lý)
set -euo pipefail
export LC_ALL=C.UTF-8
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- Khai báo màu sắc ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- Kiểm tra quyền root & nâng quyền---
if [[ $EUID -ne 0 ]]; then
    sudo -E "$0" "$@"
    exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- Kiểm tra WP-CLI ---
# Kiểm tra WP-CLI, mặc dù wpsila có cài rồi, nhưng phòng người dùng gỡ.
# Thoát sớm nếu chưa cài (fail-fast).
if ! command -v wp &> /dev/null; then
    echo "Loi: WP-CLI chua duoc cai dat."
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo -e "${RED}=== GO BO REDIS OBJECT CACHE (DEEP CLEAN) ===${NC}"
echo -e "${YELLOW}Luu y: Script nay se xoa sach Plugin Redis va cac cau hinh lien quan.${NC}"
echo -e "${YELLOW}Chu y: No chi xoa cai dat cho [ten mien cu the duoc chi dinh], khong xoa Redis cua tat ca website tren VPS.${NC}"
echo -e "${YELLOW}Redis PHP & Redis Server van duoc giu lai, nhung khong hoat dong tren website da bi xoa cau hinh.${NC}"

# 1. Nhập tên miền
echo "--------------------------------------------------------"
read -r -p "Nhap ten mien website (VD: example.com): " INPUT_DOMAIN

# Làm sạch tên miền
TEMP_DOMAIN=$(echo "$INPUT_DOMAIN" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
DOMAIN=$(echo "$TEMP_DOMAIN" | sed -E 's|^https?://||' | sed -E 's|/.*$||' | sed -E 's|:[0-9]+$||')

# Kiểm tra tên miền rỗng
if [[ -z "$DOMAIN" ]]; then
     echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"
     exit 1
fi

# Kiểm tra tên miền trên VPS đã được cài đặt hay chưa?
WP_PATH="/var/www/$DOMAIN/public_html" # Cấu hình chuẩn trên wpsila.
CONFIG_FILE="$WP_PATH/wp-config.php" # Đường dẫn của file wp-config.php

# --- ĐẶT MÃ CLEANUP VÀ TRAP ---
# Để dự phòng mã bị dừng giữa chừng thì bảo mật wp-config.php vẫn được giữ lại.
IS_LOCKED=0 # Khai báo mặc định để tránh lỗi "unbound variable".

cleanup() {
    # Nếu biến IS_LOCKED là true (tức là script đã mở khóa file)
    if (( ${IS_LOCKED:-0} == 1 )) && [[ -f "$CONFIG_FILE" ]]; then
        chmod 640 "$CONFIG_FILE"
        echo "An toan hon: Da khoa lai file wp-config.php."
    fi
}
# Kích hoạt khi script thoát hoặc bị ngắt (Ctrl+C)
trap cleanup EXIT INT TERM # Các trường hợp bash bị dừng giữa chừng thì kích hoạt trap cleanup.

# Thông báo khi không tìm thấy thư mục cài đặt của website.
# Điều kiện bao gồm cả việc không tìm thấy file wp-config.php
if [[ ! -d "$WP_PATH" ]] || [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Loi: Khong tim thay WordPress tai: $WP_PATH${NC}"
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 2. Xác nhận
echo -e "${RED}CANH BAO: Thao tac tren domain: $DOMAIN${NC}"
read -r -p "Nhap 'y' de XOA HOAN TOAN Redis tren website: " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo -e "${GREEN}Da huy thao tac.${NC}"
    exit 0
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 3. Xử lý quyền FILE WP-CONFIG.PHP (UNLOCK)
echo -e "${YELLOW}[1/4] Mo khoa file wp-config.php...${NC}"

CURRENT_PERM=$(stat -c '%a' "$CONFIG_FILE")

if [[ "$CURRENT_PERM" == "640" ]] || [[ "$CURRENT_PERM" == "440" ]]; then
    chmod 660 "$CONFIG_FILE" # Mở khóa
    IS_LOCKED=1
fi

# Đảm bảo quyền sở hữu đúng để WP-CLI ghi được
chown root:www-data "$CONFIG_FILE"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 4. Thực hiện gỡ bỏ (WP-CLI)
echo -e "${YELLOW}[2/4] Dang go bo Redis...${NC}"

# 4.0. Dọn dẹp Cache
echo "   - Flushing WordPress Cache..."
wp cache flush --allow-root --path="$WP_PATH" --quiet || true

# 4.1. Vô hiệu hóa Object Cache
echo "   - Vo hieu hoa Object Cache..."

# Dùng || true để không dừng script nếu redis chưa enable
# Ngắt kết nối giữa WordPress và Redis
wp redis disable --allow-root --path="$WP_PATH" --quiet || true

# [Safety] Xóa thủ công file drop-in
if [[ -f "$WP_PATH/wp-content/object-cache.php" ]]; then
    rm -f "$WP_PATH/wp-content/object-cache.php"
    echo "   - Da xoa object-cache.php"
fi

# 4.2. Xóa các hằng số cấu hình (Deep Clean)
echo "   - Don dep wp-config.php..."

# Danh sách đầy đủ các biến có thể xuất hiện
KEYS_TO_REMOVE=(
    "WP_REDIS_PREFIX"
    "WP_CACHE_KEY_SALT"
    "WP_REDIS_SCHEME"
    "WP_REDIS_PATH"
    "WP_REDIS_HOST"
    "WP_REDIS_PORT"
    "WP_REDIS_TIMEOUT"
    "WP_REDIS_READ_TIMEOUT"
    "WP_REDIS_DATABASE"
    "WP_REDIS_PASSWORD" 
    "WP_REDIS_CLIENT" 
)

for KEY in "${KEYS_TO_REMOVE[@]}"; do
    # Kiểm tra tồn tại trước khi xóa
	if wp config has "$KEY" --allow-root --path="$WP_PATH" 2>/dev/null; then
		# Nếu xóa thành công (&&) thì mới in thông báo
		wp config delete "$KEY" --allow-root --path="$WP_PATH" --quiet && echo "      + Da xoa: $KEY" || echo "      ! Loi: Khong the xoa $KEY"
	fi
done

# 4.3. Gỡ bỏ Plugin
echo "   - Go bo plugin Redis..."
if wp plugin is-installed redis-cache --allow-root --path="$WP_PATH"; then
    wp plugin deactivate redis-cache --uninstall --allow-root --path="$WP_PATH" --quiet || true
    echo "    + Plugin da go."
else
    echo "    + Khong tim thay plugin."
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 5. Khôi phục quyền FILE (RE-LOCK)
echo -e "${YELLOW}[3/4] Khoi phuc va don dep...${NC}"

if (( IS_LOCKED == 1 )); then
    chmod 640 "$CONFIG_FILE"
    echo "   - Da khoa lai wp-config.php (640)."
fi

# Xóa các file/folder rác còn sót lại
rm -rf "$WP_PATH/wp-content/cache/redis" 2>/dev/null || true
rm -f "$WP_PATH/wp-content/redis-config.php" 2>/dev/null || true # File config cũ của một số plugin
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 6. Hoàn tất
echo -e "${YELLOW}[4/4] Hoan tat...${NC}"
echo -e "${GREEN}=== THANH CONG! ===${NC}"
echo -e "Website: ${YELLOW}$DOMAIN${NC}"
echo -e "Status: ${GREEN}Da don dep thanh cong!${NC}"
# -------------------------------------------------------------------------------------------------------------------------------