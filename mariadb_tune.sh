#!/usr/bin/env bash
set -euo pipefail

# --- SAFE MARIADB TUNING SCRIPT (UBUNTU 22/24 LTS EDITION) ---
# Mục tiêu: Tối ưu cho WordPress trên VPS cấu hình thấp
# Tương thích: Ubuntu 22.04, 24.04 (MariaDB 10.6+)

# --- 1. Cấu hình đường dẫn ---
DIR_PATH="/etc/mysql/mariadb.conf.d"
FILE_NAME="99-wp-safe-tuning.cnf"
CNF_PATH="${DIR_PATH}/${FILE_NAME}"
BACKUP_DIR="/var/backups/mariadb-tuning"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG="/var/log/mariadb-safe-tune.log"

# Tạo file log
touch "$LOG" && chmod 600 "$LOG"

# Kiểm tra quyền Root
if [[ $EUID -ne 0 ]]; then
    echo "❌ Lỗi: Bạn cần chạy bằng quyền root (sudo)."
    exit 1
fi

# Kiểm tra thư mục config (Chắc chắn đúng trên Ubuntu 22/24)
if [[ ! -d "$DIR_PATH" ]]; then
    echo "❌ Không tìm thấy thư mục: $DIR_PATH. Bạn có chắc đã cài MariaDB chưa?"
    exit 1
fi

mkdir -p "$BACKUP_DIR"

# --- 2. Tính toán RAM & Thông số ---
# Lấy tổng RAM (MB)
total_ram_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
total_ram_mb=$(( total_ram_kb / 1024 ))
echo "📊 Detected RAM: ${total_ram_mb} MB (Ubuntu LTS Environment)" | tee -a "$LOG"

# LOGIC TÍNH TOÁN (Giữ nguyên vì đã rất hợp lý cho VPS nhỏ)
if (( total_ram_mb < 600 )); then
    # VPS 512MB
    buffer_pool="128M"
    max_conn=20
    log_file_size="48M"
    perf_schema="OFF"
elif (( total_ram_mb < 1100 )); then
    # VPS 1GB
    buffer_pool="256M"
    max_conn=40
    log_file_size="64M"
    perf_schema="OFF"
elif (( total_ram_mb < 2100 )); then
    # VPS 2GB
    buffer_pool="768M"
    max_conn=80
    log_file_size="128M"
    perf_schema="OFF"
elif (( total_ram_mb < 4100 )); then
    # VPS 4GB
    buffer_pool="2048M"
    max_conn=150
    log_file_size="256M"
    perf_schema="OFF"
else
    # VPS > 4GB
    calc_pool=$(( total_ram_mb * 60 / 100 ))
    buffer_pool="${calc_pool}M"
    max_conn=300
    log_file_size="512M"
    perf_schema="ON"
fi

echo "🔧 Plan: Buffer Pool=${buffer_pool}, Max Conn=${max_conn}" | tee -a "$LOG"

# --- 3. Tạo nội dung Config ---
TMP_FILE="$(mktemp)"
cat > "$TMP_FILE" <<EOF
[mysqld]
# --- BẢO MẬT & TIẾT KIỆM DISK ---
# Chỉ cho phép kết nối từ localhost (An toàn cho VPS đơn)
bind-address = 127.0.0.1
# Tắt Binary Log nếu không làm Replication (Tiết kiệm dung lượng đĩa cực lớn)
skip-log-bin

# --- RAM & Caching ---
innodb_buffer_pool_size = ${buffer_pool}

# --- Ổn định & Kết nối ---
max_connections = ${max_conn}
wait_timeout = 300
interactive_timeout = 300
max_allowed_packet = 64M

# --- Tối ưu I/O (Ghi đĩa) ---
innodb_flush_method = O_DIRECT
# Giá trị 2 tối ưu cho Blog, giảm I/O đáng kể
innodb_flush_log_at_trx_commit = 2
# An toàn trên MariaDB 10.6+ (Ubuntu 22/24)
innodb_log_file_size = ${log_file_size}

# --- Tiết kiệm tài nguyên ---
performance_schema = ${perf_schema}
skip-name-resolve = 1

# --- Charset chuẩn WP ---
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
EOF

# --- 4. Thực thi & Backup ---
if [[ -f "$CNF_PATH" ]]; then
    cp "$CNF_PATH" "${BACKUP_DIR}/$(basename "$CNF_PATH").bak.${TIMESTAMP}"
fi

mv "$TMP_FILE" "$CNF_PATH"
chmod 644 "$CNF_PATH"

# --- 5. Restart & Rollback ---
echo "♻️  Đang khởi động lại MariaDB..."
systemctl daemon-reload 2>/dev/null || true

if systemctl restart mariadb; then
    echo "✅ THÀNH CÔNG! MariaDB đã chạy mượt mà."
    echo "👉 Kiểm tra RAM DB đang dùng: mysql -e \"SELECT ROUND(VARIABLE_VALUE/1024/1024) AS 'Buffer Pool (MB)' FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_bytes_data';\""
else
    echo "❌ THẤT BẠI! Đang khôi phục lại cấu hình cũ..."
    rm -f "$CNF_PATH"
    
    if [[ -f "${BACKUP_DIR}/$(basename "$CNF_PATH").bak.${TIMESTAMP}" ]]; then
        mv "${BACKUP_DIR}/$(basename "$CNF_PATH").bak.${TIMESTAMP}" "$CNF_PATH"
        echo "✅ Đã khôi phục file cấu hình cũ."
    fi

    if systemctl restart mariadb; then
        echo "✅ MariaDB đã hoạt động trở lại (Reverted)."
    else
        echo "☠️ LỖI NGHIÊM TRỌNG: MariaDB chết hẳn. Check ngay: journalctl -xeu mariadb"
    fi
    exit 1
fi