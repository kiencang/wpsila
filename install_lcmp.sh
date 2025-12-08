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
echo "--------------------------------------------------------------------"
echo "Dang kiem tra moi truong VPS (Clean OS Check)..."
echo "--------------------------------------------------------------------"

# C. Kiểm tra trước môi trường server, phòng lỗi cài đè, cài nhầm
# C1. KIỂM TRA QUYỀN ROOT

# Bắt buộc phải chạy bằng root để cài đặt phần mềm
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Loi: Ban phai chay script nay bang quyen Root.${NC}"
   echo -e "Vui long vao terminal voi quyen Root, sau do chay lai lenh."
   exit 1
fi

# C2 pre. Kiểm tra sự tồn tại của file xác nhận cài xong wpSila, nhằm có các thông báo phù hợp hơn
ALREADY_WPSILA="SCRIPT_DIR/wpsila_success.txt"

# Kiểm tra xem file cài thành công đã có chưa, có rồi thì không cài nữa
if [ -f "$ALREADY_WPSILA" ]; then
	echo -e "${YELLOW}Ban da cai wpSila tren VPS nay.${NC}"
	echo -e "${YELLOW}Enter de thoat.${NC}"
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
sleep 2
echo "-------------------------------------------------------------------------------------------------"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# D. Cài Caddy Web Server
echo -e "${GREEN}[1/6] Dang cap nhat he thong...${NC}"
sudo apt update && sudo apt upgrade -y

echo -e "${GREEN}[2/6] Dang cai dat cac goi phu thuoc...${NC}"
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl

echo -e "${GREEN}[3/6] Dang them GPG Key va Repository cua Caddy...${NC}"
# Lưu ý: Đã thêm cờ --yes để cho phép ghi đè nếu file đã tồn tại
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null

echo -e "${GREEN}[4/6] Dang thiet lap quyen han cho file key va list...${NC}"
# Cần sudo để chmod các file hệ thống này
sudo chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
sudo chmod o+r /etc/apt/sources.list.d/caddy-stable.list

echo -e "${GREEN}[5/6] Dang cap nhat apt va cai dat Caddy...${NC}"
sudo apt update && sudo apt install caddy -y

echo -e "${GREEN}[6/6] Dang cau hinh tuong lua (UFW)...${NC}"
# xóa quy tắc cũ
sudo ufw delete allow ssh || true

# bật ssh kèm giới hạn để hạn chế tấn công
sudo ufw limit ssh 

# bật các cổng
sudo ufw allow 80
sudo ufw allow 443

# chính thức áp dụng các quy tắc
sudo ufw --force enable

echo -e "${GREEN}>>> Cai dat hoan tat! Kiem tra trang thai Caddy:${NC}"
sudo systemctl status caddy --no-pager
echo -e "${GREEN}>>> Buoc tiep theo: Cai dat PHP & MariaDB.${NC}"
sleep 2

echo "-------------------------------------------------------------------------------------------------"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# E. Cài PHP & MariaDB
echo -e "${GREEN}[1/3] Dang cai dat PHP ${PHP_VER} va cac module can thiet...${NC}"

# Thêm repository và cài đặt PHP
sudo apt update
sudo apt install -y lsb-release ca-certificates apt-transport-https software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# ==============================================================
# DANH SÁCH CÁC GÓI PHP ĐƯỢC CÀI. CÁC GÓI CHỈ CẦN DÀNH CHO BLOG.
# ==============================================================

echo -e "${GREEN}[*] Dang chuan bi cai dat PHP phien ban: ${PHP_VER} ${NC}"

# E1. DANH SÁCH GÓI (Sử dụng biến ${PHP_VER} để ghép chuỗi)
PHP_PACKAGES=(
    "php${PHP_VER}-fpm"       # Xử lý PHP (Bắt buộc)
    "php${PHP_VER}-cli"       # Chạy WP-CLI & Cron (Bắt buộc)
    "php${PHP_VER}-mysql"     # Kết nối DB (Bắt buộc)
    "php${PHP_VER}-opcache"   # Tăng tốc độ (Rất nên có)
    "php${PHP_VER}-curl"      # Kết nối mạng/API (Bắt buộc)
    "php${PHP_VER}-mbstring"  # Xử lý tiếng Việt (Bắt buộc)
    "php${PHP_VER}-xml"       # SEO/Sitemap (Bắt buộc)
    "php${PHP_VER}-zip"       # Giải nén theme/plugin (Bắt buộc)
    "php${PHP_VER}-gd"        # Xử lý ảnh (Đủ dùng cho Blog)
    "php${PHP_VER}-intl"      # Định dạng ngày tháng quốc tế (Nên có)
    "php${PHP_VER}-bcmath"    # Tính toán chính xác (Nên có - để tương thích plugin tốt hơn)
)

# E2. LỆNH CÀI ĐẶT
# "${PHP_PACKAGES[@]}" sẽ bung toàn bộ danh sách trên ra thành chuỗi
apt install -y "${PHP_PACKAGES[@]}"

echo -e "${GREEN}[2/3] Dang cai dat MariaDB Server...${NC}"
# Thường là phiên bản 10.11 trên Ubuntu 24.04 LTS
# Cách kiểm tra: mariadb --version, việc biết được phiên bản cụ thể sẽ giúp chúng ta có những cài đặt chính xác hơn sau này.
sudo apt install -y mariadb-server

# E3. BẢO MẬT MARIADB (HARDENING)
echo -e "${GREEN}[3/3] Dang thuc hien bao mat MariaDB (Secure Installation)...${NC}"

# Chạy một khối lệnh SQL để thực hiện các yêu cầu bảo mật:
# 1. Xóa anonymous users
# 2. Chỉ cho phép root login từ localhost (tắt remote root)
# 3. Xóa database 'test' và quyền truy cập vào nó
# 4. Reload privileges

sudo mariadb <<EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# Cần bổ sung mã để thêm file vào thư mục nhằm xác nhận đã cài thành công LCMP trên VPS
# Nằm cùng thư mục
INSTALLED_SUCCESSFULLY="SCRIPT_DIR/wpsila_success.txt"

# Xóa file cũ nếu nó có tồn tại
sudo rm -f "$INSTALLED_SUCCESSFULLY"

# Tạo file mới xác nhận cài thành công
cat > "$INSTALLED_SUCCESSFULLY" <<EOF
----------------------------------------
wpSila CLI
Date: $(date)
----------------------------------------
EOF
echo -e "${GREEN}Cai dat thanh cong PHP & MariaDB.${NC}"
# -------------------------------------------------------------------------------------------------------------------------------