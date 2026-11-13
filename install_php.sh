# shellcheck shell=bash
# -----------------------------------------------------------
# MODULE: Cài đặt PHP Repo ondrej (Có Fallback đa tầng)
# File: install_php.sh
# File này được nhúng vào script install_lcmp.sh
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo -e "${GREEN}[1/3] Dang nap PHP Repo ${PHP_VER} va cac module can thiet...${NC}"
echo -e "${YELLOW}Luu y: Qua trinh ket noi PPA co the dung im 5-15s o dong 'Adding repository.', vui long doi...${NC}"

# Hàm phụ trợ: Chuyển sang kho CDN mới packages.sury.org nếu Launchpad PPA gặp sự cố
use_sury_cdn_repo() {
    echo -e "${YELLOW}Canh bao: Kho Launchpad PPA gap su co. Chuyen sang kho CDN chinh chu (packages.sury.org)...${NC}"
    rm -f /etc/apt/sources.list.d/ondrej-ubuntu-php*
    mkdir -p /etc/apt/keyrings

    # Nguồn 1: Tải trực tiếp apt.gpg từ packages.sury.org (có retry chống rớt mạng tạm thời)
    if curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 'https://packages.sury.org/php/apt.gpg' -o /etc/apt/keyrings/deb.sury.org-php.gpg; then
        . /etc/os-release
        echo "deb [signed-by=/etc/apt/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $VERSION_CODENAME main" | tee /etc/apt/sources.list.d/sury-php.list > /dev/null
        chmod a+r /etc/apt/keyrings/deb.sury.org-php.gpg
        chmod a+r /etc/apt/sources.list.d/sury-php.list
        return 0
    fi

    # Nguồn 2 (Dự phòng GPG Key): Tải gói keyring .deb chính thức từ packages.sury.org
    if curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 'https://packages.sury.org/debsuryorg-archive-keyring.deb' -o /tmp/debsuryorg-keyring.deb; then
        if dpkg -i /tmp/debsuryorg-keyring.deb &>/dev/null && [[ -f /usr/share/keyrings/debsuryorg-archive-keyring.gpg ]]; then
            rm -f /tmp/debsuryorg-keyring.deb
            . /etc/os-release
            echo "deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ $VERSION_CODENAME main" | tee /etc/apt/sources.list.d/sury-php.list > /dev/null
            chmod a+r /etc/apt/sources.list.d/sury-php.list
            return 0
        fi
        rm -f /tmp/debsuryorg-keyring.deb
    fi

    return 1
}

# Tầng 1: Thử thêm PPA ondrej/php trên Launchpad
if ! add-apt-repository ppa:ondrej/php -y; then
    # Tầng 2: Nếu Launchpad lỗi, chuyển sang CDN packages.sury.org
    use_sury_cdn_repo || echo -e "${YELLOW}Se su dung Repo mac dinh cua Ubuntu...${NC}"
fi

# Cập nhật danh sách gói (Nếu lỗi thì thử chuyển sang Sury CDN hoặc Repo gốc của Ubuntu)
if ! apt-get update; then
    if ! use_sury_cdn_repo || ! apt-get update; then
        echo -e "${YELLOW}Canh bao: Kho PHP ngoai gap su co. Chuyen sang dung Repo chinh thuc cua Ubuntu...${NC}"
        rm -f /etc/apt/sources.list.d/ondrej-ubuntu-php* /etc/apt/sources.list.d/sury-php.list
        apt-get update
    fi
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# DANH SÁCH CÁC GÓI PHP ĐƯỢC CÀI.
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

# Cài đặt PHP và các module (Nếu tải gói từ PPA bị lỗi 404/503 thì fallback sang Sury CDN hoặc Repo Ubuntu)
if ! apt-get install -y -o Acquire::Retries=3 "${PHP_PACKAGES[@]}"; then
    echo -e "${YELLOW}Canh bao: Tai goi PHP bi loi. Dang thu chuyen sang kho du phong...${NC}"
    if use_sury_cdn_repo && apt-get update && apt-get install -y -o Acquire::Retries=3 "${PHP_PACKAGES[@]}"; then
        echo -e "${GREEN}Da cai dat thanh cong PHP tu kho du phong Sury CDN.${NC}"
    else
        echo -e "${YELLOW}Chuyen sang cai dat PHP tu Repo chinh thuc cua Ubuntu...${NC}"
        rm -f /etc/apt/sources.list.d/ondrej-ubuntu-php* /etc/apt/sources.list.d/sury-php.list
        apt-get update
        if apt-cache show "php${PHP_VER}-fpm" &>/dev/null; then
            apt-get install -y -o Acquire::Retries=3 "${PHP_PACKAGES[@]}"
        else
            # Tự động phát hiện phiên bản PHP sẵn có của Ubuntu (ví dụ PHP 8.1 trên Ubuntu 22.04) để không bị dừng cài đặt
            UBUNTU_DEFAULT_PHP=$(apt-cache depends php-fpm 2>/dev/null | awk '/Depends: php[0-9]+\.[0-9]+-fpm/ {print $2}' | sed -E 's/^php([0-9]+\.[0-9]+)-fpm$/\1/' | head -n 1 || true)
            if [[ -n "$UBUNTU_DEFAULT_PHP" ]]; then
                echo -e "${YELLOW}Thong bao: Kho mac dinh cua Ubuntu hien tai cung cap PHP ${UBUNTU_DEFAULT_PHP} (thay vi ${PHP_VER}).${NC}"
                echo -e "${YELLOW}He thong se tu dong cai dat PHP ${UBUNTU_DEFAULT_PHP} va dong bo vao wpsila.conf...${NC}"
                PHP_VER="$UBUNTU_DEFAULT_PHP"
                export PHP_VER
                if [[ -n "${WPSILA_CONFIG_FILE:-}" && -f "$WPSILA_CONFIG_FILE" ]]; then
                    sed -i "s|^PHP_VER=.*|PHP_VER=\"${PHP_VER}\"|" "$WPSILA_CONFIG_FILE"
                fi
                PHP_PACKAGES=(
                    "php${PHP_VER}-fpm" "php${PHP_VER}-cli" "php${PHP_VER}-mysql" "php${PHP_VER}-opcache"
                    "php${PHP_VER}-curl" "php${PHP_VER}-mbstring" "php${PHP_VER}-xml" "php${PHP_VER}-zip"
                    "php${PHP_VER}-gd" "php${PHP_VER}-imagick" "php${PHP_VER}-intl" "php${PHP_VER}-bcmath"
                    "php${PHP_VER}-redis" "php${PHP_VER}-exif" "php${PHP_VER}-soap"
                )
                apt-get install -y -o Acquire::Retries=3 "${PHP_PACKAGES[@]}"
            else
                echo -e "${RED}LOI: Khong tim thay goi PHP trong kho Ubuntu va ca 2 kho PPA/Sury CDN deu khong the ket noi.${NC}"
                exit 1
            fi
        fi
    fi
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Đảm bảo PHP-FPM khởi động
systemctl enable --now "php${PHP_VER}-fpm"

# Kiểm tra trạng thái cuối cùng
if systemctl is-active --quiet "php${PHP_VER}-fpm"; then
    echo -e "${GREEN}[3/3] PHP ${PHP_VER} da cai dat THANH CONG!${NC}"
    # Hiển thị phiên bản để double check
    php -v | head -n 1
else
    echo -e "${RED}Co loi xay ra trong qua trinh cai dat!${NC}"
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------