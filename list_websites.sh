#!/bin/bash

# -----------------------------------------------------------
# MODULE: Tổng quan Hệ thống (VPS) & Danh sách Website
# File: list_websites.sh (Mục 19 trên Menu)
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
set -euo pipefail
export LC_ALL=C.UTF-8
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   sudo -E "$0" "$@"
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Nạp cấu hình từ wpsila.conf (để lấy nhánh PHP_VER hiện tại)
SCRIPT_WPSILA_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
WPSILA_CONFIG_FILE="$SCRIPT_WPSILA_DIR/wpsila.conf"

if [[ -f "$WPSILA_CONFIG_FILE" ]]; then
    source "$WPSILA_CONFIG_FILE"
fi
PHP_VER="${PHP_VER:-8.3}"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Các hàm phụ trợ kiểm tra phiên bản từ APT
NEED_PATCH_UPDATE=0

# Làm gọn chuỗi phiên bản (Ví dụ: 1:10.11.19+maria~ubu2404 -> 10.11.19)
clean_ver() {
    echo "$1" | sed -E 's/^[0-9]+://; s/[-+~].*$//'
}

# Kiểm tra phiên bản đang cài vs phiên bản mới nhất trong kho APT cache
# Tham số $1: Tên gói (VD: php8.3-fpm, mariadb-server, caddy, redis-server)
# Tham số $2: Có đánh dấu gợi ý cập nhật tự động không (1 = có, 0 = không)
get_pkg_version_info() {
    local pkg_name="$1"
    local track_update="${2:-0}"
    local policy_out installed_raw candidate_raw installed_clean candidate_clean

    policy_out=$(apt-cache policy "$pkg_name" 2>/dev/null || true)
    installed_raw=$(echo "$policy_out" | awk '/Installed:/ {print $2}' || true)
    candidate_raw=$(echo "$policy_out" | awk '/Candidate:/ {print $2}' || true)

    if [[ -z "$installed_raw" || "$installed_raw" == "(none)" ]]; then
        echo -e "${YELLOW}Chua cai dat${NC}"
        return
    fi

    installed_clean=$(clean_ver "$installed_raw")
    candidate_clean=$(clean_ver "$candidate_raw")

    if [[ -n "$candidate_raw" && "$candidate_raw" != "(none)" && "$installed_raw" != "$candidate_raw" ]]; then
        if (( track_update == 1 )); then
            NEED_PATCH_UPDATE=1
        fi
        printf "%-10s | ${YELLOW}(Co ban moi: %s!)${NC}" "$installed_clean" "$candidate_clean"
    else
        printf "%-10s | ${GREEN}(Da la ban moi nhat)${NC}" "$installed_clean"
    fi
}

# Kiểm tra trạng thái chạy của systemd service
get_svc_status() {
    local svc_name="$1"
    if systemctl is-active --quiet "$svc_name" 2>/dev/null; then
        echo -e "${GREEN}[Dang chay]${NC}"
    else
        echo -e "${RED}[Dang dung]${NC}"
    fi
}
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# PHẦN 1: THU THẬP & HIỂN THỊ THÔNG TIN MÁY CHỦ (VPS STATUS)
OS_NAME="Ubuntu"
if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    OS_NAME="${PRETTY_NAME:-Ubuntu}"
fi
UPTIME_STR=$(uptime -p 2>/dev/null | sed 's/^up //' || echo "N/A")

# Tính RAM & Swap
RAM_TOTAL=$(free -m | awk '/^Mem:/ {print $2}')
RAM_USED=$(free -m | awk '/^Mem:/ {print $3}')
RAM_PERCENT=$(( RAM_USED * 100 / (RAM_TOTAL > 0 ? RAM_TOTAL : 1) ))

SWAP_TOTAL=$(free -m | awk '/^Swap:/ {print $2}')
SWAP_USED=$(free -m | awk '/^Swap:/ {print $3}')
if (( SWAP_TOTAL > 0 )); then
    SWAP_STR="${SWAP_USED}MB / ${SWAP_TOTAL}MB"
else
    SWAP_STR="Chua tao (0MB)"
fi

# Tính Ổ cứng (/)
DISK_STR=$(df -h / | awk 'NR==2 {printf "%s / %s (%s)", $3, $2, $5}')

# Kiểm tra UFW & Fail2Ban
if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
    UFW_STR="${GREEN}Dang bat${NC}"
else
    UFW_STR="${RED}Dang tat${NC}"
fi

if systemctl is-active --quiet fail2ban 2>/dev/null; then
    BANNED_IPS=$(fail2ban-client status sshd 2>/dev/null | awk -F: '/Currently banned/ {gsub(/^[ \t]+/, "", $2); print $2}' || echo "0")
    F2B_STR="${GREEN}Dang bat${NC} (Dang khoa: ${YELLOW}${BANNED_IPS:-0}${NC} IP)"
else
    F2B_STR="${RED}Dang tat${NC}"
fi

echo -e "${BLUE}=============================================================================${NC}"
echo -e "${GREEN}                 TONG QUAN HE THONG & WEBSITE (WPSILA)                 ${NC}"
echo -e "${BLUE}=============================================================================${NC}"
echo -e "${YELLOW}[1] THONG TIN MAY CHU (VPS STATUS)${NC}"
echo -e "  - He dieu hanh : ${GREEN}${OS_NAME}${NC} (Uptime: ${UPTIME_STR})"
echo -e "  - Bo nho RAM   : ${YELLOW}${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PERCENT}%)${NC} | Swap: ${YELLOW}${SWAP_STR}${NC}"
echo -e "  - O cung (/)   : ${YELLOW}${DISK_STR}${NC}"
echo -e "  - Bao mat VPS  : UFW: ${UFW_STR} | Fail2Ban SSH: ${F2B_STR}"
echo "-----------------------------------------------------------------------------"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# PHẦN 2: HIỂN THỊ PHIÊN BẢN PHẦN MỀM LÕI (CORE STACK)
echo -e "${YELLOW}[2] PHIEN BAN PHAN MEM LOI (CORE STACK)${NC}"

# 1. Caddy
if command -v caddy &>/dev/null; then
    CADDY_SVC=$(get_svc_status "caddy")
    CADDY_VER_INFO=$(get_pkg_version_info "caddy" 0)
    echo -e "  - Caddy Server : ${CADDY_SVC} | Phien ban: ${CADDY_VER_INFO}"
else
    echo -e "  - Caddy Server : ${RED}[Chua cai dat]${NC}"
fi

# 2. PHP-FPM
if command -v php &>/dev/null; then
    PHP_SVC=$(get_svc_status "php${PHP_VER}-fpm")
    PHP_VER_INFO=$(get_pkg_version_info "php${PHP_VER}-fpm" 1)
    echo -e "  - PHP-FPM ($PHP_VER): ${PHP_SVC} | Phien ban: ${PHP_VER_INFO}"
else
    echo -e "  - PHP-FPM ($PHP_VER): ${RED}[Chua cai dat]${NC}"
fi

# 3. MariaDB
if command -v mariadb &>/dev/null; then
    MDB_SVC=$(get_svc_status "mariadb")
    MDB_VER_INFO=$(get_pkg_version_info "mariadb-server" 1)
    echo -e "  - MariaDB      : ${MDB_SVC} | Phien ban: ${MDB_VER_INFO}"
else
    echo -e "  - MariaDB      : ${RED}[Chua cai dat]${NC}"
fi

# 4. Redis Server
if command -v redis-server &>/dev/null; then
    REDIS_SVC=$(get_svc_status "redis-server")
    REDIS_VER_INFO=$(get_pkg_version_info "redis-server" 0)
    echo -e "  - Redis Server : ${REDIS_SVC} | Phien ban: ${REDIS_VER_INFO}"
else
    echo -e "  - Redis Server : ${YELLOW}[Chua cai dat]${NC} (Chi can cho web traffic cao - Muc 16)"
fi

# 5. WP-CLI
if command -v wp &>/dev/null; then
    WPCLI_VER=$(wp cli version --allow-root 2>/dev/null | awk '{print $2}' || echo "N/A")
    echo -e "  - WP-CLI       : ${GREEN}[San sang] ${NC} | Phien ban: ${WPCLI_VER}"
else
    echo -e "  - WP-CLI       : ${YELLOW}[Chua cai dat]${NC} (Se tu dong cai khi tao web dau tien)"
fi
echo "-----------------------------------------------------------------------------"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# PHẦN 3: DANH SÁCH WEBSITE WORDPRESS TRÊN VPS
echo -e "${YELLOW}[3] DANH SACH WEBSITE WORDPRESS TREN VPS${NC}"
echo "-----------------------------------------------------------------------------"
printf "%-4s | %-30s | %-10s | %-12s | %-10s\n" "STT" "Dia chi Website (Domain)" "Dung luong" "wp-config" "Redis"
echo "-----------------------------------------------------------------------------"

COUNT=0

for config_path in /var/www/*/public_html/wp-config.php; do
    [[ -e "$config_path" ]] || continue
    
    COUNT=$((COUNT + 1))
    DOMAIN=$(echo "$config_path" | cut -d'/' -f4)
    WEB_DIR="/var/www/$DOMAIN"
    
    # 1. Tính dung lượng thư mục web
    SIZE=$(du -sh "$WEB_DIR" 2>/dev/null | awk '{print $1}' || echo "N/A")
    
    # 2. Kiểm tra trạng thái khóa wp-config.php
    PERM=$(stat -c '%a' "$config_path" 2>/dev/null || echo "---")
    if [[ "$PERM" == "640" || "$PERM" == "440" ]]; then
        LOCK_STATUS="Khoa ($PERM)"
    else
        LOCK_STATUS="Mo ($PERM)"
    fi
    
    # 3. Kiểm tra xem web có đang bật Redis Object Cache không
    if [[ -f "$WEB_DIR/public_html/wp-content/object-cache.php" ]]; then
        REDIS_STATUS="Dang bat"
    else
        REDIS_STATUS="Tat"
    fi

    printf "%-4s | %-30s | %-10s | %-12s | %-10s\n" "$COUNT" "$DOMAIN" "$SIZE" "$LOCK_STATUS" "$REDIS_STATUS"
done

if (( COUNT == 0 )); then
    echo -e "${YELLOW}Chua co website WordPress nao duoc cai dat tren VPS nay.${NC}"
fi

echo "-----------------------------------------------------------------------------"
echo -e "Tong so website WordPress: ${GREEN}${COUNT}${NC}"

# Kiểm tra thêm xem có cài đặt trang quản trị Database (Adminer) không
if [[ -d "/var/www/adminer" ]] && [[ -d "/etc/caddy/sites-enabled" ]]; then
    ADMINER_DOMAINS=$(grep -l "/var/www/adminer" /etc/caddy/sites-enabled/*.caddy 2>/dev/null | xargs -r -n1 basename | sed 's/\.caddy$//' || true)
    if [[ -n "$ADMINER_DOMAINS" ]]; then
        echo -e "Dia chi quan tri Database (Adminer): ${YELLOW}https://${ADMINER_DOMAINS}${NC}"
    fi
fi
echo -e "${BLUE}=============================================================================${NC}"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# PHẦN 4: HỖ TRỢ CẬP NHẬT BẢN VÁ TẠI CHỖ NẾU PHÁT HIỆN BẢN MỚI
if (( NEED_PATCH_UPDATE == 1 )); then
    echo ""
    echo -e "${YELLOW}[!] PHAT HIEN CO BAN VA BAO MAT MOI CHO PHP HOAC MARIADB!${NC}"
    read -r -p "Ban co muon cap nhat an toan (Zero-Downtime) ngay bay gio khong? [y/N]: " DO_PATCH < /dev/tty
    if [[ "$DO_PATCH" =~ ^[yY](es)?$ ]]; then
        echo -e "${GREEN}>>> Dang tien hanh cap nhat ban va cho PHP ${PHP_VER} va MariaDB...${NC}"
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install --only-upgrade -y "php${PHP_VER}-*" "mariadb-*"
        echo -e "${GREEN}>>> Cap nhat hoan tat! Phien ban moi da duoc ap dung.${NC}"
    else
        echo -e "${YELLOW}Da bo qua cap nhat. Ban co the quay lai muc 19 de cap nhat bat cu luc nao.${NC}"
    fi
fi