# -----------------------------------------------------------
# MODULE: Cài đặt PHP Repo ondrej
# File: install_php.sh
# File này được nhúng vào script install_lcmp.sh
# -----------------------------------------------------------

echo -e "${GREEN}[1/3] Dang nap PHP Repo ondrej ${PHP_VER} va cac module can thiet...${NC}"
# Setup Repository (Them -y cho apt update dau tien de tranh hoi)
# Repo ondrej/php
add-apt-repository ppa:ondrej/php -y

# Thêm repo thì cập nhật lại
apt-get update

# ==============================================================
# DANH SÁCH CÁC GÓI PHP ĐƯỢC CÀI.
# ==============================================================

echo -e "${GREEN}[2/3] Dang chuan bi cai dat PHP phien ban: ${PHP_VER} ${NC}"

# Da loai bo soap vi it dung cho Blog
PHP_PACKAGES=(
    "php${PHP_VER}-fpm"       # Process Manager
    "php${PHP_VER}-cli"       # Command Line Interface & Cron
    "php${PHP_VER}-mysql"     # Database Driver
    "php${PHP_VER}-opcache"   # Speed Optimization
    "php${PHP_VER}-curl"      # Remote Request
    "php${PHP_VER}-mbstring"  # String Handling (Tiếng Việt)
    "php${PHP_VER}-xml"       # SEO & Sitemap
    "php${PHP_VER}-zip"       # Unzip Plugins/Themes
    "php${PHP_VER}-gd"        # Fallback Image Lib
    "php${PHP_VER}-imagick"   # Primary Image Lib (Best for Blog)
    "php${PHP_VER}-intl"      # Date/Time Format
    "php${PHP_VER}-bcmath"    # Math Precision (Plugin support)
)

# Cai dat PHP va cac module
apt-get install -y "${PHP_PACKAGES[@]}"

# Dam bao PHP-FPM khoi dong
systemctl enable --now "php${PHP_VER}-fpm"

# E4. Kiểm tra trạng thái cuối cùng
if	systemctl is-active --quiet "php${PHP_VER}-fpm"; then
    echo -e "${GREEN}[3/3] PHP ${PHP_VER} da cai dat THANH CONG!${NC}"
    php -v | head -n 1
else
    echo -e "${RED}Co loi xay ra trong qua trinh cai dat!${NC}"
    exit 1
fi