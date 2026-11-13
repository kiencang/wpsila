# shellcheck shell=bash
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
    fail2ban \
    python3-systemd \
    ufw

# 2. Thêm GPG Key, Repo Caddy & Cài đặt (Có Fallback 3 tầng: Cloudsmith Repo -> GitHub Release .deb -> Ubuntu Official Repo)
echo -e "${GREEN}[2/5] Them Repo Caddy chinh chu va tien hanh cai dat...${NC}"

# Xóa file cũ nếu tồn tại để tránh lỗi ghi đè hoặc trùng lặp
rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
rm -f /etc/apt/sources.list.d/caddy-stable.list

install_caddy_from_github() {
    echo -e "${YELLOW}Canh bao: Kho Cloudsmith gap su co. Chuyen sang tai goi .deb chinh chu tu GitHub (caddyserver/caddy)...${NC}"
    local arch latest_url latest_tag ver deb_url
    arch=$(dpkg --print-architecture)
    deb_url=""

    # Ưu tiên 1: Lấy tag mới nhất qua HTTP Redirect (Không dùng api.github.com nên không bị giới hạn 60 req/giờ trên IP VPS)
    latest_url=$(curl -fsSLI --retry 3 --connect-timeout 10 -o /dev/null -w '%{url_effective}' "https://github.com/caddyserver/caddy/releases/latest" || true)
    if [[ "$latest_url" == *"/releases/tag/v"* ]]; then
        latest_tag="${latest_url##*/}"
        ver="${latest_tag#v}"
        if [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            deb_url="https://github.com/caddyserver/caddy/releases/download/v${ver}/caddy_${ver}_linux_${arch}.deb"
        fi
    fi

    # Ưu tiên 2 (Dự phòng): Quét qua GitHub API nếu Redirect không trả về tag chuẩn
    if [[ -z "$deb_url" ]]; then
        deb_url=$(curl -fsSL --retry 2 --connect-timeout 10 "https://api.github.com/repos/caddyserver/caddy/releases/latest" | grep -oE "https://github\.com/caddyserver/caddy/releases/download/[^\" ]+_${arch}\.deb" | head -n 1 || true)
    fi

    if [[ -n "$deb_url" ]] && curl -fsSL --retry 3 --retry-delay 2 "$deb_url" -o /tmp/caddy_latest.deb; then
        # Dùng apt-get install trực tiếp file .deb và kiểm tra binary caddy để tránh bẫy exit code giả
        if apt-get install -y /tmp/caddy_latest.deb && command -v caddy &>/dev/null; then
            rm -f /tmp/caddy_latest.deb
            return 0
        fi
    fi
    rm -f /tmp/caddy_latest.deb
    return 1
}

CADDY_INSTALLED=0

# Tầng 1: Kho chính thức Cloudsmith của Caddy
if curl -1sLf --retry 3 --retry-delay 2 --connect-timeout 10 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg && \
   curl -1sLf --retry 3 --retry-delay 2 --connect-timeout 10 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null; then
    chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    chmod o+r /etc/apt/sources.list.d/caddy-stable.list
    echo -e "${GREEN}[3/5] Tien hanh cai dat Caddy...${NC}"
    if apt-get update && apt-get install -y -o Acquire::Retries=3 caddy; then
        CADDY_INSTALLED=1
    fi
fi

# Tầng 2: Nếu Cloudsmith lỗi, tải gói .deb chính thức từ GitHub Releases của Caddy
if (( CADDY_INSTALLED == 0 )); then
    rm -f /etc/apt/sources.list.d/caddy-stable.list /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    apt-get update -qq || true
    if install_caddy_from_github; then
        CADDY_INSTALLED=1
        echo -e "${GREEN}Da cai dat thanh cong Caddy tu GitHub Releases.${NC}"
    fi
fi

# Tầng 3: Nếu cả Cloudsmith và GitHub đều lỗi, fallback về kho chính thức của Ubuntu
if (( CADDY_INSTALLED == 0 )); then
    echo -e "${YELLOW}Chuyen sang cai dat Caddy tu Repo chinh thuc cua Ubuntu...${NC}"
    apt-get update
    apt-get install -y -o Acquire::Retries=3 caddy
fi
unset CADDY_INSTALLED

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
    echo -e "${YELLOW}>>> Ban can cai moi lai VPS (reinstall) & thu cai lai wpsila.${NC}"
	exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# [NEW] CẤU HÌNH KIẾN TRÚC MODULAR (SITES-ENABLED)
echo -e "${GREEN}[INFO] Dang thiet lap kien truc Modular cho Caddy...${NC}"

# B1. Tạo thư mục chứa file cấu hình riêng cho từng web và thư mục snippets dùng chung
# sites-enabled: Nơi chứa file .caddy của từng domain
# snippets: Nơi chứa wp_common.conf dùng chung cho mọi website WordPress
mkdir -p /etc/caddy/sites-enabled
mkdir -p /etc/caddy/snippets

cat > /etc/caddy/snippets/wp_common.conf <<'EOF'
# ==============================================================================
# WPSILA SHARED WORDPRESS CADDY SNIPPET (/etc/caddy/snippets/wp_common.conf)
# Chỉnh sửa tại file này sẽ tự động áp dụng cho toàn bộ website trên VPS
# ==============================================================================

encode zstd gzip

# Tăng giới hạn upload (đồng bộ với post_max_size=105M và upload_max_filesize=100M trong php.ini)
request_body {
    max_size 105MB
}

# --- SECURITY HEADERS ---
# Sau khi HTTPS đã chạy ổn định, có thể bỏ comment dòng Strict-Transport-Security
header {
    X-Content-Type-Options "nosniff"
    X-Frame-Options "SAMEORIGIN"
    X-XSS-Protection "0"
    Referrer-Policy "strict-origin-when-cross-origin"
    Permissions-Policy "camera=(), microphone=(), geolocation=(), browsing-topics=()"
    # Strict-Transport-Security "max-age=31536000; includeSubDomains"
    -Server
    -X-Powered-By
}

# --- CACHE CODE (CSS/JS) ---
# Không dùng immutable để tránh lỗi khi update code
@code_assets {
    file
    path *.css *.js
}
header @code_assets Cache-Control "public, max-age=604800"

# --- CACHE MEDIA (ẢNH/FONT/VIDEO) ---
# Dùng immutable vì file ảnh/font ít khi sửa nội dung mà giữ nguyên tên
@media_assets {
    file
    path *.ico *.gif *.jpg *.jpeg *.png *.svg *.woff *.woff2 *.ttf *.otf *.eot *.webp *.avif *.mp4 *.webm
}
header @media_assets Cache-Control "public, max-age=31536000, immutable"

# --- TRAFFIC CONTROL (RATE LIMIT LITE) ---
# 1. Chặn các Bot đốt tài nguyên & Crawler vô dụng (Bảo vệ CPU/RAM cho VPS 1-2GB)
# Ngăn chặn hàng loạt request từ các bot SEO/Scraper không cần thiết (vẫn giữ Google, Bing, Facebook, Zalo...)
@bad_bots {
    header User-Agent *MJ12bot*
    header User-Agent *PetalBot*
    header User-Agent *DotBot*
    header User-Agent *SemrushBot*
    header User-Agent *AhrefsBot*
    header User-Agent *BLEXBot*
    header User-Agent *Barkrowler*
    header User-Agent *Bytespider*
    header User-Agent *DataForSeoBot*
    header User-Agent *Maubot*
    header User-Agent *LieBaoFast*
    header User-Agent *Mb2345Browser*
}
respond @bad_bots 403

# 2. Chặn Scan User ngoài trang chủ (/?author=1), nhưng không chặn trong /wp-admin/*
@user_enum {
    not path /wp-admin/*
    query author=*
}
respond @user_enum 403

# 3. Chặn dò tìm danh sách User qua REST API (/wp-json/wp/v2/users & /?rest_route=/wp/v2/users) đối với khách chưa đăng nhập
# Vẫn cho phép Admin đã đăng nhập (có cookie wordpress_logged_in_) sử dụng Gutenberg Editor bình thường
@rest_user_enum_path {
    path /wp-json/wp/v2/users*
    not header_regexp Cookie wordpress_logged_in_
}
respond @rest_user_enum_path 403

@rest_user_enum_query {
    vars_regexp rest_enum {http.request.uri.query} (^|&)rest_route=(/|%2[fF])wp(/|%2[fF])v2(/|%2[fF])users
    not header_regexp Cookie wordpress_logged_in_
}
respond @rest_user_enum_query 403

# --- CHẶN THỰC THI PHP TRONG THƯ MỤC UPLOADS (MỌI CẤP THƯ MỤC CON & CHỐNG BYPASS PATH_INFO) ---
@uploads_php {
    path_regexp (?i)^/wp-content/uploads/.*\.(php[0-9]?|phtml|phar|inc)(/|$)
}
respond @uploads_php 404

# --- CHẶN TRUY CẬP FILE ẨN (.git, .env, .htaccess...) Ở MỌI THƯ MỤC CON (TRỪ /.well-known/* CHO SSL) ---
@hidden_files {
    not path /.well-known/*
    path */.*
}
respond @hidden_files 404

# --- CHẶN FILE HỆ THỐNG NHẠY CẢM (SECURITY BLOCK) ---
@forbidden {
    # 1. Block System Files
    path /wp-config.php*
    path /readme.html
    path /license.txt

    # 2. Block xmlrpc & public wp-cron (wpsila đã chạy wp-cron qua System Cron CLI)
    path /xmlrpc.php
    path /wp-cron.php

    # 3. Block Backups & Logs
    path *.sql *.bak *.log *.old *.swp
}
respond @forbidden 404
EOF

# B2. Backup file Caddyfile mặc định của nhà phát hành (nếu chưa backup)
if [[ -f /etc/caddy/Caddyfile && ! -f /etc/caddy/Caddyfile.orig ]]; then
    mv /etc/caddy/Caddyfile /etc/caddy/Caddyfile.orig
    echo "Da backup Caddyfile goc thanh Caddyfile.orig"
fi

# B3. Tạo Caddyfile gốc mới (Master Config)
# File này chỉ làm nhiệm vụ import các file con
# Lấy email của người cài để dùng lấy chứng chỉ https
# Dựa trên https://www.cloudflare.com/ips-v4 & https://www.cloudflare.com/ips-v6 để lấy nguồn IP proxy
CADDY_VER=$(caddy version 2>/dev/null | awk '{print $1}' | sed 's/^v//' || true)
cat > /etc/caddy/Caddyfile <<EOF
{
    # Global Options
    # Tu dong quan ly SSL qua Email nay
    email $ADMIN_EMAIL
EOF

if [[ -n "$CADDY_VER" ]] && dpkg --compare-versions "$CADDY_VER" ge "2.7"; then
cat >> /etc/caddy/Caddyfile <<'EOPROXY'

	# Cấu hình Trusted Proxies cho Cloudflare (chi ho tro tu Caddy v2.7+)
	servers {
		trusted_proxies static private_ranges 173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 104.24.0.0/14 172.64.0.0/13 131.0.72.0/22 2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32 2405:8100::/32 2a06:98c0::/29 2c0f:f248::/32
	}
EOPROXY
fi

cat >> /etc/caddy/Caddyfile <<'EOF'
}

# [QUAN TRONG] Import tat ca file cau hinh trong thu muc sites-enabled
import /etc/caddy/sites-enabled/*.caddy
EOF
unset CADDY_VER

# Format lại file cho đẹp chuẩn Caddy
caddy fmt --overwrite /etc/caddy/Caddyfile || true

# B4. Reload để áp dụng kiến trúc mới
if caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile; then
    systemctl reload caddy
else
    echo -e "${RED}[LOI] File /etc/caddy/Caddyfile khong hop le!${NC}"
    exit 1
fi
echo -e "${GREEN}>>> Kien truc Caddy Modular da san sang.${NC}"
echo -e "${GREEN}>>> Module Caddy hoan tat.${NC}"
# -------------------------------------------------------------------------------------------------------------------------------