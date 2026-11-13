# shellcheck shell=bash
# -----------------------------------------------------------
# MODULE: Cài đặt MariaDB
# File: install_mariadb.sh
# File này được nhúng vào script install_lcmp.sh
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo -e "${GREEN}[1/3] Dang cai dat MariaDB Server...${NC}"

# 1. Thêm Repo MariaDB chính chủ (Có Fallback 3 tầng: Geo-Mirror -> Global Archive CDN -> Ubuntu Official Repo)
mkdir -p /etc/apt/keyrings
. /etc/os-release

MARIADB_KEY_OK=0
# Nguồn Key 1: mariadb.org
if curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 'https://mariadb.org/mariadb_release_signing_key.pgp' -o /etc/apt/keyrings/mariadb-keyring.pgp; then
    MARIADB_KEY_OK=1
# Nguồn Key 2 (Dự phòng): supplychain.mariadb.com
elif curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 'https://supplychain.mariadb.com/mariadb-keyring-2019.gpg' -o /etc/apt/keyrings/mariadb-keyring.pgp; then
    MARIADB_KEY_OK=1
fi

use_mariadb_cdn_repo() {
    echo -e "${YELLOW}Canh bao: Mirror khu vuc (deb.mariadb.org) gap su co. Chuyen sang kho CDN chinh thuc (dlm.mariadb.com)...${NC}"
    echo "deb [signed-by=/etc/apt/keyrings/mariadb-keyring.pgp] https://dlm.mariadb.com/repo/mariadb-server/${MARIADB_VER}/repo/ubuntu $VERSION_CODENAME main" | tee /etc/apt/sources.list.d/mariadb.list > /dev/null
    chmod a+r /etc/apt/sources.list.d/mariadb.list
}

if (( MARIADB_KEY_OK == 1 )); then
    # Tầng 1: Mirror điều hướng theo vị trí địa lý (deb.mariadb.org)
    echo "deb [signed-by=/etc/apt/keyrings/mariadb-keyring.pgp] https://deb.mariadb.org/${MARIADB_VER}/ubuntu $VERSION_CODENAME main" | tee /etc/apt/sources.list.d/mariadb.list > /dev/null
    chmod a+r /etc/apt/keyrings/mariadb-keyring.pgp
    chmod a+r /etc/apt/sources.list.d/mariadb.list
else
    echo -e "${YELLOW}Canh bao: Khong the tai GPG Key MariaDB. Se su dung Repo chinh thuc cua Ubuntu...${NC}"
    rm -f /etc/apt/sources.list.d/mariadb.list
fi

# Update lại apt sau khi thêm repo (Tầng 1 lỗi -> Tầng 2 MariaDB CDN -> Tầng 3 Repo mặc định của Ubuntu)
if ! apt-get update; then
    if (( MARIADB_KEY_OK == 1 )) && use_mariadb_cdn_repo && apt-get update; then
        echo -e "${GREEN}Da ket noi thanh cong kho du phong MariaDB CDN (dlm.mariadb.com).${NC}"
    else
        echo -e "${YELLOW}Canh bao: Kho MariaDB ngoai gap su co. Chuyen sang dung Repo chinh thuc cua Ubuntu...${NC}"
        rm -f /etc/apt/sources.list.d/mariadb.list
        apt-get update
    fi
fi

# Cài đặt MariaDB và công cụ Backup (Có Fallback đa tầng nếu tải gói .deb bị lỗi 404/503)
if ! apt-get install -y -o Acquire::Retries=3 mariadb-server mariadb-client mariadb-backup; then
    echo -e "${YELLOW}Canh bao: Tai goi tu Mirror MariaDB bi loi. Dang thu kho du phong...${NC}"
    if (( MARIADB_KEY_OK == 1 )) && use_mariadb_cdn_repo && apt-get update && apt-get install -y -o Acquire::Retries=3 mariadb-server mariadb-client mariadb-backup; then
        echo -e "${GREEN}Da cai dat thanh cong MariaDB tu kho MariaDB CDN (dlm.mariadb.com).${NC}"
    else
        echo -e "${YELLOW}Chuyen sang cai tu Repo chinh thuc cua Ubuntu...${NC}"
        rm -f /etc/apt/sources.list.d/mariadb.list
        apt-get update
        apt-get install -y -o Acquire::Retries=3 mariadb-server mariadb-client mariadb-backup
    fi
fi
unset MARIADB_KEY_OK

# Khởi động MariaDB
systemctl enable --now mariadb

# Chờ MariaDB khởi động hoàn toàn (Smart wait)
echo "Dang doi MariaDB khoi dong..."
timeout 60s bash -c 'until systemctl is-active --quiet mariadb; do sleep 1; done'
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# F1. BẢO MẬT MARIADB (HARDENING)
echo -e "${GREEN}[2/3] Dang thuc hien bao mat MariaDB (Secure Installation)...${NC}"

# Chạy SQL Hardening
# Lưu ý: Lệnh mariadb sẽ chạy thẳng qua socket
mariadb <<EOF
-- Xóa user rỗng (Anonymous)
DELETE FROM mysql.user WHERE User='';
-- Ép buộc Root login qua Socket (Bảo mật tuyệt đối, không dùng mật khẩu)
ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket;
-- Cấm root login từ xa
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
-- Xóa database test
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
-- Áp dụng các thay đổi
FLUSH PRIVILEGES;
EOF
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# F2. Kiểm tra trạng thái cuối cùng
if systemctl is-active --quiet mariadb; then
    echo -e "${GREEN}[3/3] MariaDB da cai dat THANH CONG!${NC}"
    mariadb --version | head -n 1
else
    echo -e "${RED}Co loi xay ra trong qua trinh cai dat!${NC}"
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------