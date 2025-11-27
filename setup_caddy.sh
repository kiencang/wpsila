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
$DOMAIN {
    # Cấu hình cho WordPress
    encode gzip
    php_fastcgi unix//run/php/php-fpm.sock
    file_server
    
    # Đánh dấu marker để nhận diện sau này
    $MARKER
}
EOF

# 3. Thực hiện Logic kiểm tra
# grep -q: Chế độ im lặng (quiet), chỉ trả về đúng (0) hoặc sai (1), không in ra màn hình
# 2>/dev/null: Ẩn lỗi nếu file không tồn tại
if grep -q "$MARKER" "$CADDY_FILE" 2>/dev/null; then
    
    echo "TIM THAY marker '$MARKER'. Dang noi noi dung vao cuoi file..."
    
    # Nối tiếp vào cuối file (Append)
    echo "$CONTENT" >> "$CADDY_FILE"

else
    
    echo "KHONG TIM THAY marker '$MARKER'. Dang xoa cu va tao file moi..."
    
    # Ghi đè file (Overwrite)
    echo "$CONTENT" > "$CADDY_FILE"

fi

# 4. Format và Reload lại Caddy
echo "Đang kiểm tra và reload Caddy..."
caddy fmt --overwrite "$CADDY_FILE" > /dev/null 2>&1
#sudo systemctl reload caddy

echo "Hoàn tất!"