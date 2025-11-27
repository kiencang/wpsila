#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# Chạy lệnh
# curl -sL https://raw.githubusercontent.com/kiencang/wpcaddydemo/refs/heads/main/install_caddy.sh | bash

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
# --- CẤU HÌNH BIẾN NGẪU NHIÊN (CHUẨN PIPEFAIL) ---
# Logic: Lấy trước 1 lượng data raw (head -c 500) -> Lọc -> Cắt chuỗi bằng Bash

# 1. Tạo Database Name: wp_ + 8 ký tự
# Lấy 100 byte rác, lọc lấy chữ thường/số, gán vào biến tạm
_TMP_DB=$(head -c 500 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9')
# Cắt lấy 8 ký tự đầu tiên
GEN_DB_NAME="wp_${_TMP_DB:0:8}"

# 2. Tạo User Name: user_ + 8 ký tự
_TMP_USER=$(head -c 500 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9')
GEN_DB_USER="user_${_TMP_USER:0:8}"

# 3. Tạo Password: 20 ký tự (Hoa + Thường + Số)
_TMP_PASS=$(head -c 500 /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9')
GEN_DB_PASS="${_TMP_PASS:0:20}"

# Xóa biến tạm cho gọn
unset _TMP_DB _TMP_USER _TMP_PASS

# --- BẮT ĐẦU CÀI ĐẶT ---
# Cài PHP & MariaDB
echo -e "${GREEN}[1/4] Dang cai dat PHP 8.3 va cac module can thiet...${NC}"

# Thêm repository và cài đặt PHP
sudo apt update
sudo apt install -y lsb-release ca-certificates apt-transport-https software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Cài đặt PHP 8.3 và các extensions
sudo apt install -y php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-mbstring php8.3-xml php8.3-zip php8.3-imagick php8.3-intl php8.3-bcmath

echo -e "${GREEN}[2/4] Dang cai dat MariaDB Server...${NC}"
sudo apt install -y mariadb-server

# --- BẢO MẬT MARIADB (HARDENING) ---
echo -e "${GREEN}[3/4] Dang thuc hien bao mat MariaDB (Secure Installation)...${NC}"

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

echo -e "${GREEN}[4/4] Dang tao Database va User cho WordPress...${NC}"

# Sử dụng biến đã tạo ở trên vào câu lệnh SQL
# Lưu ý: Vì biến chỉ chứa [a-zA-Z0-9] nên không cần escape phức tạp, rất an toàn.

sudo mariadb -e "CREATE DATABASE IF NOT EXISTS ${GEN_DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mariadb -e "CREATE USER IF NOT EXISTS '${GEN_DB_USER}'@'localhost' IDENTIFIED BY '${GEN_DB_PASS}';"
sudo mariadb -e "GRANT ALL PRIVILEGES ON ${GEN_DB_NAME}.* TO '${GEN_DB_USER}'@'localhost';"
sudo mariadb -e "FLUSH PRIVILEGES;"

# --- KẾT THÚC VÀ XUẤT THÔNG TIN ---

# Lưu thông tin vào file để tra cứu sau này (Quan trọng vì mật khẩu là ngẫu nhiên)
CRED_FILE="$HOME/wpp.txt"
cat > "$CRED_FILE" <<EOF
----------------------------------------
WORDPRESS DATABASE CREDENTIALS
Date: $(date)
----------------------------------------
Database Name : ${GEN_DB_NAME}
Database User : ${GEN_DB_USER}
Database Pass : ${GEN_DB_PASS}
----------------------------------------
EOF
chmod 600 "$CRED_FILE" # Chỉ user hiện tại mới đọc được file này

# Để xem lại nội dung dùng lệnh sau trên terminal: cat ~/wpp.txt
# Copy bằng cách bôi đen ở terminal, sau đó paste (ctrl + V) như bình thường ở giao diện cài đặt
# Sau khi cài xong WordPress cần xóa file này đi bằng lệnh: rm ~/wpp.txt

echo -e "${GREEN}>>> Cai dat hoan tat!${NC}"
echo -e "${YELLOW}Thong tin Database (Da duoc luu tai $CRED_FILE):${NC}"
echo -e "  - Database: ${GEN_DB_NAME}"
echo -e "  - User:     ${GEN_DB_USER}"
echo -e "  - Pass:     ${GEN_DB_PASS}"
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
read -p "Domain: " INPUT_DOMAIN < /dev/tty

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
sudo mkdir -p /var/www/$DOMAIN/public_html

echo -e "${GREEN}[2/5] Dang tao thu muc logs va cap quyen...${NC}"
# Tạo thư mục logs
sudo mkdir -p /var/www/$DOMAIN/logs
# Cấp quyền cho user caddy để ghi được log truy cập
sudo chown -R caddy:caddy /var/www/$DOMAIN/logs

# --- BƯỚC 3: TẢI VÀ GIẢI NÉN WORDPRESS ---
echo -e "${GREEN}[3/5] Dang tai WordPress phien ban moi nhat...${NC}"

# Di chuyển vào thư mục tên miền
cd /var/www/$DOMAIN

# Tải file về (thêm cờ -f để báo lỗi nếu link hỏng/404)
# Xóa file cũ nếu tồn tại để tránh lỗi permission
sudo rm -f latest.tar.gz

sudo curl -fLO https://wordpress.org/latest.tar.gz

echo -e "${GREEN}[4/5] Dang giai nen ma nguon...${NC}"
# Giải nén thẳng vào thư mục đích, bỏ qua lớp vỏ 'wordpress' bên ngoài
sudo tar xzf latest.tar.gz -C /var/www/$DOMAIN/public_html --strip-components=1

# Dọn dẹp file nén 
sudo rm -f latest.tar.gz

# --- BƯỚC 4: PHÂN QUYỀN (PERMISSIONS) ---
echo -e "${GREEN}[5/5] Dang thiet lap quyen han chuan cho WordPress...${NC}"

WP_ROOT="/var/www/$DOMAIN/public_html"
PARENT_DIR="/var/www/$DOMAIN"
WP_OWNER="www-data"
WP_GROUP="www-data"

# Gán chủ sở hữu: www-data (để PHP có thể ghi file, cài plugin, upload ảnh)
sudo chown -R $WP_OWNER:$WP_GROUP $WP_ROOT

# Gán chủ sở hữu thư mục cha, không đệ quy, không -R
sudo chown $WP_OWNER:$WP_GROUP $PARENT_DIR

# Đưa caddy vào nhóm của www-data, không cần thiết
# sudo usermod -aG www-data caddy

# Chuẩn hóa quyền theo khuyến nghị bảo mật của WordPress:
# - Thư mục: 755 (rwxr-xr-x)
# - File: 644 (rw-r--r--)
sudo find $WP_ROOT -type d -exec chmod 755 {} \;
sudo find $WP_ROOT -type f -exec chmod 644 {} \;

# Đảm bảo Caddy có thể "đi xuyên qua" thư mục /var/www để đọc file
sudo chmod +x /var/www

# Khởi động lại để tránh phân quyền bị cache
sudo systemctl reload php8.3-fpm

# --- HOÀN TẤT ---
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}   Cai Dat Ma Nguon WordPress Hoan Tat!   ${NC}"
echo -e "${GREEN}=============================================${NC}"
echo -e "Domain:        ${YELLOW}$DOMAIN${NC}"
echo -e "Web Root:      ${YELLOW}$WP_ROOT${NC}"
echo -e "Logs Directory: ${YELLOW}/var/www/$DOMAIN/logs${NC}"
echo -e "${GREEN}>>> Buoc tiep theo: Cau hinh Caddyfile.${NC}"

# --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Chinh sua file Caddyfile
# 1. Khai báo biến đường dẫn và Marker
CADDY_FILE="/etc/caddy/Caddyfile"
MARKER="#wpSila_kiencang"

# 2. Định nghĩa nội dung bạn muốn thêm vào
# Lưu ý: Tôi thêm $MARKER vào nội dung để lần sau chạy nó sẽ nhận diện được
read -r -d '' CONTENT <<EOF || true
# 1. Chuyen huong www ve non-www 
www.$DOMAIN {
    redir https://$DOMAIN{uri} permanent
}

# 2. Cau hinh chinh
$DOMAIN {
    root * /var/www/$DOMAIN/public_html
    encode zstd gzip

    # --- Cai tien 1: Log: De sua loi khi can ---
    log {
        output file /var/www/$DOMAIN/logs/access.log {
            roll_size 10mb
            roll_keep 10
        }
    }

    # PHP FastCGI
    php_fastcgi unix//run/php/php8.3-fpm.sock

    # File Server
    file_server

    # Tang gioi han upload 
    request_body {
        max_size 50MB
    }

    # --- Cai tien 2: SECURITY HEADERS (bao mat trinh duyet) ---
    header {
        # chong lai clickjacking (nguoi khac nhung web cua ban vao iframe)
        X-Frame-Options "SAMEORIGIN"
        # chong lai MIME sniffing
        X-Content-Type-Options "nosniff"
        # bao ma XSS co ban
        X-XSS-Protection "1; mode=block"
        # Ep trinh duyet chi dung HTTPS (HSTS), cai nay la tuy chon
        # Mac dinh tat, muon bat thi bo dau # phia truoc Strict-Transport-Security...
        # Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    }

# --- Cai tien 3: Cache nang cao ---

    # Nhom 1: CSS va JS (Cache 1 tuan - 604800s)
    # Danh cho truong hop hay sua giao dien, code
    @code_assets {
        file
        path *.css *.js
    }
    header @code_assets Cache-Control "public, max-age=604800"

    # Nhom 2: Image, Font, Icon (Cache 1 nam - 31536000s)
    # Nhung file nay rat it khi thay doi noi dung, nen de lau toi da
    @media_assets {
        file
        path *.ico *.gif *.jpg *.jpeg *.png *.svg *.woff *.woff2 *.webp
    }
    header @media_assets Cache-Control "public, max-age=31536000"

    # --- Cai tien 4: chan file mo rong (bao mat file nhay cam) ---
    @forbidden {
        # chan thuc thi PHP o noi khong can thiet
        path /wp-content/uploads/*.php
        path /wp-includes/*.php
        # chan file cau hinh & file ma nguon he thong
        path /wp-config.php
        path /.htaccess
        path /.git
        path /.env
        path *.sql
        path *.bak
    }
    respond @forbidden 404
}
    # Đánh dấu marker để nhận diện sau này
    $MARKER
EOF

# 3. Thực hiện Logic kiểm tra
# grep -q: Chế độ im lặng (quiet), chỉ trả về đúng (0) hoặc sai (1), không in ra màn hình
# 2>/dev/null: Ẩn lỗi nếu file không tồn tại
if grep -q "$MARKER" "$CADDY_FILE" 2>/dev/null; then
		
	echo "TIM THAY marker '$MARKER'. Dang noi noi dung vao cuoi file..."
		
	# Thay thế cho echo >> (Nối thêm)
	echo "$CONTENT" | sudo tee -a "$CADDY_FILE" > /dev/null

else
		
	echo "KHONG TIM THAY marker '$MARKER'. Dang xoa cu va tao file moi..."
		
	# Thay thế cho echo > (Ghi đè)
	echo "$CONTENT" | sudo tee "$CADDY_FILE" > /dev/null

fi

echo "Dang kiem tra va reload Caddy..."
# 4. Format
caddy fmt --overwrite "$CADDY_FILE" > /dev/null 2>&1

# Cấp lại quyền cho user caddy để ghi được log truy cập
# Phòng lỗi mất quyền và không khởi động lại được caddy bằng systemctl reload caddy
sudo chown -R caddy:caddy /var/www/$DOMAIN/logs

#5. Reload lại Caddy
sudo systemctl reload caddy

echo "Hoàn tất!"
