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

# Tự động cân chỉnh dung lượng OPcache & Memory Limit ưu tiên cho WordPress Blog (đặc biệt trên VPS 1GB - 2GB RAM)
total_ram_kb=$(grep -i 'MemTotal' /proc/meminfo | awk '{print $2}')
total_ram_mb=$((total_ram_kb / 1024))

if (( total_ram_mb <= 1200 )); then
    # VPS 1GB RAM: Blog không dùng WooCommerce chỉ tốn ~35-50MB OPcache -> Đặt 96MB tiết kiệm 32MB RAM cho OS
    OPCACHE_MEM=96
    OPCACHE_STRINGS=12
    OPCACHE_FILES=10000
    PHP_MEM_LIMIT="192M"
elif (( total_ram_mb <= 2500 )); then
    # VPS 2GB RAM: Mức cân bằng lý tưởng cho 1-3 blog
    OPCACHE_MEM=128
    OPCACHE_STRINGS=16
    OPCACHE_FILES=16229
    PHP_MEM_LIMIT="256M"
else
    # VPS >= 4GB RAM
    OPCACHE_MEM=192
    OPCACHE_STRINGS=24
    OPCACHE_FILES=32531
    PHP_MEM_LIMIT="256M"
fi

echo ">> Dang tao file cau hinh toi uu cho WordPress Blog (OPcache: ${OPCACHE_MEM}MB, Memory Limit: ${PHP_MEM_LIMIT})..."

cat > "${CONFIG_FILE}" <<EOF
; ==============================================================================
; Target: Low-end VPS (1-2GB Priority) | WordPress Blog (RAM: ${total_ram_mb} MB)
; ==============================================================================

[opcache]
opcache.enable=1
opcache.memory_consumption=${OPCACHE_MEM}
opcache.interned_strings_buffer=${OPCACHE_STRINGS}
opcache.max_accelerated_files=${OPCACHE_FILES}
; Blog it thay doi file code, tang revalidate_freq len 10s de giam 5 lan so luot doc o cung (stat syscall)
opcache.revalidate_freq=10
opcache.validate_timestamps=1
opcache.save_comments=1
opcache.enable_cli=0

[PHP]
; Cache đường dẫn
realpath_cache_size=4096k
realpath_cache_ttl=600

; RAM & Upload (post_max_size lon hon upload_max_filesize 5MB de chua tron multipart form header)
memory_limit=${PHP_MEM_LIMIT}
upload_max_filesize=100M
post_max_size=105M

; Timeouts (Tăng để backup không lỗi)
max_execution_time=300
max_input_time=300
max_input_vars=3000

; Security Headers & Hardening (Vẫn giữ allow_url_fopen=1 để cài plugin/update tiện lợi)
expose_php=0
allow_url_include=0
session.use_strict_mode=1
session.cookie_httponly=1
session.cookie_samesite=Lax

; Functions (Chỉ giữ lại exec cho plugin nén ảnh/backup)
disable_functions = system,passthru,shell_exec,pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_get_handler,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,show_source,proc_open,popen
EOF
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- KHỞI ĐỘNG LẠI PHP ---
echo ">> Dang kiem tra va reload lai PHP-FPM..."
PHP_FPM_BIN=$(PATH="/usr/sbin:/sbin:$PATH" command -v "php-fpm${PHP_VER}" || true)
if [[ -n "$PHP_FPM_BIN" ]] && "$PHP_FPM_BIN" -t; then
    systemctl reload "php${PHP_VER}-fpm"
    echo -e "${GREEN}THANH CONG! Cau hinh da duoc ap dung cho PHP $PHP_VER ${NC}"
    echo "File cau hinh: $CONFIG_FILE"
else
    echo -e "${RED}Loi cau hinh PHP INI! Dang khoi phuc trang thai cu...${NC}"
    rm -f "${CONFIG_FILE}"
    exit 1
fi
echo "-------------------------------------------------------------"
# -------------------------------------------------------------------------------------------------------------------------------