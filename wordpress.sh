# shellcheck shell=bash
# -----------------------------------------------------------
# MODULE: Cài đặt WordPress và phân quyền.
# File: wordpress.sh
# File này được nhúng vào script install_wp.sh
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# G1. TẠO CẤU TRÚC THƯ MỤC
# Một số điểm lưu ý về cấu trúc thư mục 
# 1. Mỗi tên miền là một thư mục riêng trong var/www => Chống hoàn toàn việc trùng lặp.
# 2. logs và public_html (thư mục web) tách riêng để tránh việc phân quyền phức tạp.
# 3. logs và public_html vẫn thuộc về cùng một thư mục cha chung, điều đó giúp dễ xóa sau này >
# > Xóa thư mục tên miền là xóa cả logs và thư mục web (public_html).

echo -e "${GREEN}[1/5] Dang tao thu muc chua ma nguon...${NC}"
# Tạo thư mục web root (-p giúp không báo lỗi nếu thư mục đã tồn tại)
mkdir -p "/var/www/$DOMAIN/public_html"
CREATED_WEB_DIR=1

echo -e "${GREEN}[2/5] Dang tao thu muc logs va cap quyen...${NC}"
# Tạo thư mục logs
mkdir -p "/var/www/$DOMAIN/logs"

# Cấp quyền cho user caddy để ghi được log truy cập
chown -R caddy:caddy "/var/www/$DOMAIN/logs"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# G2. TẢI WP-CLI VÀ MÃ NGUỒN WORDPRESS (CÓ FALLBACK ĐA TẦNG)
echo -e "${GREEN}[3/5] Dang chuan bi WP-CLI va tai WordPress phien ban moi nhat...${NC}"

# G2.1. Cài đặt WP-CLI nếu chưa có (kèm xác thực SHA-512 và Fallback 2 nguồn)
if ! [[ -x "$(command -v wp)" ]]; then
    echo " -> Dang tai WP-CLI..."
    cd /tmp || exit 1
    rm -f wp-cli.phar wp-cli.phar.sha512

    WPCLI_OK=0
    # Nguồn 1: Nhánh builds chính thức trên GitHub (kèm kiểm tra SHA-512)
    if curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o wp-cli.phar; then
        if curl -fsSL --retry 2 --connect-timeout 10 https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar.sha512 -o wp-cli.phar.sha512; then
            EXPECTED_WPCLI_SHA512=$(awk '{print $1}' wp-cli.phar.sha512 | tr -d '\r\n ')
            ACTUAL_WPCLI_SHA512=$(sha512sum wp-cli.phar | awk '{print $1}')
            rm -f wp-cli.phar.sha512
            if [[ -n "$EXPECTED_WPCLI_SHA512" && "$EXPECTED_WPCLI_SHA512" == "$ACTUAL_WPCLI_SHA512" ]]; then
                WPCLI_OK=1
            else
                echo -e "${YELLOW}Canh bao: Checksum WP-CLI tu nguon 1 khong khop, dang thu nguon du phong...${NC}"
                rm -f wp-cli.phar
            fi
        elif [[ -s wp-cli.phar ]]; then
            WPCLI_OK=1
        fi
    fi

    # Nguồn 2 (Dự phòng): Tải từ GitHub Releases chính thức của wp-cli/wp-cli
    if (( WPCLI_OK == 0 )); then
        echo -e "${YELLOW} -> Chuyen sang tai WP-CLI tu kho du phong GitHub Releases...${NC}"
        if curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 https://github.com/wp-cli/wp-cli/releases/latest/download/wp-cli.phar -o wp-cli.phar && [[ -s wp-cli.phar ]]; then
            WPCLI_OK=1
        fi
    fi

    if (( WPCLI_OK == 1 )); then
        chmod +x wp-cli.phar
        mv wp-cli.phar /usr/local/bin/wp
    else
        rm -f /tmp/wp-cli.phar /tmp/wp-cli.phar.sha512
        echo -e "${RED}LOI: Khong the tai WP-CLI tu ca 2 nguon! Vui long kiem tra ket noi mang.${NC}"
        exit 1
    fi
    unset WPCLI_OK
fi

# G2.2. Tải và giải nén mã nguồn WordPress (Có Fallback 3 nguồn chống lỗi 429 Too Many Requests từ wordpress.org)
cd "/var/www/$DOMAIN" || { echo "Loi: Khong tim thay thu muc!"; exit 1; }
rm -f latest.tar.gz latest.tar.gz.sha1

WP_DOWNLOAD_OK=0

# Nguồn 1: Tải trực tiếp latest.tar.gz từ wordpress.org (kèm kiểm tra SHA-1)
if curl -fLO --retry 3 --retry-delay 2 --connect-timeout 10 https://wordpress.org/latest.tar.gz; then
    if curl -fsSL --retry 2 --connect-timeout 10 https://wordpress.org/latest.tar.gz.sha1 -o latest.tar.gz.sha1; then
        EXPECTED_WP_SHA1=$(awk '{print $1}' latest.tar.gz.sha1 | tr -d '\r\n ')
        ACTUAL_WP_SHA1=$(sha1sum latest.tar.gz | awk '{print $1}')
        rm -f latest.tar.gz.sha1
        if [[ -n "$EXPECTED_WP_SHA1" && "$EXPECTED_WP_SHA1" == "$ACTUAL_WP_SHA1" ]]; then
            WP_DOWNLOAD_OK=1
        else
            echo -e "${YELLOW}Canh bao: Checksum SHA-1 cua latest.tar.gz khong khop! Chuyen sang nguon du phong...${NC}"
            rm -f latest.tar.gz
        fi
    elif [[ -s latest.tar.gz ]]; then
        WP_DOWNLOAD_OK=1
    fi
fi

# Nguồn 2 (Dự phòng): Tải bản phát hành ổn định (Stable Tag) mới nhất từ GitHub Mirror chính thức (WordPress/WordPress)
# Tuyệt đối không tải nhánh master (vốn là nhánh trunk/alpha đang phát triển)
if (( WP_DOWNLOAD_OK == 0 )); then
    echo -e "${YELLOW}Canh bao: wordpress.org dang gioi han ket noi (429/Timeout). Chuyen sang kho du phong GitHub (WordPress/WordPress)...${NC}"
    LATEST_WP_TAG=""

    # Ưu tiên 2a: Lấy tag ổn định mới nhất từ trang Tags của GitHub (Không qua api.github.com nên không bị giới hạn 60 req/giờ)
    # Khóa đuôi bằng dấu nháy kép " để không cắt nhầm phần đầu của các tag thử nghiệm như 6.8-beta1 hoặc 6.8-RC1
    LATEST_WP_TAG=$(curl -fsSL --retry 2 --connect-timeout 10 "https://github.com/WordPress/WordPress/tags" | grep -oE '/WordPress/WordPress/releases/tag/[0-9]+\.[0-9]+(\.[0-9]+)?"' | tr -d '"' | sed 's|.*/||' | sort -V | tail -n 1 || true)

    # Ưu tiên 2b: Dự phòng qua GitHub Tags API (lọc chỉ lấy phiên bản số X.Y hoặc X.Y.Z, loại bỏ alpha/beta/RC)
    if [[ -z "$LATEST_WP_TAG" ]]; then
        LATEST_WP_TAG=$(curl -fsSL --retry 2 --connect-timeout 10 "https://api.github.com/repos/WordPress/WordPress/tags?per_page=30" | grep -oE '"name":[[:space:]]*"[0-9]+\.[0-9]+(\.[0-9]+)?"' | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -V | tail -n 1 || true)
    fi

    if [[ -n "$LATEST_WP_TAG" ]]; then
        GH_WP_TARBALL="https://github.com/WordPress/WordPress/archive/refs/tags/${LATEST_WP_TAG}.tar.gz"
        if curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 "$GH_WP_TARBALL" -o latest.tar.gz && [[ -s latest.tar.gz ]]; then
            WP_DOWNLOAD_OK=1
            echo -e "${GREEN}Da tai thanh cong WordPress v${LATEST_WP_TAG} (Stable) tu kho du phong GitHub.${NC}"
        fi
    fi
    unset LATEST_WP_TAG
fi

if (( WP_DOWNLOAD_OK == 0 )); then
    echo -e "${RED}LOI: Khong the tai ma nguon WordPress tu tat ca cac nguon!${NC}"
    exit 1
fi
unset WP_DOWNLOAD_OK

echo -e "${GREEN}[4/5] Dang giai nen ma nguon...${NC}"
# Giải nén thẳng vào thư mục đích, bỏ qua lớp vỏ thư mục bên ngoài
tar xzf latest.tar.gz -C "/var/www/$DOMAIN/public_html" --strip-components=1

# Dọn dẹp file nén 
rm -f latest.tar.gz

# Thiết lập quyền ban đầu cho thư mục mã nguồn để chạy WP-CLI an toàn dưới quyền www-data
chown -R root:www-data "/var/www/$DOMAIN/public_html"
find "/var/www/$DOMAIN/public_html" -type d -exec chmod 2775 {} +
find "/var/www/$DOMAIN/public_html" -type f -exec chmod 664 {} +
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# G3. TỰ ĐỘNG CẤU HÌNH WP-CONFIG VÀ INSTALL DB
echo -e "${GREEN}>>> Dang tu dong cau hinh wp-config.php va database...${NC}"
# Dự phòng cho trường hợp không tìm thấy email chính thức của người cài đặt
# Lấy email mặc định theo tên miền
DEFAULT_INSTALL_WP_EMAIL="admin@$DOMAIN"

# Giá trị $INSTALL_WP_EMAIL (email của người dùng nhập) lấy từ wpsila.conf
# Nếu nó không tồn tại thì lấy giá trị $DEFAULT_INSTALL_WP_EMAIL
# Vì giá trị INSTALL_WP_EMAIL phải có thì mới cài được
INSTALL_WP_EMAIL="${INSTALL_WP_EMAIL:-$DEFAULT_INSTALL_WP_EMAIL}"

# G3.2. Định nghĩa biến nội bộ cho quá trình cài đặt
WP_PATH="/var/www/$DOMAIN/public_html" # Đường dẫn vào thư mục chứa web
WP_ADMIN_USER="admin" # User quản trị web
WP_ADMIN_PASS="p_$(openssl rand -hex 12)" # Tạo pass ngẫu nhiên
WP_ADMIN_EMAIL="$INSTALL_WP_EMAIL" # Email dùng để đăng ký

# Di chuyển vào thư mục code
cd "$WP_PATH" || { echo "Loi: Khong tim thay thu muc!"; exit 1; }

# G3.3. Tạo file wp-config.php từ thông tin DB ở Bước 2
# Chạy dưới quyền user www-data (thay vì root) để đảm bảo nguyên tắc Least Privilege
runuser -u www-data -- wp config create \
                    --path="$WP_PATH" \
                    --dbname="$GEN_DB_NAME" \
                    --dbuser="$GEN_DB_USER" \
                    --dbpass="$GEN_DB_PASS" \
                    --dbhost="localhost" \
                    --force

# G3.4. Chạy lệnh Install để nạp dữ liệu vào Database
echo "Dang khoi tao du lieu WordPress..."
runuser -u www-data -- wp core install \
                    --path="$WP_PATH" \
                    --url="https://$DOMAIN" \
                    --title="Website $DOMAIN" \
                    --admin_user="$WP_ADMIN_USER" \
                    --admin_password="$WP_ADMIN_PASS" \
                    --admin_email="$WP_ADMIN_EMAIL" \
                    --skip-email

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
chmod 600 "$CRED_FILE"

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

# Định nghĩa đường dẫn file config 
WP_CONFIG="$WP_ROOT/wp-config.php"

# Thiết lập FS_METHOD và tắt WP-Cron mặc định trước khi cố định quyền wp-config.php
runuser -u www-data -- wp config set FS_METHOD direct --type=constant --path="$WP_ROOT"

# [NEW] CAI DAT SYSTEM CRON
echo -e "${GREEN}>>> Dang chuyen doi WP-Cron sang System Cron...${NC}"

# 1. Tắt Cron mặc định trong wp-config.php và giới hạn số bản lưu nháp (Revisions) để giữ Database Blog luôn gọn nhẹ
# --raw là bắt buộc để giá trị là boolean/integer chứ không phải string
runuser -u www-data -- wp config set DISABLE_WP_CRON true --raw --type=constant --path="$WP_ROOT"
runuser -u www-data -- wp config set WP_POST_REVISIONS 5 --raw --type=constant --path="$WP_ROOT"
runuser -u www-data -- wp config set AUTOSAVE_INTERVAL 120 --raw --type=constant --path="$WP_ROOT"

# Gán chủ sở hữu thư mục cha, không đệ quy, không -R
# Cái này dùng để nhốt user sFTP trong tương lai không leo ra ngoài thư mục web nó có quyền
# Tức là nó chỉ có quyền trong phạm vi web nó được gán không leo toàn bộ các web trên VPS
chown root:root "$PARENT_DIR"
chmod 755 "$PARENT_DIR"

# Gán group www-data là chủ sở hữu (để PHP có thể ghi file, cài plugin, upload ảnh)
# User sở hữu là root
chown -R root:www-data "$WP_ROOT"

# Chuẩn hóa quyền để không mâu thuẫn quyền của nhau sau này khi tạo tài khoản sFTP:
# - Thư mục: 775 (rwxrwxr-x)
# - File: 664 (rw-rw-r--)
# số 2 trước 775 là để các file sau này do sFTP up lên mặc định thuộc quyền sở hữu của group www-data
# Do vậy user www-data thuộc group www-data sẽ có quyền làm việc với file đó mà không bị lỗi không đủ quyền.
# Cách dùng find "$WP_ROOT" -type d -exec chmod 2775 {} + sẽ nhanh hơn cách find "$WP_ROOT" -type d -exec chmod 2775 {} \;
find "$WP_ROOT" -type d -exec chmod 2775 {} +
find "$WP_ROOT" -type f -exec chmod 664 {} +

# Phân quyền để quản lý chặt file wp-config
# Mặc định cho phép plugin & sFTP chỉnh sửa wp-config.php
# Để tăng bảo mật chuyển 660 -> 640 (kèm chattr +i), có thể thực hiện tùy chọn nâng cao này qua menu điều khiển
if [[ -f "$WP_CONFIG" ]]; then
    chmod 660 "$WP_CONFIG"
fi

# Đảm bảo Caddy có thể "đi xuyên qua" thư mục /var/www để đọc file
chmod +x /var/www

# Khởi động lại để tránh phân quyền bị cache
systemctl reload "php${PHP_VER}-fpm"

# 2. Thêm Cronjob cho user www-data (chạy 5 phút/lần)
# [TỐI ƯU] Sử dụng đường dẫn tuyệt đối tới PHP theo phiên bản đã cài đặt
# Đảm bảo cron chạy đúng phiên bản PHP với FPM (Ví dụ: php8.3)
PHP_BIN="/usr/bin/php${PHP_VER}"

# Kiểm tra nếu biến PHP_VER rỗng (phòng ngừa), fallback về php thường
if [[ -z "${PHP_VER:-}" ]]; then
    PHP_BIN="/usr/bin/php"
fi

# Bắt buộc phải giữ nguyên cú pháp cổ điển > /dev/null 2>&1
# Tiến trình Cron của Ubuntu sử dụng shell dash (chỉ hiểu /bin/sh tiêu chuẩn), nó không hiểu Bash. Nếu đổi thành &> /dev/null, Cronjob này sẽ bị lỗi cú pháp và không chạy.
CRON_CMD="*/5 * * * * $PHP_BIN /var/www/$DOMAIN/public_html/wp-cron.php > /dev/null 2>&1"

# Logic thêm cron (Idempotent - Chạy nhiều lần không bị trùng)
(crontab -u www-data -l 2>/dev/null | grep -Fq "$CRON_CMD") || (crontab -u www-data -l 2>/dev/null || true; echo "$CRON_CMD") | crontab -u www-data -

echo -e "${GREEN}>>> Da thiet lap System Cron (5 phut/lan) su dung $PHP_BIN.${NC}"

# --- HOÀN TẤT ---
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}   Cai Dat Ma Nguon WordPress Hoan Tat!   ${NC}"
echo -e "${GREEN}=============================================${NC}"
echo -e "Domain: ${YELLOW}$DOMAIN${NC}"
echo -e "Web Root: ${YELLOW}$WP_ROOT${NC}"
echo -e "Logs Directory: ${YELLOW}/var/www/$DOMAIN/logs${NC}"
echo -e "${GREEN}>>> Buoc tiep theo: Cau hinh Caddyfile.${NC}"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------