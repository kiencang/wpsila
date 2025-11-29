#!/bin/bash

# --- CẤU HÌNH ---
PHP_VERSION="8.3"          # Phien ban PHP ban dang dung
REDIS_MAX_MEMORY="256mb"   # 256mb la hop ly cho VPS 1GB. Neu chay nhieu site, nen giam xuong 128mb
REDIS_CONF="/etc/redis/redis.conf"

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# Chạy lệnh
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/install_redis.sh | bash

# Màu sắc
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- BƯỚC 1: KIỂM TRA QUYỀN ROOT ---
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Loi: Ban phai chay script nay bang quyen Root.${NC}"
   exit 1
fi

# --- BƯỚC 2: CÀI ĐẶT REDIS SERVER ---
echo -e "${GREEN}[1/5] Dang cai dat Redis server...${NC}"
apt-get update -qq
# DEBIAN_FRONTEND=noninteractive giup tranh cac cua so hoi config khi cai dat
DEBIAN_FRONTEND=noninteractive apt-get install -y redis-server

# Kich hoat Redis khoi dong cung VPS
systemctl enable redis-server

# --- BƯỚC 3: TỐI ƯU KERNEL (QUAN TRỌNG CHO VPS 1GB RAM) ---
echo -e "${GREEN}[2/5] Toi uu Kernel Linux cho Redis...${NC}"
# Fix loi Redis khong the cap phat bo nho khi RAM day
if ! grep -q "vm.overcommit_memory = 1" /etc/sysctl.conf; then
    echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf
    sysctl vm.overcommit_memory=1
fi

# --- BƯỚC 4: TỐI ƯU CONFIG REDIS ---
echo -e "${GREEN}[3/5] Toi uu Redis config (${REDIS_MAX_MEMORY}, allkeys-lru)...${NC}"
cp "$REDIS_CONF" "${REDIS_CONF}.bak"

# 1. Bind chi localhost (Bao mat)
sed -i "s/^bind .*/bind 127.0.0.1 ::1/" "$REDIS_CONF"

# 2. Cau hinh Maxmemory
# Neu dong maxmemory da ton tai (co the bi comment), uncomment va sua gia tri
if grep -q "^# maxmemory " "$REDIS_CONF"; then
    sed -i "s/^# maxmemory .*/maxmemory ${REDIS_MAX_MEMORY}/" "$REDIS_CONF"
elif grep -q "^maxmemory " "$REDIS_CONF"; then
    sed -i "s/^maxmemory .*/maxmemory ${REDIS_MAX_MEMORY}/" "$REDIS_CONF"
else
    # Neu khong tim thay, them vao cuoi file
    echo "maxmemory ${REDIS_MAX_MEMORY}" >> "$REDIS_CONF"
fi

# 3. Cau hinh Policy (allkeys-lru)
if grep -q "^# maxmemory-policy " "$REDIS_CONF"; then
    sed -i "s/^# maxmemory-policy .*/maxmemory-policy allkeys-lru/" "$REDIS_CONF"
elif grep -q "^maxmemory-policy " "$REDIS_CONF"; then
    sed -i "s/^maxmemory-policy .*/maxmemory-policy allkeys-lru/" "$REDIS_CONF"
else
    echo "maxmemory-policy allkeys-lru" >> "$REDIS_CONF"
fi

# Restart Redis
systemctl restart redis-server

# --- BƯỚC 5: CÀI ĐẶT THƯ VIỆN PHP ---
echo -e "${GREEN}[4/5] Cai thu vien PHP ${PHP_VERSION} Redis...${NC}"

if command -v "php${PHP_VERSION}" >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y "php${PHP_VERSION}-redis"
else
    echo -e "${RED}Loi: Khong tim thay PHP ${PHP_VERSION} tren he thong.${NC}"
    exit 1
fi

# --- BƯỚC 6: RELOAD PHP ---
echo -e "${GREEN}[5/5] Reload lai PHP-FPM...${NC}"
PHP_SERVICE="php${PHP_VERSION}-fpm"

if systemctl list-units --full -all | grep -Fq "$PHP_SERVICE"; then
    systemctl reload "$PHP_SERVICE"
    echo -e "${GREEN}PHP ${PHP_VERSION} FPM reloaded.${NC}"
else
    echo -e "${YELLOW}Canh bao: Khong tim thay service ${PHP_SERVICE}. Hay tu restart PHP cua ban.${NC}"
fi

# --- KẾT THÚC ---
echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN} CAI DAT SERVER HOAN TAT! ${NC}"
echo -e "${GREEN} Da cai dat xong moi truong (Redis Server + PHP Extension).${NC}"
echo -e "${YELLOW}------------------------------------------------------${NC}"
echo -e "${YELLOW} [VIEC BAN CAN LAM TIEP THEO]:${NC}"
echo -e "${YELLOW} 1. Vao WordPress Admin > Plugins > Add New.${NC}"
echo -e "${YELLOW} 2. Tim va cai plugin 'Redis Object Cache'.${NC}"
echo -e "${YELLOW} 3. Active plugin -> Vao Settings -> Enable Object Cache.${NC}"
echo -e "${GREEN}======================================================${NC}"