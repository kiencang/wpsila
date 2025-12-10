#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Chạy lệnh
# version 0.05.12.25
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/install_lcmp.sh | bash
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# A. Màu sắc cho thông báo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color (ngắt màu)
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# B. CẤU HÌNH PHIÊN BẢN PHP
# B1. Đặt giá trị mặc định (phòng hờ không tìm thấy file config)
DEFAULT_PHP_VER="8.3"

# B2. Định nghĩa đường dẫn file config 
# Lấy đường dẫn tuyệt đối của thư mục chứa file script đang chạy
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# Trỏ vào file config nằm cùng thư mục đó
WPSILA_CONFIG_FILE="$SCRIPT_DIR/wpsila.conf"

# B3. Kiểm tra và nạp file config
if [ -f "$WPSILA_CONFIG_FILE" ]; then
    # Lệnh 'source' hoặc dấu chấm '.' sẽ đọc biến từ file kia vào script này
    source "$WPSILA_CONFIG_FILE"
    echo -e "${GREEN}Da tim thay file cau hinh: ${WPSILA_CONFIG_FILE}${NC}"
else
    echo -e "${YELLOW}Khong tim thay file config. Su dung phien ban mac dinh.${NC}"
fi

# B4. Chốt phiên bản cuối cùng
# Cú pháp ${BIEN_1:-$BIEN_2} nghĩa là: Nếu BIEN_1 rỗng (chưa set trong config), thì lấy BIEN_2
PHP_VER="${PHP_VER:-$DEFAULT_PHP_VER}"

echo "Phien ban PHP: $PHP_VER"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo "--------------------------------------------------------"
echo "Dang kiem tra moi truong VPS (Clean OS Check)..."
echo "--------------------------------------------------------"

# C. Kiểm tra trước môi trường server, phòng lỗi cài đè, cài nhầm
# C1. NÂNG QUYỀN NẾU KHÔNG PHẢI LÀ ROOT

# 1. Kiểm tra xem đang chạy với quyền gì
if [[ $EUID -ne 0 ]]; then
   # 2. Nếu không phải root, tự động chạy lại script này bằng sudo
   sudo "$0" "$@"
   # 3. Thoát tiến trình cũ (không phải root) để tiến trình mới (có root) chạy
   exit $?
fi

# C2 pre. Kiểm tra sự tồn tại của file xác nhận cài xong wpSila, nhằm có các thông báo phù hợp hơn
ALREADY_WPSILA="$SCRIPT_DIR/wpsila_success.txt"

# Kiểm tra xem file cài thành công đã có chưa, có rồi thì không cài nữa
if [ -f "$ALREADY_WPSILA" ]; then
	echo -e "${YELLOW}Ban da cai wpSila tren VPS nay.${NC}"
	exit 0
fi	

# C2. KIỂM TRA CỔNG 80 & 443(Dùng lệnh ss) 
# Mục đích: Phát hiện Nginx, Apache, OpenLiteSpeed hoặc bất kỳ Web Server nào đang chạy.
# ss -tuln: Hien thi TCP/UDP, Listening, Numeric ports
# grep -q ":80 ": Tim chuoi ":80 " (co dau cach de tranh nham voi 8080)

if ss -tuln | grep -q ":80 "; then
    echo -e "${RED}[X] LOI NGHIEM TRONG: Cong 80 (HTTP) dang ban!${NC}"
    echo -e "${YELLOW}Nguyen nhan:${NC} VPS nay dang chay mot Web Server nao do (Caddy, Nginx, Apache, hoac Docker...)."
    echo -e "${YELLOW}Giai phap:${NC} Vui long su dung mot VPS moi tinh (Clean OS) de tranh xung dot va loi he thong."
    echo -e "Script da dung lai de bao ve VPS cua ban."
    exit 1
fi

if ss -tuln | grep -q ":443 "; then
    echo -e "${RED}[X] LOI NGHIEM TRONG: Cong 443 (HTTPS) dang ban!${NC}"
    echo -e "${YELLOW}Nguyen nhan:${NC} VPS nay dang chay mot Web Server nao do (Caddy, Nginx, Apache, hoac Docker...)."
    echo -e "${YELLOW}Giai phap:${NC} Vui long su dung mot VPS moi tinh (Clean OS) de tranh xung dot va loi he thong."
    echo -e "Script da dung lai de bao ve VPS cua ban."
    exit 1
fi

# C3. KIỂM TRA USER "CADDY" 
# Mục đích: Phát hiện tàn dư của Caddy cũ (dù đã tắt nhưng còn config rác).
if id "caddy" &>/dev/null; then
    echo -e "${RED}[X] LOI: User 'caddy' da ton tai.${NC}"
    echo -e "${YELLOW}Nguyen nhan:${NC} VPS nay da tung duoc cai dat Caddy Web Server truoc day."
    echo -e "${YELLOW}Giai phap:${NC} De dam bao on dinh, vui long Reinstall OS (Cai lai he dieu hanh) ve trang thai ban dau."
    exit 1
fi

# --- NẾU VƯỢT QUA TẤT CẢ ---
echo -e "${GREEN}[OK] Kiem tra hoan tat. Moi truong sach se.${NC}"
echo "Dang bat dau qua trinh cai dat..."
echo "--------------------------------------------------------"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# D. Cài Caddy Web Server
# Nhúng file cài caddy web server, dễ chỉnh sửa & cập nhật thêm sau này
# Xác định thư mục
SCRIPT_WPSILA_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CADDYWS_INSTALL_FILE="$SCRIPT_WPSILA_DIR/caddy_web_server.sh"

# Kiểm tra xem tệp tin có tồn tại không thì mới nhúng
if [ -f "$CADDYWS_INSTALL_FILE" ]; then
	echo -e "${GREEN}Chuan bi cai Caddy Web Server...${NC}"
    source "$CADDYWS_INSTALL_FILE"
else
    echo -e "${YELLOW}Khong tim thay file cai Caddy Web Server (caddy_web_server.sh).${NC}"
	echo -e "${YELLOW}Kiem tra su ton tai cua file, hoac duong dan co chinh xác khong.${NC}"
fi
echo "--------------------------------------------------------"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# E. Cài PHP & MariaDB
# File cài PHP & MariaDB, tách riêng cho dễ chỉnh sửa, cập nhật
PHP_MARIADB_FILE="$SCRIPT_WPSILA_DIR/php_mariadb.sh"

if [ -f "$PHP_MARIADB_FILE" ]; then
	echo -e "${GREEN}Chuan bi cai PHP & MariaDB...${NC}"
	# Nhúng file
    source "$PHP_MARIADB_FILE"
else
    echo -e "${YELLOW}Khong tim thay file cai PHP & MariaDB (php_mariadb.sh).${NC}"
	echo -e "${YELLOW}Kiem tra su ton tai cua file, hoac duong dan co chinh xác khong.${NC}"
fi

echo -e "${GREEN}Cai dat thanh cong PHP & MariaDB.${NC}"
echo "--------------------------------------------------------"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# E. Lưu lại thông tin để biết là đã cài thành công
# Cần bổ sung mã để thêm file vào thư mục nhằm xác nhận đã cài thành công LCMP trên VPS
# Nằm cùng thư mục
INSTALLED_SUCCESSFULLY="$SCRIPT_DIR/wpsila_success.txt"

# Xóa file cũ nếu nó có tồn tại
rm -f "$INSTALLED_SUCCESSFULLY"

# Tạo file mới xác nhận cài thành công LCMP
cat > "$INSTALLED_SUCCESSFULLY" <<EOF
----------------------------------------
wpSila CLI
Cai thanh cong LCMP
Date: $(date)
----------------------------------------
EOF

echo -e "${GREEN}Da luu lai thong tin cai LCMP thanh cong.${NC}"
echo "--------------------------------------------------------"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------