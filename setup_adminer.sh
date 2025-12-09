#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# --- KIỂM TRA QUYỀN ROOT ---
if [[ $EUID -ne 0 ]]; then
   echo "Lỗi: Script này phải được chạy với quyền root (sudo)."
   exit 1
fi

# --- ĐẢM BẢO LOG FOLDER TỒN TẠI ---
# Tạo thư mục nếu chưa có (-p giúp không báo lỗi nếu đã có)
mkdir -p /var/log/caddy


# --- NHẬP THÔNG TIN ---
echo "========================================================"
echo "   SETUP ADMINER (PHP 8.3) & AUTO CADDY CONFIG"
echo "========================================================"
read -p "Nhập tên miền cho Adminer (VD: db.domain.com): " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    echo "Lỗi: Bạn chưa nhập tên miền."
    exit 1
fi

# --- CẤU HÌNH ---
PHP_SOCKET="/run/php/php8.3-fpm.sock"
INSTALL_DIR="/var/www/adminer"
CADDY_FILE="/etc/caddy/Caddyfile"
USER_NAME="adminer"

# Tạo mật khẩu
DB_PASS=$(openssl rand -base64 12)
WEB_PASS=$(openssl rand -base64 12)

# --- 1. KIỂM TRA MÔI TRƯỜNG ---
echo "[1/4] Kiểm tra môi trường PHP 8.3..."
if [ ! -S "$PHP_SOCKET" ]; then
    echo "Lỗi: Không tìm thấy socket tại $PHP_SOCKET."
    exit 1
fi
echo "-> OK."

# --- 2. CÀI ĐẶT ADMINER ---
echo "[2/4] Đang tải Adminer..."
mkdir -p "$INSTALL_DIR"
rm -f "$INSTALL_DIR/index.php"

# SỬA LỖI: Dùng link chính chủ Adminer.org để luôn lấy bản mới nhất & bỏ -q để hiện tiến trình
echo "  -> Đang tải source code..."
if wget -O "$INSTALL_DIR/index.php" "https://www.adminer.org/latest-mysql.php"; then
    echo "  -> Tải Adminer thành công."
else
    echo "Lỗi: Không thể tải Adminer từ adminer.org"
    exit 1
fi

echo "  -> Đang tải giao diện (CSS)..."
# Link CSS này vẫn ổn, nhưng nên thêm check lỗi
if wget -O "$INSTALL_DIR/adminer.css" "https://raw.githubusercontent.com/pepa-linha/adminer-theme-hydra/master/adminer.css"; then
    echo "  -> Tải CSS thành công."
else
    echo "Cảnh báo: Không thể tải CSS (Giao diện sẽ về mặc định)."
    # Không exit ở đây vì CSS không quá quan trọng
fi

chown -R www-data:www-data "$INSTALL_DIR"
chmod 755 "$INSTALL_DIR"

# --- 3. TẠO USER MARIADB ---
echo "[3/4] Đang cấu hình User MariaDB..."
if ! systemctl is-active --quiet mariadb; then
    systemctl start mariadb
fi

mysql -e "CREATE USER IF NOT EXISTS '${USER_NAME}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -e "ALTER USER '${USER_NAME}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON *.* TO '${USER_NAME}'@'localhost' WITH GRANT OPTION;"
mysql -e "FLUSH PRIVILEGES;"

# --- 4. TỰ ĐỘNG CẤU HÌNH CADDY (DÙNG EOF) ---
echo "[4/4] Đang xử lý Caddyfile..."

if ! command -v caddy &> /dev/null; then
    echo "Lỗi: Caddy chưa được cài đặt."
    exit 1
fi

# Kiểm tra tồn tại
if grep -q "$INSTALL_DIR" "$CADDY_FILE"; then
    echo "CẢNH BÁO: Đường dẫn '$INSTALL_DIR' đã có trong Caddyfile."
    echo "-> Đã BỎ QUA việc chèn để tránh trùng lặp."
else
    # Hash password
    HASHED_PASS=$(caddy hash-password --plaintext "$WEB_PASS")

    # Dùng EOF để chèn nội dung vào cuối file Caddyfile
    # Lưu ý: Các biến $VAR vẫn được hiểu bên trong EOF
    cat >> "$CADDY_FILE" <<EOF 

$DOMAIN_NAME {
    root * $INSTALL_DIR
    php_fastcgi unix/$PHP_SOCKET
    file_server

    # Bao mat 2 lop (Basic Auth)
    basicauth / {
        $USER_NAME $HASHED_PASS
    }

    # An file he thong
    @hiddenFiles {
        path */.*
    }
    respond @hiddenFiles 404
    
    # Log rieng biet
    log {
        output file /var/log/caddy/adminer_access.log
    }
}
EOF

    echo "-> Đã thêm cấu hình vào Caddyfile."
    
    # Format và Reload
    caddy fmt --overwrite "$CADDY_FILE"

	# Nếu không làm bước này, Caddy không thể ghi file vào đây được
	# Gán quyền liên quan đến thư mục log
	chown -R caddy:caddy /var/log/caddy
	chmod 755 /var/log/caddy	
	
    systemctl reload caddy
    echo "-> Đã Reload Caddy."
fi

# --- XUẤT KẾT QUẢ ---
echo ""
echo "========================================================"
echo "   CÀI ĐẶT THÀNH CÔNG!"
echo "========================================================"
echo "URL: https://$DOMAIN_NAME"
echo ""
echo "[LỚP 1] WEB LOGIN (Basic Auth):"
echo "   User: $USER_NAME"
echo "   Pass: $WEB_PASS"
echo ""
echo "[LỚP 2] DATABASE LOGIN:"
echo "   User: $USER_NAME"
echo "   Pass: $DB_PASS"
echo "========================================================"