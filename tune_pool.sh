#!/bin/bash

# -----------------------------------------------------------
# Tối ưu Pool
# File: tune_pool.sh
# Tối ưu theo dung lượng RAM
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Kiểm tra quyền root & nâng quyền
if [[ $EUID -ne 0 ]]; then
   # Thêm tham số -E cho sudo để giữ lại các biến môi trường (nếu có)
   sudo -E "$0" "$@"
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Màu sắc cho thông báo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color (ngắt màu)
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# QUAN TRỌNG: CẤU HÌNH PHIÊN BẢN PHP
# Nạp cấu hình trung tâm từ wpsila.conf
# (Ví dụ: file config nằm cùng thư mục với script đang chạy)
# Dòng lệnh này đảm bảo biến SCRIPT_WPSILA_DIR luôn là đường dẫn tuyệt đối tới thư mục chứa file này
# Xác định thư mục
SCRIPT_WPSILA_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Trỏ vào file config nằm cùng thư mục đó
WPSILA_CONFIG_FILE="$SCRIPT_WPSILA_DIR/wpsila.conf"

# Kiểm tra và nạp file config
if [[ ! -f "$WPSILA_CONFIG_FILE" ]]; then
    echo -e "${RED}Loi: Khong tim thay file cau hinh trung tam ($WPSILA_CONFIG_FILE)!${NC}"
    exit 1
fi

source "$WPSILA_CONFIG_FILE"

if [[ -z "${PHP_VER:-}" ]]; then
    echo -e "${RED}Loi: Bien PHP_VER chua duoc khai bao trong wpsila.conf!${NC}"
    exit 1
fi

# Thông báo phiên bản PHP
export PHP_VER
export SCRIPT_WPSILA_DIR
echo -e "Phien ban PHP he thong: ${GREEN}$PHP_VER${NC}"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# ========================================================================
# SCRIPT TỰ ĐỘNG TỐI ƯU PHP-FPM POOL THEO RAM (Dành cho Ubuntu/Debian)
# ========================================================================

# Kiểm tra xem có đang cài đặt PHP không?
if ! command -v php &> /dev/null; then
    echo -e "${YELLOW}Khong tim thay PHP. Vui long cai dat PHP truoc.${NC}"
    exit 1
fi

CONF_DIR="/etc/php/${PHP_VER}/fpm/pool.d"

if [[ ! -d "$CONF_DIR" ]]; then
    echo -e "${YELLOW}Khong tim thay thu muc cau hinh: $CONF_DIR ${NC}"
    exit 1
fi

# 3. PHÁT HIỆN DUNG LƯỢNG RAM (MB)
# Lấy tổng RAM theo KB từ Kernel (Chính xác tuyệt đối, không phụ thuộc ngôn ngữ)
total_ram_kb=$(grep -i 'MemTotal' /proc/meminfo | awk '{print $2}')

# Chuyển đổi sang MB để hiển thị hoặc tính toán đơn giản (chia 1024)
# Dùng phép tính số học của bash $((...)) nhanh hơn dùng lệnh bên ngoài
TOTAL_RAM=$((total_ram_kb / 1024))

echo ">> Thong tin he thong:"
echo "- Tong RAM: ${TOTAL_RAM} MB"

# 4. TÍNH TOÁN THÔNG SỐ (Logic Safe Tuning - Ưu tiên WordPress Blog trên VPS 1GB - 2GB RAM)
# Đặc thù WordPress Blog (không chạy WooCommerce): Mỗi tiến trình PHP-FPM tốn trung bình ~35-45MB RAM (do OPcache đã dùng chung).
# Giữ số tiến trình chờ (start/spare) gọn gàng trên VPS 1-2GB để nhường RAM rảnh cho Linux Page Cache tăng tốc đọc file tĩnh.

if [[ "$TOTAL_RAM" -le 1200 ]]; then
    # --- CẤU HÌNH CHO VPS ~1GB RAM (Ưu tiên an toàn tuyệt đối chống OOM) ---
    RAM_PROFILE="1GB (Low End Blog)"
    PM_MAX_CHILDREN=6
    PM_START_SERVERS=2
    PM_MIN_SPARE=1
    PM_MAX_SPARE=3
    PM_MAX_REQUESTS=500

elif [[ "$TOTAL_RAM" -le 2500 ]]; then
    # --- CẤU HÌNH CHO VPS ~2GB RAM (Phân khúc chủ lực cho Blog) ---
    RAM_PROFILE="2GB (Entry Level Blog)"
    PM_MAX_CHILDREN=15
    PM_START_SERVERS=3
    PM_MIN_SPARE=2
    PM_MAX_SPARE=5
    PM_MAX_REQUESTS=500

elif [[ "$TOTAL_RAM" -le 5000 ]]; then
    # --- CẤU HÌNH CHO VPS ~4GB RAM ---
    RAM_PROFILE="4GB (Mid Range)"
    PM_MAX_CHILDREN=30
    PM_START_SERVERS=6
    PM_MIN_SPARE=4
    PM_MAX_SPARE=10
    PM_MAX_REQUESTS=1000

elif [[ "$TOTAL_RAM" -le 10000 ]]; then
    # --- CẤU HÌNH CHO VPS ~8GB RAM ---
    RAM_PROFILE="8GB (High Performance)"
    PM_MAX_CHILDREN=60
    PM_START_SERVERS=12
    PM_MIN_SPARE=6
    PM_MAX_SPARE=18
    PM_MAX_REQUESTS=1000

else
    # --- CẤU HÌNH CHO VPS >= 16GB RAM ---
    RAM_PROFILE="16GB+ (Enterprise)"
    PM_MAX_CHILDREN=100
    PM_START_SERVERS=20
    PM_MIN_SPARE=10
    PM_MAX_SPARE=30
    PM_MAX_REQUESTS=1000
fi

echo ">> Ap dung cau hinh cho muc RAM: $RAM_PROFILE"
echo "- pm.max_children = $PM_MAX_CHILDREN"
echo "- pm.start_servers = $PM_START_SERVERS"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 5. TẠO FILE CẤU HÌNH (GHI ĐÈ)
# Lưu ý quan trọng: PHP-FPM nạp các file trong pool.d/*.conf theo thứ tự bảng chữ cái ASCII.
# Chữ số '9' (ASCII 57) đứng trước chữ cái 'w' (ASCII 119), nên tiền tố '99-' sẽ bị đọc TRƯỚC www.conf và bị www.conf ghi đè.
# Do đó, bắt buộc dùng tiền tố 'zz-' (đứng sau 'w') để ghi đè chính xác cấu hình [www] mặc định.
rm -f "${CONF_DIR}/99-wpsila-pool-tune.conf"
CONFIG_FILE="${CONF_DIR}/zz-wpsila-pool-tune.conf"

cat > "${CONFIG_FILE}" <<EOF
; =========================================================================
; TUNED BY WPSILA SCRIPT - RAM PROFILE: ${RAM_PROFILE}
; File nay duoc doc sau www.conf (nho tien to zz-) de ghi de cau hinh [www]
; =========================================================================

[www]
pm = dynamic
pm.max_children = ${PM_MAX_CHILDREN}
pm.start_servers = ${PM_START_SERVERS}
pm.min_spare_servers = ${PM_MIN_SPARE}
pm.max_spare_servers = ${PM_MAX_SPARE}
; Tai tao worker sau ${PM_MAX_REQUESTS} request de giai phong triet de bo nho ro ri tu plugin
pm.max_requests = ${PM_MAX_REQUESTS}
; Tự động thu hồi tiến trình PHP nếu bị treo I/O quá 300s (đồng bộ với max_execution_time)
request_terminate_timeout = 300s
EOF
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 6. RELOAD PHP-FPM
echo ">> Dang reload lai PHP-FPM..."

# Test cấu hình trước khi reload để tránh sập web
PHP_FPM_BIN=$(PATH="/usr/sbin:/sbin:$PATH" command -v "php-fpm${PHP_VER}" || true)
if [[ -n "$PHP_FPM_BIN" ]] && "$PHP_FPM_BIN" -t; then
    systemctl reload "php${PHP_VER}-fpm"
    echo -e "${GREEN}THANH CONG! Cau hinh moi da duoc ap dung cho Pool.${NC}"
	echo "File cau hinh: $CONFIG_FILE"
else
    echo -e "${RED}Loi cau hinh! Da huy bo reload. Vui long kiem tra lai file log.${NC}"
    rm -f "${CONFIG_FILE}"
    echo -e "${YELLOW}Da xoa bo cau hinh loi de khoi phuc lai trang thai cu.${NC}"
    exit 1
fi
echo "-------------------------------------------------------------"
# -------------------------------------------------------------------------------------------------------------------------------