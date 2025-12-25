# -----------------------------------------------------------
# MODULE: Cài đặt MariaDB
# File: install_mariadb.sh
# File này được nhúng vào script install_lcmp.sh
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo -e "${GREEN}[1/3] Dang cai dat MariaDB Server...${NC}"

# 1. Thêm Repo MariaDB chính chủ
# Tạo thư mục keyring nếu chưa có
mkdir -p /etc/apt/keyrings

# Tải Key với flag -fsSL (Fail silent, Show error, Follow redirect) để an toàn
# Kiểm tra nếu tải thất bại thì báo lỗi ngay
if ! curl -fsSL 'https://mariadb.org/mariadb_release_signing_key.pgp' -o /etc/apt/keyrings/mariadb-keyring.pgp; then
    echo -e "${RED}Loi: Khong the tai GPG Key cho MariaDB.${NC}"
    exit 1
fi

# File source list
# Tự động detect OS codename (jammy/noble)
. /etc/os-release
echo "deb [signed-by=/etc/apt/keyrings/mariadb-keyring.pgp] https://deb.mariadb.org/${MARIADB_VER}/ubuntu $VERSION_CODENAME main" | tee /etc/apt/sources.list.d/mariadb.list

# Update lại apt sau khi thêm repo
apt-get update

# Cài đặt MariaDB và công cụ Backup
# Thêm mariadb-backup để sau này dễ dàng sao lưu
apt-get install -y mariadb-server mariadb-client mariadb-backup

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

# Chay SQL Hardening
# Lưu ý: Vì mới cài đặt nên root chưa có pass, lệnh mariadb sẽ chạy thẳng qua socket
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
-- Apply thay đổi
FLUSH PRIVILEGES;
EOF

# F2. Kiểm tra trạng thái cuối cùng
if systemctl is-active --quiet mariadb; then
    echo -e "${GREEN}[3/3] MariaDB da cai dat THANH CONG!${NC}"
    mariadb --version | head -n 1
else
    echo -e "${RED}Co loi xay ra trong qua trinh cai dat!${NC}"
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------