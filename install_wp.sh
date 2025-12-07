#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# Chạy lệnh
# version 0.05.12.25
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/install_wp.sh | bash

# Màu sắc cho thông báo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# QUAN TRỌNG: CẤU HÌNH PHIÊN BẢN PHP
# 1. Đặt giá trị mặc định (phòng hờ không tìm thấy file config)
DEFAULT_PHP_VER="8.3"

# 2. Định nghĩa đường dẫn file config 
# (Ví dụ: file config nằm cùng thư mục với script đang chạy)
# Lấy đường dẫn tuyệt đối của thư mục chứa file script đang chạy
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# Trỏ vào file config nằm cùng thư mục đó
WPSILA_CONFIG_FILE="$SCRIPT_DIR/wpsila.conf"

# 3. Kiểm tra và nạp file config
if [ -f "$WPSILA_CONFIG_FILE" ]; then
    # Lệnh 'source' hoặc dấu chấm '.' sẽ đọc biến từ file kia vào script này
    source "$WPSILA_CONFIG_FILE"
    echo -e "${GREEN}Da tim thay file cau hinh: ${WPSILA_CONFIG_FILE}${NC}"
else
    echo -e "${YELLOW}Khong tim thay file config. Su dung phien ban mac dinh.${NC}"
fi

# 4. Chốt phiên bản cuối cùng
# Cú pháp ${BIEN_1:-$BIEN_2} nghĩa là: Nếu BIEN_1 rỗng (chưa set trong config), thì lấy BIEN_2
PHP_VER="${PHP_VER:-$DEFAULT_PHP_VER}"

echo "Phien ban PHP: $PHP_VER"

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
# Điều chỉnh phân quyền để dễ dàng hơn trong việc tạo tài khoản sFTP sau này.
echo -e "${GREEN}[5/5] Dang thiet lap quyen han chuan cho WordPress...${NC}"

WP_ROOT="/var/www/$DOMAIN/public_html"
PARENT_DIR="/var/www/$DOMAIN"

# Gán chủ sở hữu thư mục cha, không đệ quy, không -R
# Cái này dùng để nhốt user sFTP trong tương lai không leo ra ngoài thư mục web nó có quyền
# Tức là nó chỉ có quyền trong phạm vi web nó được gán không leo toàn bộ các web trên VPS
sudo chown root:root $PARENT_DIR
sudo chmod 755 $PARENT_DIR

# Gán Group www-data là chủ sở hữu (để PHP có thể ghi file, cài plugin, upload ảnh)
# User sở hữu là root
sudo chown -R root:www-data $WP_ROOT

# Chuẩn hóa quyền để không mâu thuẫn quyền của nhau sau này khi tạo tài khoản sFTP:
# - Thư mục: 775 (rwxrwxr-x)
# - File: 664 (rw-rw-r--)
# số 2 trước 775 là để các file sau này do sFTP up lên mặc định thuộc quyền sở hữu của group www-data
# Do vậy user www-data thuộc group www-data sẽ có quyền làm việc với file đó mà không bị lỗi không đủ quyền.
sudo find $WP_ROOT -type d -exec chmod 2775 {} \;
sudo find $WP_ROOT -type f -exec chmod 664 {} \;

# Định nghĩa đường dẫn file config 
WP_CONFIG="$WP_ROOT/wp-config.php"

# Bổ sung để vượt qua sự khó tính về quyền trong WordPress. Dù phân quyền trên đã ổn.
# Kiểm tra: Nếu chưa có FS_METHOD thì mới thực hiện
if ! grep -q "FS_METHOD" "$WP_CONFIG"; then
    # Dùng lệnh sed để chèn ngay sau thẻ mở <?php
    # Dấu ^ đảm bảo chỉ tìm <?php ở đầu dòng (tránh nhầm lẫn nếu có trong comment)
    sudo sed -i "0,/<?php/s/<?php/<?php\n\ndefine( 'FS_METHOD', 'direct' );/" "$WP_CONFIG"
    
    echo "Da them cau hinh FS_METHOD: direct"
else
    echo "Cau hinh FS_METHOD da ton tai."
fi

# Phân quyền để quản lý chặt file wp-config
if [ -f "$WP_CONFIG" ]; then
    sudo chmod 660 $WP_CONFIG
fi

# Đảm bảo Caddy có thể "đi xuyên qua" thư mục /var/www để đọc file
sudo chmod +x /var/www

# Khởi động lại để tránh phân quyền bị cache
sudo systemctl reload php${PHP_VER}-fpm

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
# ---------------------------------------------------------
# 1. Khai báo biến đường dẫn và Marker
CADDY_FILE="/etc/caddy/Caddyfile"
MARKER="#wpsila_kiencang"
# URL trỏ tới file template (đã thay đổi theo link của bạn)
TEMPLATE_URL="https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/caddyfile_wp.tpl"
TEMP_CADDY="/tmp/caddy_gen_temp.conf"

# Xác định và chuẩn hóa dạng tên miền
if [[ "$DOMAIN" == www.* ]]; then
    RED_DOMAIN="${DOMAIN#www.}"
else
    RED_DOMAIN="www.$DOMAIN"
fi

echo "Domain chinh: $DOMAIN"
echo "Domain chuyen huong: $RED_DOMAIN"

# 2. Tải template cấu hình từ GitHub
echo -e "${GREEN}>>> Dang tai Caddy Template tu GitHub...${NC}"
if ! curl -sL "$TEMPLATE_URL" -o "$TEMP_CADDY"; then
    echo -e "${RED}Loi: Khong the tai file template Caddy. Kiem tra lai ket noi mang hoac URL.${NC}"
    exit 1
fi

# 3. Xử lý thay thế biến vào Template
sed -i "s|{{DOMAIN}}|$DOMAIN|g" "$TEMP_CADDY"
sed -i "s|{{RED_DOMAIN}}|$RED_DOMAIN|g" "$TEMP_CADDY"
sed -i "s|{{PHP_VER}}|$PHP_VER|g" "$TEMP_CADDY"

CONTENT=$(cat "$TEMP_CADDY")
rm -f "$TEMP_CADDY"

# --- TẠO BACKUP AN TOÀN ---
TIMESTAMP=$(date +%s)
BACKUP_FILE="${CADDY_FILE}.bak_${TIMESTAMP}"

# Kiểm tra nếu file tồn tại thì mới backup để tránh lỗi
if [ -f "$CADDY_FILE" ]; then
    echo "Dang tao file backup: $BACKUP_FILE"
    sudo cp "$CADDY_FILE" "$BACKUP_FILE"
else
    echo "Day la lan cai dat dau tien, chua co file Caddyfile cu de backup."
    # Tạo file rỗng để tránh lỗi cho các lệnh phía sau
    sudo touch "$CADDY_FILE"
fi

# 4. Thực hiện ghi vào Caddyfile chính
if grep -q "$MARKER" "$CADDY_FILE" 2>/dev/null; then
    echo "TIM THAY marker '$MARKER'. Dang them cau hinh vao cuoi file Caddyfile..."
    echo "$CONTENT" | sudo tee -a "$CADDY_FILE" > /dev/null
else
    echo "CAI DAT WORDPRESS lan dau! Tao file Caddyfile moi..."
    echo "$CONTENT" | sudo tee "$CADDY_FILE" > /dev/null
fi

# Format lại cho đẹp
sudo caddy fmt --overwrite "$CADDY_FILE" > /dev/null 2>&1

# 5. VALIDATE & ROLLBACK
echo "Dang kiem tra cu phap Caddyfile..."

# Kiểm tra tính hợp lệ
if ! sudo caddy validate --config "$CADDY_FILE" --adapter caddyfile > /dev/null 2>&1; then
    echo -e "${RED}CANH BAO: File Caddyfile bi loi cu phap!${NC}"
    
    # In ra lỗi cụ thể cho người dùng xem sai ở đâu
    sudo caddy validate --config "$CADDY_FILE" --adapter caddyfile
    
    echo -e "${YELLOW}Dang khoi phuc lai file ban dau...${NC}"
    
    if [ -f "$BACKUP_FILE" ]; then
        sudo cp "$BACKUP_FILE" "$CADDY_FILE"
        echo "Da khoi phuc lai file goc an toan."
    else
        # Trường hợp cài lần đầu mà lỗi luôn thì xóa file lỗi đi
        echo "Khong co file backup (cai lan dau). Xoa file loi..."
        sudo rm "$CADDY_FILE"
    fi
    
    exit 1
else
    # Nếu mọi thứ OK, Reload lại Caddy
    echo "Cau hinh hop le. Dang reload Caddy..."
	# Ngăn ngừa việc mất quyền hay xảy ra, khiến cho việc tải lại không thành công.
	# Nguyên nhân là vì mặc dù phân quyền đã làm, nhưng trong quá trình cài đặt có thể root ghi vào file log.
	# Nó thành chủ sở hữu và không cho user caddy can thiệp vào nữa, cách phòng thủ tốt nhất là tái lập lại quyền.
	# Rất dễ xảy ra với việc cài lần đầu tiên.
	sudo chown -R caddy:caddy /var/www/$DOMAIN/logs
	
    sudo systemctl reload caddy
    echo "Hoan tat! Da cap nhat cau hinh cho $DOMAIN trong Caddyfile."
fi

echo "Nhap lenh: cat ~/wpp.txt de xem thong tin dang nhap WordPress."
echo "Hoan tat! Xin chuc mung ban da cai thanh cong WordPress trên Caddy Web Server."