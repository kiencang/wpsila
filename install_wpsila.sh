#!/bin/bash

# -------------------------------------------------------------------------
# wpsila - install WordPress blog
# -------------------------------------------------------------------------
# Website: https://wpsila.com
# GitHub: https://github.com/kiencang/wpsila
# Copyright (c) 2025 - Nguyen Duc Anh
# This script is licensed under GPL-3.0
# -------------------------------------------------------------------------
# curl -sL https://vps.wpsila.com | sudo bash
# -------------------------------------------------------------------------
# Version 0.3.1 - 25/12/2025
# -------------------------------------------------------------------------
# Test
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/install_wpsila.sh | sudo bash
# -------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Dừng script ngay lập tức nếu có biến chưa khai báo hoặc pipeline bị lỗi
# Lưu ý: set -e sẽ được xử lý khéo léo trong hàm download để không ngắt script đột ngột
set -euo pipefail

# Thiet lap moi truong chuan cho Automation
export LC_ALL=C.UTF-8
export DEBIAN_FRONTEND=noninteractive

# Phiên bản của bash script / rất quan trọng để tải đúng phiên bản các file cài tương ứng
SILA_VERSION="v0.3.1"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# A. Màu sắc cho thông báo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color (ngắt màu)
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 0. Cấu hình
# Thư mục lưu các file cài đặt
# Thêm tiền tố kiencang để giảm tối đa xác suất trùng tên
INSTALL_DIR="/opt/kiencang-wpsila"

# Chú ý link Repo, cần cập nhật cả vps.wpsila.com nếu nó có thay đổi
# vps.wpsila.com là nơi chứa mã nguồn này, có thể để chuyển hướng hoặc chứa trực tiếp.
# Đang để chứa trực tiếp mã nguồn
REPO_URL="https://raw.githubusercontent.com/kiencang/wpsila/${SILA_VERSION}"
BIN_LINK="/usr/local/bin/wpsila"

# Hàm báo lỗi và thoát
error_exit() {
    echo -e "\033[0;31mLoi: $1\033[0m"
    exit 1
}
# -------------------------------------------------------------------------------------------------------------------------------

#+++

# -------------------------------------------------------------------------------------------------------------------------------
echo "=== DANG CAI DAT WPSILA ==="
# 1. Kiểm tra xem đang chạy với quyền gì
if [[ $EUID -ne 0 ]]; then
# Yêu cầu chạy quyền ROOT
    echo -e "${RED}Ban phai chay script voi quyen root.${NC}"
    exit 1
fi

# Kiểm tra hệ điều hành có phù hợp hay không?
# Yêu cầu Ubuntu 22.04 hoặc 24.04
if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    # Xóa dấu ngoặc kép nếu có (ví dụ "24.04" -> 24.04)
    CURRENT_VER=$(echo "$VERSION_ID" | tr -d '"')
    
    if [[ "$ID" != "ubuntu" ]] || [[ ! "$CURRENT_VER" =~ ^(22.04|24.04)$ ]]; then
        echo -e "${RED}[!] Loi: WPSILA chi ho tro Ubuntu 22.04 va 24.04.${NC}"
        echo -e "[!] He dieu hanh cua ban: $PRETTY_NAME"
        exit 1
    fi
    echo -e "${GREEN}[OK]${NC} He dieu hanh hop le: $PRETTY_NAME"
else
    echo -e "${RED}[!] Khong tim thay thong tin he dieu hanh!${NC}"
    exit 1
fi

# Kiểm tra xem có phải là yêu cầu update mã nguồn không
UPDATE_WPSILA="${1:-noupdate}"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 2. Tạo thư mục cho mã nguồn của wpsila
if [[ ! -d "$INSTALL_DIR" ]]; then
    mkdir -p "$INSTALL_DIR"
fi

# Chặn ghi đè
if [[ "$UPDATE_WPSILA" != "update" ]]; then
    # Kiểm tra sự tồn tại của file cấu hình
    if [[ -f "${INSTALL_DIR}/wpsila.conf" ]]; then
        echo -e "${RED}[!] Tim thay file cau hinh: ${INSTALL_DIR}/wpsila.conf${NC}"
        echo -e "${RED}[!] Ban da cai dat wpsila truoc day!${NC}"
        echo -e "----------------------------------------------------------------"
        echo -e "Chung toi dung chay de tranh ghi de co the gay loi website."
        echo -e "----------------------------------------------------------------"
        exit 0
    fi
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 3. Cài đặt wget, ca-certificates, coreutils và python3
# -------------------------------------------------------------------------------------------------------------------------------

# Hàm kiểm tra gói (Dùng dpkg để chính xác cho cả lệnh và thư viện)
is_pkg_installed() {
    dpkg -s "$1" &> /dev/null
}

# Danh sách các gói cần thiết
REQUIRED_PKGS="wget ca-certificates coreutils python3"
NEED_INSTALL=false

for pkg in $REQUIRED_PKGS; do
    if ! is_pkg_installed "$pkg"; then
        NEED_INSTALL=true
        break
    fi
done

if [ "$NEED_INSTALL" = true ]; then
# -------------------------------------------------------------------------
# Tắt tiến trình chạy cập nhật ngầm của Ubuntu
# -------------------------------------------------------------------------

# Tương đương module anti_apt_lock.sh (trong install_lcmp.sh) >>
# >> nhưng cái này là file cài đầu tiên nên phải nhúng trực tiếp

# Hàm khôi phục sau khi cài xong
	restore_environment() {
		echo ">>> [System] Bat lai che do cap nhat nen..."
		# Gỡ bỏ lệnh cấm (unmask) và khởi động lại timer
		systemctl unmask apt-daily.service apt-daily-upgrade.service > /dev/null 2>&1
		systemctl unmask apt-daily.timer apt-daily-upgrade.timer > /dev/null 2>&1
		systemctl start apt-daily.timer apt-daily-upgrade.timer > /dev/null 2>&1
	}

# Hàm xử lý lock chuyên nghiệp - An toàn tuyệt đối
	prepare_environment() {
		echo ">>> [System] Dang kiem tra che do cap nhat nen cua Ubuntu..."

		# 1. MASKING: Tạm thời vô hiệu hóa trigger cập nhật
		# Dùng 'mask' mạnh hơn 'stop'. Nó ngăn systemd kích hoạt service dù có ai đó cố tình gọi.
		systemctl mask apt-daily.service apt-daily-upgrade.service > /dev/null 2>&1
		systemctl mask apt-daily.timer apt-daily-upgrade.timer > /dev/null 2>&1

		# 2. WAITING: Chờ đợi văn minh (Không kill)
		# Danh sách các file lock quan trọng
		local LOCK_FILES=(
			"/var/lib/dpkg/lock-frontend"
			"/var/lib/dpkg/lock"
			"/var/lib/apt/lists/lock"
			"/var/cache/apt/archives/lock"
		)

		local TIMEOUT=300 # Chờ tối đa 5 phút (300s) cho tiến trình cũ update xong
		local COUNT=0

		# Vòng lặp kiểm tra xem có tiến trình nào đang giữ lock không
		# fuser trả về 0 nghĩa là có tiến trình đang dùng file -> Cần chờ
		while fuser "${LOCK_FILES[@]}" >/dev/null 2>&1; do
			if [ "$COUNT" -ge "$TIMEOUT" ]; then
				echo "!!! [Loi] Qua trinh cap nhat he thong bi ket lai qua lau (> 5 phut)."
				echo "!!! Vui long cai lai va chay script wpsila ngay sau khi cai."
				# Chuyên nghiệp là: Nếu kẹt quá lâu, hãy dừng lại báo lỗi thay vì phá hỏng hệ thống
				# Tuy nhiên, bước unmask bên dưới vẫn phải chạy để trả lại trạng thái.
				restore_environment
				exit 1
			fi
			
			echo ">>> Dang cho cap nhat nen hoan tat... ($((TIMEOUT - COUNT))s con lai)"
			sleep 5
			COUNT=$((COUNT + 5))
		done

		echo ">>> [System] Khoa da duoc mo. San sang cai dat."
	}

	echo "2. Thiet lap moi truong cai dat..."

	# Gọi hàm khóa môi trường
	prepare_environment

	# [QUAN TRỌNG] Đặt TRAP ngay lập tức sau khi khóa. 
	# Nếu script lỗi bất cứ đâu từ dòng này trở đi, nó sẽ tự động chạy restore_environment
	trap restore_environment EXIT
# -------------------------------------------------------------------------

    echo "Dang cai dat/cap nhat cac goi phu thuoc: $REQUIRED_PKGS..."
	# shellcheck disable=SC2086
    if apt-get update -qq && apt-get install -y -qq $REQUIRED_PKGS; then
       echo "Cai dat thanh cong cac goi co ban."
    else
       error_exit "Khong the cai dat cac phu thuoc co ban."
    fi
else
    echo "${GREEN}Tat ca cac goi phu thuoc da co san.${NC}"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 4. Làm sạch file cũ (Clean Install)
echo "Dang lam sach thu muc cai dat..."
# Xóa toàn bộ file .sh cũ nếu có
rm -f "$INSTALL_DIR/"*.sh
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 4.1 MA BASH DE DAN VAO install_wpsila.sh
# Sử dụng mã generate_checksum bên branches Dev chạy để lấy mã này về
# Dev bắt buộc phải dùng trước khi công bố phiên bản mới
# Có tác dụng ngăn chặn các vấn đề liên quan đến lỗi đường truyền
# ----------------------------------------------------------------------------
# Generated at: Thu Dec 25 09:28:26 +07 2025
# Version: v0.3.1
declare -A CHECKSUMS=(
    ["wpsila.conf"]="37949dce87686d946195ae65dcd0e1e95a763c1bfa40ee7c2583f20040680ac2"
    ["wpsila_menu.sh"]="015d72aade1e588ace99246a70e72e9bfa76d53c6e26d72629e27d2d9bfe5787"
    ["install_lcmp.sh"]="bbaa4ffd3f2c5c75acaed80833ebdba724f60393e028e1a709fca67377e5fa1f"
    ["anti_apt_lock.sh"]="156b35535f96580641f177f01120d46817f7da366bdd5221215be6a8333ec4f6"
    ["install_caddyserver.sh"]="96f9a5ed4e6b39ef696c30f5689d5a8b68b951f3d4cd43a5351df7433aafa601"
    ["install_php.sh"]="d88717e1a8bfc21f6de225da608433e79f4c8c71e62da8690b4f6ab2008cfd88"
    ["install_mariadb.sh"]="836c8e841fae50429f0e4b3941aa03745f9818f6b1c77bddc2f72bc2680f88cd"
    ["install_wp.sh"]="e162aa3b5ec2dc09caf6c1a9a62c93a77fbf8f5ec7d417ae416b736756ca312c"
    ["domain_check.sh"]="a702ed01bc140bcec5f46ec7f5c6a1fb700a0c8480a5f5ba8e3920a048478e0b"
    ["database_user_wp.sh"]="b8f828f59972c5d2bcb874ead560022f6fc62d2ba6bcb949c4162e863e11b792"
    ["wordpress.sh"]="cdd28f30d6ae4c2b587ec58f86d57a2cd78933afcfd93bc72b532aa6c80157f9"
    ["caddyfile.sh"]="1dc3c517126f4fabca597e3d934b4a83d48a816a64a92dab4f03d2302ba81d00"
    ["caddyfile_subdomain.sh"]="2e88d32e2a265732b5712ea9682fedb9be4df3ba744191f9578700483dfaee0b"
    ["tune_mariadb.sh"]="c0d6d37705ac870429150ad8a05a2fc9628a0c1a0b5fe0588588f9686187eb28"
    ["tune_php.sh"]="ee512b5608f0c6151b8f4281a895854e34638a62d3b59e056b307d8ad516760c"
    ["tune_pool.sh"]="c5bbbbbbabc788b28148e1b41ee1f1786c214f945923670a6d2ca47f191255cf"
    ["remove_web.sh"]="e2fd8a2174fda78c07be1524b389837616c17b2871a2506237fb1a31c0a09520"
    ["setup_sftp.sh"]="204de081c8bdbb2ff384ac9f2506d35036ae2983cf05cf1b23b66d886b3d483f"
    ["setup_adminer.sh"]="63ede23b94cc968050a577ca0e1492423a1825f6624d74b00ef6425e9251e22a"
    ["show_pass.sh"]="1cef0cde8bb5b444ba55b0be9cf676c4bd246f20221ad041d8f5c4aa5785e2e3"
    ["check_for_update.sh"]="678099ed54dc58d73c4549c3d4c7afc721ad33c87de129a1655ca4ec3cd242d4"
)
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 5. Tải file
echo "Dang tai cac module..."

download_file() {
    local filename="$1"
    local dest="$2"
    local url="$REPO_URL/$filename"
    local expected_checksum="${CHECKSUMS[$filename]}"

    # 1. Tien hang tai file
    # Thêm --tries=3 --timeout=15 để hạn chế vấn đề mạng lag
    if ! wget -q --no-cache --tries=3 --timeout=15 "$url" -O "$dest"; then
        echo -e "${RED}[DOWNLOAD FAIL]${NC} Khong the tai: $url"
        rm -f "$dest"
        error_exit "Loi ket noi hoac duong dan khong chinh xac."
    fi

    # 2. Kiem tra file tai ve co du lieu khong
    if [[ ! -s "$dest" ]]; then
        rm -f "$dest"
        error_exit "File tai ve bi rong (0 bytes): $dest"
    fi

    # 3. KIEM TRA CHECKSUM
    if [[ -n "$expected_checksum" ]]; then
        local actual_checksum
        actual_checksum=$(sha256sum "$dest" | awk '{print $1}')

        if [[ "$actual_checksum" != "$expected_checksum" ]]; then
            echo -e "${RED}[CHECKSUM FAIL]${NC} Tap tin $filename bi thay doi hoac bi hong!"
            rm -f "$dest"
            error_exit "Checksum khong khop. Viec cai dat bi huy bo."
        fi
        echo -e "${GREEN}[CHECKSUM OK]${NC} $filename"
    fi
}
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Nếu thay đổi, bổ sung file tải về (hoặc thay đổi nội dung trong file) thì  >
# > bắt buộc phải cập nhật cả checksum được khai báo bên trên.
# Nếu thiếu mã checksum sẽ không thể tải về được, dev cần lưu ý.

# File cấu hình (chứa định nghĩa phiên bản PHP)
# Nếu là cài mới thì sẽ xóa (nếu có) và tải file mới về
# wpsila.conf cũng sẽ được tải về nếu kiểm tra cho thấy nó chưa tồn tại

# 5.1 VÒNG LẶP TỰ ĐỘNG TẢI FILE
# Lấy danh sách key (tên file) từ mảng CHECKSUMS
# Điều này giúp tránh sơ suất không tải file khi có cập nhật thêm file, đỡ phải thêm download_file thủ công
for filename in "${!CHECKSUMS[@]}"; do
    dest="$INSTALL_DIR/$filename"

    # XỬ LÝ NGOẠI LỆ: wpsila.conf
    # File cấu hình cần logic riêng để tránh ghi đè khi Update
    if [[ "$filename" == "wpsila.conf" ]]; then
        # Nếu là Update VÀ file đã tồn tại -> Bỏ qua (Giữ cấu hình cũ)
        if [[ "$UPDATE_WPSILA" == "update" && -f "$dest" ]]; then
            echo -e "${YELLOW}[KEEP]${NC} Dang su dung file cau hinh hien tai: $filename"
            continue # Chuyển sang file tiếp theo trong vòng lặp
        fi
        # Nếu không phải update, hoặc file thiếu -> Code sẽ chạy xuống dưới để tải mới (Ghi đè)
    fi

    # Thực hiện tải file
    download_file "$filename" "$dest"
done
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 6. Phân quyền
chmod 700 "$INSTALL_DIR"
chmod 700 "$INSTALL_DIR/"*.sh
chmod 700 "$INSTALL_DIR/"*.conf

# Hơi thừa nhưng bổ sung cho chắc!
chmod +x "$INSTALL_DIR/wpsila_menu.sh"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 7. Tạo Symlink an toàn
rm -f "$BIN_LINK"
ln -sf "$INSTALL_DIR/wpsila_menu.sh" "$BIN_LINK"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 8. Hoàn tất
if [[ -x "$BIN_LINK" ]]; then
    echo -e "${GREEN}=== CAI DAT THANH CONG! ===${NC}"
	echo -e "Phien ban: ${GREEN}${SILA_VERSION}${NC}"
    echo -e "Xin chuc mung ban! Hay go lenh: ${YELLOW}wpsila${NC} de bat dau su dung."
else
    error_exit "Loi khi tao lenh shortcut wpsila."
fi
# -------------------------------------------------------------------------------------------------------------------------------