# -----------------------------------------------------------
# MODULE: Cài đặt WordPress và phân quyền
# File này được nhúng vào script install_wp.sh
# -----------------------------------------------------------
# G1. TẠO CẤU TRÚC THƯ MỤC
echo -e "${GREEN}[1/5] Dang tao thu muc chua ma nguon...${NC}"
# Tạo thư mục web root (-p giúp không báo lỗi nếu thư mục đã tồn tại)
mkdir -p /var/www/$DOMAIN/public_html

echo -e "${GREEN}[2/5] Dang tao thu muc logs va cap quyen...${NC}"
# Tạo thư mục logs
mkdir -p /var/www/$DOMAIN/logs
# Cấp quyền cho user caddy để ghi được log truy cập
chown -R caddy:caddy /var/www/$DOMAIN/logs
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# G2. TẢI VÀ GIẢI NÉN WORDPRESS 
echo -e "${GREEN}[3/5] Dang tai WordPress phien ban moi nhat...${NC}"

# Di chuyển vào thư mục tên miền
cd /var/www/$DOMAIN

# Tải file về (thêm cờ -f để báo lỗi nếu link hỏng/404)
# Xóa file cũ nếu tồn tại để tránh lỗi permission
rm -f latest.tar.gz

curl -fLO https://wordpress.org/latest.tar.gz

echo -e "${GREEN}[4/5] Dang giai nen ma nguon...${NC}"
# Giải nén thẳng vào thư mục đích, bỏ qua lớp vỏ 'wordpress' bên ngoài
tar xzf latest.tar.gz -C /var/www/$DOMAIN/public_html --strip-components=1

# Dọn dẹp file nén 
rm -f latest.tar.gz
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# G3. TỰ ĐỘNG CẤU HÌNH WP-CONFIG VÀ INSTALL DB
echo -e "${GREEN}>>> Dang tu dong cau hinh wp-config.php va database...${NC}"

# G3.1. Cài đặt WP-CLI nếu chưa có
    if ! [ -x "$(command -v wp)" ]; then
        echo " -> Dang tai WP-CLI..."
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x wp-cli.phar
        mv wp-cli.phar /usr/local/bin/wp
    fi

# G3.2. Định nghĩa biến nội bộ cho quá trình cài đặt
    WP_PATH="/var/www/$DOMAIN/public_html"
    WP_ADMIN_USER="admin"
    WP_ADMIN_PASS="p_$(openssl rand -hex 12)" # Tạo pass ngẫu nhiên
    WP_ADMIN_EMAIL="admin@$DOMAIN"

    # Di chuyển vào thư mục code
    cd "$WP_PATH" || exit

# G3.3. Tạo file wp-config.php từ thông tin DB ở Bước 2
    # Dùng --allow-root vì script đang chạy quyền sudo
    wp config create --dbname="$GEN_DB_NAME" \
                     --dbuser="$GEN_DB_USER" \
                     --dbpass="$GEN_DB_PASS" \
                     --dbhost="localhost" \
                     --allow-root --force

# G3.4. Chạy lệnh Install để nạp dữ liệu vào Database
    echo " -> Dang khoi tao du lieu WordPress..."
    wp core install --url="https://$DOMAIN" \
                    --title="Website $DOMAIN" \
                    --admin_user="$WP_ADMIN_USER" \
                    --admin_password="$WP_ADMIN_PASS" \
                    --admin_email="$WP_ADMIN_EMAIL" \
                    --skip-email \
                    --allow-root

# G3.5. Ghi thêm thông tin đăng nhập WP vào file wpp.txt
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

echo -e "${GREEN}>>> Da cai dat xong WordPress core!${NC}"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# H. PHÂN QUYỀN (PERMISSIONS) ---
# Điều chỉnh phân quyền để dễ dàng hơn trong việc tạo tài khoản sFTP sau này.
echo -e "${GREEN}[5/5] Dang thiet lap quyen han chuan cho WordPress...${NC}"

WP_ROOT="/var/www/$DOMAIN/public_html"
PARENT_DIR="/var/www/$DOMAIN"

# Gán chủ sở hữu thư mục cha, không đệ quy, không -R
# Cái này dùng để nhốt user sFTP trong tương lai không leo ra ngoài thư mục web nó có quyền
# Tức là nó chỉ có quyền trong phạm vi web nó được gán không leo toàn bộ các web trên VPS
chown root:root $PARENT_DIR
chmod 755 $PARENT_DIR

# Gán Group www-data là chủ sở hữu (để PHP có thể ghi file, cài plugin, upload ảnh)
# User sở hữu là root
chown -R root:www-data $WP_ROOT

# Chuẩn hóa quyền để không mâu thuẫn quyền của nhau sau này khi tạo tài khoản sFTP:
# - Thư mục: 775 (rwxrwxr-x)
# - File: 664 (rw-rw-r--)
# số 2 trước 775 là để các file sau này do sFTP up lên mặc định thuộc quyền sở hữu của group www-data
# Do vậy user www-data thuộc group www-data sẽ có quyền làm việc với file đó mà không bị lỗi không đủ quyền.
find $WP_ROOT -type d -exec chmod 2775 {} \;
find $WP_ROOT -type f -exec chmod 664 {} \;

# Định nghĩa đường dẫn file config 
WP_CONFIG="$WP_ROOT/wp-config.php"

# Bổ sung để vượt qua sự khó tính về quyền trong WordPress. Dù phân quyền trên đã ổn.
# Kiểm tra: Nếu chưa có FS_METHOD thì mới thực hiện
if ! grep -q "FS_METHOD" "$WP_CONFIG"; then
    # Dùng lệnh sed để chèn ngay sau thẻ mở <?php
    # Dấu ^ đảm bảo chỉ tìm <?php ở đầu dòng (tránh nhầm lẫn nếu có trong comment)
    sed -i "0,/<?php/s/<?php/<?php\n\ndefine( 'FS_METHOD', 'direct' );/" "$WP_CONFIG"
    
    echo "Da them cau hinh FS_METHOD: direct"
else
    echo "Cau hinh FS_METHOD da ton tai."
fi

# Phân quyền để quản lý chặt file wp-config
if [ -f "$WP_CONFIG" ]; then
    chmod 660 $WP_CONFIG
fi

# Đảm bảo Caddy có thể "đi xuyên qua" thư mục /var/www để đọc file
chmod +x /var/www

# Khởi động lại để tránh phân quyền bị cache
systemctl reload php${PHP_VER}-fpm

# --- HOÀN TẤT ---
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}   Cai Dat Ma Nguon WordPress Hoan Tat!   ${NC}"
echo -e "${GREEN}=============================================${NC}"
echo -e "Domain:        ${YELLOW}$DOMAIN${NC}"
echo -e "Web Root:      ${YELLOW}$WP_ROOT${NC}"
echo -e "Logs Directory: ${YELLOW}/var/www/$DOMAIN/logs${NC}"
echo -e "${GREEN}>>> Buoc tiep theo: Cau hinh Caddyfile.${NC}"
sleep 2