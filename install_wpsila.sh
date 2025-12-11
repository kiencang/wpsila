#!/bin/bash

# -------------------------------------------------------------------------
# wpsila - install WordPress blog
# -------------------------------------------------------------------------
# Website:		https://wpsila.com
# GitHub:			https://github.com/kiencang/wpsila
# Copyright (c) 2025 - wpsila
# This script is licensed under M.I.T
# -------------------------------------------------------------------------
# curl -sL https://vps.wpsila.com | sudo bash
# -------------------------------------------------------------------------
# Version 0.1.1 - 11/12/2025
# -------------------------------------------------------------------------

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

# Chú ý link Repo, cần cập nhật cả vps.wpsila.com nếu nó có thay đổi
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
# 1. Kiểm tra quyền
# NÂNG QUYỀN NẾU KHÔNG PHẢI LÀ ROOT
# 1. Kiểm tra xem đang chạy với quyền gì
if [[ $EUID -ne 0 ]]; then
   # 2. Nếu không phải root, tự động chạy lại script này bằng sudo
   sudo "$0" "$@"
   # 3. Thoát tiến trình cũ (không phải root) để tiến trình mới (có root) chạy
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 2. Cài đặt wget và ca-certificates (QUAN TRỌNG: thêm ca-certificates để tránh lỗi SSL)
# Cài đặt wget và ca-certificates
if ! command -v wget &> /dev/null || ! command -v sha256sum &> /dev/null; then
    echo "Dang cai dat wget va coreutils..."
    # Cài đặt wget (cho tải file) và coreutils (cho sha256sum)
    apt-get update -qq && apt-get install -y wget ca-certificates coreutils -qq || error_exit "Khong the cai dat cac phu thuoc co ban (wget/coreutils)."
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

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# === KET QUA: MA BASH DE DAN VAO install_wpsila.sh ===
declare -A CHECKSUMS=(
    ["wpsila_menu.sh"]="12387deb4dccadbb899d2fa44f8778af7f9dc2fb011bb3a3f22de81e3af8548d"
    ["caddyfile.sh"]="94ab76338c51ec8d0691ef036424b212fff48062452aadacdec2aa150e93ff9a"
    ["domain_check.sh"]="75f063b598074e010e9b5225c70d15dd8756f8cde950253f458fe6c3d81c48d5"
    ["setup_sftp.sh"]="100d6479753cb352160e89986973c6daf362d03c7821a2ed168c4edbb52cbbbe"
    ["wpsila.conf"]="5eb2ca775745af452d4c66bca812c212061803204acae32f8470d3e0a51debcb"
    ["remove_web.sh"]="1e4a5278e5ed66874d85416f3447a8e251e1fe20be4e012d1b65b89f19256dfc"
    ["setup_adminer.sh"]="1b8230fea58707a09a2499f5fdf073adc4552a814230236d0a95ce9c33c02996"
    ["php_mariadb.sh"]="bb252f19a326f02c9ae4c04716f2c2847dac004953c916051c0b67c91f878372"
    ["php_ini_tune.sh"]="a1d08179ec2204d9145add0fc67ce4da240a1e35b7aec675ed7b9a58c5aebd42"
    ["pool_tune.sh"]="558f34573c8ffe613376cee3f56d5aae7e71fedd9314972735d3b1bc1d5d124c"
    ["database_user_wp.sh"]="30d3d1c70a42c51ae2369d90778f76b560174ababce5aaa9e2c1ff86520a4d55"
    ["caddy_web_server.sh"]="60cbc4f72f338320b07d9561a2752918c57c58bb3cf8085ac410b4b6d77667ca"
    ["wpp.sh"]="9a951a204155b053a79e57eab1781f384e1a7cee8659a09bf2ccb18901499066"
    ["install_wp.sh"]="067e4014f45db767e033d94455b496543b4bd0b49ea9a4532aca346181f63ff7"
    ["caddyfile_subdomain.sh"]="7d38e3bba7afa65560919a7ac6bb77b062c7e2749e663757276c6b8987231975"
    ["install_lcmp.sh"]="1ee5c195be766dae73a6ff2e40743badd0c8f97beb8559c086a54923ac305302"
    ["mariadb_tune.sh"]="b396373064b296c32e9853aae466ea16b5812167831aef7d613c8b69bb79b794"
    ["wordpress.sh"]="2dfb8fdca37397407b8a91a1f8bf31b2ab6f2dbc1ad68c1f6feb981d68a37116"
)
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 5. Tải file
echo "Dang tai cac module..."

download_file() {
    local filename="$1"
    local dest="$2"
    local url="$REPO_URL/$filename"
    local expected_checksum="${CHECKSUMS[$filename]}"

    # 1. Tien hang tai file
    if ! wget -q --no-cache "$url" -O "$dest"; then
        echo -e "\033[0;31m[DOWNLOAD FAIL]\033[0m Khong the tai: $url"
        rm -f "$dest"
        error_exit "Loi ket noi hoac duong dan khong chinh xac."
    fi

    # 2. Kiem tra file tai ve co du lieu khong
    if [[ ! -s "$dest" ]]; then
        rm -f "$dest"
        error_exit "File tai ve bi rong (0 bytes): $dest"
    fi

    # 3. KIEM TRA CHECKSUM
    if [[ -n "$expected_checksum" ]]; then
        local actual_checksum
        actual_checksum=$(sha256sum "$dest" | awk '{print $1}')

        if [[ "$actual_checksum" != "$expected_checksum" ]]; then
            echo -e "\033[0;31m[CHECKSUM FAIL]\033[0m Tap tin $filename bi thay doi hoac bi hong!"
            rm -f "$dest"
            error_exit "Checksum khong khop. Viec cai dat bi huy bo."
        fi
        echo -e "\033[0;32m[CHECKSUM OK]\033[0m $filename"
    fi
}
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# File cấu hình (chứa định nghĩa phiên bản PHP)
download_file "wpsila.conf" "$INSTALL_DIR/wpsila.conf"
# -------------------------

# -------------------------
# Tải về menu cho chương trình quản trị wpsila
download_file "wpsila_menu.sh" "$INSTALL_DIR/wpsila_menu.sh"
# -------------------------

# -------------------------
# Tải về các file phục vụ cho cài đặt LCMP
download_file "install_lcmp.sh" "$INSTALL_DIR/install_lcmp.sh"
download_file "caddy_web_server.sh" "$INSTALL_DIR/caddy_web_server.sh"
download_file "php_mariadb.sh" "$INSTALL_DIR/php_mariadb.sh"
# -------------------------

# -------------------------
# Tải về các file phục vụ cho việc cài đặt WordPress
download_file "install_wp.sh" "$INSTALL_DIR/install_wp.sh"
download_file "domain_check.sh" "$INSTALL_DIR/domain_check.sh"
download_file "database_user_wp.sh" "$INSTALL_DIR/database_user_wp.sh"
download_file "wordpress.sh" "$INSTALL_DIR/wordpress.sh"
download_file "caddyfile.sh" "$INSTALL_DIR/caddyfile.sh"
download_file "caddyfile_subdomain.sh" "$INSTALL_DIR/caddyfile_subdomain.sh"
# -------------------------

# -------------------------
# Tải về các file để thiết lập cấu hình cho MariaDB và PHP INI cũng như Poll Tune
download_file "mariadb_tune.sh" "$INSTALL_DIR/mariadb_tune.sh"
download_file "php_ini_tune.sh" "$INSTALL_DIR/php_ini_tune.sh"
download_file "pool_tune.sh" "$INSTALL_DIR/pool_tune.sh"
# -------------------------

# -------------------------
# Tải về file phục vụ chức năng xóa website
download_file "remove_web.sh" "$INSTALL_DIR/remove_web.sh"
# -------------------------

# -------------------------
# Tải về file tạo tài khoản sFTP
download_file "setup_sftp.sh" "$INSTALL_DIR/setup_sftp.sh"
# -------------------------

# -------------------------
# Tải về file cài adminer để tạo trang quản trị database (không cài nếu không cần)
download_file "setup_adminer.sh" "$INSTALL_DIR/setup_adminer.sh"
# -------------------------

# -------------------------
# File để hiển thị mật khẩu WordPress
download_file "wpp.sh" "$INSTALL_DIR/wpp.sh"
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