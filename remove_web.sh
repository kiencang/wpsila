#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi, biến chưa được định nghĩa
# set -e: Dừng khi có lỗi.
# set -u: Dừng khi dùng biến chưa khai báo.
# set -o pipefail: Bắt lỗi cả trong chuỗi pipe.
set -euo pipefail

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Chạy lệnh
# version 0.04.12.25
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/remove_web.sh | bash
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
read -p "Nhap ten mien muon xoa (VD: example.com): " INPUT_DOMAIN < /dev/tty

# Sanitize input: Xóa khoảng trắng, chuyển chữ hoa thành chữ thường
DOMAIN=$(echo "$INPUT_DOMAIN" | tr -d ' ' | tr '[:upper:]' '[:lower:]')

# Kiểm tra đầu vào
if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"
    exit 1
fi

if [[ "$DOMAIN" != *"."* ]]; then
    echo -e "${RED}Loi: Ten mien '$DOMAIN' khong hop le (thieu dau cham).${NC}"
    exit 1
fi

# C2. Chặn các đường dẫn hệ thống nguy hiểm, mà lệnh xóa có thể gây sụp VPS
if [[ "$DOMAIN" == "/" ]] || [[ "$DOMAIN" == "." ]] || [[ "$DOMAIN" == ".." ]]; then
    echo -e "${RED}Loi: Ten mien khong hop le.${NC}"
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
# D. Kiểm tra thư mục web có tồn tại hay không?
if [[ ! -d "$ROOT_DIR" ]]; then
    echo -e "${RED}Loi: Thu muc $ROOT_DIR khong ton tai. Script se dung lai.${NC}"
    exit 1
fi

echo -e "${YELLOW}--- Dang quet thong tin website: $DOMAIN ---${NC}"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# E. Lấy thông tin Database (Sử dụng WP-CLI - Reliable Method)
DB_NAME=""
DB_USER=""
WP_PATH="$ROOT_DIR/public_html" # Đường dẫn tới thư mục chứa wp-config.php

if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "${GREEN}Da tim thay wp-config.php.${NC}"

    # Kiểm tra xem lệnh wp có tồn tại không
    if command -v wp &> /dev/null; then
        # Lấy DB_NAME và DB_USER
        # --skip-themes --skip-plugins: Bắt buộc dùng để tránh lỗi PHP từ plugin làm hỏng luồng script
        # tr -d '\r\n': Cắt bỏ ký tự xuống dòng thừa để đảm bảo chuỗi sạch 100%
        
        DB_NAME=$(wp config get DB_NAME --path="$WP_PATH" --allow-root --quiet --skip-themes --skip-plugins 2>/dev/null | tr -d '\r\n')
        DB_USER=$(wp config get DB_USER --path="$WP_PATH" --allow-root --quiet --skip-themes --skip-plugins 2>/dev/null | tr -d '\r\n')
        
    else
        echo -e "${RED}Loi: WP-CLI chua duoc cai dat. Khong the lay thong tin DB.${NC}"
    fi

    # Kiểm tra kết quả trả về
    if [[ -z "$DB_NAME" ]]; then
        echo -e "${YELLOW}Canh bao: Khong the trich xuat ten Database (co the file config loi hoac WP-CLI gap su co).${NC}"
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
read -p "Ban co chac muon XOA VINH VIEN du lieu cua website? (y/n): " confirm < /dev/tty

if [[ ! "$confirm" =~ ^[yY](es)?$ ]]; then
    echo "Da HUY thao tac theo yeu cau. Website CHUA bi xoa."
    exit 0
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# G. Xóa Database và User
if [[ -n "$DB_NAME" ]]; then
    echo -e "${YELLOW}Dang xoa Database va User...${NC}"
    
    if ! command -v mysql &> /dev/null; then
        echo -e "${RED}Loi: Khong tim thay lenh 'mysql'. Bo qua buoc xoa DB.${NC}"
    else
        # Tạo chuỗi lệnh SQL để xóa sạch sẽ
        # 2>/dev/null ở lệnh mysql giúp ẩn các cảnh báo không cần thiết
        SQL_CMD="DROP DATABASE IF EXISTS \`$DB_NAME\`;"
        SQL_CMD+="DROP USER IF EXISTS \`$DB_USER\`@'localhost';"
        SQL_CMD+="DROP USER IF EXISTS \`$DB_USER\`@'%';"
        SQL_CMD+="FLUSH PRIVILEGES;"

        if mysql -u root -e "$SQL_CMD" 2>/dev/null; then
            echo -e "${GREEN}Da xoa Database & User thanh cong.${NC}"
        else
            echo -e "${RED}Loi: MySQL bao loi (Sai pass root hoac thieu quyen). Vui long xoa DB thu cong.${NC}"
        fi
    fi
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# G. Xóa thư mục website
echo -e "${YELLOW}Dang xoa thu muc web: $ROOT_DIR ...${NC}"

# Chốt chặn an toàn cuối cùng cho lệnh rm -rf
if [[ "$ROOT_DIR" == "/var/www" ]] || [[ "$ROOT_DIR" == "/" ]]; then
    echo -e "${RED}NGUY HIEM: Duong dan xoa khong an toan ($ROOT_DIR). Huy bo thao tac.${NC}"
    exit 1
fi

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
# G. Xóa chứng chỉ https đã xin cấp trước đây lưu trong Caddy
# Định nghĩa đường dẫn gốc chứa cert
CERT_PATH="/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory"

# G.1. Kiểm tra xem biến DOMAIN có rỗng không? (thừa, nhưng thôi cho chắc!)
if [[ -z "$DOMAIN" ]]; then
    echo "LOI: Bien ten mien bi rong! Dung lai de bao ve he thong."
    exit 1
fi

# G.2. Kiểm tra xem thư mục cert của tên miền đó có tồn tại không rồi mới xóa
if [[ -d "$CERT_PATH/$DOMAIN" ]]; then
    echo "Dang xoa chung chi cu cua $DOMAIN..."
    rm -rf "$CERT_PATH/$DOMAIN"
else
    echo "Khong tim thay chung chi cu cua $DOMAIN (Co the chua duoc tao bao gio)."
fi

# G.3. Xử lý luôn cả tên miền chuyển hướng
# Xác định tên miền chuyển hướng
if [[ "$DOMAIN" == www.* ]]; then
    # Nếu bắt đầu bằng www. -> Cắt bỏ 4 ký tự đầu (www.)
    RED_DOMAIN="${DOMAIN#www.}"
else
    # Nếu không có www. -> Thêm www. vào đầu
    RED_DOMAIN="www.$DOMAIN"
fi

# Phòng thủ
if [[ -z "$RED_DOMAIN" ]]; then
    echo "LOI: Bien ten mien bi rong! Dung lai de bao ve he thong."
    exit 1
fi

# Xóa https của cả tên miền chuyển hướng nếu nó có
if [[ -d "$CERT_PATH/$RED_DOMAIN" ]]; then
    echo "Dang xoa chung chi cu cua $RED_DOMAIN..."
    rm -rf "$CERT_PATH/$RED_DOMAIN"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# H. Thêm phần xóa cấu hình trong file Caddyfile

# H.1. Khai báo biến
CADDY_FILE="/etc/caddy/Caddyfile"

# Kiểm tra nếu người dùng chưa nhập domain
if [[ -z "$DOMAIN" ]]; then
    echo "Loi: Ten mien trong. Thoat chuong trinh, cau hinh trong Caddyfile chua duoc xoa."
    exit 1
fi

# H.2. Tạo nội dung Marker cần tìm
# Lưu ý: Marker phải khớp chính xác với những gì bạn đã thêm vào trước đó
START_MARKER="###start_wpsila_kiencang_${DOMAIN}###"
END_MARKER="###end_wpsila_kiencang_${DOMAIN}###"

# H.3. Kiểm tra xem Marker có tồn tại trong file không
# Dùng grep -F (fixed string) để tìm chính xác chuỗi, tránh lỗi regex
if ! grep -Fq "$START_MARKER" "$CADDY_FILE"; then
    echo "Thong bao: KHONG tim thay cau hinh cho domain $DOMAIN trong Caddyfile."
    exit 0
fi

echo "Dang tien hanh xoa cau hinh cho: $DOMAIN..."

# H.4. Xử lý tên miền cho Regex (Quan trọng)
# Dấu chấm (.) trong domain (ví dụ abc.com) là ký tự đặc biệt trong Regex
# Cần chuyển đổi dấu . thành \. để sed hiểu đó là dấu chấm thực sự.
DOMAIN_ESCAPED=$(echo "$DOMAIN" | sed 's/\./\\./g')

# Update lại biến Marker dùng cho Regex (có escaped domain)
REGEX_START="^###start_wpsila_kiencang_${DOMAIN_ESCAPED}###$"
REGEX_END="^###end_wpsila_kiencang_${DOMAIN_ESCAPED}###$"

# H.5. Backup file Caddyfile hiện tại (An toàn là trên hết)
# H.5.1. Lấy timestamp 1 lần duy nhất và lưu vào biến
TIMESTAMP=$(date +%s)

# H.5.2. Định nghĩa tên file backup cụ thể
BACKUP_FILE="${CADDY_FILE}.bak_${TIMESTAMP}"

# H.5.3. Tạo file backup cho caddyfile
echo "Dang tao file backup: $BACKUP_FILE"
cp "$CADDY_FILE" "$BACKUP_FILE"

# H.6. Thực hiện xóa bằng SED
# Giải thích lệnh sed:
# -i : Sửa trực tiếp trên file
# /^...$/ : Dấu ^ là bắt đầu dòng, $ là kết thúc dòng -> Đảm bảo dòng đó chỉ chứa đúng marker, không thừa thiếu khoảng trắng hay ký tự lạ.
# , : Là phạm vi từ Regex Start đến Regex End
# d : Delete (xóa)
sed -i "/$REGEX_START/,/$REGEX_END/d" "$CADDY_FILE"

# H.7. Kiểm tra tính hợp lệ của Caddyfile mới (Validation)
# Nếu Caddy báo lỗi cấu hình, lập tức khôi phục file cũ
if ! caddy validate --config "$CADDY_FILE" --adapter caddyfile > /dev/null 2>&1; then
    echo "CANH BAO: File Caddyfile bi loi sau khi sua. Dang khoi phuc lai file ban dau..."
	
    cp "$BACKUP_FILE" "$CADDY_FILE"
	
    echo "Da khoi phuc lai file Caddyfile goc. Vui long kiem tra lai Caddyfile de xoa thu cong phan tuong ung."
    exit 1
else
    # Nếu mọi thứ OK, Reload lại Caddy
    echo "Cau hinh hop le. Dang reload Caddy..."	
    systemctl reload caddy
    echo "Hoan tat! Da xoa cau hinh cho $DOMAIN trong Caddyfile."
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 10. Kết thúc & thông báo
echo -e ""
echo -e "${GREEN}=== XOA WEBSITE THANH CONG! ===${NC}"
# -------------------------------------------------------------------------------------------------------------------------------