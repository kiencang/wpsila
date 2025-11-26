#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -e

# Màu sắc cho thông báo
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}[1/6] Đang cập nhật hệ thống...${NC}"
sudo apt update && sudo apt upgrade -y

echo -e "${GREEN}[2/6] Đang cài đặt các gói phụ thuộc...${NC}"
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl

echo -e "${GREEN}[3/6] Đang thêm GPG Key và Repository của Caddy...${NC}"
# Lưu ý: Đã thêm cờ --yes để cho phép ghi đè nếu file đã tồn tại
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null

echo -e "${GREEN}[4/6] Đang thiết lập quyền hạn cho file key và list...${NC}"
# Cần sudo để chmod các file hệ thống này
sudo chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
sudo chmod o+r /etc/apt/sources.list.d/caddy-stable.list

echo -e "${GREEN}[5/6] Đang cập nhật apt và cài đặt Caddy...${NC}"
sudo apt update && sudo apt install caddy -y

echo -e "${GREEN}[6/6] Đang cấu hình tường lửa (UFW)...${NC}"
sudo ufw allow 80
sudo ufw allow 443
sudo ufw reload

echo -e "${GREEN}>>> Cài đặt hoàn tất! Kiểm tra trạng thái Caddy:${NC}"
systemctl status caddy --no-pager