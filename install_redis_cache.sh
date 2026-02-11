#!/bin/bash

# ------------------------------------------------------------------------------------------------
# MODULE: Cài đặt & Cấu hình Redis Object Cache (Full Auto)
# File: install_redis_cache.sh
# Kiểm tra Redis cache có hoạt động không?
# redis-cli monitor
# Chức năng:
#   1. Cài đặt Redis Server hệ thống (nếu chưa có).
#   2. Tối ưu hóa cấu hình Redis theo phương pháp Modular (An toàn khi update).
#   3. Tự động xử lý quyền ghi file wp-config.php (Smart Lock/Unlock).
#   4. Sinh Prefix thông minh chống trùng lặp dữ liệu giữa các web.
#   5. Cài plugin và kích hoạt cache trong WordPress.
# ------------------------------------------------------------------------------------------------

# Dừng script ngay nếu gặp lỗi (error), biến rỗng (unbound var), hoặc lỗi trong pipe
set -euo pipefail

# --- KHAI BÁO MÀU SẮC (Để hiển thị thông báo đẹp hơn) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color (Ngắt màu)

# --- KIỂM TRA QUYỀN ROOT ---
# Script này can thiệp vào hệ thống (apt, etc) nên bắt buộc phải là root
if [[ $EUID -ne 0 ]]; then
   sudo -E "$0" "$@"
   exit $?
fi

# Kiểm tra WP-CLI, mặc dù wpsila có cài rồi, nhưng phòng người dùng gỡ
if ! command -v wp &> /dev/null; then
    echo "Loi: WP-CLI chua duoc cai dat. Vui long cai dat WP-CLI truoc."
    exit 1
fi

echo -e "${GREEN}=== CAI DAT REDIS OBJECT CACHE (AUTO) ===${NC}"
echo -e "${YELLOW}Chi can thiet neu website cua ban co traffic rat cao (tren 3K view/ngay)${NC}"

echo -e "${GREEN}Ban co muon cai dat Redis cache khong?${NC}"
# Hỏi xác nhận
read -r -p "Nhap 'y' de bat dau qua trinh cai dat, hoac nhan Enter de thoat: " START_INSTALL_REDIS
    
if [[ "$START_INSTALL_REDIS" != "y" && "$START_INSTALL_REDIS" != "Y" ]]; then
    echo -e "${GREEN}Da huy thao tac. He thong cua ban van nhu ban dau.${NC}"
    exit 0 # Thoát script an toàn
fi

# ==============================================================================
# [NEW] 0. NẠP CẤU HÌNH ĐỂ LẤY PHP VERSION
# ==============================================================================
# Xác định thư mục chứa script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONF_FILE="$SCRIPT_DIR/wpsila.conf"

# Nạp file cấu hình nếu tồn tại
if [[ -f "$CONF_FILE" ]]; then
    source "$CONF_FILE"
else
    # Fallback nếu mất file config (Mặc định 8.3 cho an toàn)
    PHP_VER="8.3"
fi

echo -e "${GREEN}=== CAI DAT REDIS OBJECT CACHE (PHP ${PHP_VER}) ===${NC}"

# ==============================================================================
# 1. KIỂM TRA VÀ CÀI ĐẶT REDIS SERVER
# ==============================================================================
echo -e "${YELLOW}[1/5] Kiem tra Redis Server he thong...${NC}"

# Logic: Kiểm tra cả Redis Server VÀ Extension PHP tương ứng
# Nếu thiếu 1 trong 2 thì cài lại cho chắc
if ! command -v redis-server &> /dev/null || ! dpkg -s "php${PHP_VER}-redis" &> /dev/null; then
    echo "Dang cai dat Redis Server va Extension PHP ${PHP_VER}..."
    apt-get update -qq
    
    # [QUAN TRỌNG] Chỉ định rõ phiên bản: php${PHP_VER}-redis
    # Ví dụ: php8.3-redis. Nó sẽ khớp hoàn toàn với hệ thống hiện tại.
    apt-get install -y redis-server "php${PHP_VER}-redis"
    
    # Khởi động Redis Server
    systemctl enable --now redis-server

    # [BẮT BUỘC] Reload PHP-FPM để nhận diện extension mới vừa cài
    # Nếu không có dòng này, WP-CLI ở dưới sẽ báo lỗi thiếu extension
    systemctl reload "php${PHP_VER}-fpm"
    
    echo -e "${GREEN}Da cai dat xong va Reload PHP.${NC}"
else
    echo -e "${GREEN}Redis Server va PHP Extension da duoc cai dat.${NC}"
fi

# ==============================================================================
# PHẦN 2: TỐI ƯU HÓA CẤU HÌNH REDIS (CƠ CHẾ MODULAR)
# Mục đích: Tách file cấu hình riêng để không bị mất khi chạy 'apt upgrade'
# ==============================================================================
echo -e "${YELLOW}[2/5] Kiem tra cau hinh toi uu cho Redis...${NC}"

# --- LOGIC TÍNH RAM ---
# Lấy tổng RAM theo KB từ Kernel (Chính xác tuyệt đối, không phụ thuộc ngôn ngữ)
total_ram_kb=$(grep -i 'MemTotal' /proc/meminfo | awk '{print $2}')

# Chuyển đổi sang MB để hiển thị hoặc tính toán đơn giản (chia 1024)
# Dùng phép tính số học của bash $((...)) nhanh hơn dùng lệnh bên ngoài
TOTAL_RAM_MB=$((total_ram_kb / 1024))

REDIS_RAM_LIMIT="64mb" # Mặc định an toàn nhất

if [[ "$TOTAL_RAM_MB" -le 1100 ]]; then
    # VPS 1GB -> 64MB (An toàn tuyệt đối)
    REDIS_RAM_LIMIT="64mb"
elif [[ "$TOTAL_RAM_MB" -le 2500 ]]; then
    # VPS 2GB -> 128MB
    REDIS_RAM_LIMIT="128mb"
elif [[ "$TOTAL_RAM_MB" -le 4500 ]]; then
    # VPS 4GB -> 512MB
    REDIS_RAM_LIMIT="256mb"
else
    # VPS > 4GB -> 1GB Cache
    REDIS_RAM_LIMIT="512mb"
fi

echo -e "   - Tong RAM VPS: ${BLUE}${TOTAL_RAM_MB} MB${NC}"
echo -e "   - Gioi han Redis: ${BLUE}${REDIS_RAM_LIMIT}${NC} (Muc an toan)"

REDIS_MAIN_CONF="/etc/redis/redis.conf"
WPSILA_REDIS_CONF="/etc/redis/wpsila-redis.conf"

if [[ -f "$REDIS_MAIN_CONF" ]]; then
    # Bước 2.1: Tạo file cấu hình riêng của wpsila (nếu chưa có)
    if [[ ! -f "$WPSILA_REDIS_CONF" ]]; then
        echo "Dang tao file cau hinh rieng biet (wpsila-redis.conf)..."
        
        # Ghi nội dung cấu hình tối ưu
        cat > "$WPSILA_REDIS_CONF" <<EOF
# --- WPSILA REDIS OPTIMIZATION (Dynamic RAM) ---
# File cau hinh bo sung, duoc include vao redis.conf chinh.
# Auto-generated based on System RAM: ${TOTAL_RAM_MB} MB

# 1. Gioi han RAM
# Ly do: De tranh Redis an het RAM lam sap MySQL/PHP (OOM Killer).
maxmemory ${REDIS_RAM_LIMIT}

# 2. Chinh sach xa thai (Eviction Policy):
# Khi day RAM (REDIS_RAM_LIMIT), tu dong xoa cac key it duoc dung nhat gan day (LRU).
# Day la policy an toan nhat cho Cache.
maxmemory-policy allkeys-lru

# 3. Bao mat mang:
# Chi cho phep ket noi tu noi bo (localhost), chan ket noi tu Internet.
bind 127.0.0.1 ::1
protected-mode yes
# ---------------------------------
EOF
        # Phân quyền chuẩn: User redis sở hữu, quyền 640 (chỉ owner đọc ghi, group đọc)
        chown redis:redis "$WPSILA_REDIS_CONF"
        chmod 640 "$WPSILA_REDIS_CONF"
        
        echo "Da tao file cau hinh toi uu."
    fi

    # Bước 2.2: Nhúng (Include) file riêng vào file chính
    # Kiểm tra xem file chính đã có dòng include chưa
    if ! grep -q "include $WPSILA_REDIS_CONF" "$REDIS_MAIN_CONF"; then
        echo "Dang lien ket file cau hinh vao Redis..."
        echo "" >> "$REDIS_MAIN_CONF"
        echo "# WPSILA MODULAR CONFIG INCLUDE" >> "$REDIS_MAIN_CONF"
        # Dòng include nằm cuối file sẽ ghi đè các setting mặc định ở trên
        echo "include $WPSILA_REDIS_CONF" >> "$REDIS_MAIN_CONF"
        
        # Khởi động lại để áp dụng thay đổi
        systemctl restart redis-server
        echo -e "${GREEN}Da kich hoat cau hinh toi uu.${NC}"
    else
        echo "Cau hinh da duoc toi uu tu truoc."
    fi
fi

# ==============================================================================
# PHẦN 3: NHẬP VÀ XỬ LÝ TÊN MIỀN
# ==============================================================================
echo "--------------------------------------------------------"
read -r -p "Nhap ten mien website muon cai Redis (VD: example.com): " INPUT_DOMAIN

# Chuẩn hóa tên miền (Chữ thường, bỏ khoảng trắng, bỏ http/https, bỏ www, bỏ port)
TEMP_DOMAIN=$(echo "$INPUT_DOMAIN" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
DOMAIN=$(echo "$TEMP_DOMAIN" | sed -E 's|^https?://||' | sed -E 's|/.*$||' | sed -E 's|:[0-9]+$||')

# Kiểm tra rỗng
if [[ -z "$DOMAIN" ]]; then
     echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"
     exit 1
fi

# Định nghĩa đường dẫn
WP_PATH="/var/www/$DOMAIN/public_html"
CONFIG_FILE="$WP_PATH/wp-config.php"

# Kiểm tra sự tồn tại của mã nguồn WordPress
if [[ ! -d "$WP_PATH" ]] || [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Loi: Khong tim thay ma nguon WordPress tai: $WP_PATH${NC}"
    exit 1
fi

# ==============================================================================
# PHẦN 4: KIỂM TRA ĐÃ CÀI ĐẶT CHƯA (SAFETY CHECK)
# Mục đích: Tránh ghi đè cấu hình của website đang chạy ổn định
# ==============================================================================
echo -e "${YELLOW}[3/5] Kiem tra trang thai hien tai cua Website...${NC}"

# Sử dụng WP-CLI để kiểm tra xem hằng số WP_REDIS_PREFIX đã có chưa
if wp config has WP_REDIS_PREFIX --allow-root --path="$WP_PATH" 2>/dev/null; then
    
    # Nếu đã có, lấy thông tin ra cho người dùng xem
    CURRENT_PREFIX=$(wp config get WP_REDIS_PREFIX --allow-root --path="$WP_PATH" 2>/dev/null)
    # Lấy trạng thái kết nối (Connected/Not Connected)
    CURRENT_STATUS=$(wp redis status --allow-root --path="$WP_PATH" | grep "Status" || echo "Status: Unknown")
    
    echo ""
    echo -e "${GREEN}>>> WEBSITE NAY DA DUOC CAU HINH REDIS TU TRUOC!${NC}"
    echo "--------------------------------------------------"
    echo -e "Prefix hien tai: ${YELLOW}$CURRENT_PREFIX${NC}"
    echo -e "Trang thai:      ${BLUE}$CURRENT_STATUS${NC}"
    echo "--------------------------------------------------"
    echo -e "Ban co muon CAI DAT LAI (Re-install) khong?"
    echo -e "${RED}Luu y: Viec nay se tao Prefix moi va lam vo hieu hoa cache cu.${NC}"
    
    # Hỏi xác nhận
    read -r -p "Nhap 'y' de cai lai, hoac nhan Enter de thoat: " CHOICE
    
    if [[ "$CHOICE" != "y" && "$CHOICE" != "Y" ]]; then
        echo -e "${GREEN}Da huy thao tac. Giu nguyen cau hinh cu.${NC}"
        exit 0 # Thoát script an toàn
    fi
    
    echo -e "${YELLOW}>> Nguoi dung xac nhan cai lai. Dang tien hanh...${NC}"
else
    echo -e "${GREEN}Chua phat hien cau hinh Redis. Tiep tuc cai dat...${NC}"
fi

# ==============================================================================
# PHẦN 5: XỬ LÝ QUYỀN FILE WP-CONFIG.PHP (SMART LOCK/UNLOCK)
# Mục đích: Mở khóa file config nếu nó đang bị chmod 640/440
# ==============================================================================
echo -e "${YELLOW}[4/5] Kiem tra quyen ghi file wp-config.php...${NC}"

# Lấy quyền hiện tại dưới dạng số (VD: 640, 644)
CURRENT_PERM=$(stat -c '%a' "$CONFIG_FILE")
IS_LOCKED=false

# Nếu quyền là 640 (Owner đọc ghi, Group đọc) hoặc 440 (Chỉ đọc) -> Cần mở khóa
if [[ "$CURRENT_PERM" == "640" ]] || [[ "$CURRENT_PERM" == "440" ]]; then
    echo "Phat hien file dang bi khoa (Chmod $CURRENT_PERM)."
    echo "Dang mo khoa tam thoi (Chmod 660) de ghi cau hinh..."
    chmod 660 "$CONFIG_FILE"
    # Đánh dấu cờ là đã mở khóa, để lát nữa còn khóa lại
    IS_LOCKED=true
fi

# Đảm bảo chủ sở hữu đúng là root:www-data trước khi thao tác
chown root:www-data "$CONFIG_FILE"

# ==============================================================================
# PHẦN 6: TẠO SMART PREFIX VÀ THỰC THI CẤU HÌNH (WP-CLI)
# ==============================================================================
echo -e "${YELLOW}[5/5] Dang thiet lap Redis Object Cache...${NC}"

# 6.1. Tạo Prefix thông minh
# Thay dấu chấm bằng gạch dưới: example.com -> example_com
SAFE_DOMAIN=$(echo "$DOMAIN" | tr '.' '_')
# Tạo chuỗi ngẫu nhiên 3 byte (6 ký tự hex) -> VD: a1b2c3
RANDOM_SUFFIX=$(openssl rand -hex 3)
# Kết hợp lại: example_com_a1b2c3_
SMART_PREFIX="${SAFE_DOMAIN}_${RANDOM_SUFFIX}_"

echo "Generated New Prefix: $SMART_PREFIX"

# 6.2. Cài đặt Plugin (Nếu chưa có)
# --force: Bỏ qua lỗi nếu plugin đã được cài rồi
# Đây là plugin Redis Object Cache (https://wordpress.org/plugins/redis-cache/) của Till Krüss
wp plugin install redis-cache --activate --allow-root --path="$WP_PATH" --quiet || true

# 6.3. Bơm cấu hình vào wp-config.php
echo "Dang ghi cau hinh vao wp-config.php..."

# --type=constant: Báo cho WP-CLI biết đây là hằng số PHP (không phải chuỗi thông thường)
# --raw: Giá trị không được bao trong dấu ngoặc kép (dùng cho số nguyên)

# Set Prefix độc nhất
wp config set WP_REDIS_PREFIX "$SMART_PREFIX" --allow-root --path="$WP_PATH" --type=constant
# Set Salt (Bổ trợ bảo mật)
wp config set WP_CACHE_KEY_SALT "$SMART_PREFIX" --allow-root --path="$WP_PATH" --type=constant
# Host & Port
wp config set WP_REDIS_HOST "127.0.0.1" --allow-root --path="$WP_PATH" --type=constant
wp config set WP_REDIS_PORT "6379" --allow-root --path="$WP_PATH" --type=constant
# Timeout an toàn (1 giây): Nếu Redis chết, Web vẫn sống (chỉ chậm đi chút) thay vì báo lỗi 500
wp config set WP_REDIS_TIMEOUT 1 --allow-root --path="$WP_PATH" --raw --type=constant
wp config set WP_REDIS_READ_TIMEOUT 1 --allow-root --path="$WP_PATH" --raw --type=constant

# 6.4. Kích hoạt Object Cache
echo "Dang kich hoat Object Cache..."
wp redis enable --allow-root --path="$WP_PATH"

# 6.5. Xóa sạch cache cũ để đón cache mới
wp cache flush --allow-root --path="$WP_PATH"

# --- [BỔ SUNG] PHÂN QUYỀN CHUẨN ---
echo "Dang chuan hoa quyen han (Fix Permissions)..."

# 1. Fix file drop-in (quan trọng)
if [[ -f "$WP_PATH/wp-content/object-cache.php" ]]; then
    chown root:www-data "$WP_PATH/wp-content/object-cache.php"
    chmod 664 "$WP_PATH/wp-content/object-cache.php"
fi

# 2. Fix thư mục plugin
PLUGIN_DIR="$WP_PATH/wp-content/plugins/redis-cache"
if [[ -d "$PLUGIN_DIR" ]]; then
    chown -R root:www-data "$PLUGIN_DIR"
    # Set quyền ghi cho group www-data (để update được từ Admin)
    find "$PLUGIN_DIR" -type d -exec chmod 2775 {} +
    find "$PLUGIN_DIR" -type f -exec chmod 664 {} +
fi

# ==============================================================================
# PHẦN 7: KHÔI PHỤC QUYỀN FILE (QUAN TRỌNG)
# ==============================================================================
# Nếu lúc nãy mình đã mở khóa, thì giờ phải khóa lại để bảo mật
if [[ "$IS_LOCKED" = true ]]; then
    echo "Dang khoa lai file wp-config.php (Ve trang thai 640)..."
    chmod 640 "$CONFIG_FILE"
fi

# ==============================================================================
# PHẦN 8: HOÀN TẤT VÀ BÁO CÁO
# ==============================================================================
echo "--------------------------------------------------"
# Kiểm tra lại trạng thái lần cuối
STATUS=$(wp redis status --allow-root --path="$WP_PATH" | grep "Status" || true)

if [[ "$STATUS" == *"Connected"* ]]; then
    echo -e "${GREEN}SUCCESS! Redis da ket noi thanh cong.${NC}"
    echo -e "Website:    ${YELLOW}$DOMAIN${NC}"
    echo -e "New Prefix: ${YELLOW}$SMART_PREFIX${NC}"
    echo -e "Status:     ${GREEN}Connected${NC}"
    echo "--------------------------------------------------"
    echo "He thong da tu dong cai dat plugin va cau hinh Prefix chong trung lap."
else
    echo -e "${RED}CANH BAO: Redis chua ket noi duoc. Vui long kiem tra lai.${NC}"
    # In ra lỗi chi tiết nếu có
    wp redis status --allow-root --path="$WP_PATH"
fi