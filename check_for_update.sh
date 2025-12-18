#!/bin/bash

# -------------------------------------------------------------------------
# wpsila - Update Manager
# Website: https://wpsila.com
# Copyright (c) 2025 - Nguyen Duc Anh
# -------------------------------------------------------------------------

# Dừng script nếu có lỗi, biến chưa khai báo, hoặc pipeline lỗi
set -euo pipefail

# ==============================================================================
# CẤU HÌNH CẬP NHẬT
# ==============================================================================
SCRIPT_VERSION="v0.1.3"
GITHUB_USER="kiencang"
GITHUB_REPO="wpsila"

# Khởi tạo biến trạng thái
do_you_update="false"
# ==============================================================================

# Màu sắc thông báo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

check_for_update() {
    echo -e "${YELLOW}Dang kiem tra cap nhat tu GitHub...${NC}"

    # 1. Lấy phiên bản mới nhất từ GitHub API
    local latest_json
    latest_json=$(curl -sL -f -m 10 -A "WPSila-Updater" "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest" || echo "")

    if [[ -z "$latest_json" ]]; then
        echo -e "${RED}Loi: Khong the ket noi den GitHub API de kiem tra phien ban.${NC}"
        return 1
    fi

    local latest_tag
    latest_tag=$(echo "$latest_json" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    if [[ -z "$latest_tag" ]]; then
        echo -e "${RED}Loi: Khong tim thay thong tin phien ban tren GitHub.${NC}"
        return 1
    fi

    # 2. Nếu phiên bản khớp nhau thì dừng kiểm tra
    if [[ "$SCRIPT_VERSION" == "$latest_tag" ]]; then
        echo -e "${GREEN}Ban dang su dung phien ban moi nhat ($SCRIPT_VERSION).${NC}"
        return 0
    fi

    # 3. Phân tích Semantic Versioning (SemVer)
    local l_ver=${SCRIPT_VERSION#v}
    local r_ver=${latest_tag#v}

    IFS='.' read -r l_major l_minor l_patch <<< "$l_ver"
    IFS='.' read -r r_major r_minor r_patch <<< "$r_ver"

    # 4. Logic so sánh phiên bản an toàn
    local should_update=false

    if (( r_major > l_major )); then
        echo -e "${RED}================================================================"
        echo -e "CANH BAO: Phien ban lon $latest_tag da phat hanh!"
        echo -e "Phien ban nay co the thay doi cau truc he thong."
        echo -e "Vui long backup du lieu va cai dat lai thu cong."
        echo -e "================================================================${NC}"
        return 1
    elif (( r_major < l_major )); then
        should_update=false
    else
        # Major bằng nhau, xét Minor
        if (( r_minor > l_minor )); then
            should_update=true
        elif (( r_minor < l_minor )); then
            should_update=false
        else
            # Major và Minor bằng nhau, xét Patch
            if (( r_patch > l_patch )); then
                should_update=true
            fi
        fi
    fi

    # 5. Xác nhận cập nhật từ người dùng
    if [[ "$should_update" == "true" ]]; then
        echo -e "${YELLOW}Co phien ban moi: $latest_tag${NC} (Phien ban hien tai: $SCRIPT_VERSION)"
        echo -ne "Ban co muon cap nhat tu dong ngay bay gio khong? [y/N]: "
        read -r reply
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            do_you_update="true"
        else
            echo "Ban da chon: Bo qua cap nhat."
        fi
    fi
}

# --- THỰC THI ---

# Chạy hàm kiểm tra cập nhật (không dừng script nếu hàm này gặp lỗi mạng)
check_for_update || true

if [[ "$do_you_update" == "false" ]]; then
    echo -e "KHONG co cap nhat nao dien ra. Tiep tuc voi phien ban $SCRIPT_VERSION..."
else
    echo -e "${GREEN}Dang tai ban cap nhat va thay the tien trinh hien tai...${NC}"
    # Sử dụng exec để thay thế hoàn toàn script đang chạy bằng installer mới
    # Tránh lỗi khi các file .sh cũ bị xóa hoặc ghi đè trong lúc đang thực thi.
    exec sudo bash -c "curl -sL https://vps.wpsila.com | bash"
fi