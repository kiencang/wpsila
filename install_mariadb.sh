# -----------------------------------------------------------
# MODULE: Cài đặt MariaDB
# File: install_mariadb.sh
# File này được nhúng vào script install_lcmp.sh
# -----------------------------------------------------------
echo -e "${GREEN}[1/3] Dang cai dat MariaDB Server...${NC}"

# 1. (Optional) Thêm Repo MariaDB chính chủ để lấy bản ổn định nhất
# Khuyến nghị nên dùng bước này cho Ubuntu 22.04 để nó dùng bản mới hơn.
mkdir -p /etc/apt/keyrings
curl -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'

# File source list (Tự động detect OS codename: jammy (22.04) or noble (24.04))
# Sử dụng MariaDB 10.11 (Bản LTS rất ổn định cho WordPress hiện tại)
. /etc/os-release
echo "deb [signed-by=/etc/apt/keyrings/mariadb-keyring.pgp] https://deb.mariadb.org/10.11/ubuntu $VERSION_CODENAME main" | tee /etc/apt/sources.list.d/mariadb.list
apt-get update

# Cài đặt MariaDB
apt-get install -y mariadb-server mariadb-client

# Khởi động MariaDB
systemctl enable --now mariadb

# Chờ MariaDB khởi động hoàn toàn (Smart wait thay vì sleep cứng)
echo "Dang doi MariaDB khoi dong..."
timeout 60s bash -c 'until systemctl is-active --quiet mariadb; do sleep 1; done'

# F1. BẢO MẬT MARIADB (HARDENING)
echo -e "${GREEN}[2/3] Dang thuc hien bao mat MariaDB (Secure Installation)...${NC}"

# Chay SQL Hardening
mariadb <<EOF
DELETE FROM mysql.user WHERE User='';
ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket;
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# Câu lệnh dùng để kiểm tra xem database đã được bảo mật đúng cách chưa
# sudo mariadb -e "SELECT User, Host, Plugin FROM mysql.user; SHOW DATABASES LIKE 'test';"

# F2. Kiểm tra trạng thái cuối cùng
if systemctl is-active --quiet mariadb; then
    echo -e "${GREEN}[3/3] MariaDB da cai dat THANH CONG!${NC}"
    mariadb --version
else
    echo -e "${RED}Co loi xay ra trong qua trinh cai dat!${NC}"
    exit 1
fi