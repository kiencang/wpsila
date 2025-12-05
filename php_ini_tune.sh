#!/bin/bash
set -euo pipefail

# --- TỰ ĐỘNG PHÁT HIỆN PHP VERSION ---
# Lấy version PHP đang chạy (dạng 8.0, 8.1, 8.3...)
if ! command -v php &> /dev/null; then
    echo "❌ Không tìm thấy PHP. Vui lòng cài đặt PHP trước."
    exit 1
fi

CURRENT_PHP_VER=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
echo ">> Phát hiện phiên bản PHP: $CURRENT_PHP_VER"

CONF_DIR="/etc/php/${CURRENT_PHP_VER}/fpm/conf.d"

# Kiểm tra xem thư mục có tồn tại không
if [ ! -d "$CONF_DIR" ]; then
    echo "❌ Không tìm thấy thư mục cấu hình: $CONF_DIR"
    echo ">> Script này chỉ hỗ trợ Ubuntu/Debian với cấu trúc thư mục chuẩn."
    exit 1
fi

PHP_INI_FILE="${CONF_DIR}/99-wpsila-tuned.ini"

# --- TẠO FILE CẤU HÌNH ---
echo ">> Đang tạo cấu hình tối ưu cho WordPress..."

cat > "${PHP_INI_FILE}" <<EOF
; ==============================================================================
; TUNED BY AI EXPERT (Based on WPSILA)
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

; Functions (Giữ lại exec/shell_exec cho plugin nén ảnh/backup)
disable_functions = system,pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_get_handler,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,show_source,proc_open,popen
EOF

# --- KHỞI ĐỘNG LẠI PHP ---
echo ">> Đang reload lại PHP-FPM..."
if service php${CURRENT_PHP_VER}-fpm reload; then
    echo "✅ Hoàn tất! Cấu hình đã được áp dụng cho PHP $CURRENT_PHP_VER."
    echo "   File cấu hình: $PHP_INI_FILE"
else
    echo "⚠️  Không thể reload PHP tự động. Vui lòng chạy lệnh: service php${CURRENT_PHP_VER}-fpm reload"
fi