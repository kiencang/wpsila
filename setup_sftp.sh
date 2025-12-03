#!/bin/bash

# Dừng script ngay nếu có lỗi, biến chưa định nghĩa, hoặc lỗi trong pipe
set -euo pipefail

# ==============================================================================
# SCRIPT TỰ ĐỘNG TẠO TÀI KHOẢN SFTP CHO CADDY WEB SERVER
# Hỗ trợ chạy trực tiếp qua pipe (curl | bash)
# ==============================================================================

# curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/setup_sftp.sh | bash

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo "Loi: Script nay phai chay voi quyen root (sudo)." 
   exit 1
fi

echo "========================================================"
echo "   CAU HINH SFTP CHO CADDY WEB SERVER (UBUNTU)"
echo "========================================================"

# --- 1. NHẬP THÔNG TIN (Thêm < /dev/tty để đọc từ bàn phím khi chạy qua pipe) ---

# Nhập tên miền
read -p "Nhap ten mien (VD: example.com): " DOMAIN < /dev/tty
if [ -z "$DOMAIN" ]; then
    echo "Loi: Ten mien khong duoc de trong."
    exit 1
fi

WEB_ROOT="/var/www/$DOMAIN/public_html"

if [ ! -d "$WEB_ROOT" ]; then
    echo "Loi: Thu muc $WEB_ROOT KHONG ton tai. Vui long kiem tra lai."
    exit 1
fi

# Nhập tên user
read -p "Nhap ten tai khoan SFTP (Mac dinh: webmaster): " SFTP_USER < /dev/tty
SFTP_USER=${SFTP_USER:-webmaster}

# Nhập mật khẩu
read -s -p "Nhap mat khau cho $SFTP_USER (De trong se tu tao random): " SFTP_PASS < /dev/tty
echo ""

if [ -z "$SFTP_PASS" ]; then
    # Kiểm tra xem openssl có tồn tại không, nếu không dùng cách khác
    if command -v openssl &> /dev/null; then
        SFTP_PASS=$(openssl rand -base64 12)
    else
        SFTP_PASS=$(date +%s | sha256sum | base64 | head -c 12)
    fi
    echo "-> Da tao mat khau ngau nhien: $SFTP_PASS"
fi

# --- 2. TẠO USER & GROUP ---
echo "[+] Dang xu ly tai khoan user..."
if id "$SFTP_USER" &>/dev/null; then
    echo "    User $SFTP_USER da ton tai."
    # Đảm bảo home dir tồn tại kể cả khi user đã có từ trước
    if [ ! -d "/home/$SFTP_USER" ]; then
        mkdir -p "/home/$SFTP_USER"
        chown "$SFTP_USER:$SFTP_USER" "/home/$SFTP_USER"
        echo "    Da tao lai thu muc home cho user."
    fi
else
    useradd -m -s /bin/bash "$SFTP_USER"
    echo "    Da tao user $SFTP_USER."
fi

# Đặt mật khẩu
echo "$SFTP_USER:$SFTP_PASS" | chpasswd

# Thêm user vào group www-data
usermod -aG www-data "$SFTP_USER"
echo "    Da them $SFTP_USER vao group www-data."

# --- 3. PHÂN QUYỀN ---
echo "[+] Dang phan quyen thu muc web..."
chown -R "$SFTP_USER:www-data" "$WEB_ROOT"

# Sử dụng + thay vì \; để chạy nhanh hơn với find
find "$WEB_ROOT" -type d -exec chmod 775 {} +
find "$WEB_ROOT" -type f -exec chmod 664 {} +
find "$WEB_ROOT" -type d -exec chmod g+s {} +

echo "    Da phan quyen xong (775/664/sGID)."

# --- 4. CẤU HÌNH SSHD ---
echo "[+] Dang cau hinh SSHD (umask 002)..."
SSHD_CONFIG="/etc/ssh/sshd_config"
# Đổi tên file backup an toàn
BACKUP_SSHD="/etc/ssh/sshd_config.bak.$(date +%F_%H-%M-%S)"

cp "$SSHD_CONFIG" "$BACKUP_SSHD"
echo "    Da backup sshd_config sang $BACKUP_SSHD"

if grep -q "internal-sftp -u 002" "$SSHD_CONFIG"; then
    echo "    Cau hinh umask 002 da ton tai. Bo qua."
else
    # FIX: Dùng Regex [[:space:]]+ để bắt cả dấu cách và dấu tab
    if grep -qE "Subsystem[[:space:]]+sftp[[:space:]]+/usr/lib/openssh/sftp-server" "$SSHD_CONFIG"; then
        sed -i -E 's|Subsystem[[:space:]]+sftp[[:space:]]+/usr/lib/openssh/sftp-server|Subsystem sftp internal-sftp -u 002|g' "$SSHD_CONFIG"
        echo "    Da cap nhat sshd_config."
        
        # Kiểm tra cú pháp ssh trước khi restart để tránh sập SSH
        if sshd -t; then
            service ssh restart
            echo "    Da khoi dong lai SSH."
        else
            echo "LOI: File sshd_config co loi cu phap. Da khoi phuc file backup."
            cp "$BACKUP_SSHD" "$SSHD_CONFIG"
            exit 1
        fi
    else
        echo "    Canh bao: KHONG tim thay dong 'Subsystem sftp' mac dinh."
        echo "    Vui long kiem tra thu cong file $SSHD_CONFIG"
    fi
fi

# --- 5. CẤU HÌNH WP-CONFIG.PHP ---
WP_CONFIG="$WEB_ROOT/wp-config.php"
if [ -f "$WP_CONFIG" ]; then
    echo "[+] Dang cau hinh wp-config.php..."
    if grep -q "FS_METHOD" "$WP_CONFIG"; then
        echo "    FS_METHOD da duoc dinh nghia. Bo qua."
    else
        sed -i "/<?php/a define('FS_METHOD', 'direct');" "$WP_CONFIG"
        echo "    Da them FS_METHOD direct."
        chown "$SFTP_USER:www-data" "$WP_CONFIG"
        chmod 664 "$WP_CONFIG"
    fi
else
    echo "    KHONG tim thay file wp-config.php. Bo qua."
fi

# --- 6. TẠO SHORTCUT ---
echo "[+] Dang tao shortcut..."
SHORTCUT_NAME=$(echo "$DOMAIN" | cut -d. -f1)
USER_HOME="/home/$SFTP_USER"

# Xóa symlink cũ nếu tồn tại
if [ -L "$USER_HOME/$SHORTCUT_NAME" ]; then
    rm "$USER_HOME/$SHORTCUT_NAME"
fi

# Tạo mới
if [ -d "$USER_HOME" ]; then
    ln -s "$WEB_ROOT" "$USER_HOME/$SHORTCUT_NAME"
    chown -h "$SFTP_USER:$SFTP_USER" "$USER_HOME/$SHORTCUT_NAME"
    echo "    Da tao shortcut tai $USER_HOME/$SHORTCUT_NAME"
else
    echo "    Loi: Thu muc home $USER_HOME khong ton tai."
fi

echo "========================================================"
echo "   CAI DAT HOAN TAT!"
echo "========================================================"
echo "Thong tin dang nhap SFTP:"
echo "Host:     (IP VPS cua ban)"
echo "Port:     22"
echo "User:     $SFTP_USER"
echo "Pass:     $SFTP_PASS"
echo "Thu muc:  /var/www/$DOMAIN/public_html"
echo "========================================================"