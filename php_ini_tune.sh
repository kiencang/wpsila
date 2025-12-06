#!/bin/bash
set -euo pipefail

# Phiên bản PHP hiện tại
PHP_VER="8.3"

# ==============================================================================
# SCRIPT TỰ ĐỘNG TỐI ƯU PHP INI (Dành cho Ubuntu)
# ==============================================================================

# Test lệnh
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/php_ini_tune.sh | sudo bash

# Kiểm tra xem hệ thống có đang chạy PHP hay không
if ! command -v php &> /dev/null; then
    echo "❌ Không tìm thấy PHP. Vui lòng cài đặt PHP trước."
    exit 1
fi

# Thư mục chứa các file cấu hình bổ sung cho PHP-FPM
CONF_DIR="/etc/php/${PHP_VER}/fpm/conf.d"

# Kiểm tra xem thư mục có tồn tại không
if [ ! -d "$CONF_DIR" ]; then
    echo "❌ KHONG tim thay thu muc cau hinh: $CONF_DIR"
    echo ">> Script nay chi ho tro Ubuntu/Debian voi cau hinh thu muc chuan."
    exit 1
fi

# Đặt tên cho file và lưu nó vào thư mục cấu hình bổ sung
PHP_INI_FILE="${CONF_DIR}/99-wpsila-tuned.ini"

# --- TẠO FILE CẤU HÌNH ---
echo ">> Dang tao file cau hinh toi uu cho WordPress..."

cat > "${PHP_INI_FILE}" <<EOF
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
if service php${PHP_VER}-fpm reload; then
    echo "✅ Hoan tat! Cau hinh da duoc ap dung cho PHP $PHP_VER."
    echo "   File cau hinh: $PHP_INI_FILE"
else
    echo "⚠️  KHONG the reload PHP tu dong. Vui long chay lenh: service php${PHP_VER}-fpm reload"
fi