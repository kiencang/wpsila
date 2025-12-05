#!/bin/bash

# ==============================================================================
# WP SILA MARIADB TUNER (BACKUP SAFE EDITION)
# Target: Ubuntu 24.04 | MariaDB 10.11 | PHP 8.3 | Caddy
# Use Case: Blog 1000+ Posts & Frequent Backups
# ==============================================================================

# Kiểm tra quyền root
if [ "$(id -u)" != "0" ]; then
   echo "Lỗi: Bạn phải chạy script này với quyền root (sudo)."
   exit 1
fi

echo ">> Đang kiểm tra cấu hình hệ thống..."

# Lấy thông tin RAM (MB)
total_ram_mb=$(free -m | awk '/Mem:/ {print $2}')
echo "- Tổng RAM hệ thống: ${total_ram_mb} MB"

CONFIG_DIR="/etc/mysql/mariadb.conf.d"
CONFIG_FILE="$CONFIG_DIR/99-wpsila-tune.cnf"

if [ ! -d "$CONFIG_DIR" ]; then
    echo "Lỗi: Không tìm thấy thư mục cấu hình MariaDB ($CONFIG_DIR)."
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

# ==============================================================================
# TẠO FILE CẤU HÌNH (AN TOÀN TUYỆT ĐỐI CHO BACKUP)
# ==============================================================================

echo ">> Đang tạo file cấu hình tối ưu backup..."

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

echo ">> Đang khởi động lại MariaDB..."

if systemctl restart mariadb; then
    if systemctl is-active --quiet mariadb; then
        echo "✅ THÀNH CÔNG! MariaDB đã sẵn sàng cho Blog & Backup."
        echo "   Max Packet Size: 128M (An toàn cho 1000+ bài viết)"
    else
        echo "⚠️ CẢNH BÁO: Service restart OK nhưng không active."
        rm -f "$CONFIG_FILE"
        systemctl restart mariadb
        echo "❌ Đã hoàn tác."
    fi
else
    echo "❌ LỖI: Không thể khởi động. Đang hoàn tác..."
    rm -f "$CONFIG_FILE"
    systemctl restart mariadb
    echo "✅ Đã khôi phục trạng thái cũ."
fi