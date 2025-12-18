#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# Thiet lap moi truong chuan cho Automation
export LC_ALL=C.UTF-8
export DEBIAN_FRONTEND=noninteractive

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# A. Màu sắc cho thông báo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# B. Kiểm tra quyền chạy
# NÂNG QUYỀN NẾU KHÔNG PHẢI LÀ ROOT
# 1. Kiểm tra xem đang chạy với quyền gì
if [[ $EUID -ne 0 ]]; then
   # 2. Nếu không phải root, tự động chạy lại script này bằng sudo
   sudo "$0" "$@"
   # 3. Thoát tiến trình cũ (không phải root) để tiến trình mới (có root) chạy
   exit $?
fi

# Xác định kiểu cài đặt có phải là subdomain hay không
# Mặc định là nosd, tức là không phải dạng cài subdomain
# Tham số đầu vào mặc định ở vị trí đầu tiên (1)
INSTALL_TYPE="${1:-nosd}"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# C. Kiểm tra môi trường
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
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# D. CẤU HÌNH PHIÊN BẢN PHP
# D1. Đặt giá trị mặc định (phòng hờ không tìm thấy file config / wpsila.conf)
DEFAULT_PHP_VER="8.3"

# D2. Định nghĩa đường dẫn file config 
# (Ví dụ: file config nằm cùng thư mục với script đang chạy)
# Dòng lệnh này đảm bảo biến SCRIPT_WPSILA_DIR luôn là đường dẫn tuyệt đối tới thư mục chứa file này
# Cách chuẩn mực
SCRIPT_WPSILA_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# ---
# Hoặc có thể dùng cách đơn giản này:
# SCRIPT_WPSILA_DIR="$(dirname "$(realpath "$0")")"
# ----

# Trỏ vào file config nằm cùng thư mục đó
WPSILA_CONFIG_FILE="$SCRIPT_WPSILA_DIR/wpsila.conf"

# D3. Kiểm tra và nạp file config
if [[ -f "$WPSILA_CONFIG_FILE" ]]; then
    # Lệnh 'source' hoặc dấu chấm '.' sẽ đọc biến từ file kia vào script này
    source "$WPSILA_CONFIG_FILE"
    echo -e "${GREEN}Da tim thay file cau hinh: ${WPSILA_CONFIG_FILE}${NC}"
else
    echo -e "${YELLOW}Khong tim thay file config. Su dung phien ban mac dinh.${NC}"
fi

# D4. Chốt phiên bản cuối cùng
# Cú pháp ${BIEN_1:-$BIEN_2} nghĩa là: Nếu BIEN_1 rỗng (chưa set trong config), thì lấy BIEN_2
# Export ngay lập tức để toàn bộ quy trình bên dưới nhận diện được
export PHP_VER="${PHP_VER:-$DEFAULT_PHP_VER}"
export SCRIPT_WPSILA_DIR

echo "Phien ban PHP: $PHP_VER"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# E. NHẬP VÀ XỬ LÝ TÊN MIỀN
# Kiểm tra tên miền người dùng nhập vào
DOMAIN_CHECK="$SCRIPT_WPSILA_DIR/domain_check.sh"

# Nhúng file kiểm tra tên miền nhập vào
if [[ -f "$DOMAIN_CHECK" ]]; then    
    # Lệnh source quan trọng để nhúng trực tiếp vào file chính
    source "$DOMAIN_CHECK"
else 
	echo -e "${RED}KHONG TIM THAY file kiem tra ten mien nhap vao (domain_check.sh)!${NC}"
	echo -e "${RED}Hay kiem tra lai su ton tai cua file nay, hoac duong dan cua no.${NC}"
	exit 1
fi	

echo "-------------------------------------------------------------------------------------------------"

# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# F. Tạo Database & User
# Tạo database & user cho WordPress
DATABASE_USER_WP="$SCRIPT_WPSILA_DIR/database_user_wp.sh"

# Nhúng cài đặt database & user vào
if [[ -f "$DATABASE_USER_WP" ]]; then    
    # Lệnh source quan trọng để nhúng trực tiếp vào file chính
    source "$DATABASE_USER_WP"
else 
	echo -e "${RED}KHONG TIM THAY file tao database & user cho WordPress (database_user_wp.sh)!${NC}"
	echo -e "${RED}Hay kiem tra lai su ton tai cua file nay, hoac duong dan cua no.${NC}"
	exit 1
fi	

echo "-------------------------------------------------------------------------------------------------"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# G. Cai dat WordPress (G) & Phân quyền (H)
# Xác định đường dẫn tuyệt đối đến file cài đặt WordPress
WORDPRESS_FILE_TEMP="$SCRIPT_WPSILA_DIR/wordpress.sh"

# Nhúng cài đặt WordPress vào, kiểm tra sự tồn tại để đảm bảo không lỗi
if [[ -f "$WORDPRESS_FILE_TEMP" ]]; then    
    # Lệnh source quan trọng để nhúng trực tiếp vào file chính
    source "$WORDPRESS_FILE_TEMP"
else 
	echo -e "${RED}KHONG TIM THAY file cài WordPress (wordpress.sh)! Hay kiem tra lai su ton tai cua file nay, hoac duong dan cua no.${NC}"
	exit 1
fi	

echo "-------------------------------------------------------------------------------------------------"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# I. Chinh sua file Caddyfile
# ---------------------------------------------------------
# I1. Khai báo biến đường dẫn và Marker
CADDY_FILE="/etc/caddy/Caddyfile"
MARKER="#wpsila_kiencang"

# Xác định và chuẩn hóa dạng tên miền
echo "Domain chinh: $DOMAIN"

# Không phải subdomian mới cần thông báo
if [[ "$INSTALL_TYPE" != "subdomain" ]]; then
	echo "Domain chuyen huong: $RED_DOMAIN"
fi

# I2. Nội dung Caddyfile
#Xác định đường dẫn tuyệt đối đến file caddyfile mẫu để ghi đè vào file server Caddyfile
# Mặc định / Không phải kiểu subdomain
CADDY_FILE_TEMP="$SCRIPT_WPSILA_DIR/caddyfile.sh"

# Nếu là kiểu subdomain thì chọn file caddy tương ứng
if [[ "$INSTALL_TYPE" == "subdomain" ]]; then
	CADDY_FILE_TEMP="$SCRIPT_WPSILA_DIR/caddyfile_subdomain.sh"
fi

# Nhúng caddyfile vào, kiểm tra sự tồn tại để đảm bảo không lỗi
if [[ -f "$CADDY_FILE_TEMP" ]]; then    
    # Lệnh source quan trọng để nhúng trực tiếp vào file chính
    source "$CADDY_FILE_TEMP"
else 
	echo -e "${RED}KHONG TIM THAY Caddyfile (caddyfile.sh hoac caddyfile_subdomain.sh)!.${NC}"
	echo -e "${RED}Hay kiem tra lai su ton tai cua file nay, hoac duong dan cua no.${NC}"
	exit 1
fi	

# I3. TẠO BACKUP AN TOÀN 
TIMESTAMP=$(date +%s)
BACKUP_FILE="${CADDY_FILE}.bak_${TIMESTAMP}"

# Hàm xóa các file backup cũ để tránh rác file backup
rotate_caddy_backup() {
    local CADDY_PATH="/etc/caddy/Caddyfile"
    local MAX_BACKUPS=10
    
    # 1. Logic tìm và xóa file cũ
    # ls -1t: Liệt kê 1 cột, sắp xếp theo thời gian (Mới nhất ở trên cùng)
    # tail -n +11: Bỏ qua 10 dòng đầu, lấy từ dòng 11 đến hết (Đây là các file cũ thừa ra)
    # xargs -r rm: Nhận danh sách và xóa. -r để không báo lỗi nếu không có file nào cần xóa.
    
    ls -1t "${CADDY_PATH}.bak_"* 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm -f
    
    # (Optional) Log ra màn hình để debug
    local CURRENT_COUNT=$(ls -1 "${CADDY_PATH}.bak_"* 2>/dev/null | wc -l)
    echo "Backup rotation complete. Current backups: $CURRENT_COUNT (Limit: $MAX_BACKUPS)"
}

# Kiểm tra nếu file tồn tại thì mới backup để tránh lỗi
if [[ -f "$CADDY_FILE" ]]; then
    echo "Dang tao file backup: $BACKUP_FILE"
    cp "$CADDY_FILE" "$BACKUP_FILE"
	
	# Gọi hàm xoay vòng để dọn dẹp ngay lập tức
	# Tránh việc có một đống các file backup sau này
	rotate_caddy_backup
else
    echo "Day la lan cai dat dau tien, chua co file Caddyfile cu de backup."
    # Tạo file rỗng để tránh lỗi cho các lệnh phía sau
    touch "$CADDY_FILE"
fi

# I4. Thực hiện ghi vào Caddyfile chính
if grep -q "$MARKER" "$CADDY_FILE" 2>/dev/null; then
    echo "TIM THAY marker '$MARKER'. Dang them cau hinh vao cuoi file Caddyfile..."
    echo "$CONTENT" | tee -a "$CADDY_FILE" > /dev/null
else
    echo "CAI DAT WORDPRESS lan dau! Tao file Caddyfile moi..."
    echo "$CONTENT" | tee "$CADDY_FILE" > /dev/null
fi

# Format lại cho đẹp
caddy fmt --overwrite "$CADDY_FILE" > /dev/null 2>&1

# I5. VALIDATE & ROLLBACK
echo "Dang kiem tra cu phap Caddyfile..."

# Kiểm tra tính hợp lệ
if ! caddy validate --config "$CADDY_FILE" --adapter caddyfile > /dev/null 2>&1; then
    echo -e "${RED}CANH BAO: File Caddyfile bi loi cu phap!${NC}"
    
    # In ra lỗi cụ thể cho người dùng xem sai ở đâu
    caddy validate --config "$CADDY_FILE" --adapter caddyfile
    
    echo -e "${YELLOW}Dang khoi phuc lai file ban dau...${NC}"
    
    if [[ -f "$BACKUP_FILE" ]]; then
        cp "$BACKUP_FILE" "$CADDY_FILE"
        echo "Da khoi phuc lai file goc an toan."
    else
        # Trường hợp cài lần đầu mà lỗi luôn thì xóa file lỗi đi
        echo "Khong co file backup (cai lan dau). Xoa file loi..."
        rm "$CADDY_FILE"
    fi
    
    exit 1
else
    # Nếu mọi thứ OK, Reload lại Caddy
    echo "Cau hinh hop le. Dang reload Caddy..."
	# Ngăn ngừa việc mất quyền hay xảy ra, khiến cho việc tải lại không thành công.
	# Nguyên nhân là vì mặc dù phân quyền đã làm, nhưng trong quá trình cài đặt có thể root ghi vào file log.
	# Nó thành chủ sở hữu và không cho user caddy can thiệp vào nữa, cách phòng thủ tốt nhất là tái lập lại quyền.
	# Rất dễ xảy ra với việc cài lần đầu tiên.
	chown -R caddy:caddy /var/www/$DOMAIN/logs
	
    systemctl reload caddy
    echo "Da cap nhat cau hinh cho $DOMAIN trong Caddyfile."
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo "Hoan tat! Xin chuc mung ban da cai thanh cong WordPress trên Caddy Web Server."
echo "Nhap muc <4> de xem thong tin pass cua trang WordPress ban vua tao."
# -------------------------------------------------------------------------------------------------------------------------------