#!/bin/bash

# -------------------------------------------------------------------------------------------------------------------------------
set -euo pipefail

# Phiên bản hiện tại của wpsila
SILA_VERSION="v1.4.0"
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
# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/install_wpsila.sh | sudo bash
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
		echo ">>> [System] Bat lai che do cap nhat nen..."
		# Gỡ bỏ lệnh cấm (unmask) và khởi động lại timer
		systemctl unmask apt-daily.service apt-daily-upgrade.service &> /dev/null
		systemctl unmask apt-daily.timer apt-daily-upgrade.timer &> /dev/null
		systemctl start apt-daily.timer apt-daily-upgrade.timer &> /dev/null
	}

# Hàm xử lý lock chuyên nghiệp - An toàn tuyệt đối
	prepare_environment() {
		echo ">>> [System] Dang kiem tra che do cap nhat nen cua Ubuntu..."

		# 1. MASKING: Tạm thời vô hiệu hóa trigger cập nhật
		# Dùng 'mask' mạnh hơn 'stop'. Nó ngăn systemd kích hoạt service dù có ai đó cố tình gọi.
		systemctl mask apt-daily.service apt-daily-upgrade.service &> /dev/null
		systemctl mask apt-daily.timer apt-daily-upgrade.timer &> /dev/null

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
		while fuser "${LOCK_FILES[@]}" &> /dev/null; do
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
    echo -e "${GREEN}Tat ca cac goi phu thuoc da co san.${NC}"
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
=== KET QUA: Copy doan duoi day va thay vao script cai dat ===
# --------------------------------------------------------------------------------
# Generated at: Fri Nov 13 11:28:29 +07 2026
# Version: v1.4.0
declare -A CHECKSUMS=(
    ["wpsila.conf"]="2edbaef3dc7bbef03470455a6c12b3b594ca83db8bdf787efafe8f8e61a09b95"
    ["wpsila_menu.sh"]="587fd60b75eecbd71dd68b57cad2c21b908eac7e1b80c0b7424f058659946bb8"
    ["install_lcmp.sh"]="a6ba5f85efe5bc4f982299b4cc3498074b880e6c316dec7c58b305e12f5a70f2"
    ["anti_apt_lock.sh"]="394a3f452371795ea6a8924f74580c6cbaaa8feeabd05e8e6bb24b91e7d7a7d5"
    ["install_caddyserver.sh"]="84724a1186c738331d2978a297405185f537ed871d03c4334d19f72f51e27c20"
    ["install_php.sh"]="d7f68130f6b77e3cdc690a5de23852d6127a1a44e8f6b9c981ae4b6b9ea05169"
    ["install_mariadb.sh"]="35920ed9e452a78cbc0527d97fcb39ba5e6b4194310a72feb829b8878c58452d"
    ["install_wp.sh"]="d849eedeb5bb7f16dc34800f8de023268184aac81c42f07a6907bb313cb91564"
    ["domain_check.sh"]="1905c2648924e3c9ab42608b9701ef4d7692cbf38893d2d560ce621db5f423f4"
    ["database_user_wp.sh"]="9f11dc3c7426dc8fb0adcef3cdea9f5a09bf71b0c0529ebf8efeac9d2f730972"
    ["wordpress.sh"]="cde4111c7f938497f493cdea81599a2f6e541251d199580b3b27287756bcf6d6"
    ["caddyfile.sh"]="a3b05f58c453b3f00d16cda865a00594085115b37d38648d6b4814308f277c8a"
    ["caddyfile_subdomain.sh"]="aa20c4c329db51deb09481c1f36d38da0b2d15950534c830cdede12e952c73ad"
    ["tune_mariadb.sh"]="a76ca6118bfbad12a86e2b049ca691efbc795b8cda964d85b2228825ee6ccb3b"
    ["tune_php.sh"]="e223f83eefacb4fa6c8f40a009c8b24d9507fc1cc5675d07ba8aca8634cc564a"
    ["tune_pool.sh"]="a3a1d33ed044576348315121ed4e69a894ef539934b52ab637ba943319a82b6b"
    ["setup_swap.sh"]="bcfa315ec6dffdb0c9c5573d2fe66338a8dac68e0ef6bf35cc3fa2e70e964780"
    ["setup_fail2ban_core.sh"]="8ecb74309fde4408c3335399b183a43bd629659fe981c12146eb9aa53cdf3d00"
    ["remove_web.sh"]="85af7ec4dc09690ab389a3b40e0b42295da3e2c12a12d6127172fff4b75b6485"
    ["setup_sftp.sh"]="0bf74ffa3ab770a55a19238b08adf707b77cdaa53bafa0f99f35fd280e10dd79"
    ["setup_adminer.sh"]="d916b8bb0f94b1b0073f7bf71159a67cee2c27932d965a7cf5eef1638d299460"
    ["show_pass.sh"]="35124c7bd96c1ec3f8dfaf8e69d75dc8b02d8c0f562d380c47b86613be7fc148"
    ["check_for_update.sh"]="689b57659467bcb8f1cdf4d684edb31c2863e76f8410d26ae27e581f9ed55d3f"
    ["manage_wp_config.sh"]="c78466bda9f929952f0390603954c1d53cf105a879d8747e27dcbc03ba83cf45"
    ["view_logs.sh"]="61b0ed4e76e7cbfc76c5266acb9b8ac2760b46b43b8d3d2ff23676ba5aee241e"
    ["wp_reset_pass.sh"]="9409b9404c29815db0cfe355c530ed48ced435f1457074108e3740349b45aed7"
    ["get_db_info.sh"]="856989c4e1496fdd69d3cae62d7205ec2d651d74ee08d1b2da572792873be152"
    ["install_redis_cache.sh"]="250ab0b39ea072137fa25bb478a68787e785fc31ecb991c0955ceac50b2b90fe"
    ["uninstall_redis_cache.sh"]="415356e7c5e60cd6c80f74f0449c026660d46d498d68574fdc27f84d1ce8723e"
    ["remove_pass_files.sh"]="83fcd53c7a37d824052cc80e02752402c601b021b095e478eb4dcf8658e2f249"
    ["list_websites.sh"]="d529f286f0fd8b0db3f71c924af855cc2bbc9a683ea0613a21ed2729d22f1fb4"
    ["manage_backup.sh"]="904eb11318d9b3fed5bc910ea6faf80d4acdfd19a6e4e307686cc87dd3ad60e7"
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
        # Nếu không phải update, hoặc file thiếu -> Code sẽ chạy xuống dưới để tải mới (Ghi đè)
    fi

    # Thực hiện tải file
    download_file "$filename" "$dest"
done
unset filename dest # HỦY BIẾN TẠM
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
