#!/bin/bash

# -----------------------------------------------------------
# Thiết lập tài khoản sFTP
# File: setup_sftp.sh
# sFTP riêng cho từng website, không chung
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# A. Màu sắc cho thông báo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# SCRIPT TẠO TÀI KHOẢN SFTP (CHROOT JAIL)
# Dành cho cấu trúc: Vỏ /var/www/domain (root:root 755)
# Lõi /var/www/domain/public_html (root:www-data 2775)
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 1. KIỂM TRA QUYỀN ROOT
# NÂNG QUYỀN NẾU KHÔNG PHẢI LÀ ROOT
# 1. Kiểm tra xem đang chạy với quyền gì
if [[ $EUID -ne 0 ]]; then
   # 2. Nếu không phải root, tự động chạy lại script này bằng sudo
   # Thêm tham số -E cho sudo để giữ lại các biến môi trường (nếu có)
   sudo -E "$0" "$@"
   # 3. Thoát tiến trình cũ (không phải root) để tiến trình mới (có root) chạy
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Cx. Kiểm tra môi trường
# Script này yêu cầu Caddy và PHP đã được cài trước đó
echo -e "${GREEN}>>> Dang kiem tra moi truong he thong...${NC}"

if ! id "caddy" &>/dev/null; then
    echo -e "${RED}Loi: User 'caddy' chua ton tai.${NC}"
    echo -e "${YELLOW}Goi y: Cai dat Caddy Server truoc do chua thanh cong hoac ban chua cai Caddy Server (nhan so 1 de cai).${NC}"
    exit 1
fi

if ! id "www-data" &>/dev/null; then
    echo -e "${RED}Loi: User 'www-data' chua ton tai.${NC}"
    echo -e "${YELLOW}Goi y: Hay cai dat PHP-FPM.${NC}"
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 2. NHẬP THÔNG TIN
echo "--------------------------------------------------------"
echo "CONG CU TAO USER SFTP CHO WORDPRESS (SECURE MODE)"
echo "--------------------------------------------------------"
read -r -p "Nhap dia chi website (VD: example.com): " INPUT_DOMAIN < /dev/tty

# Sanitize input: Xóa khoảng trắng, chuyển chữ hoa thành chữ thường
DOMAIN=$(echo "$INPUT_DOMAIN" | tr -d ' ' | tr '[:upper:]' '[:lower:]')

# Kiểm tra đầu vào
if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}Loi: Dia chi website khong duoc de trong!${NC}"
    exit 1
fi

# Thoát sớm với định dạng sai
if [[ "$DOMAIN" != *"."* ]]; then
    echo -e "${RED}Loi: Dia chi website '$DOMAIN' khong hop le (thieu dau cham).${NC}"
    exit 1
fi

# Kiểm tra chặt hơn với cấu trúc tên miền tiêu chuẩn
if [[ ! "$DOMAIN" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*\.[a-z]{2,}$ ]]; then
    echo -e "${RED}Loi: Dia chi website '$DOMAIN' chua ky tu khong hop le hoac sai dinh dang.${NC}"
	exit 1
fi

# Qua được các cửa ải
if [[ "$INPUT_DOMAIN" != "$DOMAIN" ]]; then
    echo -e "${GREEN}Script da tu dong chuan hoa input '${INPUT_DOMAIN}' thanh '${DOMAIN}'${NC}"
fi

# Định nghĩa thư mục Vỏ (Jail)
JAIL_DIR="/var/www/$DOMAIN"

# Kiểm tra ngay khi nhập tên miền
if [[ ! -d "$JAIL_DIR" ]]; then
    echo "Loi: Thu muc $JAIL_DIR KHONG ton tai!"
    echo "Hay chac chan trang web co ton tai."
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Kiểm tra thông tin user sFTP
read -r -p "Nhap user sFTP moi: " SFTP_USER < /dev/tty

if [[ -z "$SFTP_USER" ]]; then
    echo "Loi: User '$SFTP_USER' khong duoc de trong!"
    exit 1
fi

if id "$SFTP_USER" &>/dev/null; then
    echo "Loi: User '$SFTP_USER' da ton tai tren he thong!"
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 4. THIẾT LẬP CẤU HÌNH HỆ THỐNG (Chạy 1 lần là dùng mãi mãi)
echo ""
echo "Dang kiem tra cau hinh he thong..."

# 4.1. Tạo group 'sftp_only' nếu chưa có
if ! getent group sftp_only > /dev/null; then
    groupadd sftp_only
    echo "Da tao group: sftp_only"
fi

# 4.2. Cấu hình SSHD (Phương pháp tách file config - Modern Way)
SSHD_CONFIG_MAIN="/etc/ssh/sshd_config"
SSHD_CONFIG_DIR="/etc/ssh/sshd_config.d"
SFTP_CONFIG_FILE="$SSHD_CONFIG_DIR/99-sftp-jail.conf"
NEED_RESTART=0

echo "Dang cau hinh SSH theo chuan moi (config.d)..."

# Bước 1: Kiểm tra xem thư mục config.d có tồn tại không (Mặc định Ubuntu 22/24 đều có)
if [[ ! -d "$SSHD_CONFIG_DIR" ]]; then
    mkdir -p "$SSHD_CONFIG_DIR"
fi

# Bước 2: Đảm bảo file config gốc có lệnh "Include"
# Hầu hết Ubuntu mặc định đã có dòng này ở đầu file.
# Nếu chưa có, ta phải thêm vào đầu file (hoặc cuối file cũng được, nhưng đầu file tốt hơn).
if ! grep -Fq "Include $SSHD_CONFIG_DIR/*.conf" "$SSHD_CONFIG_MAIN"; then
    echo "Canh bao: File config chinh chua co lenh Include. Dang them vao..."
    # Backup trước
    cp "$SSHD_CONFIG_MAIN" "${SSHD_CONFIG_MAIN}.bak"
    
    # Thêm dòng Include vào đầu file (sử dụng sed)
    # 1i nghĩa là insert vào dòng 1
    sed -i "1i Include $SSHD_CONFIG_DIR/*.conf" "$SSHD_CONFIG_MAIN"
    echo "Da them lenh Include vao $SSHD_CONFIG_MAIN"
fi

# Bước 3: Tạo file cấu hình riêng cho SFTP
# Chúng ta dùng tên 99-sftp-jail.conf để đảm bảo nó được load.
# Kiểm tra nếu nội dung file chưa đúng hoặc file chưa tồn tại thì ghi đè lại cho chắc.

# Nội dung cấu hình mong muốn
read -r -d '' SFTP_CONFIG_CONTENT << EOT || true
# --- SFTP JAIL CONFIGURATION ---
# Created by Auto Script
Match Group sftp_only
    ChrootDirectory %h
    ForceCommand internal-sftp -u 002
    AllowTCPForwarding no
    X11Forwarding no
    PasswordAuthentication yes
# -------------------------------
EOT

# Kiểm tra xem file đã tồn tại chưa
if [[ ! -f "$SFTP_CONFIG_FILE" ]]; then
    echo "$SFTP_CONFIG_CONTENT" > "$SFTP_CONFIG_FILE"
    echo "Da tao file cau hinh rieng: $SFTP_CONFIG_FILE"
    NEED_RESTART=1
else
    # Nếu file tồn tại, kiểm tra xem nội dung có khớp không (để tránh ghi đè không cần thiết)
    # Nếu nội dung khác nhau, ta ghi đè lại
    if [[ "$SFTP_CONFIG_CONTENT" != "$(cat "$SFTP_CONFIG_FILE")" ]]; then
        echo "$SFTP_CONFIG_CONTENT" > "$SFTP_CONFIG_FILE"
        echo "Da cap nhat noi dung file: $SFTP_CONFIG_FILE"
        NEED_RESTART=1
    else
        echo "Cau hinh SFTP trong $SFTP_CONFIG_FILE da chuan."
    fi
fi

# Bước 4: Kiểm tra và Reload SSH
if (( NEED_RESTART == 1 )); then
    if sshd -t; then
        systemctl reload ssh
        echo "Da reload dich vu SSH (Config an toan)."
    else
        echo "NGUY HIEM: File sshd config bi loi cu phap!"
        echo "Vui long kiem tra lai file $SFTP_CONFIG_FILE"
        # Xóa file gây lỗi để hệ thống hoạt động bình thường
        rm -f "$SFTP_CONFIG_FILE"
        echo "Da xoa file config gay loi de bao dam an toan cho Server."
		
        # Khôi phục lại file backup nếu cần thiết (tuỳ chọn)
		cp "${SSHD_CONFIG_MAIN}.bak" "$SSHD_CONFIG_MAIN"
        echo "-> Da khoi phuc lai file config cu."
        exit 1
    fi
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 5. TẠO USER VÀ PHÂN QUYỀN
echo ""
echo "Dang tao user '$SFTP_USER'..."

# Giải thích lệnh useradd:
# -d $JAIL_DIR : Home directory trỏ về /var/www/domain (Để SSH chroot vào đây)
# -s /usr/sbin/nologin : Không cho chạy lệnh shell (Bảo mật)
# -G www-data : Để user này có quyền ghi vào thư mục public_html (nhờ permission 2775)
# -G sftp_only : Để user này bị SSH config "tóm" lấy và nhốt vào lồng
# -N: Không tạo group riêng trùng tên user (dùng luôn group chính là www-data)
# -M: Không tạo home dir (vì thư mục đã có sẵn)
useradd -d "$JAIL_DIR" -s /usr/sbin/nologin -g www-data -G sftp_only -M -N "$SFTP_USER"

# --- [SUA LOI NHAP PASSWD] ---
# Thay vì dùng lệnh 'passwd' dễ lỗi, ta dùng 'read' để nhập vào biến trước
echo "Thiet lap mat khau tu dong cho user '$SFTP_USER':"

SFTP_PASS=sftp_$(openssl rand -hex 12)

# Mã hóa mật khẩu và gán trực tiếp (Bypass PAM check)
ENCRYPTED_PASS=$(openssl passwd -6 "$SFTP_PASS")
usermod -p "$ENCRYPTED_PASS" "$SFTP_USER"
echo "Da thiet lap mat khau thanh cong."
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 6. KIỂM TRA LẠI QUYỀN THƯ MỤC VỎ (SAFETY CHECK)
# Yêu cầu bắt buộc của SSH Chroot: Thư mục Home phải là root:root và quyền 755
CURRENT_OWNER=$(stat -c '%U:%G' "$JAIL_DIR")
CURRENT_PERM=$(stat -c '%a' "$JAIL_DIR")

if [[ "$CURRENT_OWNER" != "root:root" ]] || [[ "$CURRENT_PERM" != "755" ]]; then
    echo "Phat hien sai quyen thu muc vo. Dang sua lai cho dung chuan Chroot..."
    chown root:root "$JAIL_DIR"
    chmod 755 "$JAIL_DIR"
    echo "Da fix quyen $JAIL_DIR thanh root:root (755)."
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 7. Tìm cổng SSH 
# grep tim dong "port", head lay dong dau, awk lay cot 2, || true chong loi
DETECTED_PORT=$(sshd -T 2>/dev/null | grep "^port " | head -n 1 | awk '{print $2}' || true)

# B2: Neu B1 that bai (rong), fallback sang grep file config
if [[ -z "$DETECTED_PORT" ]]; then
    DETECTED_PORT=$(grep -i "^[[:space:]]*Port" /etc/ssh/sshd_config | head -n 1 | awk '{print $2}' || true)
fi

# B3: Neu ca 2 deu that bai, mac dinh la 22
SSH_PORT=${DETECTED_PORT:-22}
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 8. HOÀN TẤT
# Xác định thư mục
SCRIPT_WPSILA_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Ghi thêm thông tin đăng nhập vào file sftpp.txt
CRED_FILE="$SCRIPT_WPSILA_DIR/sftpp.txt"

# Kiểm tra nếu file tồn tại thì mới xóa
rm -f "$CRED_FILE"

# Tạo mới
cat > "$CRED_FILE" <<EOF
----------------------------------------
SFTP CREDENTIALS
Date: $(date)
DOMAIN: $DOMAIN
----------------------------------------
Host:       (IP VPS cua ban)
Port:       $SSH_PORT
Protocol:   SFTP (SSH File Transfer Protocol)
User:       $SFTP_USER
Password:   $SFTP_PASS
EOF
chmod 600 "$CRED_FILE" # Chỉ user hiện tại mới đọc được file này

echo ""
echo "========================================================"
echo "✅ TAO TAI KHOAN SFTP THANH CONG!"
echo "========================================================"
echo "📂 Thong tin ket noi FileZilla / WinSCP:"
echo "   - Host:       (IP VPS cua ban)"
echo "   - Port:       $SSH_PORT"
echo "   - Protocol:   SFTP (SSH File Transfer Protocol)"
echo "   - User:       $SFTP_USER"
echo "   - Password:   $SFTP_PASS"
echo "   - Xem lai thong tin pass o muc <6>"
echo "--------------------------------------------------------"
echo "📝 Luu y:"
echo "   - Khi dang nhap, user se thay minh o thu muc goc (/)."
echo "   - User phai vao thu muc 'public_html' de thay code web."
echo "   - User khong the di ra ngoai thu muc web cua ho."
echo "========================================================"
# -------------------------------------------------------------------------------------------------------------------------------