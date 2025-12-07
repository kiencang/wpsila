#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

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
    echo "Đang đọc file tại: $TARGET_FILE"
    cat "$TARGET_FILE"
else
    echo "LỖI: Không tìm thấy file tại $TARGET_FILE"
    # Bạn có thể bỏ dòng exit 1 nếu muốn script chạy tiếp các lệnh sau
    exit 1
fi