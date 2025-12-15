#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# Kiểm tra quyền
# NÂNG QUYỀN NẾU KHÔNG PHẢI LÀ ROOT
# 1. Kiểm tra xem đang chạy với quyền gì
if [[ $EUID -ne 0 ]]; then
   # 2. Nếu không phải root, tự động chạy lại script này bằng sudo
   # Thêm tham số -E cho sudo để giữ lại các biến môi trường (nếu có)
   sudo -E "$0" "$@"
   # 3. Thoát tiến trình cũ (không phải root) để tiến trình mới (có root) chạy
   exit $?
fi

# 1. Xác định user thực sự (Xử lý lỗi unbound variable)
# Cú pháp ${SUDO_USER:-$USER} nghĩa là:
# Nếu có SUDO_USER thì dùng nó, nếu không thì dùng user hiện tại ($USER)
REAL_USER="${SUDO_USER:-$USER}"

# 2. Lấy đường dẫn Home chuẩn của user đó từ hệ thống
# Lệnh 'getent passwd' sẽ tra cứu thông tin user chính xác nhất
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# 3. Tạo đường dẫn file đầy đủ
TARGET_FILE="$USER_HOME/wpp.txt"

# 4. Kiểm tra và chạy lệnh
if [ -f "$TARGET_FILE" ]; then
    echo "Dang doc file tai: $TARGET_FILE"
    cat "$TARGET_FILE"
else
    echo "KHONG tim thay file tai $TARGET_FILE"
fi