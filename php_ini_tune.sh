#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# Định nghĩa file cấu hình
PHP_VER="8.3" 
PHP_INI_FILE="/etc/php/${PHP_VER}/fpm/conf.d/99-wpsila-php.ini"

# Chạy lệnh
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/php_ini_tune.sh | bash

echo ">> Đang tạo cấu hình PHP tối ưu cho Blog & Media..."

cat > "${PHP_INI_FILE}" <<EOF
; ==============================================================================
; WP SILA PHP TUNER (BLOG EDITION)
; Target: Blog 1000+ posts | Image Compression | Backup Safe
; ==============================================================================

[opcache]
; Giữ 128MB là chuẩn. Blog ít khi dùng hết số này, nhưng giảm xuống 64MB tiết kiệm không đáng kể.
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=16

; Blog (kể cả 1000 bài) có lượng file code PHP ít hơn Shop nhiều. 
; Đặt 10,000 là con số tối ưu để không lãng phí tài nguyên quản lý cache.
opcache.max_accelerated_files=10000

; Tự động check code mới sau 2s.
opcache.revalidate_freq=2
opcache.validate_timestamps=1
opcache.enable_cli=0

[PHP]
; ========= Xử lý File & Tốc độ =========
; 4MB cache đường dẫn là đủ cho cấu trúc thư mục của Blog
realpath_cache_size=4096k
realpath_cache_ttl=600

; ========= Tài nguyên (Resource Limits) =========
; Blog 1000 bài chạy 256M là rất dư dả và an toàn.
; Nếu VPS quá yếu (1GB RAM), có thể giảm xuống 192M, nhưng 256M là chuẩn an toàn.
memory_limit=256M

; ========= Tối ưu cho Backup & Nén ảnh =========
; 100MB đủ để upload hầu hết file backup của Blog hoặc ảnh gốc cực lớn.
upload_max_filesize=100M
post_max_size=100M

; Tăng timeout lên 300s (5 phút) là CHÌA KHÓA.
; Khi nén hàng loạt ảnh hoặc restore DB lớn, tiến trình cần sống lâu hơn mặc định.
max_execution_time=300
max_input_time=300

; 2000 biến là đủ cho các menu phức tạp của Blog tin tức.
max_input_vars=2000

; ========= Bảo mật & Tương thích =========
expose_php=0
session.use_strict_mode=1
session.cookie_httponly=1
session.cookie_samesite=Lax
session.gc_maxlifetime=86400

; ========= QUAN TRỌNG: Cấp quyền cho Plugin =========
; Đã MỞ: exec, passthru, shell_exec (Cần thiết cho Image Optimizers & Backup)
; Chỉ CHẶN: system và các hàm process control (nguy hiểm & blog không dùng)
disable_functions = system,pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_get_handler,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,show_source,proc_open,popen

; ========= Encoding =========
default_charset = "UTF-8"
EOF

# Copy sang CLI nếu cần dùng WP-CLI ổn định
# cp "${PHP_INI_FILE}" "/etc/php/${PHP_VER}/cli/conf.d/99-wpsila-php.ini"

echo "✅ Đã tạo cấu hình PHP cho Blog (Hỗ trợ tốt Backup & Nén ảnh)."