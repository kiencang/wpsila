#!/bin/bash

# --- Cấu hình ---
# Đường dẫn Repository GỐC chứa các file thành phần
REPO_URL="https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main"
# Thư mục tạm thời để tải file
TEMP_DIR="/tmp/wpsila_checksum_temp"

# Danh sách Tên file CẦN TÍNH CHECKSUM
# Bạn có thể sao chép và dán danh sách này trực tiếp từ phần 5 của script cài đặt
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
# -----------------

# Kiểm tra sự tồn tại của wget và sha256sum
if ! command -v wget &> /dev/null || ! command -v sha256sum &> /dev/null; then
    echo "Loi: Can cai dat 'wget' va 'sha256sum' truoc khi chay script nay."
    exit 1
fi

echo "=== BAT DAU TAO CHECKSUM (Lay file tu GitHub) ==="

# Tạo thư mục tạm và đảm bảo thư mục sạch
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR" || exit 1

# Tải và Tính toán Checksum
echo "Dang tai ve va tinh toan checksum..."
declare -A CHECKSUMS_RESULT
TOTAL_FILES=${#FILE_LIST[@]}
COUNT=0

for filename in "${FILE_LIST[@]}"; do
    COUNT=$((COUNT + 1))
    URL="$REPO_URL/$filename"
    
    # 1. Tải file
    echo "[$COUNT/$TOTAL_FILES] Dang tai: $filename..."
    if ! wget -q "$URL" -O "$filename"; then
        echo "Loi tai file $filename. Bo qua."
        continue
    fi

    # 2. Tính checksum
    CHECKSUM=$(sha256sum "$filename" | awk '{print $1}')
    CHECKSUMS_RESULT["$filename"]="$CHECKSUM"
done

# Xóa thư mục tạm
cd ..
rm -rf "$TEMP_DIR"

# Xuất mã Bash cho script cài đặt
echo
echo "=== KET QUA: MA BASH DE DAN VAO install_wpsila.sh ==="
echo "----------------------------------------------------------------------------------------------------------------"
echo "declare -A CHECKSUMS=("

for filename in "${!CHECKSUMS_RESULT[@]}"; do
    checksum="${CHECKSUMS_RESULT[$filename]}"
    echo "    [\"$filename\"]=\"$checksum\""
done

echo ")"
echo "# ----------------------------------------------------------------------------------------------------------------"