#!/bin/bash

# Dừng script nếu có lỗi
set -e

# Màu sắc
GREEN='\033[0;32m'
NC='\033[0m'

# --- BƯỚC 1: NHẬP DOMAIN ---
# Sử dụng read -p để yêu cầu người dùng nhập liệu
echo -e "${GREEN}>>> Vui long nhap ten mien cua ban (vi du: example.com):${NC}"
read -p "Domain: " DOMAIN

# Kiểm tra nếu người dùng không nhập gì mà bấm Enter
if [ -z "$DOMAIN" ]; then
    echo "Loi: ten mien khong duoc de trong!"
    exit 1
fi

echo -e "${GREEN}>>> Dang tien hanh cai dat cho domain: $DOMAIN${NC}"

# --- BƯỚC 2: TẠO THƯ MỤC WEB ROOT ---
echo -e "${GREEN}[1/5] Tao thu muc chua ma nguon...${NC}"
sudo mkdir -p /var/www/$DOMAIN/public_html

# --- BƯỚC 3: TẠO THƯ MỤC LOGS ---
echo -e "${GREEN}[2/5] Tao thu muc logs va cap quyen cho Caddy...${NC}"
sudo mkdir -p /var/www/$DOMAIN/logs
# Caddy cần quyền ghi vào logs, trong khi PHP chạy dưới quyền www-data
sudo chown -R caddy:caddy /var/www/$DOMAIN/logs

# --- BƯỚC 4 & 5: TẢI VỀ VÀ GIẢI NÉN ---
echo -e "${GREEN}[3/5] Dang tai ve WordPress moi nhat...${NC}"

# Tải về thư mục tạm hiện tại để tránh lỗi đường dẫn
sudo curl -LO https://wordpress.org/latest.tar.gz

echo -e "${GREEN}[4/5] Dang giai nen vao thu muc dich...${NC}"
# Giải nén thẳng vào public_html và loại bỏ thư mục mẹ "wordpress" (--strip-components=1)
sudo tar xzvf latest.tar.gz -C /var/www/$DOMAIN/public_html --strip-components=1

# Xóa file nén cho sạch
sudo rm latest.tar.gz

# --- BƯỚC 6: PHÂN QUYỀN ---
echo -e "${GREEN}[5/5] Dang thiet lap quyen han (Permissions)...${NC}"

WP_ROOT="/var/www/$DOMAIN/public_html"
PARENT_DIR="/var/www/$DOMAIN"
WP_OWNER="www-data"
WP_GROUP="www-data"

# Gán chủ sở hữu cho thư mục code là www-data (để PHP có thể ghi file, update plugin)
sudo chown -R $WP_OWNER:$WP_GROUP "$WP_ROOT"
# Gán chủ sở hữu cho thư mục cha
sudo chown $WP_OWNER:$WP_GROUP "$PARENT_DIR"

# Chuẩn hóa quyền: Thư mục 755, File 644 (Bảo mật tiêu chuẩn cho WP)
sudo find "$WP_ROOT" -type d -exec chmod 755 {} \;
sudo find "$WP_ROOT" -type f -exec chmod 644 {} \;

# Đảm bảo quyền thực thi cho thư mục cha để webserver có thể truy cập vào trong
sudo chmod +x /var/www

echo -e "${GREEN}>>> Hoan tat cai dat ma nguon WordPress cho: $DOMAIN${NC}"
echo -e "Thư mục web: $WP_ROOT"
echo -e "Thư mục log: /var/www/$DOMAIN/logs"