# -----------------------------------------------------------
# MODULE: Cài đặt Caddy Web Server
# File này được nhúng vào script install_lcmp.sh
# -----------------------------------------------------------
echo -e "${GREEN}[1/6] Dang cap nhat he thong...${NC}"
apt update && apt upgrade -y

echo -e "${GREEN}[2/6] Dang cai dat cac goi phu thuoc...${NC}"
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl

echo -e "${GREEN}[3/6] Dang them GPG Key va Repository cua Caddy...${NC}"

# Lưu ý: Đã thêm cờ --yes để cho phép ghi đè nếu file đã tồn tại
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null

echo -e "${GREEN}[4/6] Dang thiet lap quyen han cho file key va list...${NC}"
# Cần sudo để chmod các file hệ thống này
chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
chmod o+r /etc/apt/sources.list.d/caddy-stable.list

echo -e "${GREEN}[5/6] Dang cap nhat apt va cai dat Caddy...${NC}"
apt update && apt install caddy -y

echo -e "${GREEN}[6/6] Dang cau hinh tuong lua (UFW)...${NC}"
# xóa quy tắc cũ
ufw delete allow ssh || true

# bật ssh kèm giới hạn để hạn chế tấn công
ufw limit ssh 

# bật các cổng
ufw allow 80
ufw allow 443

# chính thức áp dụng các quy tắc
ufw --force enable

echo -e "${GREEN}>>> Cai dat hoan tat! Kiem tra trang thai Caddy:${NC}"
systemctl status caddy --no-pager
echo -e "${GREEN}>>> Buoc tiep theo: Cai dat PHP & MariaDB.${NC}"