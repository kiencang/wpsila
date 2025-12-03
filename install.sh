#!/bin/bash

# Thư mục cài đặt
INSTALL_DIR="/opt/wpsila"
REPO_URL="https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main"

# Chạy lệnh
# bash <(curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/install.sh)

echo "Đang khởi tạo WPSila Manager..."

# 1. Tạo thư mục chứa code
mkdir -p "$INSTALL_DIR"

# 2. Tải các file thành phần về
echo "Đang tải các module..."
# Lưu ý: Bạn cần đổi tên file menu.sh trên GitHub cho khớp, hoặc sửa lệnh dưới đây
wget -q "$REPO_URL/wpsila_menu.sh" -O "$INSTALL_DIR/menu.sh"
wget -q "$REPO_URL/install_caddy.sh" -O "$INSTALL_DIR/install_caddy.sh"
wget -q "$REPO_URL/install_wp.sh" -O "$INSTALL_DIR/install_wp.sh"
wget -q "$REPO_URL/remove_web.sh" -O "$INSTALL_DIR/remove_web.sh"

# 3. Bảo mật và cấp quyền (Chỉ root mới được đọc/ghi/chạy)
chmod 700 "$INSTALL_DIR/"*.sh
chmod 700 "$INSTALL_DIR"

# 4. Tạo lệnh tắt (Symlink)
rm -f /usr/local/bin/wpsila # Xóa lệnh cũ nếu có
ln -s "$INSTALL_DIR/menu.sh" /usr/local/bin/wpsila

echo "Cài đặt thành công!"
echo "Hãy gõ lệnh: wpsila để bắt đầu sử dụng."