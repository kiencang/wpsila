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
# B. KIỂM TRA QUYỀN
# NÂNG QUYỀN NẾU KHÔNG PHẢI LÀ ROOT (cho nhóm có quyền gọi sudo)
# 1. Kiểm tra xem đang chạy với quyền gì
if [[ $EUID -ne 0 ]]; then
   # 2. Nếu không phải root, tự động chạy lại script này bằng sudo
   # Thêm tham số -E cho sudo để giữ lại các biến môi trường (nếu có)
   sudo -E "$0" "$@"
   # 3. Thoát tiến trình cũ (không phải root) để tiến trình mới (có root) chạy
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# C. ĐẢM BẢO LOG FOLDER TỒN TẠI
# Tạo thư mục nếu chưa có (-p giúp không báo lỗi nếu đã có)
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy
chmod 755 /var/log/caddy	
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# D. NHẬP THÔNG TIN TÊN MIỀN CHO QUẢN TRỊ DATABASE
echo "========================================================"
echo "   SETUP ADMINER (PHP 8.3) & AUTO CADDY CONFIG"
echo "========================================================"
read -p "Nhap ten mien cho Adminer (VD: db.domain.com): " INPUT_DOMAIN

    # Xử lý chuỗi
    TEMP_DOMAIN=$(echo "$INPUT_DOMAIN" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    DOMAIN=$(echo "$TEMP_DOMAIN" | sed -e 's|^https\?://||' -e 's|/.*$||')
    
    # Validation cơ bản
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${RED}Loi: Dia chi khong duoc de trong!${NC}"
		exit 1
    elif [[ "$DOMAIN" != *"."* ]]; then
        echo -e "${RED}Loi: Dia chi '$DOMAIN' khong hop le (thieu dau cham).${NC}"
		exit 1
    else
        if [[ "$INPUT_DOMAIN" != "$DOMAIN" ]]; then
             echo -e "${GREEN}Script da tu dong chuan hoa input '${INPUT_DOMAIN}' thanh '${DOMAIN}'${NC}"
        fi
    fi

# Caddyfile	
CADDY_FILE="/etc/caddy/Caddyfile"	

# Kiểm tra sớm để tránh rác cài đặt
if grep -Eq "^[^#]*([[:space:]]|^)$DOMAIN([[:space:]]|:|\{|$)" "$CADDY_FILE"; then
    echo "CANH BAO: $DOMAIN da co trong Caddyfile."
    echo "-> Da BO QUA viec chen de tranh trung lap."
	exit 1	
fi	
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Dx. CẤU HÌNH PHIÊN BẢN PHP

# Dx1. Đặt giá trị mặc định (phòng hờ không tìm thấy file config / wpsila.conf)
DEFAULT_PHP_VER="8.3"

# Dx2. Định nghĩa đường dẫn file config 
# (Ví dụ: file config nằm cùng thư mục với script đang chạy)
# Dòng lệnh này đảm bảo biến SCRIPT_WPSILA_DIR luôn là đường dẫn tuyệt đối tới thư mục chứa file này
# Xác định thư mục
SCRIPT_WPSILA_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Trỏ vào file config nằm cùng thư mục đó
WPSILA_CONFIG_FILE="$SCRIPT_WPSILA_DIR/wpsila.conf"

# Dx3. Kiểm tra và nạp file config
if [[ -f "$WPSILA_CONFIG_FILE" ]]; then
    # Lệnh 'source' hoặc dấu chấm '.' sẽ đọc biến từ file kia vào script này
    source "$WPSILA_CONFIG_FILE"
    echo -e "${GREEN}Da tim thay file cau hinh: ${WPSILA_CONFIG_FILE}${NC}"
else
    echo -e "${YELLOW}Khong tim thay file config. Su dung phien ban mac dinh.${NC}"
fi

# Dx4. Chốt phiên bản cuối cùng
# Cú pháp ${BIEN_1:-$BIEN_2} nghĩa là: Nếu BIEN_1 rỗng (chưa set trong config), thì lấy BIEN_2
PHP_VER="${PHP_VER:-$DEFAULT_PHP_VER}"

echo "Phien ban PHP: $PHP_VER"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# D. CẤU HÌNH
# Gán socket phiên bản PHP tương ứng
PHP_SOCKET="/run/php/php${PHP_VER}-fpm.sock"

# Thư mục cài adminer
INSTALL_DIR="/var/www/adminer"

# Cố định cho cả 2 phần để đỡ rắc rối
USER_NAME="adminer_db"

# Tạo mật khẩu
DB_PASS=$(openssl rand -base64 12)
WEB_PASS=$(openssl rand -base64 12)

# --- 1. KIỂM TRA MÔI TRƯỜNG ---
echo "[1/4] Kiem tra moi truong PHP ${PHP_VER}..."
if [[ ! -S "$PHP_SOCKET" ]]; then
    echo "Loi: Khong tim thay socket tai $PHP_SOCKET."
    exit 1
fi
echo "-> OK."

# Kiểm tra trước sự tồn tại của thư mục adminer trong caddyfile để chặn sớm ngay từ đầu
# Tránh việc cài đặt
if grep -q "$INSTALL_DIR" "$CADDY_FILE"; then
    echo "CANH BAO: Duong dan '$INSTALL_DIR' da co trong Caddyfile."
    echo "-> Da BO QUA viec chen de tranh trung lap."
	exit 1
fi	

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
chmod 644 "$INSTALL_DIR/index.php"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# E. TẠO USER MARIADB 
echo "[3/4] Dang cau hinh User MariaDB..."
if ! systemctl is-active --quiet mariadb; then
    systemctl start mariadb
fi

mysql <<EOF
CREATE USER IF NOT EXISTS '${USER_NAME}'@'localhost' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${USER_NAME}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${USER_NAME}'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- F. TỰ ĐỘNG CẤU HÌNH CADDY (DÙNG EOF) ---
MARKER="#wpsila_kiencang"
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

if [[ -f "$CADDY_FILE" ]]; then
    cp "$CADDY_FILE" "$BACKUP_FILE"
else
    echo -e "${RED}Khong tim thay Caddyfile de backup!${NC}"
    exit 1
fi

echo "-> Backup cho Caddyfile da duoc tao: $BACKUP_FILE"

# Kiểm tra tồn tại của tên miền trong file caddyfile
# ^[^#]* : Bắt đầu dòng KHÔNG phải dấu # (bỏ qua comment)
# [[:space:]] : Domain thường đứng sau khoảng trắng hoặc đầu dòng
if grep -Eq "^[^#]*([[:space:]]|^)$DOMAIN([[:space:]]|:|\{|$)" "$CADDY_FILE"; then
    echo "CANH BAO: $DOMAIN da co trong Caddyfile."
    echo "-> Da BO QUA viec chen de tranh trung lap."
	exit 1
else
    # Hash password
    HASHED_PASS=$(caddy hash-password --plaintext "$WEB_PASS")

    # Dùng EOF để chèn nội dung vào cuối file Caddyfile
    # Lưu ý: Các biến $VAR vẫn được hiểu bên trong EOF
	# Nối vào file Caddyfile
    cat >> "$CADDY_FILE" <<EOF 
###start_wpsila_kiencang_$DOMAIN###
$DOMAIN {
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
    # Danh dau maker de nhan dien sau nay
    $MARKER
###end_wpsila_kiencang_$DOMAIN###
EOF

    echo "-> Da them cau hinh vao Caddyfile."
    
    # Format và Reload
    caddy fmt --overwrite "$CADDY_FILE"
	
	# Kiểm tra tính hợp lệ của file Caddydile
	if ! caddy validate --config "$CADDY_FILE" --adapter caddyfile > /dev/null 2>&1; then
		echo -e "${RED}CANH BAO: File Caddyfile bi loi cu phap!${NC}"
		
		# In ra lỗi cụ thể cho người dùng xem sai ở đâu
		caddy validate --config "$CADDY_FILE" --adapter caddyfile
		
		echo -e "${YELLOW}Dang khoi phuc lai file ban dau...${NC}"
		
		if [[ -f "$BACKUP_FILE" ]]; then
			cp "$BACKUP_FILE" "$CADDY_FILE"
			echo "Da khoi phuc lai file goc an toan."
		fi
		
		exit 1
	fi	

	# Đến phần này nghĩa là file caddyfile không lỗi, có thể khởi động lại Caddy được.
	# Nếu không làm bước này, Caddy không thể ghi file vào đây được.
	# Gán quyền liên quan đến thư mục log, gán lại, phòng root chiếm quyền gây lỗi khởi động lại.
	chown -R caddy:caddy /var/log/caddy
	chmod 755 /var/log/caddy	
	
    systemctl reload caddy
    echo "-> Da Reload Caddy."
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# G. Ghi thêm thông tin đăng nhập adminer vào file adminer.txt
CRED_FILE="$SCRIPT_WPSILA_DIR/adminer.txt"

# Kiểm tra nếu file tồn tại thì mới xóa
rm -f "$CRED_FILE"

# Tạo mới
cat > "$CRED_FILE" <<EOF
----------------------------------------
ADMINER CREDENTIALS
Date: $(date)
----------------------------------------
URL: https://${DOMAIN}
[LOP 1] WEB LOGIN (Basic Auth):
User: ${USER_NAME}
Pass: ${WEB_PASS}
----------------------------------------
[LOP 2] DATABASE LOGIN:
User: ${USER_NAME}
Pass: ${DB_PASS}
EOF
chmod 600 "$CRED_FILE" # Chỉ user hiện tại mới đọc được file này

# Xuất ra màn hình
echo ""
echo "======================================="
echo "   CAI DAT THANH CONG!"
echo "======================================="
echo "URL: https://$DOMAIN"
echo ""
echo "[LOP 1] WEB LOGIN (Basic Auth):"
echo "   User: $USER_NAME"
echo "   Pass: $WEB_PASS"
echo ""
echo "[LOP 2] DATABASE LOGIN:"
echo "   User: $USER_NAME"
echo "   Pass: $DB_PASS"
echo "	Xem lai pass o mục <9>"
echo "======================================="
# -------------------------------------------------------------------------------------------------------------------------------