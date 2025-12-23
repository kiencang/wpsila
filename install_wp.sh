#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# Thiet lap moi truong chuan cho Automation
export LC_ALL=C.UTF-8
export DEBIAN_FRONTEND=noninteractive

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
# B. Kiểm tra quyền chạy
# NÂNG QUYỀN NẾU KHÔNG PHẢI LÀ ROOT
# 1. Kiểm tra xem đang chạy với quyền gì
if [[ $EUID -ne 0 ]]; then
   # 2. Nếu không phải root, tự động chạy lại script này bằng sudo
   # -E để giữ lại biến môi trường
   sudo -E "$0" "$@"
   # 3. Thoát tiến trình cũ (không phải root) để tiến trình mới (có root) chạy
   exit $?
fi

# Xác định kiểu cài đặt có phải là subdomain hay không
# Mặc định là nosd, tức là không phải dạng cài subdomain
# Tham số đầu vào mặc định ở vị trí đầu tiên (1)
INSTALL_TYPE="${1:-nosd}"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# C. Kiểm tra môi trường
# Script này yêu cầu Caddy và PHP đã được cài trước đó
echo -e "${GREEN}>>> Dang kiem tra moi truong he thong...${NC}"

if ! id "caddy" &>/dev/null; then
    echo -e "${RED}Loi: User 'caddy' chua ton tai.${NC}"
    echo -e "${YELLOW}Goi y: Cai dat Caddy Web Server truoc do chua thanh cong.${NC}"
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
# D. CẤU HÌNH PHIÊN BẢN PHP
# D1. Đặt giá trị mặc định (phòng hờ không tìm thấy file config / wpsila.conf)
DEFAULT_PHP_VER="8.3"

# D2. Định nghĩa đường dẫn file config 
# (Ví dụ: file config nằm cùng thư mục với script đang chạy)
# Dòng lệnh này đảm bảo biến SCRIPT_WPSILA_DIR luôn là đường dẫn tuyệt đối tới thư mục chứa file này
# Cách chuẩn mực
SCRIPT_WPSILA_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# ---
# Hoặc có thể dùng cách đơn giản này:
# SCRIPT_WPSILA_DIR="$(dirname "$(realpath "$0")")"
# ----

# Trỏ vào file config nằm cùng thư mục đó
WPSILA_CONFIG_FILE="$SCRIPT_WPSILA_DIR/wpsila.conf"

# D3. Kiểm tra và nạp file config
if [[ -f "$WPSILA_CONFIG_FILE" ]]; then
    # Lệnh 'source' hoặc dấu chấm '.' sẽ đọc biến từ file kia vào script này
    source "$WPSILA_CONFIG_FILE"
    echo -e "${GREEN}Da tim thay file cau hinh: ${WPSILA_CONFIG_FILE}${NC}"
else
    echo -e "${YELLOW}Khong tim thay file config. Su dung phien ban mac dinh.${NC}"
fi

# D4. Chốt phiên bản cuối cùng
# Cú pháp ${BIEN_1:-$BIEN_2} nghĩa là: Nếu BIEN_1 rỗng (chưa set trong config), thì lấy BIEN_2
# Export ngay lập tức để toàn bộ quy trình bên dưới nhận diện được
export PHP_VER="${PHP_VER:-$DEFAULT_PHP_VER}"
export SCRIPT_WPSILA_DIR

echo "Phien ban PHP: $PHP_VER"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# E. NHẬP VÀ XỬ LÝ TÊN MIỀN
# Kiểm tra tên miền người dùng nhập vào
DOMAIN_CHECK="$SCRIPT_WPSILA_DIR/domain_check.sh"

# Nhúng file kiểm tra tên miền nhập vào
if [[ -f "$DOMAIN_CHECK" ]]; then    
    # Lệnh source quan trọng để nhúng trực tiếp vào file chính
    source "$DOMAIN_CHECK"
else 
	echo -e "${RED}KHONG TIM THAY file kiem tra ten mien nhap vao (domain_check.sh)!${NC}"
	echo -e "${RED}Hay kiem tra lai su ton tai cua file nay, hoac duong dan cua no.${NC}"
	exit 1
fi	

echo "-------------------------------------------------------------------------------------------------"

# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# F. Tạo Database & User
# Tạo database & user cho WordPress
DATABASE_USER_WP="$SCRIPT_WPSILA_DIR/database_user_wp.sh"

# Nhúng cài đặt database & user vào
if [[ -f "$DATABASE_USER_WP" ]]; then    
    # Lệnh source quan trọng để nhúng trực tiếp vào file chính
    source "$DATABASE_USER_WP"
else 
	echo -e "${RED}KHONG TIM THAY file tao database & user cho WordPress (database_user_wp.sh)!${NC}"
	echo -e "${RED}Hay kiem tra lai su ton tai cua file nay, hoac duong dan cua no.${NC}"
	exit 1
fi	

echo "-------------------------------------------------------------------------------------------------"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# G. Cai dat WordPress (G) & Phân quyền (H)
# Xác định đường dẫn tuyệt đối đến file cài đặt WordPress
WORDPRESS_FILE_TEMP="$SCRIPT_WPSILA_DIR/wordpress.sh"

# Nhúng cài đặt WordPress vào, kiểm tra sự tồn tại để đảm bảo không lỗi
if [[ -f "$WORDPRESS_FILE_TEMP" ]]; then    
    # Lệnh source quan trọng để nhúng trực tiếp vào file chính
    source "$WORDPRESS_FILE_TEMP"
else 
	echo -e "${RED}KHONG TIM THAY file cài WordPress (wordpress.sh)! Hay kiem tra lai su ton tai cua file nay, hoac duong dan cua no.${NC}"
	exit 1
fi	

echo "-------------------------------------------------------------------------------------------------"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# I. Chinh sua file Caddyfile (KIẾN TRÚC MODULAR)
# ---------------------------------------------------------

# I1. Định nghĩa đường dẫn file cấu hình RIÊNG BIỆT cho domain này
# File sẽ nằm trong /etc/caddy/sites-enabled/domain.com.caddy
CADDY_SITE_FILE="/etc/caddy/sites-enabled/${DOMAIN}.caddy"

echo "Domain chinh: $DOMAIN"

# Không phải subdomian mới cần thông báo
if [[ "$INSTALL_TYPE" != "subdomain" ]]; then
	echo "Domain chuyen huong: $RED_DOMAIN"
fi

# Kiểm tra nếu file cấu hình cho domain này đã tồn tại
if [[ -f "$CADDY_SITE_FILE" ]]; then
    echo -e "${RED}LOI: File cau hinh cho $DOMAIN da ton tai ($CADDY_SITE_FILE).${NC}"
    echo -e "${YELLOW}Vui long xoa web cu truoc khi cai lai.${NC}"
    exit 1
fi

# I2. Nội dung Caddyfile
# Mặc định / Không phải kiểu subdomain
CADDY_FILE_TEMP="$SCRIPT_WPSILA_DIR/caddyfile.sh"

# Nếu là kiểu subdomain thì chọn file caddy tương ứng
if [[ "$INSTALL_TYPE" == "subdomain" ]]; then
	CADDY_FILE_TEMP="$SCRIPT_WPSILA_DIR/caddyfile_subdomain.sh"
fi

# Nhúng caddyfile mẫu vào để lấy biến $CONTENT
if [[ -f "$CADDY_FILE_TEMP" ]]; then    
    source "$CADDY_FILE_TEMP"
else 
	echo -e "${RED}KHONG TIM THAY Caddyfile mau!${NC}"
	exit 1
fi	

# Kiểm tra biến CONTENT có dữ liệu không
if [[ -z "${CONTENT:-}" ]]; then
    echo -e "${RED}LOI: Noi dung cau hinh Caddy (CONTENT) bi rong!${NC}"
    exit 1
fi

# I3. GHI FILE CẤU HÌNH (Write New File)
echo "Dang tao file cau hinh Caddy rieng biet..."

# Ghi nội dung vào file mới
echo "$CONTENT" > "$CADDY_SITE_FILE"

# Format lại cho đẹp (Caddy chuẩn hóa)
caddy fmt --overwrite "$CADDY_SITE_FILE" > /dev/null 2>&1

# I4. VALIDATE & RELOAD
echo "Dang kiem tra cu phap Caddyfile..."

# Kiểm tra tính hợp lệ của TOÀN BỘ cấu hình (bao gồm cả file mới vừa import)
if ! caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile > /dev/null 2>&1; then
    echo -e "${RED}CANH BAO: File cau hinh moi gay loi he thong!${NC}"
    
    # In ra lỗi cụ thể
    caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
    
    echo -e "${YELLOW}Dang xoa file gay loi de bao dam an toan...${NC}"
    rm -f "$CADDY_SITE_FILE"
    
    exit 1
else
    # Nếu mọi thứ OK, Reload lại Caddy
    echo "Cau hinh hop le. Dang reload Caddy..."
	
	# Fix quyền Log như cũ
	chown -R caddy:caddy "/var/www/$DOMAIN/logs"
	
    systemctl reload caddy
    echo "Da cap nhat cau hinh cho $DOMAIN."
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo "Hoan tat! Xin chuc mung ban da cai thanh cong WordPress trên Caddy Web Server."
echo "Nhap muc <4> de xem thong tin pass cua trang WordPress ban vua tao."
# -------------------------------------------------------------------------------------------------------------------------------