#!/bin/bash

# -------------------------------------------------------------------------------------------------------------------------------
set -euo pipefail

# Phiên bản hiện tại của wpsila
SILA_VERSION="v1.4.2"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

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
# Test trước khi đẩy lên link chính
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/test/install_wpsila.sh | sudo bash
# -------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Thiet lap moi truong chuan cho Automation
export LC_ALL=C.UTF-8
export DEBIAN_FRONTEND=noninteractive
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
STAGE_DIR=""
APT_PREP_ACTIVE=0

cleanup_staging() {
    if [[ -n "${STAGE_DIR:-}" && -d "$STAGE_DIR" ]]; then
        rm -rf "$STAGE_DIR"
    fi
}

on_exit() {
    cleanup_staging
    if (( APT_PREP_ACTIVE == 1 )) && declare -F restore_environment &>/dev/null; then
        restore_environment
    fi
}
trap on_exit EXIT

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
REQUIRED_PKGS="wget ca-certificates coreutils python3 psmisc"
NEED_INSTALL=0

for pkg in $REQUIRED_PKGS; do
    if ! is_pkg_installed "$pkg"; then
        NEED_INSTALL=1
        break
    fi
done
unset pkg # HỦY BIẾN TẠM

if (( NEED_INSTALL == 1 )); then
# -------------------------------------------------------------------------
# Tắt tiến trình chạy cập nhật ngầm của Ubuntu
# -------------------------------------------------------------------------

# Tương đương module anti_apt_lock.sh (trong install_lcmp.sh) >>
# >> nhưng cái này là file cài đầu tiên nên phải nhúng trực tiếp

# Hàm khôi phục sau khi cài xong
	restore_environment() {
		if (( APT_PREP_ACTIVE == 0 )); then
			return 0
		fi
		APT_PREP_ACTIVE=0
		echo ">>> [System] Bat lai che do cap nhat nen..."
		# Gỡ bỏ lệnh cấm (unmask) và khởi động lại timer (có || true để an toàn với set -e)
		systemctl unmask apt-daily.service apt-daily-upgrade.service &> /dev/null || true
		systemctl unmask apt-daily.timer apt-daily-upgrade.timer &> /dev/null || true
		systemctl start apt-daily.timer apt-daily-upgrade.timer &> /dev/null || true
	}

# Hàm xử lý lock chuyên nghiệp - An toàn tuyệt đối
	prepare_environment() {
		echo ">>> [System] Dang kiem tra che do cap nhat nen cua Ubuntu..."

		# 1. MASKING: Tạm thời vô hiệu hóa trigger cập nhật
		# Dùng 'mask' mạnh hơn 'stop'. Nó ngăn systemd kích hoạt service dù có ai đó cố tình gọi.
		systemctl mask apt-daily.service apt-daily-upgrade.service &> /dev/null || true
		systemctl mask apt-daily.timer apt-daily-upgrade.timer &> /dev/null || true

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

		is_apt_locked() {
			if command -v fuser &>/dev/null; then
				fuser "${LOCK_FILES[@]}" &>/dev/null
				return $?
			else
				pgrep -x "apt|apt-get|dpkg|unattended-upgr" &>/dev/null
				return $?
			fi
		}

		# Vòng lặp kiểm tra xem có tiến trình nào đang giữ lock không
		while is_apt_locked; do
			if [[ "$COUNT" -ge "$TIMEOUT" ]]; then
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
	APT_PREP_ACTIVE=1
	prepare_environment
# -------------------------------------------------------------------------

    echo "Dang cai dat/cap nhat cac goi phu thuoc: $REQUIRED_PKGS..."
	# shellcheck disable=SC2086
    if apt-get update -qq && apt-get install -y -qq $REQUIRED_PKGS; then
       echo "Cai dat thanh cong cac goi co ban."
    else
       error_exit "Khong the cai dat cac phu thuoc co ban."
    fi
else
    echo -e "${GREEN}Tat ca cac goi phu thuoc da co san.${NC}"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 4. Chuẩn bị thư mục tạm để tải Atomic (chỉ thay thế code cũ sau khi tất cả file vượt qua Checksum SHA-256)
echo "Dang chuan bi thu muc tam tai module..."
STAGE_DIR=$(mktemp -d)
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 4.1 MA BASH DE DAN VAO install_wpsila.sh
# Sử dụng mã generate_checksum bên branches Dev chạy để lấy mã này về
# Dev bắt buộc phải dùng trước khi công bố phiên bản mới
# Có tác dụng ngăn chặn các vấn đề liên quan đến lỗi đường truyền
# --------------------------------------------------------------------------------
# Generated at: Sat Nov 14 02:30:00 +07 2026
# Version: v1.4.1
declare -A CHECKSUMS=(
    ["wpsila.conf"]="2edbaef3dc7bbef03470455a6c12b3b594ca83db8bdf787efafe8f8e61a09b95"
    ["wpsila_menu.sh"]="3cb27b2c258eda66b5ec0935ebf164f8541f845de87c787d3cabf9e795a70023"
    ["install_lcmp.sh"]="8bc03a81c0ad9cda5679b3e81f605b6618a724dd013245ed9c20d7b7038b936b"
    ["anti_apt_lock.sh"]="e08e831caea1293e6337cb42af42c40693d643c28540b137bbffa800e052bb3e"
    ["install_caddyserver.sh"]="3034cbb7a0f44ee2add77612a346cc6a8ad59767c3f4cd11adae50d6b6e30534"
    ["install_php.sh"]="a16049dbfe54b31edcdfe69da4bce5fc8120f7ace834ac6fd099d2e96d956c45"
    ["install_mariadb.sh"]="2b1f090a2b128ae304afc8c7b3ee3d36d4d65aa84a547f959e2d271d4820f076"
    ["install_wp.sh"]="34e2547b4d1a91a6bdd1f974cf572fdddc674e9708b54f93fac639437c0e04ad"
    ["domain_check.sh"]="6c3f9c63dfea59ccc7a10b6ed4cb71c6ddb86dbc236fbccd0b29c8d76874c59d"
    ["database_user_wp.sh"]="ed8916a89e7aef148b8a3c79bbf749b36161d78702489136658062321e219eb5"
    ["wordpress.sh"]="f2b6389a2effd3df3f3bfeabd67d03e24d5d43cb481c71579c0e619785bcf0af"
    ["caddyfile.sh"]="585bbe08560c19650bbcbdad70057e618bb0a7aebaf594b3fa709a1232f994e6"
    ["caddyfile_subdomain.sh"]="c2c664f1bf891236bb6436ba04287dc2e10be52875c6f13ef0187016f812b242"
    ["tune_mariadb.sh"]="730e9be0290af943a5886a283558d5763342a1faa11555bb4672b507eaeb7037"
    ["tune_php.sh"]="48d6bfbbad9c060a39feae5c0a7d879e7fbfe7007335ee4d593712ee9cd8ad8c"
    ["tune_pool.sh"]="2d3d441502e956e58171e336c57ea878b7cc1ed28ccf3b31d53b0bbbe87e5c43"
    ["setup_swap.sh"]="45e43fe28c486a897a6cbcd268e3312b5caf1ba67912d9cb4e2f407c97988757"
    ["setup_fail2ban_core.sh"]="1902d32ef519956ad5016af43655d0168df78108bfaf17a1f7f7c24426bc8a19"
    ["remove_web.sh"]="44d3fe2bb2e6ea15392bce0f80d0ab70cfa7072bbe471a5c4c528f0f4f346c28"
    ["setup_sftp.sh"]="822d6681c81970aea64f04df7241c6ac52205ef2324ebdf7c28deb565191ef9d"
    ["setup_adminer.sh"]="9b131d03d0e076191a35c16c80b6623352daab28f771ab554216c6aa1f046375"
    ["show_pass.sh"]="3babb5a8ea49dea2bd54ed1d685109f6fa2b882d854fdc6d869daa9246203ef1"
    ["check_for_update.sh"]="286e388f0979dcf77243a66da0ff457446391e28592a107dfd1e6719bdfff29d"
    ["manage_wp_config.sh"]="2a30e8c4c6b9ca102bf5b97e584af50099046b607a153f8b41372cc8075c8bdd"
    ["view_logs.sh"]="dee27976ed367edae02ab07b942337f88ca8ef94184de3b2dfd7e4ee8d368826"
    ["wp_reset_pass.sh"]="100f648d5b735dea30989d6f9d9d26586dbe2b59bd92ae635fcc21abb0d708b6"
    ["get_db_info.sh"]="44a17af322c2e6c79b0022d2095057207f4ef666fee6739b8da9ece338a625aa"
    ["install_redis_cache.sh"]="2d4f4a91f6ef9623a2e309b4927ae4d3812702003389e8014992e99e0b9dd87a"
    ["uninstall_redis_cache.sh"]="51e6811b4eaf8ccbd0239628c3bb22c8bed171e2302bd8356db56deb001fb201"
    ["remove_pass_files.sh"]="83fcd53c7a37d824052cc80e02752402c601b021b095e478eb4dcf8658e2f249"
    ["list_websites.sh"]="5c208a5296994676f9ba09fff35fdcf1b3bcda1ccc08ee39afd6102a0f305dbc"
    ["manage_backup.sh"]="531880c6260662f03b6ec49ad76ac4b19898ee4bb78e3f0001335e2c514dc1bb"
)
# --------------------------------------------------------------------------------

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
        # Nếu không phải update, hoặc file thiếu -> Tải mới vào staging để thay thế
    fi

    # Thực hiện tải file vào thư mục tạm trước (Atomic Staging)
    download_file "$filename" "$STAGE_DIR/$filename"
done
unset filename dest # HỦY BIẾN TẠM

# Toàn bộ file đều tải thành công và khớp Checksum SHA-256 -> Cập nhật đồng bộ vào thư mục đích
rm -f "$INSTALL_DIR/"*.sh
mv -f "$STAGE_DIR/"* "$INSTALL_DIR/"
cleanup_staging
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
    echo -e "Xin chuc mung ban! Hay go lenh: ${YELLOW}sudo wpsila${NC} de bat dau su dung."
else
    error_exit "Loi khi tao lenh shortcut wpsila."
fi
# -------------------------------------------------------------------------------------------------------------------------------
