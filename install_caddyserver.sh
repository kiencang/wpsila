# -----------------------------------------------------------
# MODULE: Cài đặt Caddy Web Server
# File: install_caddyserver.sh
# File này được nhúng vào script install_lcmp.sh
# Yêu cầu: biến $ADMIN_EMAIL phải được export từ script cha
# Tuân thủ hướng dẫn: https://caddyserver.com/docs/install
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo "--------------------------------------------------------"
echo -e "${GREEN}[MODULE] Bat dau cai dat Caddy Web Server...${NC}"

# [SAFETY CHECK] Kiểm tra biến môi trường bắt buộc
# ${ADMIN_EMAIL:-} giúp tránh lỗi "unbound variable" nếu set -u đang bật
if [[ -z "${ADMIN_EMAIL:-}" ]]; then
    echo -e "${RED}[LOI] Khong tim thay bien ADMIN_EMAIL.${NC}"
    echo -e "${YELLOW}Vui long chay script tu file install_lcmp.sh${NC}"
    exit 1
fi

# 1. Cài đặt các gói phụ trợ cần thiết
# debian-keyring, debian-archive-keyring: Đảm bảo apt nhận diện đúng signature
echo -e "${GREEN}[1/5] Cai dat dependencies (cac goi phu thuoc)...${NC}"
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
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- TỰ ĐỘNG PHÁT HIỆN CỔNG SSH ---
echo -e "${GREEN}[INFO] Dang phat hien SSH Port...${NC}"

# B1: Thử dùng sshd -T (chính xác nhất)
# grep tìm dòng "port", head lấy dòng đầu, awk lấy cột 2, || true chống lỗi
DETECTED_PORT=$(sshd -T 2>/dev/null | grep "^port " | head -n 1 | awk '{print $2}' || true)

# B2: Nếu B1 thất bại (rỗng), fallback sang grep file config
if [[ -z "$DETECTED_PORT" ]]; then
    DETECTED_PORT=$(grep -i "^[[:space:]]*Port" /etc/ssh/sshd_config | head -n 1 | awk '{print $2}' || true)
fi

# B3: Nếu cả hai thất bại, mặc định là 22
SSH_PORT=${DETECTED_PORT:-22}

echo -e "${YELLOW}Phat hien SSH Port dang chay: ${SSH_PORT}${NC}"
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
    echo -e "${YELLOW}>>> Ban can cai moi lai VPS & thu cai lai wpsila.${NC}"
	exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# [NEW] CẤU HÌNH KIẾN TRÚC MODULAR (SITES-ENABLED)
echo -e "${GREEN}[INFO] Dang thiet lap kien truc Modular cho Caddy...${NC}"

# B1. Tạo thư mục chứa file cấu hình riêng cho từng web
# sites-enabled: Nơi chứa file .caddy của từng domain
mkdir -p /etc/caddy/sites-enabled

# B2. Backup file Caddyfile mặc định của nhà phát hành (nếu chưa backup)
if [[ ! -f /etc/caddy/Caddyfile.orig ]]; then
    mv /etc/caddy/Caddyfile /etc/caddy/Caddyfile.orig
    echo "Da backup Caddyfile goc thanh Caddyfile.orig"
fi

# B3. Tạo Caddyfile gốc mới (Master Config)
# File này chỉ làm nhiệm vụ import các file con
cat > /etc/caddy/Caddyfile <<EOF
{
    # Global Options
    # Tu dong quan ly SSL qua Email nay
    email $ADMIN_EMAIL
}

# [QUAN TRONG] Import tat ca file cau hinh trong thu muc sites-enabled
import /etc/caddy/sites-enabled/*.caddy
EOF

# Format lại file cho đẹp chuẩn Caddy
caddy fmt --overwrite /etc/caddy/Caddyfile

# B4. Reload để áp dụng kiến trúc mới
systemctl reload caddy
echo -e "${GREEN}>>> Kien truc Caddy Modular da san sang.${NC}"

echo -e "${GREEN}>>> Module Caddy hoan tat.${NC}"
# -------------------------------------------------------------------------------------------------------------------------------