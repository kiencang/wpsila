# -----------------------------------------------------------
# MODULE: Cài đặt database và user cho WordPress
# File này được nhúng vào script install_wp.sh
# -----------------------------------------------------------
echo -e "${GREEN}Dang tao Database va User cho WordPress...${NC}"

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

# 1. Tạo Database
mariadb -e "CREATE DATABASE IF NOT EXISTS ${GEN_DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 2. Tạo User cho đường Socket (localhost) - ĐỂ TỐI ƯU HIỆU NĂNG
# Dành cho trường hợp wp-config dùng 'localhost'
mariadb -e "CREATE USER IF NOT EXISTS '${GEN_DB_USER}'@'localhost' IDENTIFIED BY '${GEN_DB_PASS}';"
mariadb -e "GRANT ALL PRIVILEGES ON ${GEN_DB_NAME}.* TO '${GEN_DB_USER}'@'localhost';"

# 3. Tạo User cho đường TCP/IP (127.0.0.1) - ĐỂ TƯƠNG THÍCH TUYỆT ĐỐI
# Dành cho trường hợp wp-config dùng '127.0.0.1' và tương thích với skip-name-resolve
mariadb -e "CREATE USER IF NOT EXISTS '${GEN_DB_USER}'@'127.0.0.1' IDENTIFIED BY '${GEN_DB_PASS}';"
mariadb -e "GRANT ALL PRIVILEGES ON ${GEN_DB_NAME}.* TO '${GEN_DB_USER}'@'127.0.0.1';"

# 4. Flush
mariadb -e "FLUSH PRIVILEGES;"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# F5. Xuất thông tin
# Lưu thông tin vào file để tra cứu sau này (Quan trọng vì mật khẩu là ngẫu nhiên)
CRED_FILE="$HOME/wpp.txt"

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

# Để xem lại nội dung dùng lệnh sau trên terminal: cat ~/wpp.txt (đã bổ sung vào menu để người dùng cuối xem)
# Copy bằng cách bôi đen ở terminal, sau đó paste (ctrl + V) như bình thường ở giao diện cài đặt
# Sau khi cài xong WordPress cần xóa file này đi bằng lệnh: rm ~/wpp.txt
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