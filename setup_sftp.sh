#!/bin/bash

# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail
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
# 2. NHẬP THÔNG TIN
echo "--------------------------------------------------------"
echo "CONG CU TAO USER SFTP CHO WORDPRESS (SECURE MODE)"
echo "--------------------------------------------------------"
read -p "Nhap ten mien (VD: example.com): " DOMAIN < /dev/tty
read -p "Nhap user sFTP moi: " SFTP_USER < /dev/tty

# Định nghĩa thư mục Vỏ (Jail)
JAIL_DIR="/var/www/$DOMAIN"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 3. KIỂM TRA ĐẦU VÀO
if [[ ! -d "$JAIL_DIR" ]]; then
    echo "Loi: Thu muc $JAIL_DIR KHONG ton tai!"
    echo "Hay chac chan trang web co ton tai."
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

# 4.2. Cấu hình SSHD (Quan trọng)
SSHD_CONFIG="/etc/ssh/sshd_config"
NEED_RESTART=0

# Backup file config
cp $SSHD_CONFIG "${SSHD_CONFIG}.bak"

# Thêm block Match Group vào cuối file nếu chưa có
if ! grep -q "^Match Group sftp_only" $SSHD_CONFIG; then
    cat <<EOT >> $SSHD_CONFIG

# --- Added by SFTP Script ---
Match Group sftp_only
    ChrootDirectory %h
    ForceCommand internal-sftp -u 002
    AllowTCPForwarding no
    X11Forwarding no
    PasswordAuthentication yes
# ----------------------------
EOT
    echo "Da them cau hinh Match Group sftp_only."
    NEED_RESTART=1
else
    echo "Cau hinh SSH da chuan."
fi

# Áp dụng cấu hình SSH mới, sử dụng reload, đừng sử dụng restart vì nó có khả năng ngắt kết nối giữa chừng.
if [[ $NEED_RESTART -eq 1 ]]; then
    # Kiểm tra cú pháp file config trước (Safety First)
    if sshd -t; then
        systemctl reload ssh
        echo "Da reload dich vu SSH (Cau hinh an toan)."
    else
        echo "NGUY HIEM: File sshd_config bi loi cu phap!"
        echo "Khong reload SSH de tranh mat ket noi server."
        # Khôi phục lại file backup nếu cần thiết (tuỳ chọn)
        cp "${SSHD_CONFIG}.bak" "$SSHD_CONFIG"
        echo "   -> Da khoi phuc lai file config cu."
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
echo "Thiet lap mat khau cho user '$SFTP_USER':"

# Thêm cờ -s: Silent (ẩn ký tự khi gõ mật khẩu để bảo mật) nếu cần, nhưng để hiện cho chắc chắn
# < /dev/tty: Đảm bảo script luôn đọc từ bàn phím kể cả khi chạy qua pipe
read -p " -> Nhap mat khau moi: " SFTP_PASS < /dev/tty
echo "" # Xuống dòng vì -s không tự xuống dòng
read -p " -> Nhap lai mat khau: " SFTP_PASS_CONFIRM < /dev/tty
echo ""

# Kiểm tra khớp mật khẩu
if [[ "$SFTP_PASS" != "$SFTP_PASS_CONFIRM" ]]; then
    echo "Loi: Mat khau nhap lai khong khop!"
    # Xóa user vừa tạo để tránh rác
    userdel "$SFTP_USER"
    exit 1
fi

# Mã hóa mật khẩu và gán trực tiếp (Bypass PAM check)
ENCRYPTED_PASS=$(openssl passwd -6 "$SFTP_PASS")
usermod -p "$ENCRYPTED_PASS" "$SFTP_USER"
echo "Da thiet lap mat khau thanh cong."
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 6. KIỂM TRA LẠI QUYỀN THƯ MỤC VỎ (SAFETY CHECK)
# Yêu cầu bắt buộc của SSH Chroot: Thư mục Home phải là root:root và quyền 755
CURRENT_OWNER=$(stat -c '%U:%G' $JAIL_DIR)
CURRENT_PERM=$(stat -c '%a' $JAIL_DIR)

if [[ "$CURRENT_OWNER" != "root:root" ]] || [[ "$CURRENT_PERM" != "755" ]]; then
    echo "Phat hien sai quyen thu muc vo. Dang sua lai cho dung chuan Chroot..."
    chown root:root "$JAIL_DIR"
    chmod 755 "$JAIL_DIR"
    echo "Da fix quyen $JAIL_DIR thanh root:root (755)."
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# 7. HOÀN TẤT
echo ""
echo "========================================================"
echo "✅ TAO TAI KHOAN SFTP THANH CONG!"
echo "========================================================"
echo "📂 Thong tin ket noi FileZilla / WinSCP:"
echo "   - Host:       (IP VPS cua ban)"
echo "   - Port:       22"
echo "   - Protocol:   SFTP (SSH File Transfer Protocol)"
echo "   - User:       $SFTP_USER"
echo "   - Password:   (Mat khau ban vua nhap)"
echo "--------------------------------------------------------"
echo "📝 Luu y:"
echo "   - Khi dang nhap, user se thay minh o thu muc goc (/)."
echo "   - User phai vao thu muc 'public_html' de thay code web."
echo "   - User khong the di ra ngoai thu muc web cua ho."
echo "========================================================"
# -------------------------------------------------------------------------------------------------------------------------------