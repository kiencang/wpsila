#!/bin/bash

# Script kiểm tra chất lượng cài đặt WPSILA
# Chạy với quyền root sau khi cài xong
set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== BAT DAU KIEM TRA HE THONG WPSILA ==="
ERRORS=0

# Hàm assert
check() {
    if eval "$1"; then
        echo -e "${GREEN}[PASS] $2${NC}"
    else
        echo -e "${RED}[FAIL] $2${NC}"
        ERRORS=$((ERRORS+1))
    fi
}

# 1. Kiem tra Service
echo "--- 1. Checking Services ---"
check "systemctl is-active --quiet caddy" "Caddy Server is running"
check "systemctl is-active --quiet mariadb" "MariaDB is running"
# Tìm service PHP (tự động theo version)
PHP_SVC=$(ls /lib/systemd/system/php*-fpm.service | head -n 1 | xargs basename)
check "systemctl is-active --quiet $PHP_SVC" "PHP-FPM ($PHP_SVC) is running"

# 2. Kiem tra Port
echo "--- 2. Checking Ports ---"
check "ss -tuln | grep -q ':80 '" "Port 80 is OPEN"
check "ss -tuln | grep -q ':443 '" "Port 443 is OPEN"

# 3. Kiem tra Security & Config
echo "--- 3. Checking Configuration ---"
check "[ -d /etc/caddy/sites-enabled ]" "Thu muc Caddy Modular (sites-enabled) ton tai"
check "grep -q 'import /etc/caddy/sites-enabled' /etc/caddy/Caddyfile" "Caddyfile goc da co lenh import"
check "[ -f /etc/mysql/mariadb.conf.d/99-wpsila-db-tune.cnf ]" "File Tune MariaDB ton tai"
check "ls /etc/php/*/fpm/pool.d/99-wpsila-pool-tune.conf >/dev/null 2>&1" "File Tune PHP Pool ton tai"

# 4. Kiem tra User & Permission
echo "--- 4. Checking Security ---"
check "id caddy >/dev/null 2>&1" "User 'caddy' ton tai"
check "! sudo -u caddy touch /root/test_security 2>/dev/null" "User 'caddy' KHONG co quyen ghi vao /root"

# 5. Kiem tra mot website mau (Neu ban da cai 1 web ten example.com)
# Thay 'example.com' bang domain ban da test
TEST_DOMAIN="example.com"
if [ -d "/var/www/$TEST_DOMAIN" ]; then
    echo "--- 5. Checking Website: $TEST_DOMAIN ---"
    check "[ -f /etc/caddy/sites-enabled/${TEST_DOMAIN}.caddy ]" "File config Modular cho domain ton tai"
    check "[ -f /var/www/$TEST_DOMAIN/public_html/wp-config.php ]" "WordPress core da duoc cai dat"
    
    # Kiểm tra HTTP Code trả về có phải 200 hoặc 301/302 không
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $TEST_DOMAIN" http://127.0.0.1)
    if [[ "$HTTP_CODE" =~ ^(200|301|302|308)$ ]]; then
         echo -e "${GREEN}[PASS] Website tra ve HTTP Code hop le: $HTTP_CODE${NC}"
    else
         echo -e "${RED}[FAIL] Website tra ve loi: $HTTP_CODE${NC}"
         ERRORS=$((ERRORS+1))
    fi
fi

echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}KET QUA: HE THONG HOAT DONG TOT (100% PASS)${NC}"
    exit 0
else
    echo -e "${RED}KET QUA: PHAT HIEN $ERRORS LOI.${NC}"
    exit 1
fi