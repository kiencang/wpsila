#!/bin/bash

# Dừng script ngay nếu có lỗi
set -e

# Chạy lệnh
# curl -sL https://raw.githubusercontent.com/kiencang/wpcaddydemo/refs/heads/main/setup_caddy.sh | bash

# --- CẤU HÌNH ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CADDY_FILE="/etc/caddy/Caddyfile"
MARKER="# Caddyfile wpSila"

# Kiểm tra quyền root (Bắt buộc)
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Loi: Vui long chay script voi quyen root (sudo).${NC}"
  exit 1
fi

# --- BƯỚC 1: NHẬP DOMAIN ---
echo -e "${GREEN}>>> Nhap domain ban muon cau hinh (vi du: example.com):${NC}"
read -p "Domain: " INPUT_DOMAIN < /dev/tty

# Xử lý chuỗi: Xóa toàn bộ khoảng trắng và chuyển về chữ thường
DOMAIN=$(echo "$INPUT_DOMAIN" | tr -d ' ' | tr '[:upper:]' '[:lower:]')

if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}Loi: Ban chua nhap domain.${NC}"
    exit 1
fi

# Kiểm tra sơ bộ định dạng domain (phải có dấu chấm)
if [[ "$DOMAIN" != *"."* ]]; then
    echo -e "${RED}Loi: Ten mien '$DOMAIN' khong hop le (thieu dau cham).${NC}"
    exit 1
fi

echo -e "${GREEN}>>> Dang chuan bi cau hinh cho: $DOMAIN${NC}"

# --- BƯỚC 2: CHUẨN BỊ NỘI DUNG ---
# Lưu ý: Dùng <<EOF (không ngoặc kép) để bash thay thế biến ${DOMAIN}
read -r -d '' CADDY_CONTENT <<'EOF'

# 1. Redirect www to non-www
www.${DOMAIN} {
    redir https://${DOMAIN}{uri} permanent
}

# 2. Main configuration
${DOMAIN} {
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

    # PHP FastCGI
    php_fastcgi unix//run/php/php8.3-fpm.sock

    # File Server
    file_server

    request_body {
        max_size 50MB
    }

    # Security Headers
    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
        Permissions-Policy "camera=(), microphone=(), geolocation=()"
        -Server 
    }

    # Cache Static Assets
    @code_assets {
        file
        path *.css *.js
    }
    header @code_assets Cache-Control "public, max-age=604800, immutable"

    # Cache Media Assets
    @media_assets {
        file
        path *.ico *.gif *.jpg *.jpeg *.png *.svg *.woff *.woff2 *.webp
    }
    header @media_assets Cache-Control "public, max-age=31536000, immutable"

    # Block Sensitive Files
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

# Tạo file nếu chưa tồn tại (để tránh lỗi grep)
if [ ! -f "$CADDY_FILE" ]; then
    echo -e "${YELLOW}File cau hinh chua ton tai, dang tao moi...${NC}"
    sudo touch "$CADDY_FILE"
fi

# Kiểm tra xem Marker đã có trong file chưa
if grep -q "$MARKER" "$CADDY_FILE"; then
    # TRƯỜNG HỢP 1: Đã có Marker -> Nối thêm vào cuối (Append)
    echo -e "${YELLOW}Phat hien dau hieu wpSila cu (Marker found).${NC}"
    echo -e "${GREEN}>>> Dang bo sung domain moi vao cuoi file...${NC}"
    
    # Dùng tee -a để nối thêm
    echo "$CADDY_CONTENT" | sudo tee -a "$CADDY_FILE" > /dev/null

else
    # TRƯỜNG HỢP 2: Không có Marker (Cài mới hoặc file mặc định) -> Ghi đè (Overwrite)
    echo -e "${YELLOW}Khong tim thay dau hieu script (Cai dat moi hoac file mac dinh).${NC}"
    
    # Backup file gốc nếu nó không trống
    if [ -s "$CADDY_FILE" ]; then
        echo -e "${YELLOW}>>> Dang backup Caddyfile goc thanh Caddyfile.bak...${NC}"
        sudo cp "$CADDY_FILE" "${CADDY_FILE}.bak"
    fi

    echo -e "${GREEN}>>> Dang XOA file cu va GHI DE noi dung moi...${NC}"
    
    # Dùng tee (không có -a) để ghi đè toàn bộ
    echo "$CADDY_CONTENT" | sudo tee "$CADDY_FILE" > /dev/null
fi