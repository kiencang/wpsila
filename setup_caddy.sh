#!/bin/bash

# Chạy lệnh
# curl -sL https://raw.githubusercontent.com/kiencang/wpcaddydemo/refs/heads/main/setup_caddy.sh | bash

# 1. Khai báo biến đường dẫn và Marker
CADDY_FILE="/etc/caddy/Caddyfile"
MARKER="#wpSila_kiencang"
DOMAIN="website-cua-ban.com"

# 2. Định nghĩa nội dung bạn muốn thêm vào
# Lưu ý: Tôi thêm $MARKER vào nội dung để lần sau chạy nó sẽ nhận diện được
read -r -d '' CONTENT <<EOF
# 1. Chuyen huong www ve non-www 
www.$DOMAIN {
    redir https://$DOMAIN{uri} permanent
}

# 2. Cau hinh chinh
$DOMAIN {
    root * /var/www/$DOMAIN/public_html
    encode zstd gzip

    # --- Cai tien 1: Log: De sua loi khi can ---
    log {
        output file /var/www/$DOMAIN/logs/access.log {
            roll_size 10mb
            roll_keep 10
        }
    }

    # PHP FastCGI
    php_fastcgi unix//run/php/php8.3-fpm.sock

    # File Server
    file_server

    # Tang gioi han upload 
    request_body {
        max_size 50MB
    }

    # --- Cai tien 2: SECURITY HEADERS (bao mat trinh duyet) ---
    header {
        # chong lai clickjacking (nguoi khac nhung web cua ban vao iframe)
        X-Frame-Options "SAMEORIGIN"
        # chong lai MIME sniffing
        X-Content-Type-Options "nosniff"
        # bao ma XSS co ban
        X-XSS-Protection "1; mode=block"
        # Ep trinh duyet chi dung HTTPS (HSTS), cai nay la tuy chon
        # Mac dinh tat, muon bat thi bo dau # phia truoc Strict-Transport-Security...
        # Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    }

# --- Cai tien 3: Cache nang cao ---

    # Nhom 1: CSS va JS (Cache 1 tuan - 604800s)
    # Danh cho truong hop hay sua giao dien, code
    @code_assets {
        file
        path *.css *.js
    }
    header @code_assets Cache-Control "public, max-age=604800"

    # Nhom 2: Image, Font, Icon (Cache 1 nam - 31536000s)
    # Nhung file nay rat it khi thay doi noi dung, nen de lau toi da
    @media_assets {
        file
        path *.ico *.gif *.jpg *.jpeg *.png *.svg *.woff *.woff2 *.webp
    }
    header @media_assets Cache-Control "public, max-age=31536000"

    # --- Cai tien 4: chan file mo rong (bao mat file nhay cam) ---
    @forbidden {
        # chan thuc thi PHP o noi khong can thiet
        path /wp-content/uploads/*.php
        path /wp-includes/*.php
        # chan file cau hinh & file ma nguon he thong
        path /wp-config.php
        path /.htaccess
        path /.git
        path /.env
        path *.sql
        path *.bak
    }
    respond @forbidden 404
}
    # Đánh dấu marker để nhận diện sau này
    $MARKER
EOF

# 3. Thực hiện Logic kiểm tra
# grep -q: Chế độ im lặng (quiet), chỉ trả về đúng (0) hoặc sai (1), không in ra màn hình
# 2>/dev/null: Ẩn lỗi nếu file không tồn tại
# Kiểm tra xem domain này ĐÃ TỒN TẠI trong file chưa để tránh trùng lặp
if grep -wq "$DOMAIN" "$CADDY_FILE" 2>/dev/null; then
    echo -e "${RED}Cảnh báo: Domain $DOMAIN đã tồn tại trong Caddyfile.${NC}"
    echo -e "${YELLOW}Bỏ qua việc ghi file để tránh lỗi trùng lặp (Duplicate Site).${NC}"
    # Bạn có thể chọn exit hoặc tiếp tục reload nếu muốn
    # exit 0 
else
	if grep -q "$MARKER" "$CADDY_FILE" 2>/dev/null; then
		
		echo "TIM THAY marker '$MARKER'. Dang noi noi dung vao cuoi file..."
		
		# Nối tiếp vào cuối file (Append)
		echo "$CONTENT" >> "$CADDY_FILE"

	else
		
		echo "KHONG TIM THAY marker '$MARKER'. Dang xoa cu va tao file moi..."
		
		# Ghi đè file (Overwrite)
		echo "$CONTENT" > "$CADDY_FILE"

	fi
fi

echo "Dang kiem tra va reload Caddy..."
# 4. Format
caddy fmt --overwrite "$CADDY_FILE" > /dev/null 2>&1

#5. Reload lại Caddy

echo "Hoàn tất!"