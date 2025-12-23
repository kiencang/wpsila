#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi, biến chưa được định nghĩa
# set -e: Dừng khi có lỗi.
# set -u: Dừng khi dùng biến chưa khai báo.
# set -o pipefail: Bắt lỗi cả trong chuỗi pipe.
set -euo pipefail

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
read -r -p "Nhap ten mien muon xoa (VD: example.com): " INPUT_DOMAIN < /dev/tty

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
		# Thêm "|| true" để nếu WP-CLI lỗi, script không bị dừng bởi set -e
        DB_NAME=$(wp config get DB_NAME --path="$WP_PATH" --allow-root --quiet --skip-themes --skip-plugins 2>/dev/null | tr -d '\r\n' || true)
        DB_USER=$(wp config get DB_USER --path="$WP_PATH" --allow-root --quiet --skip-themes --skip-plugins 2>/dev/null | tr -d '\r\n' || true)
        
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
    
    if ! command -v mysql &> /dev/null; then
        echo -e "${RED}Loi: Khong tim thay lenh 'mysql'. Bo qua buoc xoa DB.${NC}"
    else
        # Tạo chuỗi lệnh SQL để xóa sạch sẽ
        # 2>/dev/null ở lệnh mysql giúp ẩn các cảnh báo không cần thiết
        SQL_CMD="DROP DATABASE IF EXISTS \`$DB_NAME\`;"
        SQL_CMD+="DROP USER IF EXISTS \`$DB_USER\`@'localhost';"
		SQL_CMD+="DROP USER IF EXISTS \`$DB_USER\`@'127.0.0.1';"
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
# G2. Xóa thư mục website
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
# G3. Xóa chứng chỉ https đã xin cấp trước đây lưu trong Caddy
# Định nghĩa đường dẫn gốc chứa cert
CERT_PATH="/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory"

# G3.1. Kiểm tra xem biến DOMAIN có rỗng không? (thừa, nhưng thôi cho chắc!)
if [[ -z "$DOMAIN" ]]; then
    echo "LOI: Bien ten mien bi rong! Dung lai de bao ve he thong."
    exit 1
fi

# G3.2. Kiểm tra xem thư mục cert của tên miền đó có tồn tại không rồi mới xóa
if [[ -d "$CERT_PATH/$DOMAIN" ]]; then
    echo "Dang xoa chung chi cu cua $DOMAIN..."
	rm -rf "${CERT_PATH:?}/$DOMAIN"
else
    echo "Khong tim thay chung chi cu cua $DOMAIN (Co the chua duoc tao bao gio)."
fi

# G3.3. Xử lý luôn cả tên miền chuyển hướng
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
	rm -rf "${CERT_PATH:?}/$RED_DOMAIN"
fi
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
# I. Kết thúc & thông báo
echo -e ""
echo -e "${GREEN}=== XOA WEBSITE THANH CONG! ===${NC}"
# -------------------------------------------------------------------------------------------------------------------------------