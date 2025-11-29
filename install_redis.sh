#!/bin/bash

# --- CẤU HÌNH ---
PHP_VERSION="8.3"          # Phien ban PHP ban dang dung
# 128mb cho VPS 1GB. 256mb rat de gay crash MySQL/Redis
REDIS_MAX_MEMORY="128mb"   
REDIS_CONF="/etc/redis/redis.conf"

# Dừng script ngay lập tức nếu có lệnh bị lỗi hoặc biến chưa định nghĩa
set -euo pipefail

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

# Kiem tra OS (Script nay chi danh cho Ubuntu/Debian)
if ! command -v apt-get >/dev/null 2>&1; then
    echo -e "${RED}Loi: Script nay chi ho tro Ubuntu/Debian.${NC}"
    exit 1
fi

# --- BƯỚC 2: CÀI ĐẶT REDIS SERVER ---
echo -e "${GREEN}[1/6] Dang cai dat Redis server...${NC}"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y redis-server

systemctl enable redis-server

# --- BƯỚC 3: TỐI ƯU KERNEL (QUAN TRỌNG) ---
echo -e "${GREEN}[2/6] Toi uu Kernel Linux cho Redis...${NC}"
# vm.overcommit_memory = 1 bat buoc phai co de tranh loi OOM
if ! grep -q "vm.overcommit_memory = 1" /etc/sysctl.conf; then
    echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf
    sysctl vm.overcommit_memory=1
fi

# --- BƯỚC 4: TỐI ƯU CONFIG REDIS ---
echo -e "${GREEN}[3/6] Toi uu Redis config (RAM: ${REDIS_MAX_MEMORY}, No Persistence)...${NC}"
cp "$REDIS_CONF" "${REDIS_CONF}.bak"

# 1. Bind Localhost
sed -i "s/^bind .*/bind 127.0.0.1 ::1/" "$REDIS_CONF"

# 2. Cau hinh Maxmemory (Xu ly gon hon)
# Xoa cac dong maxmemory cu neu co
sed -i '/^maxmemory /d' "$REDIS_CONF"
sed -i '/^# maxmemory /d' "$REDIS_CONF"
# Them dong moi vao cuoi file
echo "maxmemory ${REDIS_MAX_MEMORY}" >> "$REDIS_CONF"

# 3. Cau hinh Policy (allkeys-lru)
sed -i '/^maxmemory-policy /d' "$REDIS_CONF"
sed -i '/^# maxmemory-policy /d' "$REDIS_CONF"
echo "maxmemory-policy allkeys-lru" >> "$REDIS_CONF"

# 4. [QUAN TRONG] Tat tinh nang luu dia (Persistence) de tiet kiem RAM/CPU cho VPS yeu
# Comment tat ca cac dong 'save' mac dinh
sed -i 's/^save /# save /' "$REDIS_CONF"
# Them cau hinh tat save
if ! grep -q '^save ""' "$REDIS_CONF"; then
    echo 'save ""' >> "$REDIS_CONF"
fi

# Restart Redis de ap dung
systemctl restart redis-server

# --- BƯỚC 5: CÀI ĐẶT THƯ VIỆN PHP ---
echo -e "${GREEN}[4/6] Cai thu vien PHP ${PHP_VERSION} Redis...${NC}"

if command -v "php${PHP_VERSION}" >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y "php${PHP_VERSION}-redis"
else
    echo -e "${RED}Loi: Khong tim thay PHP ${PHP_VERSION} tren he thong.${NC}"
    exit 1
fi

# --- BƯỚC 6: RELOAD PHP ---
echo -e "${GREEN}[5/6] Reload lai PHP-FPM...${NC}"
PHP_SERVICE="php${PHP_VERSION}-fpm"

if systemctl is-active --quiet "$PHP_SERVICE"; then
    systemctl reload "$PHP_SERVICE"
    echo -e "${GREEN}PHP ${PHP_VERSION} FPM da duoc reload.${NC}"
elif systemctl is-active --quiet "${PHP_SERVICE}.service"; then
    systemctl reload "${PHP_SERVICE}.service"
    echo -e "${GREEN}PHP ${PHP_VERSION} FPM da duoc reload.${NC}"
else
    echo -e "${YELLOW}Canh bao: Khong tim thay service ${PHP_SERVICE}. Hay tu restart PHP cua ban.${NC}"
fi

# --- BƯỚC 7: KIỂM TRA KẾT QUẢ ---
echo -e "${GREEN}[6/6] Kiem tra ket noi Redis...${NC}"
if redis-cli ping | grep -q "PONG"; then
    echo -e "${GREEN}Redis dang chay TOT (PONG).${NC}"
else
    echo -e "${RED}Canh bao: Redis khong phan hoi. Hay kiem tra lai log.${NC}"
fi

# --- KẾT THÚC ---
echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN} CAI DAT HOAN TAT (OPTIMIZED FOR 1GB RAM) ${NC}"
echo -e "${YELLOW}------------------------------------------------------${NC}"
echo -e "${YELLOW} 1. Vao WordPress Admin > Plugins > Add New.${NC}"
echo -e "${YELLOW} 2. Cai dat 'Redis Object Cache'.${NC}"
echo -e "${YELLOW} 3. Active -> Enable Object Cache.${NC}"
echo -e "${GREEN}======================================================${NC}"