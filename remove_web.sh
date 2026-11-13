#!/bin/bash

# -----------------------------------------------------------
# Bash xóa website WordPress
# File: remove_web.sh
# Nó cố gắng xóa triệt để toàn bộ dấu tích
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Dừng script ngay lập tức nếu có lệnh bị lỗi, biến chưa được định nghĩa
# set -e: Dừng khi có lỗi.
# set -u: Dừng khi dùng biến chưa khai báo.
# set -o pipefail: Bắt lỗi cả trong chuỗi pipe.
set -euo pipefail
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# A. Màu sắc hiển thị
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# B. Kiểm tra quyền 
# NÂNG QUYỀN NẾU KHÔNG PHẢI LÀ ROOT
# 1. Kiểm tra xem đang chạy với quyền gì
if [[ $EUID -ne 0 ]]; then
   # 2. Nếu không phải root, tự động chạy lại script này bằng sudo
   # Thêm tham số -E cho sudo để giữ lại các biến môi trường (nếu có)
   sudo -E "$0" "$@"
   # 3. Thoát tiến trình cũ (không phải root) để tiến trình mới (có root) chạy
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# C. Nhập tên miền cần xóa, chuẩn hóa & chống các lỗi nhập nguy hiểm
# C1. Thông báo trước sự nguy hiểm của yêu cầu này
echo -e "${YELLOW}=== CONG CU XOA WEBSITE WORDPRESS (CADDY) ===${NC}"
echo -e "${RED}LUY Y: HANH DONG NAY KHONG THE HOAN TAC, HAY BACKUP TRUOC!${NC}"
read -r -p "Nhap dia chi website muon xoa (VD: example.com): " INPUT_DOMAIN < /dev/tty

# Sanitize input: Xóa khoảng trắng, chuyển chữ hoa thành chữ thường, cắt http(s)://, path và port
TEMP_DOMAIN=$(echo "$INPUT_DOMAIN" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
DOMAIN=$(echo "$TEMP_DOMAIN" | sed -E 's|^https?://||' | sed -E 's|/.*$||' | sed -E 's|:[0-9]+$||')

# Kiểm tra đầu vào
if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}Loi: Dia chi website khong duoc de trong!${NC}"
    exit 1
fi

# Thoát sớm với định dạng sai
if [[ "$DOMAIN" != *"."* ]]; then
    echo -e "${RED}Loi: Dia chi website '$DOMAIN' khong hop le (thieu dau cham).${NC}"
    exit 1
fi

# Kiểm tra chặt hơn với cấu trúc tên miền tiêu chuẩn
if [[ ! "$DOMAIN" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*\.[a-z]{2,}$ ]]; then
    echo -e "${RED}Loi: Dia chi website '$DOMAIN' chua ky tu khong hop le hoac sai dinh dang.${NC}"
	exit 1
fi		 

# C2. Chặn các đường dẫn hệ thống nguy hiểm, mà lệnh xóa có thể gây sụp VPS
if [[ "$DOMAIN" == "/" ]] || [[ "$DOMAIN" == "." ]] || [[ "$DOMAIN" == ".." ]]; then
    echo -e "${RED}Loi: Dia chi website khong hop le.${NC}"
    exit 1
fi

# C3. Thiết lập đường dẫn, cấu trúc này do phần khởi tạo quy định
# Do vậy khi xóa phải lấy lại cấu trúc này
ROOT_DIR="/var/www/$DOMAIN"

# C4. Tìm đến file wp-config.php để lấy thông tin database & user
CONFIG_FILE="$ROOT_DIR/public_html/wp-config.php"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# D. Kiểm tra thư mục web có tồn tại hay không? (Hỗ trợ nhận diện cả Adminer ở bất kỳ tên miền nào)
CADDY_SITE_FILE="/etc/caddy/sites-enabled/${DOMAIN}.caddy"
ADMINER_DIR="/var/www/adminer"

if [[ ! -d "$ROOT_DIR" ]]; then
    # Nếu không có thư mục /var/www/$DOMAIN, kiểm tra xem file .caddy của domain này có đang trỏ tới /var/www/adminer không
    if [[ -f "$CADDY_SITE_FILE" ]] && grep -q "$ADMINER_DIR" "$CADDY_SITE_FILE"; then
        echo -e "${YELLOW}>>> Phat hien '$DOMAIN' la trang quan tri Database (Adminer).${NC}"
        echo -e "${RED}LUU Y: Thao tac nay se xoa cau hinh Adminer ($DOMAIN), tai khoan DB 'adminer_db' va ma nguon tai $ADMINER_DIR.${NC}"
        read -r -p "Ban co chac chan muon XOA Adminer khong? (y/n): " confirm_adminer < /dev/tty

        if [[ ! "$confirm_adminer" =~ ^[yY](es)?$ ]]; then
            echo "Da HUY thao tac theo yeu cau. Adminer CHUA bi xoa."
            exit 0
        fi

        # 1. Xóa file cấu hình Caddy & Reload Caddy
        rm -f "$CADDY_SITE_FILE"
        if systemctl reload caddy; then
            echo -e "${GREEN}Da xoa cau hinh Caddy ($CADDY_SITE_FILE) va Reload thanh cong.${NC}"
        else
            echo -e "${RED}Canh bao: Khong the reload Caddy. Vui long kiem tra trang thai service.${NC}"
        fi

        # 2. Xóa chứng chỉ SSL cũ của $DOMAIN (bao gồm cả Let's Encrypt và ZeroSSL)
        for cert_dir in /var/lib/caddy/.local/share/caddy/certificates/*/"$DOMAIN"; do
            if [[ -n "$DOMAIN" && -d "$cert_dir" ]]; then
                rm -rf "$cert_dir"
                echo -e "${GREEN}Da xoa chung chi SSL cu tai: $cert_dir${NC}"
            fi
        done
        unset cert_dir

        # 3. Nếu không còn tên miền nào khác đang trỏ vào /var/www/adminer thì dọn sạch toàn bộ Adminer
        if ! grep -ql "$ADMINER_DIR" /etc/caddy/sites-enabled/*.caddy 2>/dev/null; then
            if command -v mariadb &> /dev/null; then
                if mariadb -u root -e "DROP USER IF EXISTS 'adminer_db'@'localhost'; FLUSH PRIVILEGES;" 2>/dev/null; then
                    echo -e "${GREEN}Da xoa tai khoan DB 'adminer_db'@'localhost'.${NC}"
                else
                    echo -e "${RED}Canh bao: Khong the xoa tai khoan DB 'adminer_db'@'localhost' (Kiem tra trang thai MariaDB).${NC}"
                fi
            fi

            if [[ -d "$ADMINER_DIR" ]]; then
                rm -rf "$ADMINER_DIR"
                echo -e "${GREEN}Da xoa thu muc ma nguon $ADMINER_DIR.${NC}"
            fi

            rm -f /var/log/caddy/adminer_access*.log*
            SCRIPT_WPSILA_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
            rm -f "$SCRIPT_WPSILA_DIR/adminerp.txt"
            echo -e "${GREEN}Da xoa log va file mat khau adminerp.txt.${NC}"
        fi

        echo ""
        echo -e "${GREEN}=== XOA ADMINER THANH CONG! ===${NC}"
        exit 0
    else
        echo -e "${RED}Loi: Thu muc $ROOT_DIR khong ton tai. Script se dung lai.${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}--- Dang quet thong tin website: $DOMAIN ---${NC}"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# E. Lấy thông tin Database (Ưu tiên đọc tĩnh an toàn, dự phòng WP-CLI dưới user www-data)
DB_NAME=""
DB_USER=""
WP_PATH="$ROOT_DIR/public_html" # Đường dẫn tới thư mục chứa wp-config.php

if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "${GREEN}Da tim thay wp-config.php.${NC}"

    # 1. Trích xuất tĩnh an toàn (không thực thi PHP dưới quyền root, bỏ qua dòng comment)
    DB_NAME=$(grep -E "^[[:space:]]*define\(\s*['\"]DB_NAME['\"]" "$CONFIG_FILE" 2>/dev/null | sed -E "s/.*['\"]DB_NAME['\"]\s*,\s*['\"]([^'\"]+)['\"].*/\1/" | head -n 1 | tr -d '\r\n' || true)
    DB_USER=$(grep -E "^[[:space:]]*define\(\s*['\"]DB_USER['\"]" "$CONFIG_FILE" 2>/dev/null | sed -E "s/.*['\"]DB_USER['\"]\s*,\s*['\"]([^'\"]+)['\"].*/\1/" | head -n 1 | tr -d '\r\n' || true)

    # 2. Nếu đọc tĩnh chưa lấy được, dự phòng qua WP-CLI dưới quyền www-data
    if [[ -z "$DB_NAME" || -z "$DB_USER" ]] && command -v wp &> /dev/null; then
        [[ -z "$DB_NAME" ]] && DB_NAME=$(runuser -u www-data -- wp config get DB_NAME --path="$WP_PATH" --quiet --skip-themes --skip-plugins 2>/dev/null | tr -d '\r\n' || true)
        [[ -z "$DB_USER" ]] && DB_USER=$(runuser -u www-data -- wp config get DB_USER --path="$WP_PATH" --quiet --skip-themes --skip-plugins 2>/dev/null | tr -d '\r\n' || true)
    fi

    # Kiểm tra kết quả trả về
    if [[ -z "$DB_NAME" ]]; then
        echo -e "${YELLOW}Canh bao: Khong the trich xuat ten Database (co the file config loi).${NC}"
        echo -e "${YELLOW}Hanh dong: Script se chi xoa file, DATABASE CHUA XOA.${NC}"
    else
        echo -e "Phat hien Database: ${RED}$DB_NAME${NC}"
        echo -e "Phat hien DB User:  ${RED}$DB_USER${NC}"
    fi

else
    echo -e "${YELLOW}Khong tim thay wp-config.php. Script se chi xoa thu muc web.${NC}"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# F. Xác nhận lại người dùng có chắc chắn muốn xóa không, luôn phải làm
echo -e ""
read -r -p "Ban co chac muon XOA VINH VIEN du lieu cua website? (y/n): " confirm < /dev/tty

if [[ ! "$confirm" =~ ^[yY](es)?$ ]]; then
    echo "Da HUY thao tac theo yeu cau. Website CHUA bi xoa."
    exit 0
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# G1. Xóa Database và User
if [[ -n "$DB_NAME" ]]; then
    echo -e "${YELLOW}Dang xoa Database va User...${NC}"
    
    if ! command -v mariadb &> /dev/null; then
        echo -e "${RED}Loi: Khong tim thay lenh 'mariadb'. Bo qua buoc xoa DB.${NC}"
    else
        # Tạo chuỗi lệnh SQL để xóa sạch sẽ
        # 2>/dev/null ở lệnh mariadb giúp ẩn các cảnh báo không cần thiết
        SQL_CMD="DROP DATABASE IF EXISTS \`$DB_NAME\`;"
        if [[ -n "$DB_USER" ]]; then
            SQL_CMD+="DROP USER IF EXISTS \`$DB_USER\`@'localhost';"
            SQL_CMD+="DROP USER IF EXISTS \`$DB_USER\`@'127.0.0.1';"
            SQL_CMD+="DROP USER IF EXISTS \`$DB_USER\`@'%';"
        fi
        SQL_CMD+="FLUSH PRIVILEGES;"

        if mariadb -u root -e "$SQL_CMD" 2>/dev/null; then
            echo -e "${GREEN}Da xoa Database & User thanh cong.${NC}"
        else
            echo -e "${RED}Loi: Mariadb bao loi (Sai pass root hoac thieu quyen). Vui long xoa DB thu cong.${NC}"
        fi
    fi
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# G2. Xóa thư mục website
echo -e "${YELLOW}Dang xoa thu muc web: $ROOT_DIR ...${NC}"

# Chốt chặn an toàn cuối cùng cho lệnh rm -rf
if [[ "$ROOT_DIR" == "/var/www" ]] || [[ "$ROOT_DIR" == "/" ]]; then
    echo -e "${RED}NGUY HIEM: Duong dan xoa khong an toan ($ROOT_DIR). Huy bo thao tac.${NC}"
    exit 1
fi

# Gỡ cờ bất biến chattr (nếu wp-config.php từng được khóa) trước khi xóa thư mục
chattr -R -i "$ROOT_DIR" 2>/dev/null || true

rm -rf "$ROOT_DIR"

if [[ ! -d "$ROOT_DIR" ]]; then
    echo -e "${GREEN}Da xoa thu muc $ROOT_DIR thanh cong.${NC}"
else
    echo -e "${RED}Loi: Khong the xoa thu muc $ROOT_DIR. Kiem tra lai quyen hạn (chattr?).${NC}"
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# G3. Xóa chứng chỉ https đã xin cấp trước đây lưu trong Caddy (hỗ trợ cả Let's Encrypt và ZeroSSL)
# G3.1. Kiểm tra xem biến DOMAIN có rỗng không?
if [[ -z "$DOMAIN" ]]; then
    echo "LOI: Bien ten mien bi rong! Dung lai de bao ve he thong."
    exit 1
fi

# G3.2. Quét và xóa chứng chỉ của tên miền chính trên mọi ACME directory
FOUND_MAIN_CERT=0
for cert_dir in /var/lib/caddy/.local/share/caddy/certificates/*/"$DOMAIN"; do
    if [[ -d "$cert_dir" ]]; then
        FOUND_MAIN_CERT=1
        echo -e "${YELLOW}Dang xoa chung chi cu cua $DOMAIN tai: $cert_dir ...${NC}"
        rm -rf "${cert_dir:?}"
        echo -e "${GREEN}Xoa thanh cong chung chi cu cua $DOMAIN.${NC}"
    fi
done
if (( FOUND_MAIN_CERT == 0 )); then
    echo "Khong tim thay chung chi cu cua $DOMAIN (Co the chua duoc tao bao gio)."
fi

# G3.3. Xử lý luôn cả tên miền chuyển hướng
if [[ "$DOMAIN" == www.* ]]; then
    RED_DOMAIN="${DOMAIN#www.}"
else
    RED_DOMAIN="www.$DOMAIN"
fi

if [[ -z "$RED_DOMAIN" ]]; then
    echo "LOI: Bien ten mien bi rong! Dung lai de bao ve he thong."
    exit 1
fi

FOUND_RED_CERT=0
for cert_dir in /var/lib/caddy/.local/share/caddy/certificates/*/"$RED_DOMAIN"; do
    if [[ -d "$cert_dir" ]]; then
        FOUND_RED_CERT=1
        echo -e "${YELLOW}Dang xoa chung chi cu cua $RED_DOMAIN tai: $cert_dir ...${NC}"
        rm -rf "${cert_dir:?}"
        echo -e "${GREEN}Xoa thanh cong chung chi cu cua $RED_DOMAIN.${NC}"
    fi
done
if (( FOUND_RED_CERT == 0 )); then
    echo "Khong tim thay chung chi cu cua $RED_DOMAIN (Co the chua duoc tao bao gio)."
fi
unset cert_dir FOUND_MAIN_CERT FOUND_RED_CERT
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# H. Xóa cấu hình trong Caddy (KIẾN TRÚC MODULAR)
# H1. Xác định file cấu hình
CADDY_SITE_FILE="/etc/caddy/sites-enabled/${DOMAIN}.caddy"

# H2. Kiểm tra file có tồn tại không
if [[ -f "$CADDY_SITE_FILE" ]]; then
    echo -e "${YELLOW}Dang xoa file cau hinh Caddy: $CADDY_SITE_FILE${NC}"
    
    # Xóa file
    rm -f "$CADDY_SITE_FILE"
    
    # H3. Reload Caddy để cập nhật thay đổi
    # Không cần validate phức tạp vì xóa 1 file con (nếu file đó ko gây lỗi main) thì reload an toàn
    if systemctl reload caddy; then
        echo -e "${GREEN}Da xoa cau hinh Caddy va Reload thanh cong.${NC}"
    else
        echo -e "${RED}Canh bao: Khong the reload Caddy. Vui long kiem tra trang thai service.${NC}"
    fi
else
    echo "Khong tim thay file cau hinh Caddy (Co the da xoa tu truoc)."
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Xóa Cronjob của domain tương ứng (Dùng grep -Fv để so khớp chuỗi tĩnh chính xác, không bị dấu chấm làm nhiễu regex)
echo -e "${YELLOW}Dang xoa Cronjob he thong cua website...${NC}"

(crontab -u www-data -l 2>/dev/null || true) | grep -Fv "/var/www/$DOMAIN/public_html/wp-cron.php" | crontab -u www-data - || true
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# [NEW] Xóa các tài khoản SFTP gắn với website này
echo -e "${YELLOW}Dang kiem tra va xoa tai khoan SFTP cua website...${NC}"

# Tìm trong /etc/passwd các user có Home Directory (cột 6) trùng với $ROOT_DIR (/var/www/$DOMAIN)
SFTP_USERS=$(awk -F: -v dir="$ROOT_DIR" '$6 == dir {print $1}' /etc/passwd || true)

if [[ -n "$SFTP_USERS" ]]; then
    for sftp_user in $SFTP_USERS; do
        # Kiểm tra chắc chắn user này thuộc group 'sftp_only' do wpsila tạo ra thì mới xóa
        if id -nG "$sftp_user" 2>/dev/null | grep -qw "sftp_only"; then
            # Ngắt các tiến trình SFTP của user này nếu đang kết nối trên FileZilla/WinSCP
            pkill -KILL -u "$sftp_user" &>/dev/null || true
            # Xóa user khỏi hệ thống (không dùng -r vì thư mục web đã được xóa ở bước G2)
            if userdel -f "$sftp_user" &>/dev/null; then
                echo -e "${GREEN} -> Da xoa tai khoan SFTP: $sftp_user${NC}"
            fi
        fi
    done
    unset sftp_user
else
    echo "Khong tim thay tai khoan SFTP nao gan voi $DOMAIN."
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# I. Kết thúc & thông báo
echo -e ""
echo -e "${GREEN}=== XOA WEBSITE THANH CONG! ===${NC}"
# -------------------------------------------------------------------------------------------------------------------------------