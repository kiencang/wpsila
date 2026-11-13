# shellcheck shell=bash
# -----------------------------------------------------------
# MODULE: Chống chặn thao tác với apt
# File: anti_apt_lock.sh
# File này được nhúng vào script install_lcmp.sh
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Hàm khôi phục sau khi cài xong
restore_environment() {
    local exit_code=$?
    echo ">>> [System] Dang bat lai che do cap nhat nen..."
    systemctl unmask apt-daily.service apt-daily-upgrade.service &> /dev/null || true
    systemctl unmask apt-daily.timer apt-daily-upgrade.timer &> /dev/null || true
    systemctl start apt-daily.timer apt-daily-upgrade.timer &> /dev/null || true

    if [[ $exit_code -ne 0 ]]; then
        echo -e "\033[0;31m!!! [LOI NGHIEM TRONG] Qua trinh cai dat bi dung dot ngot (Ma loi: $exit_code) !!!\033[0m"
        echo -e "\033[1;33m>>> Vui long keo len tren de xem chi tiet dong bao loi.\033[0m"
    else
        echo ">>> [System] Xong!"
    fi
}
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Hàm xử lý lock chuyên nghiệp - An toàn tuyệt đối
prepare_environment() {
    echo ">>> [System] Dang kiem tra che do cap nhat nen cua Ubuntu..."

    # 1. MASKING: Tạm thời vô hiệu hóa trigger cập nhật
    # Dùng 'mask' mạnh hơn 'stop'. Nó ngăn systemd kích hoạt service dù có ai đó cố tình gọi.
    systemctl mask apt-daily.service apt-daily-upgrade.service &> /dev/null
    systemctl mask apt-daily.timer apt-daily-upgrade.timer &> /dev/null

    # 2. WAITING: Chờ đợi văn minh (Không kill), vì kill dễ lỗi database
    # Danh sách các file lock quan trọng
    local LOCK_FILES=(
        "/var/lib/dpkg/lock-frontend"
        "/var/lib/dpkg/lock"
        "/var/lib/apt/lists/lock"
        "/var/cache/apt/archives/lock"
    )

    local TIMEOUT=300 # Chờ tối đa 5 phút (300s) cho tiến trình cũ update xong
    local COUNT=0

    # Hàm kiểm tra xem APT/DPKG có đang bị khóa không (Hỗ trợ cả trường hợp Ubuntu Minimal chưa cài sẵn gói psmisc/fuser)
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
            echo "!!! [Loi] Qua trinh cap nhat he thong bi ket qua lau (> 5 phut)."
            echo "!!! Vui long cai lai VPS (reinstall) va chay script wpsila ngay sau khi cai."
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
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo "2. Thiet lap moi truong cai dat..."

# Gọi hàm khóa môi trường
prepare_environment

# [QUAN TRỌNG] Đặt TRAP ngay lập tức sau khi khóa. 
# Nếu script lỗi bất cứ đâu từ dòng này trở đi, nó sẽ tự động chạy restore_environment
# Nếu không có lỗi, khi mã chạy hết, nó tự chạy hàm này.
trap restore_environment EXIT
# -------------------------------------------------------------------------------------------------------------------------------