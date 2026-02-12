#!/bin/bash

# -------------------------------------------------------------------------------------------------------------------------------
# MODULE: Cài đặt & Cấu hình Redis Object Cache (Full Auto - Socket Fixed)
# File: install_redis_cache.sh
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Kiểm tra Redis cache có hoạt động không?
# redis-cli -s /var/run/redis/redis-server.sock monitor
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Chức năng:
#   1. Cài đặt Redis Server hệ thống (nếu chưa có).
#   2. Tối ưu hóa cấu hình Redis theo phương pháp Modular (An toàn khi update).
#   3. Tự động xử lý quyền ghi file wp-config.php (Smart Lock/Unlock).
#   4. Sinh Prefix thông minh chống trùng lặp dữ liệu giữa các web.
#   5. Cài plugin và kích hoạt cache trong WordPress.
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Dừng script ngay nếu gặp lỗi (error), biến rỗng (unbound var), hoặc lỗi trong pipe
set -euo pipefail

# Thiết lập môi trường chuẩn cho Automation
export LC_ALL=C.UTF-8
export DEBIAN_FRONTEND=noninteractive
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- KHAI BÁO MÀU SẮC (Để hiển thị thông báo đẹp hơn) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color (Ngắt màu)
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- KIỂM TRA QUYỀN ROOT ---
if [[ $EUID -ne 0 ]]; then
   sudo -E "$0" "$@"
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Kiểm tra WP-CLI
if ! command -v wp &> /dev/null; then
    echo "Loi: WP-CLI chua duoc cai dat. Vui long cai dat WP-CLI truoc."
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo -e "${GREEN}=== CAI DAT REDIS OBJECT CACHE (AUTO) ===${NC}"
echo -e "${YELLOW}Chi can thiet neu website cua ban co traffic rat cao (tren 3K view/ngay) hoac co rat nhieu binh luan (tren 50 comment moi ngay).${NC}"

echo -e "${GREEN}Ban co muon cai dat Redis cache khong?${NC}"
read -r -p "Nhap 'y' de bat dau qua trinh cai dat, hoac nhan Enter de thoat: " START_INSTALL_REDIS
    
if [[ "$START_INSTALL_REDIS" != "y" && "$START_INSTALL_REDIS" != "Y" ]]; then
    echo -e "${GREEN}Da huy thao tac. He thong cua ban van nhu ban dau.${NC}"
    exit 0
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# ========================================================================
# [NEW] 0. NẠP CẤU HÌNH ĐỂ LẤY PHP VERSION
# ========================================================================
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONF_FILE="$SCRIPT_DIR/wpsila.conf"

if [[ -f "$CONF_FILE" ]]; then
    source "$CONF_FILE"
else
    PHP_VER="8.3"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo -e "${GREEN}=== CAI DAT REDIS OBJECT CACHE (PHP ${PHP_VER}) ===${NC}"

# ========================================================================
# 1. KIỂM TRA VÀ CÀI ĐẶT REDIS SERVER
# ========================================================================
echo -e "${YELLOW}[1/5] Kiem tra Redis Server he thong...${NC}"

if ! command -v redis-server &> /dev/null || ! dpkg -s "php${PHP_VER}-redis" &> /dev/null; then
    echo "Dang cai dat Redis Server va Extension PHP ${PHP_VER}..."
    apt-get update -qq
    apt-get install -y redis-server "php${PHP_VER}-redis"
    systemctl enable --now redis-server
    systemctl restart "php${PHP_VER}-fpm"
    echo -e "${GREEN}Da cai dat xong va Reload PHP.${NC}"
else
    echo -e "${GREEN}Redis Server va PHP Extension da duoc cai dat.${NC}"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# ========================================================================
# PHẦN 2: TỐI ƯU HÓA CẤU HÌNH REDIS (CƠ CHẾ MODULAR)
# ========================================================================
echo -e "${YELLOW}[2/5] Kiem tra cau hinh toi uu cho Redis...${NC}"

total_ram_kb=$(grep -i 'MemTotal' /proc/meminfo | awk '{print $2}')
TOTAL_RAM_MB=$((total_ram_kb / 1024))
REDIS_RAM_LIMIT="64mb"

if [[ "$TOTAL_RAM_MB" -le 1100 ]]; then REDIS_RAM_LIMIT="64mb"
elif [[ "$TOTAL_RAM_MB" -le 2500 ]]; then REDIS_RAM_LIMIT="128mb"
elif [[ "$TOTAL_RAM_MB" -le 4500 ]]; then REDIS_RAM_LIMIT="256mb"
else REDIS_RAM_LIMIT="512mb"; fi

echo -e "   - Tong RAM VPS: ${BLUE}${TOTAL_RAM_MB} MB${NC}"
echo -e "   - Gioi han Redis: ${BLUE}${REDIS_RAM_LIMIT}${NC} (Muc an toan)"

REDIS_MAIN_CONF="/etc/redis/redis.conf"
WPSILA_REDIS_CONF="/etc/redis/wpsila-redis.conf"

if [[ -f "$REDIS_MAIN_CONF" ]]; then
    if [[ ! -f "$WPSILA_REDIS_CONF" ]]; then
        echo "Dang tao file cau hinh rieng biet (wpsila-redis.conf)..."
        cat > "$WPSILA_REDIS_CONF" <<EOF
# --- WPSILA REDIS OPTIMIZATION ---
maxmemory ${REDIS_RAM_LIMIT}
maxmemory-policy allkeys-lru
bind 127.0.0.1 ::1
protected-mode yes
unixsocket /var/run/redis/redis-server.sock
unixsocketperm 770
EOF
        chown redis:redis "$WPSILA_REDIS_CONF"
        chmod 640 "$WPSILA_REDIS_CONF"
    fi

    if ! grep -q "include $WPSILA_REDIS_CONF" "$REDIS_MAIN_CONF"; then
        echo "Dang lien ket file cau hinh vao Redis..."
        echo "" >> "$REDIS_MAIN_CONF"
        echo "include $WPSILA_REDIS_CONF" >> "$REDIS_MAIN_CONF"
    fi

    # [FIX] Đảm bảo thư mục Socket tồn tại (vì /var/run thường là tmpfs)
    mkdir -p /var/run/redis
    chown redis:redis /var/run/redis
    chmod 755 /var/run/redis

    # [FIX] Luôn kiểm tra Socket, nếu thiếu phải Restart ngay
    if [[ ! -S "/var/run/redis/redis-server.sock" ]]; then
        echo "Socket chua ton tai hoặc cấu hình mới. Dang Restart Redis..."
        usermod -aG redis www-data
        systemctl restart redis-server
        sleep 2
    fi

    systemctl restart "php${PHP_VER}-fpm"
    echo -e "${GREEN}Da kich hoat cau hinh toi uu (Unix Socket Enabled).${NC}"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# ========================================================================
# PHẦN 3: NHẬP VÀ XỬ LÝ TÊN MIỀN
# ========================================================================
echo "--------------------------------------------------------"
read -r -p "Nhap ten mien website muon cai Redis (VD: example.com): " INPUT_DOMAIN
DOMAIN=$(echo "$INPUT_DOMAIN" | tr '[:upper:]' '[:lower:]' | tr -d ' ' | sed -E 's|^https?://||' | sed -E 's|/.*$||' | sed -E 's|:[0-9]+$||')

if [[ -z "$DOMAIN" ]]; then echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"; exit 1; fi

WP_PATH="/var/www/$DOMAIN/public_html"
CONFIG_FILE="$WP_PATH/wp-config.php"

if [[ ! -d "$WP_PATH" ]] || [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Loi: Khong tim thay ma nguon WordPress tai: $WP_PATH${NC}"
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# ========================================================================
# PHẦN 4: KIỂM TRA ĐÃ CÀI ĐẶT CHƯA (SAFETY CHECK)
# ========================================================================
echo -e "${YELLOW}[3/5] Kiem tra trang thai hien tai cua Website...${NC}"

# [FIX] Vô hiệu hóa file lỗi NGAY LẬP TỨC để WP-CLI không bị văng Exception
if [[ -f "$WP_PATH/wp-content/object-cache.php" ]]; then
    mv "$WP_PATH/wp-content/object-cache.php" "$WP_PATH/wp-content/object-cache.php.bak"
    echo "Tam thoi vo hieu hoa Object Cache de kiem tra..."
fi

if wp config has WP_REDIS_PREFIX --allow-root --path="$WP_PATH" 2>/dev/null; then
    CURRENT_PREFIX=$(wp config get WP_REDIS_PREFIX --allow-root --path="$WP_PATH" 2>/dev/null)
    # Vì file đã bị đổi tên thành .bak, status lúc này sẽ luôn là Not enabled hoặc Unknown
    echo ""
    echo -e "${GREEN}>>> WEBSITE NAY DA DUOC CAU HINH REDIS TU TRUOC!${NC}"
    echo "--------------------------------------------------"
    echo -e "Prefix hien tai: ${YELLOW}$CURRENT_PREFIX${NC}"
    echo "--------------------------------------------------"
    read -r -p "Nhap 'y' de cai lai (Re-install), hoac nhan Enter de thoat: " CHOICE
    if [[ "$CHOICE" != "y" && "$CHOICE" != "Y" ]]; then
        # Khôi phục lại nếu người dùng hủy
        mv "$WP_PATH/wp-content/object-cache.php.bak" "$WP_PATH/wp-content/object-cache.php" 2>/dev/null || true
        echo -e "${GREEN}Da huy thao tac.${NC}"
        exit 0
    fi
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# ========================================================================
# PHẦN 5: XỬ LÝ QUYỀN FILE WP-CONFIG.PHP (SMART LOCK/UNLOCK)
# ========================================================================
echo -e "${YELLOW}[4/5] Kiem tra quyen ghi file wp-config.php...${NC}"
CURRENT_PERM=$(stat -c '%a' "$CONFIG_FILE")
IS_LOCKED=false

if [[ "$CURRENT_PERM" == "640" ]] || [[ "$CURRENT_PERM" == "440" ]]; then
    chmod 660 "$CONFIG_FILE"
    IS_LOCKED=true
fi
chown root:www-data "$CONFIG_FILE"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# ========================================================================
# PHẦN 6: TẠO SMART PREFIX VÀ THỰC THI CẤU HÌNH (WP-CLI)
# ========================================================================
echo -e "${YELLOW}[5/5] Dang thiet lap Redis Object Cache...${NC}"

SAFE_DOMAIN=$(echo "$DOMAIN" | tr '.' '_')
RANDOM_SUFFIX=$(openssl rand -hex 3)
SMART_PREFIX="${SAFE_DOMAIN}_${RANDOM_SUFFIX}_"

echo "Generated New Prefix: $SMART_PREFIX"

wp plugin install redis-cache --activate --allow-root --path="$WP_PATH" --quiet || true

echo "Dang ghi cau hinh vao wp-config.php..."

# [FIX] Ép sử dụng phpredis extension để tránh lỗi Predis thư viện
wp config set WP_REDIS_CLIENT "phpredis" --allow-root --path="$WP_PATH" --type=constant
wp config set WP_REDIS_PREFIX "$SMART_PREFIX" --allow-root --path="$WP_PATH" --type=constant
wp config set WP_CACHE_KEY_SALT "$SMART_PREFIX" --allow-root --path="$WP_PATH" --type=constant
wp config set WP_REDIS_SCHEME "unix" --allow-root --path="$WP_PATH" --type=constant
wp config set WP_REDIS_PATH "/var/run/redis/redis-server.sock" --allow-root --path="$WP_PATH" --type=constant

wp config delete WP_REDIS_HOST --allow-root --path="$WP_PATH" 2>/dev/null || true
wp config delete WP_REDIS_PORT --allow-root --path="$WP_PATH" 2>/dev/null || true
wp config set WP_REDIS_TIMEOUT 1 --allow-root --path="$WP_PATH" --raw --type=constant
wp config set WP_REDIS_READ_TIMEOUT 1 --allow-root --path="$WP_PATH" --raw --type=constant

echo "Dang kich hoat Object Cache..."
wp redis enable --allow-root --path="$WP_PATH"
wp cache flush --allow-root --path="$WP_PATH"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- PHÂN QUYỀN CHUẨN ---
echo "Dang chuan hoa quyen han (Fix Permissions)..."
if [[ -f "$WP_PATH/wp-content/object-cache.php" ]]; then
    chown root:www-data "$WP_PATH/wp-content/object-cache.php"
    chmod 664 "$WP_PATH/wp-content/object-cache.php"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# ========================================================================
# PHẦN 7: KHÔI PHỤC QUYỀN FILE
# ========================================================================
if [[ "$IS_LOCKED" = true ]]; then
    chmod 640 "$CONFIG_FILE"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# ========================================================================
# PHẦN 8: HOÀN TẤT VÀ BÁO CÁO
# ========================================================================
echo "--------------------------------------------------"
rm -f "$WP_PATH/wp-content/object-cache.php.bak"

STATUS=$(wp redis status --allow-root --path="$WP_PATH" | grep "Status" || true)

if [[ "$STATUS" == *"Connected"* ]]; then
    echo -e "${GREEN}SUCCESS! Redis da ket noi thanh cong qua UNIX SOCKET.${NC}"
    echo -e "Website:    ${YELLOW}$DOMAIN${NC}"
    echo -e "Status:     ${GREEN}Connected${NC}"
else
    echo -e "${RED}CANH BAO: Redis chua ket noi duoc.${NC}"
    wp redis status --allow-root --path="$WP_PATH"
fi
# -------------------------------------------------------------------------------------------------------------------------------