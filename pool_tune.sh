#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# Màu sắc cho thông báo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color (ngắt màu)

# QUAN TRỌNG: CẤU HÌNH PHIÊN BẢN PHP
# 1. Đặt giá trị mặc định (phòng hờ không tìm thấy file config)
DEFAULT_PHP_VER="8.3"

# 2. Định nghĩa đường dẫn file config 
# (Ví dụ: file config nằm cùng thư mục với script đang chạy)
WPSILA_CONFIG_FILE="./wpsila.conf" 

# 3. Kiểm tra và nạp file config
if [ -f "$WPSILA_CONFIG_FILE" ]; then
    # Lệnh 'source' hoặc dấu chấm '.' sẽ đọc biến từ file kia vào script này
    source "$WPSILA_CONFIG_FILE"
    echo -e "${GREEN}Da tim thay file cau hinh: ${WPSILA_CONFIG_FILE}${NC}"
else
    echo -e "${YELLOW}Khong tim thay file config. Su dung phien ban mac dinh.${NC}"
fi

# 4. Chốt phiên bản cuối cùng
# Cú pháp ${BIEN_1:-$BIEN_2} nghĩa là: Nếu BIEN_1 rỗng (chưa set trong config), thì lấy BIEN_2
PHP_VER="${PHP_VER:-$DEFAULT_PHP_VER}"

echo "Phien ban PHP: $PHP_VER"

# ver 0.06.12.25

# ==============================================================================
# SCRIPT TỰ ĐỘNG TỐI ƯU PHP-FPM POOL THEO RAM (Dành cho Ubuntu/Debian)
# ==============================================================================

# Test lệnh
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/pool_tune.sh | sudo bash

# 1. KIỂM TRA QUYỀN ROOT
if [ "$EUID" -ne 0 ]; then
  echo "❌ Vui long chay script nay voi quyen root (sudo)."
  exit 1
fi

# Kiểm tra xem có đang cài đặt PHP không?
if ! command -v php &> /dev/null; then
    echo "❌ Khong tim thay PHP. Vui long cai dat PHP truoc."
    exit 1
fi

CONF_DIR="/etc/php/${PHP_VER}/fpm/pool.d"

if [ ! -d "$CONF_DIR" ]; then
    echo "❌ Khong tim thay thu muc cau hinh: $CONF_DIR"
    exit 1
fi

# 3. PHÁT HIỆN DUNG LƯỢNG RAM (MB)
# Lấy tổng RAM theo KB từ Kernel (Chính xác tuyệt đối, không phụ thuộc ngôn ngữ)
total_ram_kb=$(grep -i 'MemTotal' /proc/meminfo | awk '{print $2}')

# Chuyển đổi sang MB để hiển thị hoặc tính toán đơn giản (chia 1024)
# Dùng phép tính số học của bash $((...)) nhanh hơn dùng lệnh bên ngoài
TOTAL_RAM=$((total_ram_kb / 1024))

echo ">> 🖥️  Thong tin he thong:"
echo "   - Tong RAM: ${TOTAL_RAM} MB"

# 4. TÍNH TOÁN THÔNG SỐ (Logic Safe Tuning)
# Công thức dựa trên mức tiêu thụ trung bình 50-60MB/tiến trình PHP
# Dành lại RAM cho OS và MySQL.

if [ "$TOTAL_RAM" -le 1500 ]; then
    # --- CẤU HÌNH CHO VPS ~1GB RAM ---
    RAM_PROFILE="1GB (Low End)"
    PM_MAX_CHILDREN=5
    PM_START_SERVERS=2
    PM_MIN_SPARE=1
    PM_MAX_SPARE=3

elif [ "$TOTAL_RAM" -le 3500 ]; then
    # --- CẤU HÌNH CHO VPS ~2GB RAM ---
    RAM_PROFILE="2GB (Entry Level)"
    PM_MAX_CHILDREN=15
    PM_START_SERVERS=4
    PM_MIN_SPARE=2
    PM_MAX_SPARE=6

elif [ "$TOTAL_RAM" -le 7000 ]; then
    # --- CẤU HÌNH CHO VPS ~4GB RAM ---
    RAM_PROFILE="4GB (Mid Range)"
    PM_MAX_CHILDREN=40
    PM_START_SERVERS=10
    PM_MIN_SPARE=5
    PM_MAX_SPARE=15

else
    # --- CẤU HÌNH CHO VPS >= 8GB RAM ---
    RAM_PROFILE="8GB+ (High Performance)"
    PM_MAX_CHILDREN=80
    PM_START_SERVERS=20
    PM_MIN_SPARE=10
    PM_MAX_SPARE=30
fi

echo ">> ⚡ Ap dung cau hinh cho muc RAM: $RAM_PROFILE"
echo "   - pm.max_children = $PM_MAX_CHILDREN"
echo "   - pm.start_servers = $PM_START_SERVERS"

# 5. TẠO FILE CẤU HÌNH (GHI ĐÈ)
# Link dẫn của file
CONFIG_FILE="${CONF_DIR}/99-wpsila-pool-tune.conf"

cat > "${CONFIG_FILE}" <<EOF
; ==============================================================================
; TUNED BY WPSILA SCRIPT - RAM PROFILE: ${RAM_PROFILE}
; File này ghi đè cấu hình mặc định trong www.conf
; ==============================================================================

[www]
pm = dynamic
pm.max_children = ${PM_MAX_CHILDREN}
pm.start_servers = ${PM_START_SERVERS}
pm.min_spare_servers = ${PM_MIN_SPARE}
pm.max_spare_servers = ${PM_MAX_SPARE}
pm.max_requests = 1000
EOF

# 6. RELOAD PHP-FPM
echo ">> 🔄 Dang reload lai PHP-FPM..."

# Test cấu hình trước khi reload để tránh sập web
if php-fpm${PHP_VER} -t; then
    service php${PHP_VER}-fpm reload
    echo "✅ THANH CONG! Da cap nhat file: $CONFIG_FILE"
else
    echo "❌ Loi cau hinh! Da huy bo reload. Vui long kiem tra lai file log."
    rm "${CONFIG_FILE}"
    echo "   Da xoa bo cau hinh loi de khoi phuc lai trang thai cu."
fi