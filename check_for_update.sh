#!/bin/bash

# -------------------------------------------------------------------------------------------------------------------------------
set -euo pipefail

# Phiên bản hiện tại của wpsila
SCRIPT_VERSION="v1.4.1"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------
# Phần quản lý cập nhật cho toàn bộ wpsila
# File: check_for_update.sh
# So sánh version local & version trên GitHub
# -------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Kiểm tra quyền
if [[ $EUID -ne 0 ]]; then
   # 2. Nếu không phải root, tự động chạy lại script này bằng sudo
   sudo -E "$0" "$@"
   # 3. Thoát tiến trình cũ (không phải root) để tiến trình mới (có root) chạy
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
GITHUB_USER="kiencang"
GITHUB_REPO="wpsila"

# Màu sắc
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Biến trạng thái
do_you_update=0
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
check_for_update() {
    echo -e "${YELLOW}Dang kiem tra cap nhat tu GitHub...${NC}"

    # 1. Lấy tag phiên bản mới nhất (Ưu tiên qua HTTP Redirect để không bị giới hạn 60 req/giờ của GitHub API, dự phòng qua API)
    local latest_tag=""
    local redirect_url
    redirect_url=$(curl -fsSLI -m 10 -A "WPSila-Updater" -o /dev/null -w '%{url_effective}' "https://github.com/$GITHUB_USER/$GITHUB_REPO/releases/latest" || true)
    if [[ "$redirect_url" == *"/releases/tag/"* ]]; then
        latest_tag="${redirect_url##*/}"
    fi

    if [[ -z "$latest_tag" ]]; then
        local latest_json
        if ! latest_json=$(curl -sL -f -m 10 -A "WPSila-Updater" "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest"); then
            echo -e "${RED}Loi: Khong the ket noi den GitHub API hoac limit rate.${NC}"
            return 1
        fi
        latest_tag=$(echo "$latest_json" | python3 -c "import sys, json; print(json.load(sys.stdin).get('tag_name', ''))" 2>/dev/null || true)
    fi

    if [[ -z "$latest_tag" ]]; then
        echo -e "${RED}Loi: Khong tim thay tag_name trong phan hoi GitHub.${NC}"
        return 1
    fi

    # So sánh chuỗi đơn giản trước
    if [[ "$SCRIPT_VERSION" == "$latest_tag" ]]; then
        echo -e "${GREEN}Ban dang su dung phien ban moi nhat ($SCRIPT_VERSION).${NC}"
        return 0
    fi

    # 3. Tách Version (Xử lý kỹ lỗi số Bát phân 10# và làm sạch hậu tố như -beta, -rc1)
    local l_ver=${SCRIPT_VERSION#v}
    local r_ver=${latest_tag#v}

    local l_major l_minor l_patch
    local r_major r_minor r_patch

    # Tách theo dấu chấm
    IFS='.' read -r l_major l_minor l_patch <<< "$l_ver"
    IFS='.' read -r r_major r_minor r_patch <<< "$r_ver"

    # Làm sạch mọi hậu tố không phải chữ số (ví dụ: 2-beta -> 2) trước khi ép kiểu 10#
    l_major="${l_major%%[^0-9]*}"; l_minor="${l_minor%%[^0-9]*}"; l_patch="${l_patch%%[^0-9]*}"
    r_major="${r_major%%[^0-9]*}"; r_minor="${r_minor%%[^0-9]*}"; r_patch="${r_patch%%[^0-9]*}"

    # Gán mặc định 0 nếu rỗng
    l_major=${l_major:-0}; l_minor=${l_minor:-0}; l_patch=${l_patch:-0}
    r_major=${r_major:-0}; r_minor=${r_minor:-0}; r_patch=${r_patch:-0}

    local should_update=0

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
            should_update=1
        fi
    fi

    if (( should_update == 1 )); then
        echo -e "${YELLOW}Co phien ban moi: $latest_tag (Hien tai: $SCRIPT_VERSION)${NC}"
        # Dùng /dev/tty để đảm bảo read hoạt động kể cả khi script chạy trong pipe
        echo -ne "Ban co muon cap nhat ngay bay gio khong? [y/N]: "
		local reply
        read -r reply < /dev/tty
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            do_you_update=1
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

if (( do_you_update == 1 )); then
    echo -e "${GREEN}Dang tai ban cap nhat...${NC}"

    # Sử dụng exec để thay thế tiến trình hiện tại hoàn toàn
    export DEBIAN_FRONTEND=noninteractive
    
    # Lưu ý: Thêm cờ -- update để script mới biết nó đang được chạy ở chế độ update (nếu cần)
	# Bản online
    exec bash -c "curl -fsSL https://vps.wpsila.com | bash -s -- update"
	
	#Bản test
	# exec sudo bash -c "curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/install_wpsila.sh | bash -s -- update"
else
    echo -e "Tiep tuc khoi chay phien ban hien tai $SCRIPT_VERSION..."
    # [Code logic chính của script]
fi
# -------------------------------------------------------------------------------------------------------------------------------
