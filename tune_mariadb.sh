#!/bin/bash

# -----------------------------------------------------------
# Tối ưu MariaDB
# File: tune_mariadb.sh
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

# ======================================================
# WP SILA MARIADB TUNER (BACKUP SAFE EDITION)
# Target: Ubuntu 24.04 | MariaDB 10.11 | PHP 8.3 | Caddy
# Use Case: Blog 1000+ Posts & Frequent Backups
# ======================================================

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo ">> Dang kiem tra cau hinh he thong..."

# Lấy tổng RAM theo KB từ Kernel (Chính xác tuyệt đối, không phụ thuộc ngôn ngữ)
total_ram_kb=$(grep -i 'MemTotal' /proc/meminfo | awk '{print $2}')

# Chuyển đổi sang MB để hiển thị hoặc tính toán đơn giản (chia 1024)
# Dùng phép tính số học của bash $((...)) nhanh hơn dùng lệnh bên ngoài
total_ram_mb=$((total_ram_kb / 1024))

echo "- Tong RAM he thong: ${total_ram_mb} MB"

# Thư mục chứa các file cấu hình phụ của MariaDB trên Ubuntu
# Phân tách cấu hình tùy chỉnh ra khỏi cấu hình hệ thống
CONF_DIR="/etc/mysql/mariadb.conf.d"

if [[ ! -d "$CONF_DIR" ]]; then
    echo -e "${YELLOW}Loi: Khong tim thay thu muc cau hinh MariaDB ($CONF_DIR). ${NC}"
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# ======================================================
# LOGIC TÍNH TOÁN (ĐÃ ĐIỀU CHỈNH CHO BACKUP SITE LỚN)
# ======================================================

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Luôn tắt performance_schema trên VPS chạy chung Web + DB để tiết kiệm 300-400MB RAM và CPU
perf_schema="OFF"

# Tối ưu ưu tiên cho WordPress Blog (95% đọc, DB gọn, 100% bảng InnoDB) và phân khúc VPS 1GB - 2GB RAM:
if (( total_ram_mb < 1200 )); then
    # VPS ~1GB RAM (Ưu tiên tiết kiệm từng MB RAM cho OS và PHP-FPM)
    buffer_pool="192M"
    log_file_size="48M"
    max_conn=35
    tmp_table="16M"
    thread_cache=8
    table_cache=400
    table_def_cache=400
    
elif (( total_ram_mb < 2500 )); then
    # VPS ~2GB RAM (Phân khúc phổ biến nhất cho Blog: 512M đủ chứa trọn DB blog hàng nghìn bài viết trong RAM)
    buffer_pool="512M"
    log_file_size="64M"
    max_conn=50
    tmp_table="32M"
    thread_cache=16
    table_cache=800
    table_def_cache=600
    
elif (( total_ram_mb < 4500 )); then
    # VPS ~4GB RAM
    buffer_pool="1280M"
    log_file_size="128M"
    max_conn=100
    tmp_table="64M"
    thread_cache=32
    table_cache=1600
    table_def_cache=1000
    
else
    # VPS >= 8GB RAM (Dành 40% RAM cho InnoDB Buffer Pool)
    buffer_pool="40%"
    log_file_size="256M"
    max_conn=150
    tmp_table="64M"
    thread_cache=64
    table_cache=3000
    table_def_cache=1600
fi

# Xử lý trường hợp buffer_pool là dạng phần trăm (ví dụ "40%")
if [[ "$buffer_pool" == *"%" ]]; then
    percent=${buffer_pool%\%} # Lấy số 40 ra khỏi chuỗi "40%"
    
    # Bước 1: Tính ra số MB thô
    raw_mb=$(( total_ram_mb * percent / 100 ))
    
    # Bước 2: Làm tròn về bội số của 128MB (Chunk alignment)
    # Logic: Chia cho 128 (lấy phần nguyên), sau đó nhân lại cho 128
    # Ví dụ: 3200 / 128 = 25 (nguyên); 25 * 128 = 3200.
    buffer_pool_mb=$(( (raw_mb / 128) * 128 ))
    
    # Bước 3: Kiểm tra an toàn (tránh trường hợp RAM quá bé tính ra 0)
    if (( buffer_pool_mb < 128 )); then
        buffer_pool_mb=128
    fi

    buffer_pool="${buffer_pool_mb}M"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# ======================================================
# TẠO FILE CẤU HÌNH (AN TOÀN TUYỆT ĐỐI CHO BACKUP)
# ======================================================

# Tên file tùy chỉnh, số 99 để nó được đọc cuối, ghi đè các file đã được đọc trước đó (50-server.cnf...)
CONFIG_FILE="$CONF_DIR/99-wpsila-db-tune.cnf"

echo ">> Dang tao file cau hinh toi uu cho blog nhieu bai viet va backup thuong xuyen..."

cat > "$CONFIG_FILE" <<EOF
# Cấu hình tối ưu bởi WPSILA (Blog 1000+ Posts Edition)
[mysqld]

# === 1. CƠ BẢN & KẾT NỐI ===
user                    = mysql
bind-address            = 127.0.0.1
skip-name-resolve       = 1

# Tăng timeout lên 120s để an toàn khi Backup/Restore trên ổ cứng chậm
wait_timeout            = 120
interactive_timeout     = 120

# === QUAN TRỌNG NHẤT CHO BACKUP ===
# 128M giúp mysqldump/restore không bị lỗi 'Packet too large' với DB lớn
max_allowed_packet      = 128M
max_connections         = ${max_conn}
max_connect_errors      = 10000
thread_cache_size       = ${thread_cache}

# === 2. TỐI ƯU BỘ NHỚ ===
# Lưu ý: Mặc định Ubuntu đặt key_buffer_size = 128M cho bảng MyISAM cũ, nhưng WordPress hiện đại dùng 100% InnoDB.
# Hạ key_buffer_size xuống 8M giúp giải phóng ngay lập tức 120MB RAM quý giá trên VPS 1-2GB!
key_buffer_size         = 8M
# Lưu ý: innodb_buffer_pool_instances đã bị loại bỏ từ MariaDB 10.6+
innodb_buffer_pool_size = ${buffer_pool}
innodb_log_buffer_size  = 16M

# === 3. DISK I/O (TỐC ĐỘ CAO) ===
skip-log-bin
innodb_flush_method     = O_DIRECT
innodb_flush_log_at_trx_commit = 2
innodb_log_file_size    = ${log_file_size}
innodb_file_per_table   = 1

# === 4. QUERY & TABLE CACHE PERFORMANCE ===
tmp_table_size          = ${tmp_table}
max_heap_table_size     = ${tmp_table}
table_open_cache        = ${table_cache}
table_definition_cache  = ${table_def_cache}
performance_schema      = ${perf_schema}

# === 5. CHARSET ===
character-set-server    = utf8mb4
collation-server        = utf8mb4_unicode_ci
EOF
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# ======================================================
# KIỂM TRA & KHỞI ĐỘNG LẠI
# ======================================================

echo ">> Dang khoi dong lai MariaDB..."

if systemctl restart mariadb; then
    if systemctl is-active --quiet mariadb; then
        echo -e "${GREEN}THANH CONG! MariaDB da san sang cho Blog & Backup.${NC}"
        echo "Max Packet Size: 128M (An toan cho 1000+ bai viet)"
		echo "File cau hinh: $CONFIG_FILE"
    else
        echo -e "${RED}CANH BAO: Service restart OK nhung KHONG active.${NC}"
        rm -f "$CONFIG_FILE"
        systemctl restart mariadb
        echo "Da hoan tac."
    fi
else
    echo -e "${RED}Loi: Khong the khoi dong, dang hoan tac...${NC}"
    rm -f "$CONFIG_FILE"
    systemctl restart mariadb
    echo -e "${YELLOW}Da khoi phuc lai trang thai cu. ${NC}"
fi
echo "-------------------------------------------------------------"
# -------------------------------------------------------------------------------------------------------------------------------