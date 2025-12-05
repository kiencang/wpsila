#!/bin/bash
set -euo pipefail

# ==============================================================================
# SCRIPT TỰ ĐỘNG TỐI ƯU PHP-FPM POOL THEO RAM (Dành cho Ubuntu/Debian)
# ==============================================================================

# 1. KIỂM TRA QUYỀN ROOT
if [ "$EUID" -ne 0 ]; then
  echo "❌ Vui lòng chạy script này với quyền root (sudo)."
  exit 1
fi

# 2. PHÁT HIỆN PHIÊN BẢN PHP
if ! command -v php &> /dev/null; then
    echo "❌ Không tìm thấy PHP. Vui lòng cài đặt PHP trước."
    exit 1
fi
CURRENT_PHP_VER=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
CONF_DIR="/etc/php/${CURRENT_PHP_VER}/fpm/pool.d"

if [ ! -d "$CONF_DIR" ]; then
    echo "❌ Không tìm thấy thư mục cấu hình: $CONF_DIR"
    exit 1
fi

# 3. PHÁT HIỆN DUNG LƯỢNG RAM (MB)
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
echo ">> 🖥️  Thông tin hệ thống:"
echo "   - Phiên bản PHP: $CURRENT_PHP_VER"
echo "   - Tổng RAM: ${TOTAL_RAM} MB"

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

echo ">> ⚡ Áp dụng cấu hình cho mức RAM: $RAM_PROFILE"
echo "   - pm.max_children = $PM_MAX_CHILDREN"
echo "   - pm.start_servers = $PM_START_SERVERS"

# 5. TẠO FILE CẤU HÌNH (GHI ĐÈ)
CONFIG_FILE="${CONF_DIR}/z-wpsila-pool.conf"

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
echo ">> 🔄 Đang reload lại PHP-FPM..."

# Test cấu hình trước khi reload để tránh sập web
if php-fpm${CURRENT_PHP_VER} -t; then
    service php${CURRENT_PHP_VER}-fpm reload
    echo "✅ THÀNH CÔNG! Đã cập nhật file: $CONFIG_FILE"
else
    echo "❌ Lỗi cấu hình! Đã hủy bỏ reload. Vui lòng kiểm tra file log."
    rm "${CONFIG_FILE}"
    echo "   Đã xóa file cấu hình lỗi để khôi phục trạng thái cũ."
fi