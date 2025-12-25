#!/bin/bash

# -------------------------------------------------------------------------
# Cài đặt LCMP (Linux, Caddy, MariaDB, PHP) cho VPS
# File: install_lcmp.sh
# 4 file module được source vào là:
# a. anti_apt_lock.sh
# b. install_caddyserver.sh
# c. install_php.sh
# d. install_mariadb.sh
# wpsila.conf chứa thông tin phiên bản PHP & MariaDB
# -------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# Thiết lập môi trường chuẩn cho Automation
export LC_ALL=C.UTF-8
export DEBIAN_FRONTEND=noninteractive
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# A. Màu sắc cho thông báo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color (ngắt màu)
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# B. CẤU HÌNH & ĐƯỜNG DẪN
# Thiết lập các giá trị mặc định, phòng trường hợp config lỗi
DEFAULT_PHP_VER="8.3"
DEFAULT_MARIADB_VER="10.11"

# B2. Định nghĩa đường dẫn (Sử dụng cách an toàn nhất, không phụ thuộc realpath)
SCRIPT_WPSILA_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Trỏ vào file config nằm cùng thư mục
WPSILA_CONFIG_FILE="$SCRIPT_WPSILA_DIR/wpsila.conf"

# B3. Kiểm tra và nạp file config
if [[ -f "$WPSILA_CONFIG_FILE" ]]; then
    source "$WPSILA_CONFIG_FILE"
    echo -e "${GREEN}Da tim thay file cau hinh: ${WPSILA_CONFIG_FILE}${NC}"
else
    echo -e "${YELLOW}Khong tim thay file config. Su dung phien ban mac dinh.${NC}"
fi

# B4. Chốt phiên bản & Export biến
# Export ngay lập tức để toàn bộ quy trình bên dưới nhận diện được
export PHP_VER="${PHP_VER:-$DEFAULT_PHP_VER}"
export MARIADB_VER="${MARIADB_VER:-$DEFAULT_MARIADB_VER}"
export SCRIPT_WPSILA_DIR

echo -e "Phien ban PHP se cai dat: ${GREEN}$PHP_VER${NC}"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# C. KIỂM TRA MÔI TRƯỜNG (PRE-FLIGHT CHECK)

echo "--------------------------------------------------------"
echo "Dang kiem tra moi truong VPS (Clean OS Check)..."

# C1. Kiểm tra quyền Root
if [[ $EUID -ne 0 ]]; then
   # Thêm tham số -E cho sudo để giữ lại các biến môi trường (nếu có)
   sudo -E "$0" "$@"
   exit $?
fi

# -------------------------------------------------------------------------

# C1 pre. Kiểm tra file lock (đã cài rồi)
ALREADY_WPSILA="$SCRIPT_WPSILA_DIR/wpsila_success.txt"
if [[ -f "$ALREADY_WPSILA" ]]; then
    echo -e "${YELLOW}Ban da cai wpsila tren VPS nay roi.${NC}"
    exit 0
fi

# -------------------------------------------------------------------------

# C2. Kiểm tra Port 80 & 443
# Dùng grep -E để gộp lệnh, code gọn hơn
if ss -tuln | grep -qE ":(80|443) "; then
    echo -e "${RED}[X] LOI NGHIEM TRONG: Cong 80 hoac 443 dang ban!${NC}"
    echo -e "${YELLOW}Nguyen nhan:${NC} VPS dang chay Web Server khac (Apache, Nginx...)."
    echo -e "${YELLOW}Giai phap:${NC} Vui long su dung VPS moi tinh (Clean OS)."
    exit 1
fi

# C3. Kiểm tra user "caddy"
if id "caddy" &>/dev/null; then
    echo -e "${RED}[X] LOI: User 'caddy' da ton tai.${NC}"
    echo -e "${YELLOW}Giai phap:${NC} Reinstall OS ve trang thai ban dau."
    exit 1
fi

echo -e "${GREEN}[OK] Moi truong sach se.${NC}"
sleep 1
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Dx Hỏi thăm địa chỉ email trước, để dùng làm yêu cầu SSL & nhận thông báo sau này
# 1. Hàm kiểm tra định dạng
is_valid_email() {
    local email="$1"
    # Regex: support các định dạng email phổ biến
    local regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    if [[ "$email" =~ $regex ]]; then
        return 0
    else
        return 1
    fi
}

# 2. Cấu hình giới hạn
MAX_RETRIES=3       # Tổng số lần cho phép
count=0             # Biến đếm số lần đã thử

# 3. Vòng lặp giới hạn
while [ "$count" -lt "$MAX_RETRIES" ]; do
    echo ""
    read -r -p "Nhap Email quan tri (Bat buoc, day phai la email cua ban): " ADMIN_EMAIL

    # --- Kiểm tra Rỗng ---
    if [[ -z "$ADMIN_EMAIL" ]]; then
        echo "❌ Loi: Email khong duoc de trong!"
    
    # --- Kiểm tra Regex ---
    elif ! is_valid_email "$ADMIN_EMAIL"; then
        echo "❌ Loi: Dinh dang email khong hop le."
    
    # --- Nếu Hợp lệ ---
    else
        echo "✔ Email hop le: $ADMIN_EMAIL"
        break  # Thoát vòng lặp ngay lập tức, biến $ADMIN_EMAIL đã sẵn sàng sử dụng
    fi

    # --- Xử lý khi nhập sai ---
    # Tăng biến đếm (An toàn với set -e)
    count=$((count + 1))
    remaining=$((MAX_RETRIES - count))
    
    if [ "$remaining" -gt 0 ]; then
        echo "⚠️ Ban con $remaining lan thu."
    else
        echo ""
        echo "⛔ Qua so lan thu cho phep ($MAX_RETRIES lan)."
        echo "Script se dung lai de bao dam an toan."
        exit 1  # Dừng script ngay lập tức
    fi
done

export ADMIN_EMAIL
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# C4. UPDATE SYSTEM & DEPENDENCIES
# -------------------------------------------------------------------------
# Tắt tiến trình chạy cập nhật ngầm của Ubuntu
# -------------------------------------------------------------------------
echo "1. Lay quyen APT va dung tien trinh chay ngam..."
# Xác định đường dẫn
ANTI_APT_LOCK="$SCRIPT_WPSILA_DIR/anti_apt_lock.sh"

# Nhúng file vào
if [[ -f "$ANTI_APT_LOCK" ]]; then
    source "$ANTI_APT_LOCK"
else
    echo -e "${RED}Khong tim thay file: anti_apt_lock.sh${NC}"
	exit 1
fi
# -------------------------------------------------------------------------

echo "--------------------------------------------------------"
echo "Cap nhat he thong va cai dat cac goi co ban..."

# C4.1. Gỡ bỏ các webserver mặc định (Apache/Nginx) nếu có để tránh xung đột tiềm ẩn
# Dùng || true để không báo lỗi nếu không tìm thấy gói
apt-get remove --purge -y apache2 apache2-* nginx nginx-* &>/dev/null || true

# C4.2 Cập nhật và cài đặt gói bổ trợ
# Đã xóa dấu '&& \' bị thừa ở cuối lệnh để tránh lỗi cú pháp
apt-get update
apt-get install -y --no-install-recommends -o Dpkg::Lock::Timeout=60 \
	curl \
	wget \
    lsb-release \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    zip \
    unzip \
    gnupg

echo -e "${GREEN}[OK] Da cai dat xong dependencies (cac goi phu thuoc).${NC}"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# D. Cài Caddy Web Server
CADDYWS_INSTALL_FILE="$SCRIPT_WPSILA_DIR/install_caddyserver.sh"

if [[ -f "$CADDYWS_INSTALL_FILE" ]]; then
	echo -e "${GREEN}Chuan bi cai Caddy Server...${NC}"
    source "$CADDYWS_INSTALL_FILE"
else
    echo -e "${RED}Khong tim thay file: install_caddyserver.sh${NC}"
	exit 1
fi
echo "--------------------------------------------------------"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# E. Cài PHP Repo ondrej
PHP_INSTALL_FILE="$SCRIPT_WPSILA_DIR/install_php.sh"

if [[ -f "$PHP_INSTALL_FILE" ]]; then
	echo -e "${GREEN}Chuan bi cai PHP...${NC}"
    source "$PHP_INSTALL_FILE"
else
    echo -e "${RED}Khong tim thay file: install_php.sh${NC}"
	exit 1
fi

echo "--------------------------------------------------------"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# F. Cài MariaDB
MARIADB_INSTALL_FILE="$SCRIPT_WPSILA_DIR/install_mariadb.sh"

if [[ -f "$MARIADB_INSTALL_FILE" ]]; then
	echo -e "${GREEN}Chuan bi cai MariaDB...${NC}"
    source "$MARIADB_INSTALL_FILE"
else
    echo -e "${RED}Khong tim thay file: install_mariadb.sh${NC}"
	exit 1
fi

echo "--------------------------------------------------------"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# G. HOÀN TẤT
INSTALLED_SUCCESSFULLY="$SCRIPT_WPSILA_DIR/wpsila_success.txt"

# Ghi file log (ghi đè nếu đã có, tạo mới nếu chưa có)
cat > "$INSTALLED_SUCCESSFULLY" <<EOF
----------------------------------------
wpsila CLI
Cai thanh cong LCMP
Date: $(date)
PHP Version: $PHP_VER
MariaDB Version: $MARIADB_VER
Admin Email: $ADMIN_EMAIL
----------------------------------------
EOF

echo "Don dep rac he thong..."
apt-get autoremove -y
apt-get clean

echo "--------------------------------------------------------"
echo -e "${GREEN}Cai dat LCMP hoan tat!${NC}"
echo "--------------------------------------------------------"