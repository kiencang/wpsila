#!/bin/bash

# -----------------------------------------------------------
# MODULE: Liệt kê danh sách & trạng thái các website trên VPS
# File: list_websites.sh
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
set -euo pipefail
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
echo -e "${GREEN}=== DANH SACH WEBSITE DANG CAI DAT TREN VPS ===${NC}"
echo "-----------------------------------------------------------------------------"
printf "%-4s | %-30s | %-10s | %-12s | %-10s\n" "STT" "Dia chi Website (Domain)" "Dung luong" "wp-config" "Redis"
echo "-----------------------------------------------------------------------------"

COUNT=0

# Quét tất cả thư mục có chứa public_html/wp-config.php
for config_path in /var/www/*/public_html/wp-config.php; do
    # Nếu chưa có website nào thì bỏ qua vòng lặp (tránh lỗi khi glob không khớp)
    [[ -e "$config_path" ]] || continue
    
    COUNT=$((COUNT + 1))
    DOMAIN=$(echo "$config_path" | cut -d'/' -f4)
    WEB_DIR="/var/www/$DOMAIN"
    
    # 1. Tính dung lượng thư mục web (bao gồm cả code và logs)
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
        echo -e "Dia chi quan tri Database (Adminer): ${YELLOW}${ADMINER_DOMAINS}${NC}"
    fi
fi