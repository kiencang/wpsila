# -----------------------------------------------------------
# MODULE: Cài đặt PHP Repo ondrej
# File: install_php.sh
# File này được nhúng vào script install_lcmp.sh
# -----------------------------------------------------------

echo -e "${GREEN}[1/3] Dang nap PHP Repo ondrej ${PHP_VER} va cac module can thiet...${NC}"

# Setup Repository
# Repo ondrej/php là chuẩn vàng cho Ubuntu
# Lưu ý: Lệnh này sẽ tự động trigger apt update sau khi add xong
add-apt-repository ppa:ondrej/php -y

# Thêm repo thì cập nhật lại (nhưng cứ thêm cho chắc!)
apt-get update

# ==============================================================
# DANH SÁCH CÁC GÓI PHP ĐƯỢC CÀI.
# ==============================================================

echo -e "${GREEN}[2/3] Dang chuan bi cai dat PHP phien ban: ${PHP_VER} ${NC}"

PHP_PACKAGES=(
    "php${PHP_VER}-fpm"       # Core PHP process manager (Kéo theo Common, Ctype, Fileinfo, Tokenizer, Iconv...)
    "php${PHP_VER}-cli"       # WP-CLI, System maintenance
    "php${PHP_VER}-mysql"     # Kết nối Database (mysqli & pdo_mysql)
    "php${PHP_VER}-opcache"   # Tăng tốc độ PHP (Bắt buộc)
    "php${PHP_VER}-curl"      # HTTP Requests (Update, API)
    "php${PHP_VER}-mbstring"  # Xử lý tiếng Việt (Bắt buộc)
    "php${PHP_VER}-xml"       # Sitemap, SEO, RSS Feeds
    "php${PHP_VER}-zip"       # Cài/Update Plugin & Theme
    "php${PHP_VER}-gd"        # Xử lý ảnh (Cơ bản)
    "php${PHP_VER}-imagick"   # Xử lý ảnh nâng cao (Chất lượng cao cho Blog/News)
    "php${PHP_VER}-intl"      # Định dạng ngày giờ chuẩn tiếng Việt
    "php${PHP_VER}-bcmath"    # Tính toán chính xác (Cần cho một số plugin thống kê/quảng cáo)
    "php${PHP_VER}-redis"     # Object Cache (Cực quan trọng cho web tin tức high-traffic)
    "php${PHP_VER}-exif"      # Sửa lỗi xoay ảnh từ điện thoại
    "php${PHP_VER}-soap"      # Hỗ trợ API (Một số cổng thanh toán hoặc tool lấy tin tự động cần)
)

# Cai dat PHP va cac module
apt-get install -y "${PHP_PACKAGES[@]}"

# Dam bao PHP-FPM khoi dong
systemctl enable --now "php${PHP_VER}-fpm"

# E4. Kiểm tra trạng thái cuối cùng
if	systemctl is-active --quiet "php${PHP_VER}-fpm"; then
    echo -e "${GREEN}[3/3] PHP ${PHP_VER} da cai dat THANH CONG!${NC}"
    # Hiển thị phiên bản để double check
    php -v | head -n 1
else
    echo -e "${RED}Co loi xay ra trong qua trinh cai dat!${NC}"
    exit 1
fi