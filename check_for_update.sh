#!/bin/bash

# -------------------------------------------------------------------------
# wpsila - Phần quản lý cập nhật
# Version 0.3.1 - Tối ưu cho Ubuntu 22.04 & 24.04
# -------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
set -euo pipefail
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Kiểm tra quyền
if [[ $EUID -ne 0 ]]; then
   # 2. Nếu không phải root, tự động chạy lại script này bằng sudo
   sudo "$0" "$@"
   # 3. Thoát tiến trình cũ (không phải root) để tiến trình mới (có root) chạy
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
SCRIPT_VERSION="v0.3.1"
GITHUB_USER="kiencang"
GITHUB_REPO="wpsila"

# Màu sắc
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Biến trạng thái
do_you_update="false"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
check_for_update() {
    echo -e "${YELLOW}Dang kiem tra cap nhat tu GitHub...${NC}"

    # 1. Lấy JSON từ GitHub API
    local latest_json
    if ! latest_json=$(curl -sL -f -m 10 -A "WPSila-Updater" "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest"); then
        echo -e "${RED}Loi: Khong the ket noi den GitHub API hoac limit rate.${NC}"
        return 1
    fi

    # 2. [TỐI ƯU] Dùng Python3 (có sẵn trên Ubuntu 22.04/24.04) để parse JSON chuẩn xác 100%
    local latest_tag
    latest_tag=$(echo "$latest_json" | python3 -c "import sys, json; print(json.load(sys.stdin).get('tag_name', ''))")

    if [[ -z "$latest_tag" ]]; then
        echo -e "${RED}Loi: Khong tim thay tag_name trong phan hoi API.${NC}"
        return 1
    fi

    # So sánh chuỗi đơn giản trước
    if [[ "$SCRIPT_VERSION" == "$latest_tag" ]]; then
        echo -e "${GREEN}Ban dang su dung phien ban moi nhat ($SCRIPT_VERSION).${NC}"
        return 0
    fi

    # 3. Tách Version (Xử lý kỹ lỗi số Bát phân - Octal number error)
    local l_ver=${SCRIPT_VERSION#v}
    local r_ver=${latest_tag#v}

    local l_major l_minor l_patch
    local r_major r_minor r_patch

    # Tách và gán mặc định 0
    IFS='.' read -r l_major l_minor l_patch <<< "$l_ver"
    IFS='.' read -r r_major r_minor r_patch <<< "$r_ver"
    
    # Ép kiểu base 10 (10#) để tránh lỗi nếu version là 08, 09
    l_major=${l_major:-0}; l_minor=${l_minor:-0}; l_patch=${l_patch:-0}
    r_major=${r_major:-0}; r_minor=${r_minor:-0}; r_patch=${r_patch:-0}

    local should_update=false

    # 4. Logic so sánh an toàn
    # --- BLOCK MAJOR UPDATE ---
    if (( 10#$r_major > 10#$l_major )); then
        echo -e "${RED}!!! CANH BAO: Phat hien phien ban lon $latest_tag !!!${NC}"
        echo -e "Phien ban nay co thay doi cau truc (Major Update)."
        echo -e "${YELLOW}-> Tu dong cap nhat da bi CHAN de bao ve he thong.${NC}"
        echo -e "Vui long doc Changelog va cap nhat thu cong."
        return 1
    fi

    # Chỉ update nếu Major bằng nhau và (Minor lớn hơn HOẶC (Minor bằng nhau VÀ Patch lớn hơn))
    if (( 10#$r_major == 10#$l_major )); then
        if (( 10#$r_minor > 10#$l_minor )) || { (( 10#$r_minor == 10#$l_minor )) && (( 10#$r_patch > 10#$l_patch )); }; then
            should_update=true
        fi
    fi

    if [[ "$should_update" == "true" ]]; then
        echo -e "${YELLOW}Co phien ban moi: $latest_tag (Hien tai: $SCRIPT_VERSION)${NC}"
        # Dùng /dev/tty để đảm bảo read hoạt động kể cả khi script chạy trong pipe
        echo -ne "Ban co muon cap nhat ngay bay gio khong? [y/N]: "
        read -r reply < /dev/tty
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            do_you_update="true"
        fi
    fi
}
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- THỰC THI ---
# Gọi hàm, nếu lỗi (mạng/major block) thì in ra nhưng không thoát script chính
if ! check_for_update; then
    echo -e "${YELLOW}Bo qua buoc cap nhat tu dong.${NC}"
fi

if [[ "$do_you_update" == "true" ]]; then
    echo -e "${GREEN}Dang tai ban cap nhat...${NC}"
    
    # Reset timer sudo để tránh hỏi pass giữa chừng nếu đã sudo từ đầu
    sudo -v 

    # Sử dụng exec để thay thế tiến trình hiện tại hoàn toàn
    export DEBIAN_FRONTEND=noninteractive
    
    # Lưu ý: Thêm cờ -- update để script mới biết nó đang được chạy ở chế độ update (nếu cần)
	# Bản online
    exec sudo bash -c "curl -sL https://vps.wpsila.com | bash -s -- update"
	
	#Bản test
	# exec sudo bash -c "curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/install_wpsila.sh | bash -s -- update"
else
    echo -e "Tiep tuc khoi chay phien ban hien tai $SCRIPT_VERSION..."
    # [Code logic chính của script]
fi
# -------------------------------------------------------------------------------------------------------------------------------