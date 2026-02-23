#!/bin/bash

# -----------------------------------------------------------
# MODULE: Xóa các file chứa mật khẩu (Plain-text)
# File: remove_pass_files.sh
# Xóa wpp.txt, sftpp.txt, adminerp.txt để bảo mật hệ thống (nếu chúng tồn tại).
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
set -euo pipefail
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   sudo -E "$0" "$@"
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo -e "${GREEN}=== CONG CU DON DEP FILE MAT KHAU (SECURITY CLEAR) ===${NC}"
echo -e "De dam bao an toan cho VPS, ban nen xoa cac file chua mat khau sau khi da luu tru chung."
echo "------------------------------------------------"

# 1. Xác định thư mục chứa script (cũng là nơi chứa file pass)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# 2. Khai báo danh sách các file cần quét
PASS_FILES=("wpp.txt" "sftpp.txt" "adminerp.txt")
FOUND_FILES=()

# 3. Quét sự tồn tại của file và đưa vào mảng FOUND_FILES
for file in "${PASS_FILES[@]}"; do
    if [[ -f "$SCRIPT_DIR/$file" ]]; then
        FOUND_FILES+=("$file")
    fi
done

# 4. Xử lý logic nếu không tìm thấy file nào
if [[ ${#FOUND_FILES[@]} -eq 0 ]]; then
    echo -e "${GREEN}Tuyet voi! He thong cua ban dang rat sach se.${NC}"
    echo -e "Khong co file mat khau (plain-text) nao dang bi bo quen tren may chu."
    exit 0
fi

# 5. Thông báo cho người dùng biết chính xác file nào đang tồn tại
echo -e "${RED}CANH BAO: Phat hien cac file chua mat khau duoi day dang ton tai tren VPS:${NC}"
for file in "${FOUND_FILES[@]}"; do
    # Hiển thị tên file và thời gian tạo/sửa lần cuối để user nhớ
    FILE_DATE=$(stat -c '%y' "$SCRIPT_DIR/$file" | cut -d' ' -f1,2 | cut -d'.' -f1)
    echo -e "  [!] ${YELLOW}$file${NC} (Tao luc: $FILE_DATE)"
done
echo "------------------------------------------------"
echo -e "${YELLOW}Luu y: Vui long chac chan ban da COPY va LUU TRU mat khau vao noi an toan (nhu Bitwarden, 1Password, Note...) truoc khi xoa!${NC}"

# 6. Yêu cầu xác nhận (Sử dụng /dev/tty để bắt phím chuẩn xác qua pipe/menu)
read -r -p "Ban co chac chan muon XOA VINH VIEN cac file nay khong? (y/n): " CONFIRM < /dev/tty

if [[ "$CONFIRM" =~ ^[yY](es)?$ ]]; then
    echo ""
    # 7. Tiến hành xóa và báo cáo
    for file in "${FOUND_FILES[@]}"; do
        rm -f "$SCRIPT_DIR/$file"
        echo -e "${GREEN} -> Da xoa vinh vien: $file${NC}"
    done
    echo "------------------------------------------------"
    echo -e "${GREEN}HOAN TAT! He thong cua ban da duoc bao mat hon.${NC}"
else
    echo -e "\n${YELLOW}Da huy thao tac. Cac file van duoc giu lai nguyen ven tren he thong.${NC}"
fi