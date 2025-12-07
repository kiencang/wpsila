#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# Chạy lệnh
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/install_wpsila.sh | sudo bash

# --- Cấu hình ---
# LUU Y: Hay kiem tra ky duong dan REPO_URL nay tren trinh duyet
INSTALL_DIR="/opt/wpsila"
REPO_URL="https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main" 
BIN_LINK="/usr/local/bin/wpsila"

# Hàm báo lỗi và thoát
error_exit() {
    echo -e "\033[0;31mLoi: $1\033[0m"
    exit 1
}

echo "=== DANG CAI DAT WPSILA ==="

# 1. Kiểm tra quyền Root
if [[ $EUID -ne 0 ]]; then
   error_exit "Ban phai chay lenh nay duoi quyen Root!"
fi

# 2. Cài đặt wget nếu thiếu
if ! command -v wget &> /dev/null; then
    echo "Dang cai dat wget..."
    apt-get update -qq && apt-get install -y wget -qq || error_exit "Khong the cai dat wget"
fi

# 3. Tạo thư mục
mkdir -p "$INSTALL_DIR"

# 4. Làm sạch file cũ (Clean Install)
echo "Dang lam sach thu muc cai dat..."
rm -f "$INSTALL_DIR/"*.sh 

# 5. Tải file
echo "Dang tai cac module..."

download_file() {
    local url="$1"
    local dest="$2"
    # Them tham so random de tranh cache
    wget -q "${url}?v=$RANDOM" -O "$dest"
    
    # Kiem tra file co du lieu khong
    if [[ ! -s "$dest" ]]; then
        error_exit "Khong the tai file: $dest. Vui long kiem tra lai REPO_URL."
    fi
}

download_file "$REPO_URL/wpsila_menu.sh" "$INSTALL_DIR/wpsila_menu.sh"
download_file "$REPO_URL/install_lcmp.sh" "$INSTALL_DIR/install_lcmp.sh"
download_file "$REPO_URL/install_wp.sh" "$INSTALL_DIR/install_wp.sh"
download_file "$REPO_URL/remove_web.sh" "$INSTALL_DIR/remove_web.sh"
download_file "$REPO_URL/setup_sftp.sh" "$INSTALL_DIR/setup_sftp.sh"
download_file "$REPO_URL/mariadb_tune.sh" "$INSTALL_DIR/mariadb_tune.sh"
download_file "$REPO_URL/php_ini_tune.sh" "$INSTALL_DIR/php_ini_tune.sh"
download_file "$REPO_URL/pool_tune.sh" "$INSTALL_DIR/pool_tune.sh"
download_file "$REPO_URL/wpp.sh" "$INSTALL_DIR/wpp.sh"
download_file "$REPO_URL/wpsila.conf" "$INSTALL_DIR/wpsila.conf"

# 6. Phân quyền
chmod 700 "$INSTALL_DIR/"*.sh
chmod 700 "$INSTALL_DIR"

# 7. Tạo Symlink an toàn
rm -f "$BIN_LINK" 
ln -sf "$INSTALL_DIR/wpsila_menu.sh" "$BIN_LINK"

# 8. Hoàn tất
if [[ -x "$BIN_LINK" ]]; then
    echo -e "\033[0;32m=== CAI DAT THANH CONG! ===\033[0m"
    echo "Hay go lenh: wpsila de bat dau su dung."
else
    error_exit "Loi khi tao lenh shortcut wpsila."
fi