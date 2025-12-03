#!/bin/bash

set -euo pipefail

# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/test.sh | bash

so_luong=10

# Cấu trúc: if [ điều_kiện ]; then ... fi
# Lưu ý: BẮT BUỘC phải có khoảng trắng sau [ và trước ]

if [ $so_luong -gt 5 ]; then
    echo "Số lượng lớn hơn 5."
else
    echo "Số lượng nhỏ hơn hoặc bằng 5."
fi