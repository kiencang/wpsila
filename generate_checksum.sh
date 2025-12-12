#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail

# Phiên bản của bash script
VERSION="v0.1.2"

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Mã này dùng để tạo checksum cho các file tải về nhằm đảm bảo dữ liệu toàn vẹn.
# Xuất mã rồi chèn vào install_wpsila.sh
# Đoạn mã này dành cho dev, không phải người dùng cuối.
# Mỗi bản cập nhật bắt buộc phải làm để đảm bảo mã nguồn tải được.
# Có thể chạy mã này trong WSL trên Windows.
# -------------------------------------------------------------------------------------------------------------------------------

# --- Cấu hình ---
REPO_URL="https://raw.githubusercontent.com/kiencang/wpsila/${VERSION}"
TEMP_DIR="/tmp/wpsila_checksum_temp"

# Danh sách file
FILE_LIST=(
    "wpsila.conf"
    "wpsila_menu.sh"
    "install_lcmp.sh"
    "caddy_web_server.sh"
    "php_mariadb.sh"
    "install_wp.sh"
    "domain_check.sh"
    "database_user_wp.sh"
    "wordpress.sh"
    "caddyfile.sh"
    "caddyfile_subdomain.sh"
    "mariadb_tune.sh"
    "php_ini_tune.sh"
    "pool_tune.sh"
    "remove_web.sh"
    "setup_sftp.sh"
    "setup_adminer.sh"
    "wpp.sh"
)

# Kiểm tra dependency
if ! command -v wget &> /dev/null || ! command -v sha256sum &> /dev/null; then
    echo "Loi: Thieu 'wget' hoac 'sha256sum'."
    exit 1
fi

echo "=== BAT DAU TAO CHECKSUM (Lay file tu GitHub) ==="

# Tạo thư mục tạm an toàn
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR" || exit 1

declare -A CHECKSUMS_RESULT
TOTAL_FILES=${#FILE_LIST[@]}
COUNT=0

for filename in "${FILE_LIST[@]}"; do
    COUNT=$((COUNT + 1))
    URL="$REPO_URL/$filename"
    
    # In ra dòng đang xử lý để user biết tiến độ
    echo -n "[$COUNT/$TOTAL_FILES] Downloading $filename ... "
    
    # 1. Tải file (Thêm --no-cache để đảm bảo lấy code mới nhất vừa push)
    if ! wget -q --no-cache "$URL" -O "$filename"; then
        echo "FAIL (Loi tai file)"
        continue
    fi

    # 2. Tính checksum
    CHECKSUM=$(sha256sum "$filename" | awk '{print $1}')
    
    # Kiểm tra nếu file rỗng (đề phòng link đúng nhưng file 0 byte)
    if [[ ! -s "$filename" ]]; then
         echo "FAIL (File rong)"
         continue
    fi

    CHECKSUMS_RESULT["$filename"]="$CHECKSUM"
    echo "OK"
done

# Dọn dẹp
cd ..
rm -rf "$TEMP_DIR"

# Xuất kết quả
echo
echo "=== KET QUA: Copy doan duoi day va thay vao script cai dat ==="
echo "--------------------------------------------------------------------------------"
echo "declare -A CHECKSUMS=("

# Lặp qua FILE_LIST gốc để giữ đúng thứ tự sắp xếp
for filename in "${FILE_LIST[@]}"; do
    # Chỉ in ra nếu file đó đã được tính checksum thành công
    if [[ -n "${CHECKSUMS_RESULT[$filename]+abc}" ]]; then
        checksum="${CHECKSUMS_RESULT[$filename]}"
        echo "    [\"$filename\"]=\"$checksum\""
    fi
done

echo ")"
echo "--------------------------------------------------------------------------------"