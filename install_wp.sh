#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# Chạy lệnh
# version 0.02.12.25
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/install_wp.sh | bash

# Màu sắc cho thông báo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Bắt buộc phải chạy bằng root để cài đặt phần mềm
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Loi: Ban phai chay script nay bang quyen Root.${NC}"
   echo -e "Vui long vao terminal voi quyen Root, sau do chay lai lenh."
   exit 1
fi

echo -e "${GREEN}Dang tao Database va User cho WordPress...${NC}"

# --- CẤU HÌNH BIẾN NGẪU NHIÊN ---
# 1. DB Name (Thoải mái độ dài, MySQL cho phép 64 ký tự)
# Kết quả ví dụ: wp_a1b2c3d4e5f67890
GEN_DB_NAME="wp_$(openssl rand -hex 8)"

# 2. User Name (Nên giữ <= 16 ký tự để tương thích mọi phiên bản MySQL)
# Giảm xuống hex 7 (14 ký tự) + "u_" (2 ký tự) = 16 ký tự
# Kết quả ví dụ: u_a1b2c3d4e5f6g7
GEN_DB_USER="u_$(openssl rand -hex 7)"

# 3. Password (32 ký tự là rất mạnh rồi)
# Kết quả ví dụ: p_890123456789abcdef0123456789abcd
GEN_DB_PASS="p_$(openssl rand -hex 16)"

# Sử dụng biến đã tạo ở trên vào câu lệnh SQL
# Lưu ý: Vì biến chỉ chứa chữ cái thường và số nên không cần escape phức tạp, rất an toàn.

sudo mariadb -e "CREATE DATABASE IF NOT EXISTS ${GEN_DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mariadb -e "CREATE USER IF NOT EXISTS '${GEN_DB_USER}'@'localhost' IDENTIFIED BY '${GEN_DB_PASS}';"
sudo mariadb -e "GRANT ALL PRIVILEGES ON ${GEN_DB_NAME}.* TO '${GEN_DB_USER}'@'localhost';"
sudo mariadb -e "FLUSH PRIVILEGES;"

# --- KẾT THÚC VÀ XUẤT THÔNG TIN ---

# Lưu thông tin vào file để tra cứu sau này (Quan trọng vì mật khẩu là ngẫu nhiên)
CRED_FILE="$HOME/wpp.txt"

# Kiểm tra nếu file tồn tại thì mới xóa
sudo rm -f "$CRED_FILE"

# Tạo file mới cho trang WordPress đang cài
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
echo -e "${GREEN}>>> Buoc tiep theo: Cai dat WordPress.${NC}"
sleep 2

echo "-------------------------------------------------------------------------------------------------"
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Phần 4: Cai dat WordPress
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

# Cấu hình số lần thử tối đa
MAX_RETRIES=3
COUNT=0
DOMAIN=""

# Bắt đầu vòng lặp
while [[ $COUNT -lt $MAX_RETRIES ]]; do
	COUNT=$((COUNT + 1)) # Đừng để $COUNT++, nó sẽ gặp lỗi Bash gặp 0
    
    # Hiển thị prompt có kèm số lần thử để user biết
	if [[ $COUNT -eq 1 ]]; then
		read -p "Nhap Domain: " INPUT_DOMAIN < /dev/tty
	else
		echo -e "${RED}Ban vua nhap sai! Hay chu y nhap lai dung nhe.${NC}"
		read -p "Nhap Domain: " INPUT_DOMAIN < /dev/tty
	fi
    # Xử lý chuỗi, bỏ khoảng trắng, chuyển chữ hoa thành chữ thường
	TEMP_DOMAIN=$(echo "$INPUT_DOMAIN" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
	
	# 2. Gọt bỏ http, https và trailing slash
    # Input:  https://Example.com/
    # Output: example.com
    DOMAIN=$(echo "$TEMP_DOMAIN" | sed -e 's|^https\?://||' -e 's|/.*$||')
    
    # --- KIỂM TRA LOGIC ---
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"
    elif [[ "$DOMAIN" != *"."* ]]; then
        echo -e "${RED}Loi: Ten mien '$DOMAIN' khong hop le (thieu dau cham).${NC}"
    else
        # Nếu đã sửa xong mà hợp lệ -> Chấp nhận luôn
        # Có thể in ra thông báo để người dùng biết script đã tự sửa giúp họ
        if [[ "$INPUT_DOMAIN" != "$DOMAIN" ]]; then
             echo -e "${GREEN}Script da tu dong chuan hoa input '${INPUT_DOMAIN}' thanh '${DOMAIN}'${NC}"
        fi
        break
    fi

    # Nếu mã chạy xuống đây nghĩa là nhập sai
    if [[ $COUNT -eq $MAX_RETRIES ]]; then
        echo -e "${RED}Ban da nhap sai qua 3 lan. Script se dung lai de bao ve he thong.${NC}"
        exit 1
    else
        echo "Vui long thu lai..."
        echo "-------------------------"
    fi
done

# --- Script tiếp tục chạy từ đây khi dữ liệu đã đúng ---
echo -e "Thanh cong! Domain duoc chap nhan: $DOMAIN"

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

 # ==================================================================
 # BỔ SUNG: TỰ ĐỘNG CẤU HÌNH WP-CONFIG VÀ INSTALL DB
 # ==================================================================
    echo -e "${GREEN}>>> Dang tu dong cau hinh wp-config.php va Database...${NC}"

    # 1. Cài đặt WP-CLI nếu chưa có
    if ! [ -x "$(command -v wp)" ]; then
        echo " -> Dang tai WP-CLI..."
        sudo curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        sudo chmod +x wp-cli.phar
        sudo mv wp-cli.phar /usr/local/bin/wp
    fi

    # 2. Định nghĩa biến nội bộ cho quá trình cài đặt
    WP_PATH="/var/www/$DOMAIN/public_html"
    WP_ADMIN_USER="admin"
    WP_ADMIN_PASS="p_$(openssl rand -hex 12)" # Tạo pass ngẫu nhiên
    WP_ADMIN_EMAIL="admin@$DOMAIN"

    # Di chuyển vào thư mục code
    cd "$WP_PATH" || exit

    # 3. Tạo file wp-config.php từ thông tin DB ở Bước 2
    # Dùng --allow-root vì script đang chạy quyền sudo
    wp config create --dbname="$GEN_DB_NAME" \
                     --dbuser="$GEN_DB_USER" \
                     --dbpass="$GEN_DB_PASS" \
                     --dbhost="localhost" \
                     --allow-root --force

    # 4. Chạy lệnh Install để nạp dữ liệu vào Database
    echo " -> Dang khoi tao du lieu WordPress..."
    wp core install --url="https://$DOMAIN" \
                    --title="Website $DOMAIN" \
                    --admin_user="$WP_ADMIN_USER" \
                    --admin_password="$WP_ADMIN_PASS" \
                    --admin_email="$WP_ADMIN_EMAIL" \
                    --skip-email \
                    --allow-root

# 5. Ghi thêm thông tin đăng nhập WP vào file wpp.txt
cat >> "$CRED_FILE" <<EOF
----------------------------------------
WORDPRESS ADMIN INFO
----------------------------------------
Login URL  : https://$DOMAIN/wp-admin
User       : $WP_ADMIN_USER
Pass       : $WP_ADMIN_PASS
Email      : $WP_ADMIN_EMAIL
----------------------------------------
EOF

echo -e "${GREEN}>>> Da cai dat xong WordPress Core!${NC}"
# ==================================================================

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
sleep 2

echo "-------------------------------------------------------------------------------------------------"
# --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Phần 5: Chinh sua file Caddyfile
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
	
    # Tang gioi han upload, can chinh them /etc/php/8.3/fpm/php.ini cho dong bo
    request_body {
        max_size 50MB
    }	

    # Log: Tu dong xoay vong
    log {
        output file /var/www/$DOMAIN/logs/access.log {
            roll_size 10mb
            roll_keep 10
        }
    }

    # --- SECURITY HEADERS ---
    # Sau khi HTTPS da chay on dinh, hay bo comment dong Strict-Transport-Security
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        X-XSS-Protection "0"
        Referrer-Policy "strict-origin-when-cross-origin"
        Permissions-Policy "camera=(), microphone=(), geolocation=(), browsing-topics=()"
        # Strict-Transport-Security "max-age=31536000; includeSubDomains"
        -Server
        -X-Powered-By
    }

    # --- CACHE CODE (CSS/JS) ---
    # Khong dung immutable de tranh loi khi update code
    @code_assets {
        file
        path *.css *.js
    }
    header @code_assets Cache-Control "public, max-age=604800"

    # --- CACHE MEDIA (ANH/FONT) ---
    # Dung immutable vi file anh it khi sua noi dung ma giu nguyen ten
    @media_assets {
        file
        path *.ico *.gif *.jpg *.jpeg *.png *.svg *.woff *.woff2 *.webp *.avif
    }
    header @media_assets Cache-Control "public, max-age=31536000, immutable"

    # --- CHAN FILE NHAY CAM (SECURITY BLOCK) ---
    @forbidden {
        # 1. Block PHP Uploads 
        path /wp-content/uploads/*.php

        # 2. Block System Files & Directories
        path /wp-config.php
        path /.htaccess
		path /.git
        path /.git/*     
        path *.env   
        path /readme.html
        path /license.txt
		
		# 3. Block xmlrpc 
		path /xmlrpc.php
        
        # 4. Block Backups & Logs
        path *.sql *.bak *.log *.old
        # path *.zip *.rar *.tar *.7z
    }
    # Tra ve 404
    respond @forbidden 404
	
	# PHP FastCGI (Check lai duong dan socket neu dung OS khac Ubuntu/Debian)
    php_fastcgi unix//run/php/php8.3-fpm.sock

    file_server
}
    # Đánh dấu marker để nhận diện sau này
    $MARKER
EOF

# 3. Thực hiện Logic kiểm tra
# grep -q: Chế độ im lặng (quiet), chỉ trả về đúng (0) hoặc sai (1), không in ra màn hình
# 2>/dev/null: Ẩn lỗi nếu file không tồn tại
if grep -q "$MARKER" "$CADDY_FILE" 2>/dev/null; then
		
	echo "TIM THAY marker '$MARKER'. Dang them cau hinh vao cuoi file Caddyfile..."
		
	# Thay thế cho echo >> (Nối thêm)
	echo "$CONTENT" | sudo tee -a "$CADDY_FILE" > /dev/null

else
		
	echo "CAI DAT WORDPRESS lan dau tren Caddy! Dang xoa mac dinh cu va tao file Caddyfile moi..."
		
	# Thay thế cho echo > (Ghi đè)
	echo "$CONTENT" | sudo tee "$CADDY_FILE" > /dev/null

fi

echo "Dang kiem tra va reload Caddy..."
# 4. Format
caddy fmt --overwrite "$CADDY_FILE" > /dev/null 2>&1

#5. Reload lại Caddy
sudo systemctl reload caddy

echo "Hoan tat! Xin chuc mung ban da cai thanh cong WordPress trên Caddy Web Server."