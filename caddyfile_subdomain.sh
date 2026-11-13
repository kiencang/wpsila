# shellcheck shell=bash
# -----------------------------------------------------------
# MODULE: Caddyfile cho subdomain
# File: caddyfile_subdomain.sh
# File này được nhúng vào script install_wp.sh
# -----------------------------------------------------------

# Đảm bảo file snippet dùng chung /etc/caddy/snippets/wp_common.conf luôn tồn tại
# (Tương thích ngược hoàn toàn cho các VPS đã cài LCMP từ phiên bản cũ trước khi nâng cấp)
WP_COMMON_SNIPPET_FILE="/etc/caddy/snippets/wp_common.conf"
if [[ -d "/etc/caddy" && -w "/etc/caddy" ]] && [[ ! -f "$WP_COMMON_SNIPPET_FILE" ]]; then
    # Nạp nội dung snippet chuẩn từ caddyfile.sh (chế độ chỉ tạo snippet, không đọc biến RED_DOMAIN)
    if [[ -f "${SCRIPT_WPSILA_DIR:-.}/caddyfile.sh" ]]; then
        WP_SNIPPET_ONLY=1
        source "${SCRIPT_WPSILA_DIR:-.}/caddyfile.sh"
        unset WP_SNIPPET_ONLY
    fi
fi

read -r -d '' CONTENT <<EOF || true
# Subdomain khong can chuyen huong www
$DOMAIN {
    root * /var/www/$DOMAIN/public_html

    # Log: Tu dong xoay vong
    log {
        output file /var/www/$DOMAIN/logs/access.log {
            roll_size 10mb
            roll_keep 10
        }
    }

    # Nhung cau hinh bao mat & toi uu chung cho toan bo website WordPress
    import /etc/caddy/snippets/wp_common.conf

    # PHP FastCGI, lay dong theo phien ban PHP o dau file lenh
    php_fastcgi unix//run/php/php${PHP_VER}-fpm.sock

    file_server
}
EOF
