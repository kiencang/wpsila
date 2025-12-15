# -----------------------------------------------------------
# MODULE: Cài đặt MariaDB
# File: mariadb.sh
# File này được nhúng vào script install_lcmp.sh
# -----------------------------------------------------------
echo -e "${GREEN}[1/3] Dang cai dat MariaDB Server...${NC}"

# Cai dat MariaDB
apt-get install -y mariadb-server mariadb-client

# Khoi dong MariaDB
systemctl enable --now mariadb

# Cho MariaDB khoi dong hoan toan (Smart wait thay vi sleep cung)
echo "Dang doi MariaDB khoi dong..."
timeout 30s bash -c 'until systemctl is-active --quiet mariadb; do sleep 1; done'

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