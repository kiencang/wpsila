#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi, biến chưa được định nghĩa
# set -e: Dừng khi có lỗi.
# set -u: Dừng khi dùng biến chưa khai báo.
# set -o pipefail: Bắt lỗi cả trong chuỗi pipe.
set -euo pipefail

# Chạy lệnh
# version 0.02.12.25
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/remove_web.sh | bash

# Màu sắc hiển thị
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Loi: Vui long chay script voi quyen root (sudo).${NC}"
    exit 1
fi

# 2. Nhập liệu
echo -e "${YELLOW}=== CONG CU XOA WEBSITE WORDPRESS (CADDY) ===${NC}"
echo -e "${RED}LUY Y: HANH DONG NAY KHONG THE HOAN TAC, HAY BACKUP TRUOC!${NC}"
read -p "Nhap ten mien muon xoa (VD: example.com): " INPUT_DOMAIN < /dev/tty

# Sanitize input: Xóa khoảng trắng, chuyển chữ hoa thành chữ thường
DOMAIN=$(echo "$INPUT_DOMAIN" | tr -d ' ' | tr '[:upper:]' '[:lower:]')

# Validate input
if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"
    exit 1
fi

if [[ "$DOMAIN" != *"."* ]]; then
    echo -e "${RED}Loi: Ten mien '$DOMAIN' khong hop le (thieu dau cham).${NC}"
    exit 1
fi

# Chặn các đường dẫn hệ thống nguy hiểm
if [[ "$DOMAIN" == "/" ]] || [[ "$DOMAIN" == "." ]] || [[ "$DOMAIN" == ".." ]]; then
    echo -e "${RED}Loi: Ten mien khong hop le.${NC}"
    exit 1
fi

# Thiết lập đường dẫn
ROOT_DIR="/var/www/$DOMAIN"
CONFIG_FILE="$ROOT_DIR/public_html/wp-config.php"

# 3. Kiểm tra thư mục web
if [ ! -d "$ROOT_DIR" ]; then
    echo -e "${RED}Loi: Thu muc $ROOT_DIR khong ton tai. Script se dung lai.${NC}"
    exit 1
fi

echo -e "${YELLOW}--- Dang quet thong tin website: $DOMAIN ---${NC}"

# 4. Lấy thông tin Database (Verified Regex Method)
DB_NAME=""
DB_USER=""

if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}Da tim thay wp-config.php.${NC}"
    
    # Logic trích xuất:
    # 1. grep "define": Lấy dòng định nghĩa
    # 2. grep "DB_NAME": Lấy đúng hằng số
    # 3. grep -v: Loại bỏ các dòng comment bắt đầu bằng // hoặc #
    # 4. head -n 1: Chỉ lấy kết quả đầu tiên
    # 5. sed: Cắt lấy giá trị nằm giữa dấu nháy
    
    DB_NAME=$(grep "define" "$CONFIG_FILE" | grep "DB_NAME" | grep -v "^[[:space:]]*[#//]" | head -n 1 | sed -nE "s/.*['\"]DB_NAME['\"]\s*,\s*['\"]([^'\"]+)['\"].*/\1/p")
    
    DB_USER=$(grep "define" "$CONFIG_FILE" | grep "DB_USER" | grep -v "^[[:space:]]*[#//]" | head -n 1 | sed -nE "s/.*['\"]DB_USER['\"]\s*,\s*['\"]([^'\"]+)['\"].*/\1/p")
    
    if [ -z "$DB_NAME" ]; then
         echo -e "${YELLOW}Canh bao: Khong trich xuat duoc DB_NAME (Cau truc file la).${NC}"
         echo -e "${YELLOW}Script se chi xoa file ma nguon, DATABASE SE DUOC GIU LAI AN TOAN.${NC}"
    else
         echo -e "Database can xoa: ${RED}$DB_NAME${NC}"
         echo -e "User DB can xoa:  ${RED}$DB_USER${NC}"
    fi
else
    echo -e "${YELLOW}Canh bao: Khong tim thay wp-config.php. Script se chi xoa file.${NC}"
fi

# 5. Xác nhận
echo -e ""
read -p "Ban co chac muon XOA VINH VIEN du lieu cua website? (y/n): " confirm < /dev/tty

if [[ ! "$confirm" =~ ^[yY](es)?$ ]]; then
    echo "Da HUY thao tac theo yeu cau. Website CHUA bi xoa."
    exit 0
fi

# 6. Xóa Database
if [ -n "$DB_NAME" ]; then
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

# 7. Xóa File
echo -e "${YELLOW}Dang xoa thu muc web: $ROOT_DIR ...${NC}"

# Chốt chặn an toàn cuối cùng cho lệnh rm -rf
if [[ "$ROOT_DIR" == "/var/www" ]] || [[ "$ROOT_DIR" == "/" ]]; then
    echo -e "${RED}NGUY HIEM: Duong dan xoa khong an toan ($ROOT_DIR). Huy bo thao tac.${NC}"
    exit 1
fi

rm -rf "$ROOT_DIR"

if [ ! -d "$ROOT_DIR" ]; then
    echo -e "${GREEN}Da xoa thu muc $ROOT_DIR thanh cong.${NC}"
else
    echo -e "${RED}Loi: Khong the xoa thu muc $ROOT_DIR. Kiem tra lai quyen hạn (chattr?).${NC}"
    exit 1
fi

# 8. Kết thúc
echo -e ""
echo -e "${GREEN}=== XOA WEBSITE THANH CONG! ===${NC}"
echo -e "Viec can lam tiep theo:"
echo -e "1. Mo file Caddyfile xoa cau hinh domain."
echo -e "2. Chay lenh: systemctl reload caddy"