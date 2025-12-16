# -----------------------------------------------------------
# MODULE: Cài đặt Caddy Web Server
# File: install_caddyserver.sh
# File này được nhúng vào script install_lcmp.sh
# Tuân thủ hướng dẫn: https://caddyserver.com/docs/install
# -----------------------------------------------------------

echo "--------------------------------------------------------"
echo -e "${GREEN}[MODULE] Bat dau cai dat Caddy Web Server...${NC}"

# 1. Cài đặt các gói phụ trợ cần thiết
# debian-keyring, debian-archive-keyring: Đảm bảo apt nhận diện đúng signature
echo -e "${GREEN}[1/5] Cai dat dependencies...${NC}"
apt-get install -y --no-install-recommends \
    debian-keyring \
    debian-archive-keyring \
    apt-transport-https \
    curl \
    gnupg \
    ufw

# 2. Thêm GPG Key và Repo Caddy
echo -e "${GREEN}[2/5] Them Repo Caddy chinh chu...${NC}"

# Xóa file cũ nếu tồn tại để tránh lỗi ghi đè hoặc trùng lặp
rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
rm -f /etc/apt/sources.list.d/caddy-stable.list

# Tải key và add repo
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null

# Quan trọng: Cấp quyền đọc cho user '_apt'
chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
chmod o+r /etc/apt/sources.list.d/caddy-stable.list

# 3. Cài đặt Caddy
echo -e "${GREEN}[3/5] Tien hanh cai dat Caddy...${NC}"
apt-get update
apt-get install caddy -y

# Đảm bảo Caddy tự khởi động cùng hệ thống
systemctl enable caddy
systemctl start caddy

# 4. Cấu hình Firewall (UFW) - AN TOÀN CAO
echo -e "${GREEN}[4/5] Cau hinh bao mat UFW...${NC}"

# Reset UFW (Cẩn thận: Chỉ nên dùng khi cài mới)
ufw --force reset > /dev/null
ufw default deny incoming
ufw default allow outgoing

# --- PHÁT HIỆN SSH PORT CHÍNH XÁC (FIXED) ---
# Sử dụng sshd -T để lấy cấu hình Effective (bao gồm cả file include)
# Nếu lệnh sshd lỗi, fallback về mặc định 22
# Ưu tiên 1: Hỏi trực tiếp tiến trình SSH (Chính xác 100%)
DETECTED_PORT=$(sshd -T 2>/dev/null | grep "^port " | awk '{print $2}' | head -n 1 || true)

# Ưu tiên 2: Nếu lệnh trên rỗng (hiếm gặp), mới dùng cách grep file (Backup)
if [[ -z "$DETECTED_PORT" ]]; then
    DETECTED_PORT=$(grep -i "^[[:space:]]*Port" /etc/ssh/sshd_config | head -n 1 | awk '{print $2}' || true)
fi

# Nếu cả 2 đều rỗng -> Mặc định 22
SSH_PORT=${DETECTED_PORT:-22}

echo -e "${YELLOW}   -> Phat hien SSH Port thuc te: ${SSH_PORT}${NC}"

# Mở port SSH (Limit để chống brute-force cơ bản)
ufw limit "$SSH_PORT"/tcp comment 'SSH Port'

# Mở Web Ports
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw allow 443/udp comment 'HTTPS QUIC' # Rất quan trọng cho tốc độ Caddy

# Kích hoạt UFW
# Dùng --force để không hỏi confirmation (Y/n) làm ngắt script
echo "y" | ufw enable > /dev/null

# 5. Kiểm tra trạng thái
echo -e "${GREEN}[5/5] Kiem tra trang thai dich vu...${NC}"

if systemctl is-active --quiet caddy; then
    echo -e "${GREEN}>>> Caddy dang chay (Active).${NC}"
else
    echo -e "${RED}>>> LOI: Caddy khong hoat dong!${NC}"
    # Không exit 1 ở đây để script tổng quyết định, hoặc có thể exit luôn tùy bạn
fi

echo -e "${GREEN}>>> Module Caddy hoan tat.${NC}"
echo "--------------------------------------------------------"
sleep 2