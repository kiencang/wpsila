# -----------------------------------------------------------
# MODULE: Cài đặt PHP & MariaDB
# File này được nhúng vào script install_lcmp.sh
# -----------------------------------------------------------

echo -e "${GREEN}[1/3] Dang cai dat PHP ${PHP_VER} va cac module can thiet...${NC}"

# Setup Repository (Them -y cho apt update dau tien de tranh hoi)
# Dung && de dam bao lenh truoc chay xong lenh sau moi chay
# --no-install-recommends để không cài thêm các gói không cần thiết

# Chạy update và install
apt-get update && \
apt-get install -y --no-install-recommends \
    lsb-release \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    curl \
    zip \
    unzip \
    gnupg && \

# Repo ondrej/php
add-apt-repository ppa:ondrej/php -y

# Thêm repo thì cập nhật lại
apt-get update

# ==============================================================
# DANH SÁCH CÁC GÓI PHP ĐƯỢC CÀI.
# ==============================================================

echo -e "${GREEN}[*] Dang chuan bi cai dat PHP phien ban: ${PHP_VER} ${NC}"

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

echo -e "${GREEN}[2/3] Dang cai dat MariaDB Server...${NC}"

# Cai dat MariaDB
apt-get install -y mariadb-server mariadb-client

# Khoi dong MariaDB
systemctl enable --now mariadb

# Cho MariaDB khoi dong hoan toan (Smart wait thay vi sleep cung)
echo "Dang doi MariaDB khoi dong..."
timeout 30s bash -c 'until systemctl is-active --quiet mariadb; do sleep 1; done'

# E3. BẢO MẬT MARIADB (HARDENING)
echo -e "${GREEN}[3/3] Dang thuc hien bao mat MariaDB (Secure Installation)...${NC}"

# Chay SQL Hardening
mariadb <<EOF
DELETE FROM mysql.user WHERE User='';
ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket;
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# Câu lệnh dùng để kiểm tra xem database đã được bảo mật đúng cách chưa
# sudo mariadb -e "SELECT User, Host, Plugin FROM mysql.user; SHOW DATABASES LIKE 'test';"

# E4. Kiểm tra trạng thái cuoi cung
if systemctl is-active --quiet mariadb && systemctl is-active --quiet "php${PHP_VER}-fpm"; then
    echo -e "${GREEN}PHP ${PHP_VER} va MariaDB da cai dat THANH CONG!${NC}"
    mariadb --version
    php -v | head -n 1
else
    echo -e "${RED}Co loi xay ra trong qua trinh cai dat!${NC}"
    exit 1
fi