#!/bin/bash

# Dừng script nếu lỗi
set -e

# Màu sắc
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# File cấu hình Caddy
CADDY_FILE="/etc/caddy/Caddyfile"
MARKER="# Caddyfile wpSila"

# Kiểm tra quyền root (Bắt buộc vì ghi vào /etc/caddy)
if [ "$EUID" -ne 0 ]; then
  echo "Vui long chay script voi quyen root (sudo)."
  exit 1
fi

# --- BƯỚC 1: NHẬP DOMAIN ---
echo -e "${GREEN}>>> Nhap domain ban muon cau hinh (vi du: example.com):${NC}"
read -p "Domain: " INPUT_DOMAIN < /dev/tty

# Xử lý chuỗi: Xóa toàn bộ khoảng trắng và chuyển về chữ thường
DOMAIN=$(echo "$INPUT_DOMAIN" | tr -d ' ' | tr '[:upper:]' '[:lower:]')

if [ -z "$DOMAIN" ]; then
    echo "Loi: Ban chua nhap domain."
    exit 1
fi

echo -e "${GREEN}>>> Dang tao cau hinh cho: $DOMAIN${NC}"

# --- BƯỚC 2: CHUẨN BỊ NỘI DUNG ---
# Lưu ý: Sử dụng <<EOF (không ngoặc kép) để Bash thay thế được biến ${DOMAIN}
read -r -d '' CADDY_CONTENT <<EOF

# 1. Chuyen huong www ve non-www
www.${DOMAIN} {
    redir https://${DOMAIN}{uri} permanent
}

# 2. Cau hinh chinh
${DOMAIN} {
    # Thay doi email cua ban de nhan thong bao SSL
    # tls admin@${DOMAIN}
    
    root * /var/www/${DOMAIN}/public_html
    encode zstd gzip

    # Log file
    log {
        output file /var/www/${DOMAIN}/logs/access.log {
            roll_size 10mb
            roll_keep 10
        }
    }

    # PHP FastCGI (Dam bao PHP 8.3 da duoc cai dat)
    php_fastcgi unix//run/php/php8.3-fpm.sock

    # File Server
    file_server

    # Gioi han upload
    request_body {
        max_size 50MB
    }

    # --- SECURITY HEADERS ---
    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
        Permissions-Policy "camera=(), microphone=(), geolocation=()"
        -Server 
    }

    # --- CACHE ---
    @code_assets {
        file
        path *.css *.js
    }
    header @code_assets Cache-Control "public, max-age=604800, immutable"

    @media_assets {
        file
        path *.ico *.gif *.jpg *.jpeg *.png *.svg *.woff *.woff2 *.webp
    }
    header @media_assets Cache-Control "public, max-age=31536000, immutable"

    # --- BLOCK SENSITIVE FILES ---
    @forbidden {
        path /wp-content/uploads/*.php
        path /wp-includes/*.php
        path /wp-config.php
        path /.htaccess
        path /.git
        path /.env
        path *.sql
        path *.bak
        path *.log
    }
    respond @forbidden 404
}

$MARKER
EOF

# --- BƯỚC 3: KIỂM TRA VÀ GHI FILE ---

# Kiểm tra xem file Caddyfile đã tồn tại chưa để tránh lỗi grep
if [ ! -f "$CADDY_FILE" ]; then
    touch "$CADDY_FILE"
fi

if grep -q "$MARKER" "$CADDY_FILE"; then
    echo -e "${YELLOW}Phat hien dau hieu '$MARKER'.${NC}"
    echo -e "${GREEN}>>> Dang bo sung cau hinh moi vao cuoi file...${NC}"
    
    # Nối thêm vào cuối file
    echo "$CADDY_CONTENT" | tee -a "$CADDY_FILE" > /dev/null
else
    echo -e "${YELLOW}Khong tim thay '$MARKER' (day la cai dat lan dau).${NC}"
    echo -e "${GREEN}>>> Dang xoa file cu va ghi noi dung moi...${NC}"
    
    # Ghi đè toàn bộ file (Logic gốc của bạn)
    echo "$CADDY_CONTENT" | tee "$CADDY_FILE" > /dev/null
fi