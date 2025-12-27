# -----------------------------------------------------------
# MODULE: Cài đặt database và user cho WordPress
# File: database_user_wp.sh
# File này được nhúng vào script install_wp.sh
# -----------------------------------------------------------
echo -e "${GREEN}Dang tao Database va User cho WordPress...${NC}"

# -------------------------------------------------------------------------------------------------------------------------------
# --- CẤU HÌNH BIẾN NGẪU NHIÊN ---
# F1. DB Name (Thoải mái độ dài, MySQL cho phép 64 ký tự)
# Kết quả ví dụ: wp_a1b2c3d4e5f67890
GEN_DB_NAME="wp_$(openssl rand -hex 8)"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# F2. User Name (Nên giữ <= 16 ký tự để tương thích mọi phiên bản MySQL)
# Giảm xuống hex 7 (14 ký tự) + "u_" (2 ký tự) = 16 ký tự
# Kết quả ví dụ: u_a1b2c3d4e5f6g7
GEN_DB_USER="u_$(openssl rand -hex 7)"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# F3. Password (32 ký tự là rất mạnh rồi)
# Kết quả ví dụ: p_890123456789abcdef0123456789abcd
GEN_DB_PASS="p_$(openssl rand -hex 16)"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# F4. Tạo bảng trong MariaDB
# Sử dụng biến đã tạo ở trên vào câu lệnh SQL
# Lưu ý: Vì biến chỉ chứa chữ cái thường và số nên không cần escape phức tạp, rất an toàn.
# Tuy nhiên vẫn giữ backtick cho an toàn!
# Sử dụng Here-Doc (<<EOF) giúp ẩn mật khẩu khỏi danh sách tiến trình (ps aux)
# Chỉ MariaDB đọc được nội dung này qua luồng stdin

mariadb <<EOF
-- 1. Tạo Database
CREATE DATABASE IF NOT EXISTS \`${GEN_DB_NAME}\` 
DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 2. Tạo User & Gán quyền cho Socket (localhost)
CREATE USER IF NOT EXISTS '${GEN_DB_USER}'@'localhost' IDENTIFIED BY '${GEN_DB_PASS}';
GRANT ALL PRIVILEGES ON \`${GEN_DB_NAME}\`.* TO '${GEN_DB_USER}'@'localhost';

-- 3. Tạo User & Gán quyền cho TCP (127.0.0.1)
CREATE USER IF NOT EXISTS '${GEN_DB_USER}'@'127.0.0.1' IDENTIFIED BY '${GEN_DB_PASS}';
GRANT ALL PRIVILEGES ON \`${GEN_DB_NAME}\`.* TO '${GEN_DB_USER}'@'127.0.0.1';

-- 4. Flush (Thực ra MariaDB hiện đại tự flush khi tạo user, nhưng giữ lại cũng không sao)
FLUSH PRIVILEGES;
EOF
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# F5. Xuất thông tin
# Lưu thông tin vào file để tra cứu sau này (Quan trọng vì mật khẩu là ngẫu nhiên)
CRED_FILE="$SCRIPT_WPSILA_DIR/wpp.txt"

# Kiểm tra nếu file tồn tại thì mới xóa
rm -f "$CRED_FILE"

# Tạo file mới cho trang WordPress đang cài
cat > "$CRED_FILE" <<EOF
----------------------------------------
WORDPRESS DATABASE CREDENTIALS
Date: $(date)
----------------------------------------
Database Name : ${GEN_DB_NAME}
Database User : ${GEN_DB_USER}
Database Pass : ${GEN_DB_PASS}
----------------------------------------
EOF
chmod 600 "$CRED_FILE" # Chỉ user hiện tại mới đọc được file này
# Xem xét bổ sung câu lệnh để xóa file này đi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo -e "${GREEN}>>> Cai dat hoan tat!${NC}"
echo -e "${YELLOW}Thong tin Database (Da duoc luu tai $CRED_FILE):${NC}"
echo -e "  - Database: ${GEN_DB_NAME}"
echo -e "  - User:     ${GEN_DB_USER}"
echo -e "  - Pass:     ${GEN_DB_PASS}"
echo -e "${YELLOW}Kiem tra PHP version:${NC}"
php -v
echo -e "${GREEN}>>> Buoc tiep theo: Cai dat WordPress.${NC}"
sleep 2
# -------------------------------------------------------------------------------------------------------------------------------