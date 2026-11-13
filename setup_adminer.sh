#!/bin/bash

# -----------------------------------------------------------
# Thiết lập quản lý database cho toàn bộ site
# File: setup_adminer.sh
# Đây là mã ngoài nổi tiếng có tên adminer
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail
# -------------------------------------------------------------------------------------------------------------------------------

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
# Cx. Kiểm tra môi trường
# Script này yêu cầu Caddy và PHP đã được cài trước đó
echo -e "${GREEN}>>> Dang kiem tra moi truong he thong...${NC}"

if ! id "caddy" &>/dev/null; then
    echo -e "${RED}Loi: User 'caddy' chua ton tai.${NC}"
    echo -e "${YELLOW}Goi y: Cai dat Caddy Server truoc do chua thanh cong hoac ban chua cai Caddy Server (nhan so 1 de cai).${NC}"
    exit 1
fi

if ! id "www-data" &>/dev/null; then
    echo -e "${RED}Loi: User 'www-data' chua ton tai.${NC}"
    echo -e "${YELLOW}Goi y: Hay cai dat PHP-FPM.${NC}"
    exit 1
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
echo "   SETUP ADMINER (De quan tri co so du lieu/database)"
echo "========================================================"
read -r -p "Nhap dia chi cho phan quan tri database (VD: db.domain.com): " INPUT_DOMAIN < /dev/tty

# Xử lý chuỗi
# Xóa khoảng trắng, chuyển chữ hoa thành chữ thường
TEMP_DOMAIN=$(echo "$INPUT_DOMAIN" | tr -d ' ' | tr '[:upper:]' '[:lower:]')

# Xóa http://, https:// ở đằng trước nếu có
DOMAIN=$(echo "$TEMP_DOMAIN" | sed -E 's|^https?://||' | sed -E 's|/.*$||' | sed -E 's|:[0-9]+$||')
    
# Validation địa chỉ nhập vào
# Không rỗng
if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}Loi: Dia chi khong duoc de trong!${NC}"
    exit 1
fi

# Sai cú pháp cơ bản, dừng sớm	
if [[ "$DOMAIN" != *"."* ]]; then
    echo -e "${RED}Loi: Dia chi '$DOMAIN' khong hop le (thieu dau cham).${NC}"
    exit 1
fi	

# Kiểm tra cấu trúc tiêu chuẩn, giống ở phần domain check
if [[ ! "$DOMAIN" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*\.[a-z]{2,}$ ]]; then
    echo -e "${RED}Loi: Dia chi website '$DOMAIN' chua ky tu khong hop le hoac sai dinh dang.${NC}"
    exit 1
fi		 

# Qua được các cửa ải
if [[ "$INPUT_DOMAIN" != "$DOMAIN" ]]; then
    echo -e "${GREEN}Script da tu dong chuan hoa input '${INPUT_DOMAIN}' thanh '${DOMAIN}'${NC}"
fi
# --------------------

#+++

# --------------------
# Kiểm tra trước sự tồn tại của file domain.caddy xem nó tồn tại hay chưa
# Chặn sớm để chống rác cài đặt
# Ví dụ: /etc/caddy/sites-enabled/db.domain.com.caddy
CADDY_SITE_FILE="/etc/caddy/sites-enabled/${DOMAIN}.caddy"

# Kiểm tra trùng lặp
if [[ -f "$CADDY_SITE_FILE" ]]; then
    echo -e "${RED}CANH BAO: File cau hinh Caddy cho $DOMAIN da ton tai.${NC}"
    echo -e "${RED}BO QUA viec tao moi. Dung chay script.${NC}"
    exit 1
fi	
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Dx. CẤU HÌNH PHIÊN BẢN PHP
# Nạp cấu hình trung tâm từ wpsila.conf
# (Ví dụ: file config nằm cùng thư mục với script đang chạy)
# Dòng lệnh này đảm bảo biến SCRIPT_WPSILA_DIR luôn là đường dẫn tuyệt đối tới thư mục chứa file này
# Xác định thư mục
SCRIPT_WPSILA_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Trỏ vào file config nằm cùng thư mục đó
WPSILA_CONFIG_FILE="$SCRIPT_WPSILA_DIR/wpsila.conf"

# Kiểm tra và nạp file config
if [[ ! -f "$WPSILA_CONFIG_FILE" ]]; then
    echo -e "${RED}Loi: Khong tim thay file cau hinh trung tam ($WPSILA_CONFIG_FILE)!${NC}"
    exit 1
fi

source "$WPSILA_CONFIG_FILE"

if [[ -z "${PHP_VER:-}" ]]; then
    echo -e "${RED}Loi: Bien PHP_VER chua duoc khai bao trong wpsila.conf!${NC}"
    exit 1
fi

# Thông báo phiên bản PHP
export PHP_VER
export SCRIPT_WPSILA_DIR
echo -e "Phien ban PHP he thong: ${GREEN}$PHP_VER${NC}"
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
    echo -e "${RED}Loi: Khong tim thay socket tai $PHP_SOCKET.${NC}"
    exit 1
fi
echo "OK."

# --- 2. CÀI ĐẶT ADMINER (CÓ FALLBACK 2 NGUỒN & KIỂM TRA FILE PHP HỢP LỆ) ---
echo "[2/4] Dang tai Adminer..."
mkdir -p "$INSTALL_DIR"
rm -f "$INSTALL_DIR/index.php"

ADMINER_OK=0
echo "Dang tai source code..."

# Nguồn 1: Trang chủ adminer.org
if curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 "https://www.adminer.org/latest-mysql.php" -o "$INSTALL_DIR/index.php"; then
    if [[ -s "$INSTALL_DIR/index.php" ]] && grep -q "<?php" "$INSTALL_DIR/index.php"; then
        ADMINER_OK=1
    fi
fi

# Nguồn 2 (Dự phòng): GitHub Releases chính thức của vrana/adminer
if (( ADMINER_OK == 0 )); then
    echo -e "${YELLOW}Canh bao: Nguon adminer.org gap su co. Chuyen sang tai tu kho du phong GitHub (vrana/adminer)...${NC}"
    GH_ADMINER_URL=""

    # Ưu tiên 2a: Lấy tag mới nhất qua HTTP Redirect (Không dùng api.github.com nên không bị giới hạn 60 req/giờ)
    ADMINER_LATEST_REDIRECT=$(curl -fsSLI --retry 3 --connect-timeout 10 -o /dev/null -w '%{url_effective}' "https://github.com/vrana/adminer/releases/latest" || true)
    if [[ "$ADMINER_LATEST_REDIRECT" == *"/releases/tag/v"* ]]; then
        ADMINER_TAG="${ADMINER_LATEST_REDIRECT##*/}"
        ADMINER_VER="${ADMINER_TAG#v}"
        if [[ "$ADMINER_VER" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
            GH_ADMINER_URL="https://github.com/vrana/adminer/releases/download/v${ADMINER_VER}/adminer-${ADMINER_VER}-mysql.php"
        fi
    fi

    # Ưu tiên 2b: Dự phòng qua GitHub API nếu Redirect không trả về tag chuẩn
    if [[ -z "$GH_ADMINER_URL" ]]; then
        GH_ADMINER_URL=$(curl -fsSL --retry 2 --connect-timeout 10 "https://api.github.com/repos/vrana/adminer/releases/latest" | grep -oE 'https://github\.com/vrana/adminer/releases/download/[^" ]+/adminer-[0-9.]+-mysql\.php' | head -n 1 || true)
    fi

    if [[ -n "$GH_ADMINER_URL" ]] && curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 "$GH_ADMINER_URL" -o "$INSTALL_DIR/index.php"; then
        if [[ -s "$INSTALL_DIR/index.php" ]] && grep -q "<?php" "$INSTALL_DIR/index.php"; then
            ADMINER_OK=1
        fi
    fi
    unset ADMINER_LATEST_REDIRECT ADMINER_TAG ADMINER_VER GH_ADMINER_URL
fi

if (( ADMINER_OK == 1 )); then
    echo -e "${GREEN}Tai Adminer thanh cong.${NC}"
else
    rm -f "$INSTALL_DIR/index.php"
    echo -e "${RED}Loi: Khong the tai Adminer tu ca adminer.org va GitHub!${NC}"
    exit 1
fi
unset ADMINER_OK

# Gán quyền sở hữu root:root (755/644) để PHP-FPM đọc được nhưng không một website/plugin nào sửa được mã nguồn Adminer
chown -R root:root "$INSTALL_DIR"

# Phân quyền
chmod 755 "$INSTALL_DIR"
chmod 644 "$INSTALL_DIR/index.php"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# E. TẠO USER MARIADB 
echo "[3/4] Dang cau hinh User MariaDB..."

# Nếu đang tắt thì bật lên
if ! systemctl is-active --quiet mariadb; then
    systemctl start mariadb
fi

mariadb <<EOF
CREATE USER IF NOT EXISTS '${USER_NAME}'@'localhost' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${USER_NAME}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${USER_NAME}'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- F. TỰ ĐỘNG CẤU HÌNH CADDY (MODULAR) ---
echo "[4/4] Dang xu ly Caddyfile..."

if ! command -v caddy &> /dev/null; then
    echo -e "${RED}Loi: Caddy chua duoc cai dat.${NC}"
    exit 1
fi

# Hash password
HASHED_PASS=$(caddy hash-password --plaintext "$WEB_PASS")

# Tạo nội dung và ghi thẳng vào file mới
# Không cần Marker nữa
cat > "$CADDY_SITE_FILE" <<EOF 
$DOMAIN {
    root * $INSTALL_DIR
    php_fastcgi unix/$PHP_SOCKET
    file_server

    # Bao mat 2 lop (Basic Auth)
	basic_auth {
		$USER_NAME $HASHED_PASS
	}

    # An file he thong (tru /.well-known/* cho SSL)
    @hiddenFiles {
        not path /.well-known/*
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

echo "Da tao file cau hinh: $CADDY_SITE_FILE"

# Format
caddy fmt --overwrite "$CADDY_SITE_FILE" || true

# Validate toàn bộ hệ thống
if ! caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile &> /dev/null; then
    echo -e "${RED}CANH BAO: File Caddyfile bi loi cu phap!${NC}"
    caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
    
    echo -e "${YELLOW}Dang xoa file gay loi...${NC}"
    rm -f "$CADDY_SITE_FILE"
    exit 1
fi	

# Gán quyền log (Adminer dùng chung thư mục log hệ thống hoặc riêng tùy config)
chown -R caddy:caddy /var/log/caddy
chmod 755 /var/log/caddy	

systemctl reload caddy
echo "Da Reload Caddy."
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# G. Ghi thêm thông tin đăng nhập adminer vào file adminerp.txt
CRED_FILE="$SCRIPT_WPSILA_DIR/adminerp.txt"

# Kiểm tra nếu file tồn tại thì mới xóa
rm -f "$CRED_FILE"

# Tạo mới với umask 077 (chỉ root đọc được ngay từ khi tạo)
(
    umask 077
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
)
chmod 600 "$CRED_FILE" # Đảm bảo chỉ user root hiện tại mới đọc được file này

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
echo "   Xem lai thong tin pass o muc <10>"
echo -e "${YELLOW}Goi y: Sau khi luu mat khau, hay dung Menu <18> de xoa file mat khau nay di nhe!${NC}"
echo "======================================="
# -------------------------------------------------------------------------------------------------------------------------------