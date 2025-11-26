#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -e

# Màu sắc cho thông báo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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