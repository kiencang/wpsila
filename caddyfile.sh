# shellcheck shell=bash
# -----------------------------------------------------------
# MODULE: Caddyfile
# File: caddyfile.sh
# File này được nhúng vào script install_wp.sh
# -----------------------------------------------------------

# Đảm bảo file snippet dùng chung /etc/caddy/snippets/wp_common.conf luôn tồn tại
# (Tương thích ngược hoàn toàn cho các VPS đã cài LCMP từ phiên bản cũ trước khi nâng cấp)
WP_COMMON_SNIPPET_FILE="/etc/caddy/snippets/wp_common.conf"
read -r -d '' WP_COMMON_SNIPPET_CONTENT <<'EOSNIPPET' || true
# ==============================================================================
# WPSILA SHARED WORDPRESS CADDY SNIPPET (/etc/caddy/snippets/wp_common.conf)
# Chỉnh sửa tại file này sẽ tự động áp dụng cho toàn bộ website trên VPS
# ==============================================================================

encode zstd gzip

# Tăng giới hạn upload (đồng bộ với post_max_size=105M và upload_max_filesize=100M trong php.ini)
request_body {
    max_size 105MB
}

# --- SECURITY HEADERS ---
# Sau khi HTTPS đã chạy ổn định, có thể bỏ comment dòng Strict-Transport-Security
header {
    X-Content-Type-Options "nosniff"
    X-Frame-Options "SAMEORIGIN"
    X-XSS-Protection "0"
    Referrer-Policy "strict-origin-when-cross-origin"
    Permissions-Policy "camera=(), microphone=(), geolocation=(), browsing-topics=()"
    # Strict-Transport-Security "max-age=31536000; includeSubDomains"
    -Server
    -X-Powered-By
}

# --- CACHE CODE (CSS/JS) ---
# Không dùng immutable để tránh lỗi khi update code
@code_assets {
    file
    path *.css *.js
}
header @code_assets Cache-Control "public, max-age=604800"

# --- CACHE MEDIA (ẢNH/FONT/VIDEO) ---
# Dùng immutable vì file ảnh/font ít khi sửa nội dung mà giữ nguyên tên
@media_assets {
    file
    path *.ico *.gif *.jpg *.jpeg *.png *.svg *.woff *.woff2 *.ttf *.otf *.eot *.webp *.avif *.mp4 *.webm
}
header @media_assets Cache-Control "public, max-age=31536000, immutable"

# --- TRAFFIC CONTROL (RATE LIMIT LITE) ---
# 1. Chặn các Bot đốt tài nguyên & Crawler vô dụng (Bảo vệ CPU/RAM cho VPS 1-2GB)
# Ngăn chặn hàng loạt request từ các bot SEO/Scraper không cần thiết (vẫn giữ Google, Bing, Facebook, Zalo...)
@bad_bots {
    header User-Agent *MJ12bot*
    header User-Agent *PetalBot*
    header User-Agent *DotBot*
    header User-Agent *SemrushBot*
    header User-Agent *AhrefsBot*
    header User-Agent *BLEXBot*
    header User-Agent *Barkrowler*
    header User-Agent *Bytespider*
    header User-Agent *DataForSeoBot*
    header User-Agent *Maubot*
    header User-Agent *LieBaoFast*
    header User-Agent *Mb2345Browser*
}
respond @bad_bots 403

# 2. Chặn Scan User ngoài trang chủ (/?author=1), nhưng không chặn trong /wp-admin/*
@user_enum {
    not path /wp-admin/*
    query author=*
}
respond @user_enum 403

# 3. Chặn dò tìm danh sách User qua REST API (/wp-json/wp/v2/users & /?rest_route=/wp/v2/users) đối với khách chưa đăng nhập
# Vẫn cho phép Admin đã đăng nhập (có cookie wordpress_logged_in_) sử dụng Gutenberg Editor bình thường
@rest_user_enum_path {
    path /wp-json/wp/v2/users*
    not header_regexp Cookie wordpress_logged_in_
}
respond @rest_user_enum_path 403

@rest_user_enum_query {
    vars_regexp rest_enum {http.request.uri.query} (^|&)rest_route=(/|%2[fF])wp(/|%2[fF])v2(/|%2[fF])users
    not header_regexp Cookie wordpress_logged_in_
}
respond @rest_user_enum_query 403

# --- CHẶN THỰC THI PHP TRONG THƯ MỤC UPLOADS (MỌI CẤP THƯ MỤC CON & CHỐNG BYPASS PATH_INFO) ---
@uploads_php {
    path_regexp (?i)^/wp-content/uploads/.*\.(php[0-9]?|phtml|phar|inc)(/|$)
}
respond @uploads_php 404

# --- CHẶN TRUY CẬP FILE ẨN (.git, .env, .htaccess...) Ở MỌI THƯ MỤC CON (TRỪ /.well-known/* CHO SSL) ---
@hidden_files {
    not path /.well-known/*
    path */.*
}
respond @hidden_files 404

# --- CHẶN FILE HỆ THỐNG NHẠY CẢM (SECURITY BLOCK) ---
@forbidden {
    # 1. Block System Files
    path /wp-config.php*
    path /readme.html
    path /license.txt

    # 2. Block xmlrpc & public wp-cron (wpsila đã chạy wp-cron qua System Cron CLI)
    path /xmlrpc.php
    path /wp-cron.php

    # 3. Block Backups & Logs
    path *.sql *.bak *.log *.old *.swp
}
respond @forbidden 404
EOSNIPPET

if [[ -d "/etc/caddy" && -w "/etc/caddy" ]] && [[ ! -f "$WP_COMMON_SNIPPET_FILE" ]]; then
    mkdir -p /etc/caddy/snippets
    printf '%s\n' "$WP_COMMON_SNIPPET_CONTENT" > "$WP_COMMON_SNIPPET_FILE"
fi

if [[ "${WP_SNIPPET_ONLY:-0}" != "1" ]]; then
read -r -d '' CONTENT <<EOF || true
# 1. Chuyen huong $RED_DOMAIN ve $DOMAIN
$RED_DOMAIN {
    redir https://$DOMAIN{uri} permanent
}

# 2. Cau hinh chinh cho $DOMAIN
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
fi
