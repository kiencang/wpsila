#!/bin/bash

# Chạy lệnh
# bash <(curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/install_wpsila.sh)

# Thư mục cài đặt
INSTALL_DIR="/opt/wpsila"
REPO_URL="https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main"

echo "=== ĐANG CÀI ĐẶT WPSILA MANAGER ==="

# 1. Đảm bảo wget đã được cài đặt (đề phòng VPS thiếu)
if ! command -v wget &> /dev/null; then
    echo "Đang cài đặt wget..."
    apt-get update -qq && apt-get install -y wget -qq
fi

# 2. Tạo thư mục chứa code
mkdir -p "$INSTALL_DIR"

# 3. Tải các file thành phần về (Dùng flag -N để ghi đè nếu mới hơn)
echo "Đang tải các module..."
wget -q "$REPO_URL/wpsila_menu.sh" -O "$INSTALL_DIR/wpsila_menu.sh"
wget -q "$REPO_URL/install_caddy.sh" -O "$INSTALL_DIR/install_caddy.sh"
wget -q "$REPO_URL/install_wp.sh" -O "$INSTALL_DIR/install_wp.sh"
wget -q "$REPO_URL/remove_web.sh" -O "$INSTALL_DIR/remove_web.sh"

# 4. Bảo mật và cấp quyền (Chỉ root mới được đọc/ghi/chạy)
chmod 700 "$INSTALL_DIR/"*.sh
chmod 700 "$INSTALL_DIR"

# 5. Tạo lệnh tắt (Symlink)
rm -f /usr/local/bin/wpsila # Xóa lệnh cũ nếu có
ln -s "$INSTALL_DIR/wpsila_menu.sh" /usr/local/bin/wpsila

echo "=== CÀI ĐẶT THÀNH CÔNG! ==="
echo "Hãy gõ lệnh: wpsila để bắt đầu sử dụng."