#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# Chạy lệnh
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/tieng_viet.sh | bash

# Màu sắc cho thông báo
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "--------------------------------------------------"
echo -e "${GREEN}Kiểm tra tiếng Việt có dấu có hiển thị được ra màn hình không?${NC}"
echo "--------------------------------------------------"