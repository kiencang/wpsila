#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# ==============================================================================
# WP SILA MARIADB TUNER (BACKUP SAFE EDITION)
# Target: Ubuntu 24.04 | MariaDB 10.11 | PHP 8.3 | Caddy
# Use Case: Blog 1000+ Posts & Frequent Backups
# ==============================================================================

# Test lệnh
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/mariadb_tune.sh | sudo bash

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo "Loi: Ban phai chay script nay voi quyen root (sudo)."
   exit 1
fi

echo ">> Dang kiem tra cau hinh he thong..."

# Lấy tổng RAM theo KB từ Kernel (Chính xác tuyệt đối, không phụ thuộc ngôn ngữ)
total_ram_kb=$(grep -i 'MemTotal' /proc/meminfo | awk '{print $2}')

# Chuyển đổi sang MB để hiển thị hoặc tính toán đơn giản (chia 1024)
# Dùng phép tính số học của bash $((...)) nhanh hơn dùng lệnh bên ngoài
total_ram_mb=$((total_ram_kb / 1024))

echo "- Tong RAM he thong: ${total_ram_mb} MB"

# Thư mục chứa các file cấu hình phụ của MariaDB trên Ubuntu
# Phân tách cấu hình tùy chỉnh ra khỏi cấu hình hệ thống
CONFIG_DIR="/etc/mysql/mariadb.conf.d"

# Tên file tùy chỉnh, số 99 để nó được đọc cuối, ghi đè các file đã được đọc trước đó
# vì các file sẽ đọc theo thứ tự chữ cái rồi đến số...
CONFIG_FILE="$CONFIG_DIR/99-wpsila-db-tune.cnf"

if [ ! -d "$CONFIG_DIR" ]; then
    echo "Loi: Khong tim thay thu muc cau hinh MariaDB ($CONFIG_DIR)."
    exit 1
fi

# ==============================================================================
# LOGIC TÍNH TOÁN (ĐÃ ĐIỀU CHỈNH CHO BACKUP SITE LỚN)
# ==============================================================================

pool_instances=1
perf_schema="OFF"

if (( total_ram_mb < 1100 )); then
    # VPS < 1GB
    buffer_pool="256M"
    log_file_size="64M"
    max_conn=50
    tmp_table="16M"
    
elif (( total_ram_mb < 2500 )); then
    # VPS 2GB (Phổ biến)
    buffer_pool="768M"
    log_file_size="128M"
    max_conn=80
    tmp_table="32M"
    
elif (( total_ram_mb < 4500 )); then
    # VPS 4GB
    buffer_pool="2G"
    log_file_size="256M"
    max_conn=150
    tmp_table="64M"
    pool_instances=2
    
else
    # VPS > 4GB
    buffer_pool="50%"
    log_file_size="512M"
    max_conn=200
    tmp_table="64M"
    pool_instances=4
    perf_schema="ON"
fi


# Xử lý trường hợp buffer_pool là dạng phần trăm (ví dụ "50%")
if [[ "$buffer_pool" == *"%" ]]; then
    percent=${buffer_pool%\%} # Lấy số 50 ra khỏi chuỗi "50%"
    
    # Bước 1: Tính ra số MB thô
    raw_mb=$(( total_ram_mb * percent / 100 ))
    
    # Bước 2: Làm tròn về bội số của 128MB (Chunk alignment)
    # Logic: Chia cho 128 (lấy phần nguyên), sau đó nhân lại cho 128
    # Ví dụ: 4117 / 128 = 32 (nguyên); 32 * 128 = 4096.
    buffer_pool_mb=$(( (raw_mb / 128) * 128 ))
    
    # Bước 3: Kiểm tra an toàn (tránh trường hợp RAM quá bé tính ra 0)
    if (( buffer_pool_mb < 128 )); then
        buffer_pool_mb=128
    fi

    buffer_pool="${buffer_pool_mb}M"
fi

# ==============================================================================
# TẠO FILE CẤU HÌNH (AN TOÀN TUYỆT ĐỐI CHO BACKUP)
# ==============================================================================

echo ">> Dang tao file cau hinh toi uu cho backup..."

cat > "$CONFIG_FILE" <<EOF
# Cấu hình tối ưu bởi WP SILA (Blog 1000+ Posts Edition)
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

# === 2. TỐI ƯU BỘ NHỚ ===
innodb_buffer_pool_size = ${buffer_pool}
innodb_buffer_pool_instances = ${pool_instances}

# === 3. DISK I/O (TỐC ĐỘ CAO) ===
skip-log-bin
innodb_flush_method     = O_DIRECT
innodb_flush_log_at_trx_commit = 2
innodb_log_file_size    = ${log_file_size}
innodb_file_per_table   = 1

# === 4. QUERY PERFORMANCE ===
tmp_table_size          = ${tmp_table}
max_heap_table_size     = ${tmp_table}
performance_schema      = ${perf_schema}

# === 5. CHARSET ===
character-set-server    = utf8mb4
collation-server        = utf8mb4_unicode_ci
EOF

# ==============================================================================
# KIỂM TRA & KHỞI ĐỘNG LẠI
# ==============================================================================

echo ">> Dang khoi dong lai MariaDB..."

if systemctl restart mariadb; then
    if systemctl is-active --quiet mariadb; then
        echo "✅ THANH CONG! MariaDB da san sang cho Blog & Backup."
        echo "   Max Packet Size: 128M (An toan cho 1000+ bai viet)"
    else
        echo "⚠️ CANH BAO: Service restart OK nhung KHONG active."
        rm -f "$CONFIG_FILE"
        systemctl restart mariadb
        echo "❌ Da hoan tac."
    fi
else
    echo "❌ Loi: Khong the khoi dong, dang hoan tac..."
    rm -f "$CONFIG_FILE"
    systemctl restart mariadb
    echo "✅ Da khoi phuc lai trang thai cu."
fi