#!/bin/bash

# Dừng script ngay nếu có lỗi
set -e

# Định nghĩa màu sắc
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[1/4] Đang cài đặt PHP 8.3 và các module cần thiết...${NC}"
# Thêm repository và cài đặt PHP
sudo apt update
sudo apt install -y lsb-release ca-certificates apt-transport-https software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Cài đặt PHP 8.3 và các extensions
sudo apt install -y php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-mbstring php8.3-xml php8.3-zip php8.3-imagick php8.3-intl php8.3-bcmath

echo -e "${GREEN}[2/4] Đang cài đặt MariaDB Server...${NC}"
sudo apt install -y mariadb-server

echo -e "${GREEN}[3/4] Đang bảo mật MariaDB (mysql_secure_installation)...${NC}"

# Tự động hóa việc trả lời các câu hỏi bảo mật
# Thứ tự câu trả lời: Enter (pass cũ rỗng) -> Y (unix_socket) -> n (đổi pass root) -> Y (xóa anonymous) -> Y (cấm remote root) -> Y (xóa test db) -> Y (reload)
sudo mysql_secure_installation <<EOF

Y
n
Y
Y
Y
Y
EOF

echo -e "${GREEN}[4/4] Đang tạo Database và User cho WordPress...${NC}"

# Sử dụng lệnh mysql -e để chạy SQL trực tiếp mà không cần vào shell tương tác
# Lưu ý: Thêm "IF NOT EXISTS" để script không bị lỗi nếu chạy lại lần 2

sudo mariadb -e "CREATE DATABASE IF NOT EXISTS wordpress_caddy DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mariadb -e "CREATE USER IF NOT EXISTS 'wpuser_caddy'@'localhost' IDENTIFIED BY 'pass_db_caddy';"
sudo mariadb -e "GRANT ALL PRIVILEGES ON wordpress_caddy.* TO 'wpuser_caddy'@'localhost';"
sudo mariadb -e "FLUSH PRIVILEGES;"

echo -e "${GREEN}>>> Cài đặt hoàn tất!${NC}"
echo -e "${YELLOW}Thông tin Database:${NC}"
echo -e "  - Database: wordpress_caddy"
echo -e "  - User:     wpuser_caddy"
echo -e "  - Pass:     pass_db_caddy"
echo -e "${YELLOW}Kiểm tra PHP version:${NC}"
php -v
