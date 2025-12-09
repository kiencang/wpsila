#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# A. Màu sắc cho thông báo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# B. KIỂM TRA QUYỀN ROOT
if [[ $EUID -ne 0 ]]; then
   echo "Loi: Script nay phai duoc chay voi quyen root (sudo)."
   exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- ĐẢM BẢO LOG FOLDER TỒN TẠI ---
# Tạo thư mục nếu chưa có (-p giúp không báo lỗi nếu đã có)
mkdir -p /var/log/caddy
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- NHẬP THÔNG TIN ---
echo "========================================================"
echo "   SETUP ADMINER (PHP 8.3) & AUTO CADDY CONFIG"
echo "========================================================"
read -p "Nhap ten mien cho Adminer (VD: db.domain.com): " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    echo "Loi: Ten mien cho truy cap database khong duoc de trong."
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- CẤU HÌNH ---
PHP_SOCKET="/run/php/php8.3-fpm.sock"
INSTALL_DIR="/var/www/adminer"
CADDY_FILE="/etc/caddy/Caddyfile"

# Cố định cho cả 2 phần để đỡ rắc rối
USER_NAME="adminer_db"

# Tạo mật khẩu
DB_PASS=$(openssl rand -base64 12)
WEB_PASS=$(openssl rand -base64 12)

# --- 1. KIỂM TRA MÔI TRƯỜNG ---
echo "[1/4] Kiem tra moi truong PHP 8.3..."
if [ ! -S "$PHP_SOCKET" ]; then
    echo "Loi: Khong tim thay socket tai $PHP_SOCKET."
    exit 1
fi
echo "-> OK."

# --- 2. CÀI ĐẶT ADMINER ---
echo "[2/4] Dang tai Adminer..."
mkdir -p "$INSTALL_DIR"
rm -f "$INSTALL_DIR/index.php"

# SỬA LỖI: Dùng link chính chủ Adminer.org để luôn lấy bản mới nhất & bỏ -q để hiện tiến trình
echo "  -> Dang tai source code..."
if wget -O "$INSTALL_DIR/index.php" "https://www.adminer.org/latest-mysql.php"; then
    echo "  -> Tai Adminer thanh cong."
else
    echo "Loi: Khong the tai Adminer tu adminer.org"
    exit 1
fi

# Gán quyền sở hữu cho user và group www-data
chown -R www-data:www-data "$INSTALL_DIR"

# Phân quyền
chmod 755 "$INSTALL_DIR"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- 3. TẠO USER MARIADB ---
echo "[3/4] Dang cau hinh User MariaDB..."
if ! systemctl is-active --quiet mariadb; then
    systemctl start mariadb
fi

mysql -e "CREATE USER IF NOT EXISTS '${USER_NAME}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -e "ALTER USER '${USER_NAME}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON *.* TO '${USER_NAME}'@'localhost' WITH GRANT OPTION;"
mysql -e "FLUSH PRIVILEGES;"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- 4. TỰ ĐỘNG CẤU HÌNH CADDY (DÙNG EOF) ---
echo "[4/4] Dang xu ly Caddyfile..."

if ! command -v caddy &> /dev/null; then
    echo "Loi: Caddy chua duoc cai dat."
    exit 1
fi

# Tạo file backup cho caddyfile
# Lấy dấu thời gian
TIMESTAMP=$(date +%s)

# Tạo backup bằng lệnh copy
echo "Dang tao file backup cho Caddyfile"
BACKUP_FILE="${CADDY_FILE}.bak_${TIMESTAMP}"

# Kiểm tra tồn tại của thư mục adminer
if grep -q "$INSTALL_DIR" "$CADDY_FILE"; then
    echo "CANH BAO: Duong dan '$INSTALL_DIR' da co trong Caddyfile."
    echo "-> Da BO QUA viec chen de tranh trung lap."
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
        output file /var/log/caddy/adminer_access.log {
            roll_size 10mb
            roll_keep 10
        }
    }
}
EOF

    echo "-> Da them cau hinh vao Caddyfile."
    
    # Format và Reload
    caddy fmt --overwrite "$CADDY_FILE"
	
	# Kiểm tra tính hợp lệ của file Caddydile
	if ! sudo caddy validate --config "$CADDY_FILE" --adapter caddyfile > /dev/null 2>&1; then
		echo -e "${RED}CANH BAO: File Caddyfile bi loi cu phap!${NC}"
		
		# In ra lỗi cụ thể cho người dùng xem sai ở đâu
		sudo caddy validate --config "$CADDY_FILE" --adapter caddyfile
		
		echo -e "${YELLOW}Dang khoi phuc lai file ban dau...${NC}"
		
		if [ -f "$BACKUP_FILE" ]; then
			sudo cp "$BACKUP_FILE" "$CADDY_FILE"
			echo "Da khoi phuc lai file goc an toan."
		fi
		
		exit 1
	fi	

	# Đến phần này nghĩa là file caddyfile không lỗi, có thể khởi động lại Caddy được.
	# Nếu không làm bước này, Caddy không thể ghi file vào đây được.
	# Gán quyền liên quan đến thư mục log.
	chown -R caddy:caddy /var/log/caddy
	chmod 755 /var/log/caddy	
	
    systemctl reload caddy
    echo "-> Da Reload Caddy."
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- XUẤT KẾT QUẢ ---
echo ""
echo "======================================="
echo "   CAI DAT THANH CONG!"
echo "======================================="
echo "URL: https://$DOMAIN_NAME"
echo ""
echo "[LOP 1] WEB LOGIN (Basic Auth):"
echo "   User: $USER_NAME"
echo "   Pass: $WEB_PASS"
echo ""
echo "[LOP 2] DATABASE LOGIN:"
echo "   User: $USER_NAME"
echo "   Pass: $DB_PASS"
echo "======================================="
# -------------------------------------------------------------------------------------------------------------------------------