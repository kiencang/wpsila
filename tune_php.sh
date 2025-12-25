#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# Kiểm tra quyền root & nâng quyền
if [[ $EUID -ne 0 ]]; then
   # Thêm tham số -E cho sudo để giữ lại các biến môi trường (nếu có)
   sudo -E "$0" "$@"
   exit $?
fi

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
# Lấy đường dẫn tuyệt đối của thư mục chứa file script đang chạy
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# Trỏ vào file config nằm cùng thư mục đó
WPSILA_CONFIG_FILE="$SCRIPT_DIR/wpsila.conf"

# 3. Kiểm tra và nạp file config
if [[ -f "$WPSILA_CONFIG_FILE" ]]; then
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

# ==============================================================================
# SCRIPT TỰ ĐỘNG TỐI ƯU PHP INI (Dành cho Ubuntu)
# ==============================================================================

# Kiểm tra xem hệ thống có đang chạy PHP hay không
if ! command -v php &> /dev/null; then
    echo "Không tìm thấy PHP. Vui lòng cài đặt PHP trước."
    exit 1
fi

# Thư mục chứa các file cấu hình bổ sung cho PHP-FPM
CONF_DIR="/etc/php/${PHP_VER}/fpm/conf.d"

# Kiểm tra xem thư mục có tồn tại không
if [[ ! -d "$CONF_DIR" ]]; then
    echo "KHONG tim thay thu muc cau hinh: $CONF_DIR"
    echo ">> Script nay chi ho tro Ubuntu/Debian voi cau hinh thu muc chuan."
    exit 1
fi

# --- TẠO FILE CẤU HÌNH (GHI ĐÈ) ---
# Đặt tên cho file và lưu nó vào thư mục cấu hình bổ sung
CONFIG_FILE="${CONF_DIR}/99-wpsila-phpini-tune.ini"

echo ">> Dang tao file cau hinh toi uu cho WordPress..."

cat > "${CONFIG_FILE}" <<EOF
; ==============================================================================
; Target: Low-end VPS | WordPress Blog
; ==============================================================================

[opcache]
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.validate_timestamps=1
opcache.save_comments=1
opcache.enable_cli=0

[PHP]
; Cache đường dẫn
realpath_cache_size=4096k
realpath_cache_ttl=600

; RAM & Upload
memory_limit=256M
upload_max_filesize=100M
post_max_size=100M

; Timeouts (Tăng để backup không lỗi)
max_execution_time=300
max_input_time=300
max_input_vars=3000

; Security Headers
expose_php=0
session.use_strict_mode=1
session.cookie_httponly=1

; Functions (Chỉ giữ lại exec cho plugin nén ảnh/backup)
disable_functions = system,passthru,shell_exec,pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_get_handler,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,show_source,proc_open,popen
EOF

# --- KHỞI ĐỘNG LẠI PHP ---
echo ">> Dang reload lai PHP-FPM..."
if service php"${PHP_VER}"-fpm reload; then
    echo -e "${GREEN}Hoan tat! Cau hinh da duoc ap dung cho PHP $PHP_VER.${NC}"
    echo "File cau hinh: $CONFIG_FILE"
else
    echo -e "${RED}KHONG the reload PHP tu dong. Vui long chay lenh: service php${PHP_VER}-fpm reload${NC}"
fi