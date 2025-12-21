#!/bin/bash

# =========================================
# Cài đặt LCMP cho VPS
# 3 file module được source vào là:
# a. install_caddyserver.sh
# b. install_php.sh
# c. install_mariadb.sh
# wpsila.conf chứa thông tin phiên bản PHP & MariaDB
# =========================================

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# Thiet lap moi truong chuan cho Automation
export LC_ALL=C.UTF-8
export DEBIAN_FRONTEND=noninteractive

# -------------------------------------------------------------------------------------------------------------------------------
# A. Màu sắc cho thông báo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color (ngắt màu)
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# B. CẤU HÌNH & ĐƯỜNG DẪN
# Thiết lập các giá trị mặc định, phòng trường hợp config lỗi
DEFAULT_PHP_VER="8.3"
DEFAULT_MARIADB_VER="10.11"

# B2. Định nghĩa đường dẫn (Sử dụng cách an toàn nhất, không phụ thuộc realpath)
SCRIPT_WPSILA_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Trỏ vào file config nằm cùng thư mục
WPSILA_CONFIG_FILE="$SCRIPT_WPSILA_DIR/wpsila.conf"

# B3. Kiểm tra và nạp file config
if [[ -f "$WPSILA_CONFIG_FILE" ]]; then
    source "$WPSILA_CONFIG_FILE"
    echo -e "${GREEN}Da tim thay file cau hinh: ${WPSILA_CONFIG_FILE}${NC}"
else
    echo -e "${YELLOW}Khong tim thay file config. Su dung phien ban mac dinh.${NC}"
fi

# B4. Chốt phiên bản & Export biến
# Export ngay lập tức để toàn bộ quy trình bên dưới nhận diện được
export PHP_VER="${PHP_VER:-$DEFAULT_PHP_VER}"
export MARIADB_VER="${MARIADB_VER:-$DEFAULT_MARIADB_VER}"
export SCRIPT_WPSILA_DIR

echo -e "Phien ban PHP se cai dat: ${GREEN}$PHP_VER${NC}"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# C. KIỂM TRA MÔI TRƯỜNG (PRE-FLIGHT CHECK)

echo "--------------------------------------------------------"
echo "Dang kiem tra moi truong VPS (Clean OS Check)..."

# C1. Kiểm tra quyền Root
if [[ $EUID -ne 0 ]]; then
   # Thêm tham số -E cho sudo để giữ lại các biến môi trường (nếu có)
   sudo -E "$0" "$@"
   exit $?
fi

# C2 pre. Kiểm tra file lock (đã cài rồi)
ALREADY_WPSILA="$SCRIPT_WPSILA_DIR/wpsila_success.txt"
if [[ -f "$ALREADY_WPSILA" ]]; then
	echo -e "${YELLOW}Ban da cai wpsila tren VPS nay roi.${NC}"
	exit 0
fi	

# C2. Kiểm tra Port 80 & 443
# Dùng grep -E để gộp lệnh, code gọn hơn
if ss -tuln | grep -qE ":(80|443) "; then
    echo -e "${RED}[X] LOI NGHIEM TRONG: Cong 80 hoac 443 dang ban!${NC}"
    echo -e "${YELLOW}Nguyen nhan:${NC} VPS dang chay Web Server khac (Apache, Nginx...)."
    echo -e "${YELLOW}Giai phap:${NC} Vui long su dung VPS moi tinh (Clean OS)."
    exit 1
fi

# C3. Kiểm tra user "caddy"
if id "caddy" &>/dev/null; then
    echo -e "${RED}[X] LOI: User 'caddy' da ton tai.${NC}"
    echo -e "${YELLOW}Giai phap:${NC} Reinstall OS ve trang thai ban dau."
    exit 1
fi

echo -e "${GREEN}[OK] Moi truong sach se.${NC}"
sleep 1

# -------------------------------------------------------------------------------------------------------------------------------
# C4. UPDATE SYSTEM & DEPENDENCIES
echo "--------------------------------------------------------"
echo "Cap nhat he thong va cai dat cac goi co ban..."

# C4.1. Gỡ bỏ các webserver mặc định (Apache/Nginx) nếu có để tránh xung đột tiềm ẩn
# Dùng || true để không báo lỗi nếu không tìm thấy gói
apt-get remove --purge -y apache2 apache2-* nginx nginx-* &>/dev/null || true

# C4.2 Cập nhật và cài đặt gói bổ trợ
# Đã xóa dấu '&& \' bị thừa ở cuối lệnh để tránh lỗi cú pháp
apt-get update
apt-get install -y --no-install-recommends \
	curl \
	wget \
    lsb-release \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    zip \
    unzip \
    gnupg

echo -e "${GREEN}[OK] Da cai dat xong dependencies.${NC}"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# D. Cài Caddy Web Server
CADDYWS_INSTALL_FILE="$SCRIPT_WPSILA_DIR/install_caddyserver.sh"

if [[ -f "$CADDYWS_INSTALL_FILE" ]]; then
	echo -e "${GREEN}Chuan bi cai Caddy Web Server...${NC}"
    source "$CADDYWS_INSTALL_FILE"
else
    echo -e "${RED}Khong tim thay file: install_caddyserver.sh${NC}"
	exit 1
fi
echo "--------------------------------------------------------"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# E. Cài PHP Repo ondrej
PHP_INSTALL_FILE="$SCRIPT_WPSILA_DIR/install_php.sh"

if [[ -f "$PHP_INSTALL_FILE" ]]; then
	echo -e "${GREEN}Chuan bi cai PHP...${NC}"
    source "$PHP_INSTALL_FILE"
else
    echo -e "${RED}Khong tim thay file: install_php.sh${NC}"
	exit 1
fi

echo "--------------------------------------------------------"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# F. Cài MariaDB
MARIADB_INSTALL_FILE="$SCRIPT_WPSILA_DIR/install_mariadb.sh"

if [[ -f "$MARIADB_INSTALL_FILE" ]]; then
	echo -e "${GREEN}Chuan bi cai MariaDB...${NC}"
    source "$MARIADB_INSTALL_FILE"
else
    echo -e "${RED}Khong tim thay file: install_mariadb.sh${NC}"
	exit 1
fi

echo "--------------------------------------------------------"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# G. HOÀN TẤT
INSTALLED_SUCCESSFULLY="$SCRIPT_WPSILA_DIR/wpsila_success.txt"

# Xóa file cũ (cho chắc chắn)
rm -f "$INSTALLED_SUCCESSFULLY"

# Ghi file log (ghi đè)
cat > "$INSTALLED_SUCCESSFULLY" <<EOF
----------------------------------------
wpsila CLI
Cai thanh cong LCMP
PHP Version: $PHP_VER
Date: $(date)
----------------------------------------
EOF

echo "Don dep rac he thong..."
apt-get autoremove -y
apt-get clean
# rm -rf /var/lib/apt/lists/*

echo "--------------------------------------------------------"
echo -e "${GREEN}Cai dat LCMP hoan tat!${NC}"
echo "--------------------------------------------------------"