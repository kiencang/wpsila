#!/bin/bash

# Dừng script ngay lập tức nếu có biến chưa khai báo hoặc pipeline bị lỗi
# Lưu ý: set -e sẽ được xử lý khéo léo trong hàm download để không ngắt script đột ngột
set -euo pipefail

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Chạy lệnh
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/install_wpsila.sh | sudo bash
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- Cấu hình ---
INSTALL_DIR="/opt/wpsila"
# Giữ nguyên URL theo yêu cầu của bạn
REPO_URL="https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main" 
BIN_LINK="/usr/local/bin/wpsila"

# Hàm báo lỗi và thoát
error_exit() {
    echo -e "\033[0;31mLoi: $1\033[0m"
    exit 1
}
# -------------------------------------------------------------------------------------------------------------------------------

#+++

echo "=== DANG CAI DAT WPSILA ==="

# -------------------------------------------------------------------------------------------------------------------------------
# 1. Kiểm tra quyền Root
if [[ $EUID -ne 0 ]]; then
   error_exit "Ban phai chay lenh nay duoi quyen Root!"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 2. Cài đặt wget và ca-certificates (QUAN TRỌNG: thêm ca-certificates để tránh lỗi SSL)
if ! command -v wget &> /dev/null; then
    echo "Dang cai dat wget..."
    apt-get update -qq && apt-get install -y wget ca-certificates -qq || error_exit "Khong the cai dat wget"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 3. Tạo thư mục cho mã nguồn của wpSila
if [[ ! -d "$INSTALL_DIR" ]]; then
    mkdir -p "$INSTALL_DIR"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 4. Làm sạch file cũ (Clean Install)
echo "Dang lam sach thu muc cai dat..."
# Xóa cả file .sh và file .conf
rm -f "$INSTALL_DIR/"*.sh
rm -f "$INSTALL_DIR/"*.conf
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 5. Tải file
echo "Dang tai cac module..."

download_file() {
    local url="$1"
    local dest="$2"
    
    # FIX LOI: Dùng 'if ! wget' để bắt lỗi thay vì để 'set -e' tự động kill script
    # Thêm --no-cache (nếu wget hỗ trợ) hoặc bỏ qua cache server
    # Bỏ '?v=$RANDOM' để tránh lỗi 404 do sai format URL
	
    if ! wget -q --no-cache "$url" -O "$dest"; then
        echo -e "\033[0;31m[DOWNLOAD FAIL]\033[0m Khong the tai: $url"
        rm -f "$dest" # Xóa file rác nếu có
        error_exit "Loi ket noi hoac duong dan khong chinh xac."
    fi
    
    # Kiểm tra file tải về có dữ liệu không
    if [[ ! -s "$dest" ]]; then
        rm -f "$dest"
        error_exit "File tai ve bi rong (0 bytes): $dest"
    fi
}

# -------------------------------------------------------------------------------------------------------------------------------
download_file "$REPO_URL/wpsila.conf" "$INSTALL_DIR/wpsila.conf"
# 
download_file "$REPO_URL/wpsila_menu.sh" "$INSTALL_DIR/wpsila_menu.sh"
#
download_file "$REPO_URL/install_lcmp.sh" "$INSTALL_DIR/install_lcmp.sh"
# 
download_file "$REPO_URL/mariadb_tune.sh" "$INSTALL_DIR/mariadb_tune.sh"
download_file "$REPO_URL/php_ini_tune.sh" "$INSTALL_DIR/php_ini_tune.sh"
download_file "$REPO_URL/pool_tune.sh" "$INSTALL_DIR/pool_tune.sh"
#
download_file "$REPO_URL/install_wp.sh" "$INSTALL_DIR/install_wp.sh"
download_file "$REPO_URL/wordpress.sh" "$INSTALL_DIR/wordpress.sh"
download_file "$REPO_URL/caddyfile.sh" "$INSTALL_DIR/caddyfile.sh"
download_file "$REPO_URL/caddyfile_subdomain.sh" "$INSTALL_DIR/caddyfile_subdomain.sh"
#
download_file "$REPO_URL/remove_web.sh" "$INSTALL_DIR/remove_web.sh"
#
download_file "$REPO_URL/setup_sftp.sh" "$INSTALL_DIR/setup_sftp.sh"
#
download_file "$REPO_URL/wpp.sh" "$INSTALL_DIR/wpp.sh"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 6. Phân quyền
chmod 700 "$INSTALL_DIR/"*.sh
chmod 700 "$INSTALL_DIR/"*.conf
chmod 700 "$INSTALL_DIR"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 7. Tạo Symlink an toàn
rm -f "$BIN_LINK" 
ln -sf "$INSTALL_DIR/wpsila_menu.sh" "$BIN_LINK"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 8. Hoàn tất
if [[ -x "$BIN_LINK" ]]; then
    echo -e "\033[0;32m=== CAI DAT THANH CONG! ===\033[0m"
    echo "Xin chuc mung ban! Hay go lenh: wpsila de bat dau su dung."
else
    error_exit "Loi khi tao lenh shortcut wpsila."
fi
# -------------------------------------------------------------------------------------------------------------------------------