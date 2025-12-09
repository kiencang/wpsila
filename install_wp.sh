#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Chạy lệnh
# version 0.09.12.25
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/install_wp.sh | sudo bash
# -------------------------------------------------------------------------------------------------------------------------------

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
# B. Quyền chạy
# Bắt buộc phải chạy bằng root để cài đặt WordPress
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Loi: Ban phai chay script nay bang quyen Root.${NC}"
   echo -e "Vui long vao terminal voi quyen Root, sau do chay lai lenh."
   exit 1
fi

# Xác định kiểu cài đặt có phải là subdomain hay không
# Mặc định là no, tức là không phải dạng cài subdomain
# Tham số đầu vào mặc định ở vị trí đầu tiên (1)
INSTALL_TYPE="${1:-no}"
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

# D1. Đặt giá trị mặc định (phòng hờ không tìm thấy file config)
DEFAULT_PHP_VER="8.3"

# D2. Định nghĩa đường dẫn file config 
# (Ví dụ: file config nằm cùng thư mục với script đang chạy)
# Dòng lệnh này đảm bảo biến SCRIPT_WPSILA_DIR luôn là đường dẫn tuyệt đối tới thư mục chứa file này
# Xác định thư mục
SCRIPT_WPSILA_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Trỏ vào file config nằm cùng thư mục đó
WPSILA_CONFIG_FILE="$SCRIPT_WPSILA_DIR/wpsila.conf"

# D3. Kiểm tra và nạp file config
if [ -f "$WPSILA_CONFIG_FILE" ]; then
    # Lệnh 'source' hoặc dấu chấm '.' sẽ đọc biến từ file kia vào script này
    source "$WPSILA_CONFIG_FILE"
    echo -e "${GREEN}Da tim thay file cau hinh: ${WPSILA_CONFIG_FILE}${NC}"
else
    echo -e "${YELLOW}Khong tim thay file config. Su dung phien ban mac dinh.${NC}"
fi

# D4. Chốt phiên bản cuối cùng
# Cú pháp ${BIEN_1:-$BIEN_2} nghĩa là: Nếu BIEN_1 rỗng (chưa set trong config), thì lấy BIEN_2
PHP_VER="${PHP_VER:-$DEFAULT_PHP_VER}"

echo "Phien ban PHP: $PHP_VER"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# E. NHẬP VÀ XỬ LÝ TÊN MIỀN
echo -e "${GREEN}>>> Vui long nhap ten mien cua ban (vi du: example.com):${NC}"

# E1. Cấu hình số lần thử tối đa
MAX_RETRIES=3
COUNT=0
DOMAIN=""

# E2. Bắt đầu vòng lặp nhập liệu
while [[ $COUNT -lt $MAX_RETRIES ]]; do
    COUNT=$((COUNT + 1)) 
    
    if [[ $COUNT -eq 1 ]]; then
        read -p "Nhap Domain: " INPUT_DOMAIN < /dev/tty
    else
        echo -e "${RED}Ban vua nhap sai! Hay chu y nhap lai dung nhe.${NC}"
        read -p "Nhap Domain: " INPUT_DOMAIN < /dev/tty
    fi
    
    # Xử lý chuỗi
    TEMP_DOMAIN=$(echo "$INPUT_DOMAIN" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    DOMAIN=$(echo "$TEMP_DOMAIN" | sed -e 's|^https\?://||' -e 's|/.*$||')
    
    # Validation cơ bản
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"
    elif [[ "$DOMAIN" != *"."* ]]; then
        echo -e "${RED}Loi: Ten mien '$DOMAIN' khong hop le (thieu dau cham).${NC}"
    else
        if [[ "$INPUT_DOMAIN" != "$DOMAIN" ]]; then
             echo -e "${GREEN}Script da tu dong chuan hoa input '${INPUT_DOMAIN}' thanh '${DOMAIN}'${NC}"
        fi
        break
    fi

    if [[ $COUNT -eq $MAX_RETRIES ]]; then
        echo -e "${RED}Ban da nhap sai qua 3 lan. Dung script.${NC}"
        exit 1
    else
        echo "Vui long thu lai..."
        echo "-------------------------"
    fi
done

# --- BƯỚC MỚI: KIỂM TRA TỒN TẠI (QUAN TRỌNG) ---
echo "Dang kiem tra an toan he thong..."

# Không phải subdomain mới cần xác định chuyển hướng
if [ "$INSTALL_TYPE" != "subdomain" ]; then
	# Xác định luôn dạng chuyển hướng của tên miền để tiện kiểm tra thư mục web gốc
	if [[ "$DOMAIN" == www.* ]]; then
		RED_DOMAIN="${DOMAIN#www.}"
	else
		RED_DOMAIN="www.$DOMAIN"
	fi
fi

# Định nghĩa đường dẫn
# Thư mục tên miền người dùng nhập vào
WEB_ROOT_DIR_CHECK="/var/www/$DOMAIN"

if [ "$INSTALL_TYPE" != "subdomain" ]; then
	# Dự phòng thư mục tên miền chuyển hướng
	# Chỉ phải check khi kiểu cài đặt không phải là dạng subdomain
	WEB_ROOT_DIR_CHECK_RED="/var/www/$RED_DOMAIN"
fi

# Đường dẫn tới file Caddyfile
CADDY_CONF_CHECK="/etc/caddy/Caddyfile" 

# 1. Kiểm tra trong Caddyfile (Deep Scan Check)
if [ -f "$CADDY_CONF_CHECK" ]; then
    # Regex Explained:
    # (^|[[:space:]/])      : Bắt đầu dòng, khoảng trắng hoặc dấu /
    # $DOMAIN               : Tên miền
    # ([[:space:],:]|\{|$)  : Kết thúc bằng khoảng trắng, dấu phẩy (,), dấu hai chấm (:) hoặc dấu {
    
    if grep -Eq "(^|[[:space:]/])$DOMAIN([[:space:],:]|\{|$)" "$CADDY_CONF_CHECK"; then
        echo -e "${RED}NGUY HIEM: Ten mien [$DOMAIN] da duoc cau hinh trong Caddyfile!${NC}"
        echo -e "Script phat hien ten mien nay da ton tai (co the kem theo port hoac trong danh sach)."
        echo -e "Vui long kiem tra file $CADDY_CONF_CHECK va xoa cau hinh cu truoc khi chay lai."
        exit 1
    fi
fi

# 2. Kiểm tra thư mục Web
if [ -d "$WEB_ROOT_DIR_CHECK" ]; then
    echo -e "${RED}NGUY HIEM: Thu muc web [$WEB_ROOT_DIR_CHECK] da ton tai!${NC}"
    echo -e "Viec tiep tuc co the ghi de du lieu cu."
    echo -e "Vui long xoa thu muc thu cong hoac chon ten mien khac."
    exit 1
fi

# Không phải dạng subdomain mới cần kiểm tra
if [ "$INSTALL_TYPE" != "subdomain" ]; then

	if [ -d "$WEB_ROOT_DIR_CHECK_RED" ]; then
		echo -e "${RED}NGUY HIEM: Thu muc web [$WEB_ROOT_DIR_CHECK_RED] da ton tai!${NC}"
		echo -e "Viec tiep tuc co the gay nham lan."
		echo -e "Vui long xoa thu muc thu cong hoac chon ten mien khac."
		exit 1
	fi
	
fi

echo -e "${GREEN}Kiem tra an toan hoan tat.${NC}"
# -----------------------------------------------

# --- Script tiếp tục chạy từ đây khi dữ liệu đã đúng ---
echo -e "Thanh cong! Domain duoc chap nhan: $DOMAIN"
echo -e "${GREEN}>>> Dang tien hanh cai dat cho domain: ${YELLOW}$DOMAIN${NC}"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# F. Tạo Database & User

echo -e "${GREEN}Dang tao Database va User cho WordPress...${NC}"

# --- CẤU HÌNH BIẾN NGẪU NHIÊN ---
# F1. DB Name (Thoải mái độ dài, MySQL cho phép 64 ký tự)
# Kết quả ví dụ: wp_a1b2c3d4e5f67890
GEN_DB_NAME="wp_$(openssl rand -hex 8)"

# F2. User Name (Nên giữ <= 16 ký tự để tương thích mọi phiên bản MySQL)
# Giảm xuống hex 7 (14 ký tự) + "u_" (2 ký tự) = 16 ký tự
# Kết quả ví dụ: u_a1b2c3d4e5f6g7
GEN_DB_USER="u_$(openssl rand -hex 7)"

# F3. Password (32 ký tự là rất mạnh rồi)
# Kết quả ví dụ: p_890123456789abcdef0123456789abcd
GEN_DB_PASS="p_$(openssl rand -hex 16)"

# F4. Tạo bảng trong MariaDB
# Sử dụng biến đã tạo ở trên vào câu lệnh SQL
# Lưu ý: Vì biến chỉ chứa chữ cái thường và số nên không cần escape phức tạp, rất an toàn.

sudo mariadb -e "CREATE DATABASE IF NOT EXISTS ${GEN_DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mariadb -e "CREATE USER IF NOT EXISTS '${GEN_DB_USER}'@'localhost' IDENTIFIED BY '${GEN_DB_PASS}';"
sudo mariadb -e "GRANT ALL PRIVILEGES ON ${GEN_DB_NAME}.* TO '${GEN_DB_USER}'@'localhost';"
sudo mariadb -e "FLUSH PRIVILEGES;"

# F5. Xuất thông tin
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

# Để xem lại nội dung dùng lệnh sau trên terminal: cat ~/wpp.txt (đã bổ sung vào menu để người dùng cuối xem)
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
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# G. Cai dat WordPress (G) & Phân quyền (H)
# Xác định đường dẫn tuyệt đối đến file cài đặt WordPress
WORDPRESS_FILE_TEMP="$SCRIPT_WPSILA_DIR/wordpress.sh"

# Nhúng cài đặt WordPress vào, kiểm tra sự tồn tại để đảm bảo không lỗi
if [ -f "$WORDPRESS_FILE_TEMP" ]; then    
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
if [ "$INSTALL_TYPE" != "subdomain" ]; then
	echo "Domain chuyen huong: $RED_DOMAIN"
fi

# I2. Nội dung Caddyfile
#Xác định đường dẫn tuyệt đối đến file caddyfile mẫu để ghi đè vào file server Caddyfile
# Mặc định / Không phải kiểu subdomain
CADDY_FILE_TEMP="$SCRIPT_WPSILA_DIR/caddyfile.sh"

# Nếu là kiểu subdomain thì chọn file caddy tương ứng
if [ "$INSTALL_TYPE" == "subdomain" ]; then
	CADDY_FILE_TEMP="$SCRIPT_WPSILA_DIR/caddyfile_subdomain.sh"
fi

# Nhúng caddyfile vào, kiểm tra sự tồn tại để đảm bảo không lỗi
if [ -f "$CADDY_FILE_TEMP" ]; then    
    # Lệnh source quan trọng để nhúng trực tiếp vào file chính
    source "$CADDY_FILE_TEMP"
else 
	echo -e "${RED}KHONG TIM THAY Caddyfile (caddyfile.sh)! Hay kiem tra lai su ton tai cua file nay, hoac duong dan cua no.${NC}"
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
if [ -f "$CADDY_FILE" ]; then
    echo "Dang tao file backup: $BACKUP_FILE"
    sudo cp "$CADDY_FILE" "$BACKUP_FILE"
	
	# Gọi hàm xoay vòng để dọn dẹp ngay lập tức
	# Tránh việc có một đống các file backup sau này
	rotate_caddy_backup
else
    echo "Day la lan cai dat dau tien, chua co file Caddyfile cu de backup."
    # Tạo file rỗng để tránh lỗi cho các lệnh phía sau
    sudo touch "$CADDY_FILE"
fi

# I4. Thực hiện ghi vào Caddyfile chính
if grep -q "$MARKER" "$CADDY_FILE" 2>/dev/null; then
    echo "TIM THAY marker '$MARKER'. Dang them cau hinh vao cuoi file Caddyfile..."
    echo "$CONTENT" | sudo tee -a "$CADDY_FILE" > /dev/null
else
    echo "CAI DAT WORDPRESS lan dau! Tao file Caddyfile moi..."
    echo "$CONTENT" | sudo tee "$CADDY_FILE" > /dev/null
fi

# Format lại cho đẹp
sudo caddy fmt --overwrite "$CADDY_FILE" > /dev/null 2>&1

# I5. VALIDATE & ROLLBACK
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
    echo "Da cap nhat cau hinh cho $DOMAIN trong Caddyfile."
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo "Hoan tat! Xin chuc mung ban da cai thanh cong WordPress trên Caddy Web Server."
echo "Nhap muc <4> de xem thong tin pass cua trang WordPress ban vua tao."
# -------------------------------------------------------------------------------------------------------------------------------