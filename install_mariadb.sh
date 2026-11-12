# -----------------------------------------------------------
# MODULE: Cài đặt MariaDB
# File: install_mariadb.sh
# File này được nhúng vào script install_lcmp.sh
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo -e "${GREEN}[1/3] Dang cai dat MariaDB Server...${NC}"

# 1. Thêm Repo MariaDB chính chủ
mkdir -p /etc/apt/keyrings

# Nếu tải được GPG Key thì mới thêm Repo MariaDB, nếu mạng lỗi không tải được Key thì bỏ qua để dùng Repo Ubuntu luôn
if curl -fsSL 'https://mariadb.org/mariadb_release_signing_key.pgp' -o /etc/apt/keyrings/mariadb-keyring.pgp; then
    . /etc/os-release
    echo "deb [signed-by=/etc/apt/keyrings/mariadb-keyring.pgp] https://deb.mariadb.org/${MARIADB_VER}/ubuntu $VERSION_CODENAME main" | tee /etc/apt/sources.list.d/mariadb.list

    # Cấp quyền đọc cho user _apt
    chmod a+r /etc/apt/keyrings/mariadb-keyring.pgp
    chmod a+r /etc/apt/sources.list.d/mariadb.list
else
    echo -e "${YELLOW}Canh bao: Khong the tai GPG Key tu mariadb.org. Se su dung Repo chinh thuc cua Ubuntu...${NC}"
fi

# Update lại apt sau khi thêm repo (Nếu mirror deb.mariadb.org lỗi thì fallback về repo mặc định của Ubuntu)
if ! apt-get update; then
    echo -e "${YELLOW}Canh bao: Mirror deb.mariadb.org dang gap su co. Chuyen sang dung Repo chinh thuc cua Ubuntu...${NC}"
    rm -f /etc/apt/sources.list.d/mariadb.list
    apt-get update
fi

# Cài đặt MariaDB và công cụ Backup
# Bọc thêm fallback: Nếu lúc tải gói .deb từ Mirror MariaDB bị lỗi 404 thì tự động chuyển về Repo Ubuntu cài lại
if ! apt-get install -y mariadb-server mariadb-client mariadb-backup; then
    echo -e "${YELLOW}Canh bao: Tai goi tu Mirror MariaDB bi loi. Chuyen sang cai tu Repo chinh thuc cua Ubuntu...${NC}"
    rm -f /etc/apt/sources.list.d/mariadb.list
    apt-get update
    apt-get install -y mariadb-server mariadb-client mariadb-backup
fi

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