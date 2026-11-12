#!/bin/bash

# -----------------------------------------------------------
# Tối ưu PHP INI
# File: tune_php.sh
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
# ==============================================================================
# SCRIPT TỰ ĐỘNG TỐI ƯU PHP INI (Dành cho Ubuntu)
# ==============================================================================

# Kiểm tra xem hệ thống có đang chạy PHP hay không
if ! command -v php &> /dev/null; then
    echo -e "${YELLOW}Khong tim thay PHP. Vui long cai dat PHP truoc.${NC}"
    exit 1
fi

# Thư mục chứa các file cấu hình bổ sung cho PHP-FPM
CONF_DIR="/etc/php/${PHP_VER}/fpm/conf.d"

# Kiểm tra xem thư mục có tồn tại không
if [[ ! -d "$CONF_DIR" ]]; then
    echo -e "${YELLOW}KHONG tim thay thu muc cau hinh: $CONF_DIR ${NC}"
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
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- KHỞI ĐỘNG LẠI PHP ---
echo ">> Dang reload lai PHP-FPM..."
if service php"${PHP_VER}"-fpm reload; then
    echo -e "${GREEN}THANH CONG! Cau hinh da duoc ap dung cho PHP $PHP_VER ${NC}"
    echo "File cau hinh: $CONFIG_FILE"
else
    echo -e "${RED}KHONG the reload PHP tu dong. Vui long chay lenh: service php${PHP_VER}-fpm reload ${NC}"
fi
echo "-------------------------------------------------------------"
# -------------------------------------------------------------------------------------------------------------------------------