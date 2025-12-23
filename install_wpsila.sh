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
# Version 0.3.0 - 23/12/2025
# -------------------------------------------------------------------------
# Test
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/install_wpsila.sh | sudo bash
# -------------------------------------------------------------------------

# Dừng script ngay lập tức nếu có biến chưa khai báo hoặc pipeline bị lỗi
# Lưu ý: set -e sẽ được xử lý khéo léo trong hàm download để không ngắt script đột ngột
set -euo pipefail

# Thiet lap moi truong chuan cho Automation
export LC_ALL=C.UTF-8
export DEBIAN_FRONTEND=noninteractive

# Phiên bản của bash script / rất quan trọng để tải đúng phiên bản các file cài tương ứng
SILA_VERSION="v0.3.0"

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
# --- Cấu hình ---
# Thư mục lưu các file cài đặt
# Thêm tiền tố kiencang để giảm tối đa xác suất trùng tên
INSTALL_DIR="/opt/kiencang-wpsila"

# Chú ý link Repo, cần cập nhật cả vps.wpsila.com nếu nó có thay đổi
# vps.wpsila.com là nơi chứa mã nguồn này, có thể để chuyển hướng hoặc chứa trực tiếp.
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

# Kiểm tra xem có phải là yêu cầu update không
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
				echo "!!! [Loi] Qua trinh cap nhat he thong bi ket qua lau (> 5 phut)."
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
    echo "Tat ca cac goi phu thuoc da co san."
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
# Sử dụng mã generate_checksum chạy để lấy mã này về
# Dev bắt buộc phải dùng trước khi công bố phiên bản mới
# ----------------------------------------------------------------------------
# Generated at: Tue Dec 23 21:44:41 +07 2025
# Version: v0.3.0
declare -A CHECKSUMS=(
    ["wpsila.conf"]="37949dce87686d946195ae65dcd0e1e95a763c1bfa40ee7c2583f20040680ac2"
    ["wpsila_menu.sh"]="a457874ea10c7f30ddae4aac9e9c33fbc07ff1f421cec449a8e881987b6c1292"
    ["install_lcmp.sh"]="063980fde7ccb560e2a3ad77330f8468319d973f6ee5e02bcc944a0774185ab0"
    ["install_caddyserver.sh"]="96f9a5ed4e6b39ef696c30f5689d5a8b68b951f3d4cd43a5351df7433aafa601"
    ["install_php.sh"]="d88717e1a8bfc21f6de225da608433e79f4c8c71e62da8690b4f6ab2008cfd88"
    ["install_mariadb.sh"]="836c8e841fae50429f0e4b3941aa03745f9818f6b1c77bddc2f72bc2680f88cd"
    ["install_wp.sh"]="3841e2885a9768cbf151cc3d46edecd3aa581f3390f11f77d6d66dc76808a0d0"
    ["domain_check.sh"]="8d3c4b17c7552e9b333920680ef92cd0c4b298313e612e21824086698e52b975"
    ["database_user_wp.sh"]="b8f828f59972c5d2bcb874ead560022f6fc62d2ba6bcb949c4162e863e11b792"
    ["wordpress.sh"]="ce41642e1c7fe06240559f2f6181c49c2d25e1425c7fb02d01b16de1ca602368"
    ["caddyfile.sh"]="6cf2a24585b0f6b8c367039f8ae520a9a21f6fe9571d32312104d0cf48a11460"
    ["caddyfile_subdomain.sh"]="6aaac1fe52f407be8895531ac3a57fb56094f051e4dbab027a460c2b72a97d9b"
    ["tune_mariadb.sh"]="c0d6d37705ac870429150ad8a05a2fc9628a0c1a0b5fe0588588f9686187eb28"
    ["tune_php.sh"]="745a110a84afee44b0318302b1edb5a4d2a5bf598a8aa1b905dff455eec37e3d"
    ["tune_pool.sh"]="a8c07af10b5a5c5291119cce2bfe749edf3528ccf4dad254e8132b563a12ed83"
    ["remove_web.sh"]="e3fa30d6895e86c2005665932b4214bf895925dccfa31bf21f8ba2183b755d95"
    ["setup_sftp.sh"]="147be0ddafcfbd162ffd69ec0753aa81ea2b68bc10a0313da4359824df921ab0"
    ["setup_adminer.sh"]="dc2422443b9609c03e8b7f4e3f249a8c7cd2be73d3f66930aa89b6f9dae751ad"
    ["show_pass.sh"]="ea1877c03f225a3ca28693191b348cd5359e2cefaa9a7cae79f3478ca7c5e6c9"
    ["check_for_update.sh"]="2d9b5d90af2b7f3759115bccf7a661054318c4066ff723cfd5ea218ea70aefcd"
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
# Giải thích ý nghĩa
# Tải về cấu hình version php & mariadb wpsila
# "wpsila.conf" 
# -------------------------

# Tải về menu cho chương trình quản trị wpsila
# "wpsila_menu.sh" 
# -------------------------

# -------------------------
# Tải về các file phục vụ cho cài đặt LCMP
# "install_lcmp.sh" 
# "install_caddyserver.sh" 
# "install_php.sh" 
# "install_mariadb.sh" 
# -------------------------

# -------------------------
# Tải về các file phục vụ cho việc cài đặt WordPress
# "install_wp.sh"
# "domain_check.sh"
# "database_user_wp.sh"
# "wordpress.sh" 
# "caddyfile.sh"
# "caddyfile_subdomain.sh"
# -------------------------

# -------------------------
# Tải về các file để thiết lập cấu hình cho MariaDB và PHP INI cũng như Pool Tune
# "tune_mariadb.sh" 
# "tune_php.sh" 
# "tune_pool.sh" 
# -------------------------

# -------------------------
# Tải về file phục vụ chức năng xóa website
# "remove_web.sh"
# -------------------------

# -------------------------
# Tải về file tạo tài khoản sFTP
# "setup_sftp.sh"
# -------------------------

# -------------------------
# Tải về file cài adminer để tạo trang quản trị database (không cài nếu không cần)
# "setup_adminer.sh"
# -------------------------

# -------------------------
# File để hiển thị mật khẩu 
# "show_pass.sh" "$INSTALL_DIR/show_pass.sh"

# -------------------------
# Kiểm tra cập nhật cho wpsila
# "check_for_update.sh"
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