#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# Màu sắc cho thông báo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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
sudo ufw allow 80
sudo ufw allow 443
sudo ufw reload

echo -e "${GREEN}>>> Cai dat hoan tat! Kiem tra trang thai Caddy:${NC}"
sudo systemctl status caddy --no-pager

# --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Cài PHP & MariaDB
echo -e "${GREEN}[1/3] Dang cai dat PHP 8.3 va cac module can thiet...${NC}"
# Thêm repository và cài đặt PHP
sudo apt update
sudo apt install -y lsb-release ca-certificates apt-transport-https software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Cài đặt PHP 8.3 và các extensions
sudo apt install -y php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-mbstring php8.3-xml php8.3-zip php8.3-imagick php8.3-intl php8.3-bcmath

echo -e "${GREEN}[2/3] Dang cai dat MariaDB Server...${NC}"
sudo apt install -y mariadb-server

echo -e "${GREEN}[3/3] Dang tao Database va User cho WordPress...${NC}"

# Sử dụng lệnh mysql -e để chạy SQL trực tiếp mà không cần vào shell tương tác
# Lưu ý: Thêm "IF NOT EXISTS" để script không bị lỗi nếu chạy lại lần 2

sudo mariadb -e "CREATE DATABASE IF NOT EXISTS wordpress_caddy DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mariadb -e "CREATE USER IF NOT EXISTS 'wpuser_caddy'@'localhost' IDENTIFIED BY 'pass_db_caddy';"
sudo mariadb -e "GRANT ALL PRIVILEGES ON wordpress_caddy.* TO 'wpuser_caddy'@'localhost';"
sudo mariadb -e "FLUSH PRIVILEGES;"

echo -e "${GREEN}>>> Cai dat hoan tat!${NC}"
echo -e "${YELLOW}Thong tin Database:${NC}"
echo -e "  - Database: wordpress_caddy"
echo -e "  - User:     wpuser_caddy"
echo -e "  - Pass:     pass_db_caddy"
echo -e "${YELLOW}Kiem tra PHP version:${NC}"
php -v

# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Cai dat WordPress
# --- KIỂM TRA MÔI TRƯỜNG ---
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

# --- BƯỚC 1: NHẬP VÀ XỬ LÝ TÊN MIỀN ---
echo -e "${GREEN}>>> Vui long nhap ten mien cua ban (vi du: example.com):${NC}"
read -p "Domain: " INPUT_DOMAIN

# Xử lý chuỗi: Xóa toàn bộ khoảng trắng và chuyển về chữ thường
DOMAIN=$(echo "$INPUT_DOMAIN" | tr -d ' ' | tr '[:upper:]' '[:lower:]')

# Kiểm tra dữ liệu đầu vào
if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"
    exit 1
fi

# Kiểm tra sơ bộ định dạng domain (phải có dấu chấm)
if [[ "$DOMAIN" != *"."* ]]; then
    echo -e "${RED}Loi: Ten mien '$DOMAIN' khong hop le (thieu dau cham).${NC}"
    exit 1
fi

echo -e "${GREEN}>>> Dang tien hanh cai dat cho domain: ${YELLOW}$DOMAIN${NC}"

# --- BƯỚC 2: TẠO CẤU TRÚC THƯ MỤC ---
echo -e "${GREEN}[1/5] Dang tao thu muc chua ma nguon...${NC}"
# Tạo thư mục web root (-p giúp không báo lỗi nếu thư mục đã tồn tại)
sudo mkdir -p "/var/www/$DOMAIN/public_html"

echo -e "${GREEN}[2/5] Dang tao thu muc logs va cap quyen...${NC}"
# Tạo thư mục logs
sudo mkdir -p "/var/www/$DOMAIN/logs"
# Cấp quyền cho user caddy để ghi được log truy cập
sudo chown -R caddy:caddy "/var/www/$DOMAIN/logs"

# --- BƯỚC 3: TẢI VÀ GIẢI NÉN WORDPRESS ---
echo -e "${GREEN}[3/5] Dang tai WordPress phien ban moi nhat...${NC}"

# Di chuyển vào thư mục tạm /tmp để giữ sạch hệ thống
cd /tmp

# Tải file về (thêm cờ -f để báo lỗi nếu link hỏng/404)
# Xóa file cũ nếu tồn tại để tránh lỗi permission
if [[ -f latest.tar.gz ]]; then sudo rm latest.tar.gz; fi

sudo curl -fLO https://wordpress.org/latest.tar.gz

echo -e "${GREEN}[4/5] Dang giai nen ma nguon...${NC}"
# Giải nén thẳng vào thư mục đích, bỏ qua lớp vỏ 'wordpress' bên ngoài
sudo tar xzvf latest.tar.gz -C "/var/www/$DOMAIN/public_html" --strip-components=1

# Dọn dẹp file nén ở /tmp
sudo rm latest.tar.gz

# --- BƯỚC 4: PHÂN QUYỀN (PERMISSIONS) ---
echo -e "${GREEN}[5/5] Dang thiet lap quyen han chuan cho WordPress...${NC}"

WP_ROOT="/var/www/$DOMAIN/public_html"
PARENT_DIR="/var/www/$DOMAIN"
WP_OWNER="www-data"
WP_GROUP="www-data"

# Gán chủ sở hữu: www-data (để PHP có thể ghi file, cài plugin, upload ảnh)
sudo chown -R $WP_OWNER:$WP_GROUP "$WP_ROOT"
# Gán chủ sở hữu thư mục cha
sudo chown $WP_OWNER:$WP_GROUP "$PARENT_DIR"

# Chuẩn hóa quyền theo khuyến nghị bảo mật của WordPress:
# - Thư mục: 755 (rwxr-xr-x)
# - File: 644 (rw-r--r--)
sudo find "$WP_ROOT" -type d -exec chmod 755 {} \;
sudo find "$WP_ROOT" -type f -exec chmod 644 {} \;

# Đảm bảo Caddy có thể "đi xuyên qua" thư mục /var/www để đọc file
sudo chmod +x /var/www

# --- HOÀN TẤT ---
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}   Cai Dat Ma Nguon WordPress Hoan Tat!   ${NC}"
echo -e "${GREEN}=============================================${NC}"
echo -e "Domain:        ${YELLOW}$DOMAIN${NC}"
echo -e "Web Root:      ${YELLOW}$WP_ROOT${NC}"
echo -e "Logs Directory: ${YELLOW}/var/www/$DOMAIN/logs${NC}"
echo -e "${GREEN}>>> Buoc tiep theo: Cau hinh Caddyfile.${NC}"