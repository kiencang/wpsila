# -----------------------------------------------------------
# MODULE: Cài đặt PHP & MariaDB
# File này được nhúng vào script install_lcmp.sh
# -----------------------------------------------------------

echo -e "${GREEN}[1/3] Dang cai dat PHP ${PHP_VER} va cac module can thiet...${NC}"

# Thêm repository và cài đặt PHP
sudo apt update
sudo apt install -y lsb-release ca-certificates apt-transport-https software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# ==============================================================
# DANH SÁCH CÁC GÓI PHP ĐƯỢC CÀI. CÁC GÓI CHỈ CẦN DÀNH CHO BLOG.
# ==============================================================

echo -e "${GREEN}[*] Dang chuan bi cai dat PHP phien ban: ${PHP_VER} ${NC}"

# E1. DANH SÁCH GÓI (Sử dụng biến ${PHP_VER} để ghép chuỗi)
PHP_PACKAGES=(
    "php${PHP_VER}-fpm"       # Xử lý PHP (Bắt buộc)
    "php${PHP_VER}-cli"       # Chạy WP-CLI & Cron (Bắt buộc)
    "php${PHP_VER}-mysql"     # Kết nối DB (Bắt buộc)
    "php${PHP_VER}-opcache"   # Tăng tốc độ (Rất nên có)
    "php${PHP_VER}-curl"      # Kết nối mạng/API (Bắt buộc)
    "php${PHP_VER}-mbstring"  # Xử lý tiếng Việt (Bắt buộc)
    "php${PHP_VER}-xml"       # SEO/Sitemap (Bắt buộc)
    "php${PHP_VER}-zip"       # Giải nén theme/plugin (Bắt buộc)
    "php${PHP_VER}-gd"        # Xử lý ảnh (Đủ dùng cho Blog)
    "php${PHP_VER}-intl"      # Định dạng ngày tháng quốc tế (Nên có)
    "php${PHP_VER}-bcmath"    # Tính toán chính xác (Nên có - để tương thích plugin tốt hơn)
)

# E2. LỆNH CÀI ĐẶT
# "${PHP_PACKAGES[@]}" sẽ bung toàn bộ danh sách trên ra thành chuỗi
apt install -y "${PHP_PACKAGES[@]}"

echo -e "${GREEN}[2/3] Dang cai dat MariaDB Server...${NC}"
# Thường là phiên bản 10.11 trên Ubuntu 24.04 LTS
# Cách kiểm tra: mariadb --version, việc biết được phiên bản cụ thể sẽ giúp chúng ta có những cài đặt chính xác hơn sau này.
sudo apt install -y mariadb-server

# E3. BẢO MẬT MARIADB (HARDENING)
echo -e "${GREEN}[3/3] Dang thuc hien bao mat MariaDB (Secure Installation)...${NC}"

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