#!/bin/bash

# -----------------------------------------------------------
# MODULE: Cài đặt swap (an toàn & tối ưu)
# File: setup_swap.sh
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
set -euo pipefail
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- CONFIG ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SWAP_SIZE_GB=2
SWAP_FILE="/swapfile"
MIN_SWAP_KB=1500000 # ~1.5GB
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- ROOT CHECK ---
if [[ $EUID -ne 0 ]]; then
   echo -e "${YELLOW}Dang chuyen sang quyen root...${NC}"
   sudo -E "$0" "$@"
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
echo -e "${GREEN}>>> [SWAP] Kiem tra hien trang...${NC}"

# Lấy thông tin Swap hiện tại
CURRENT_SWAP_TOTAL=$(free | grep -i Swap | awk '{print $2}')
CURRENT_SWAP_USED=$(free | grep -i Swap | awk '{print $3}')

# --- LOGIC XỬ LÝ ---
if [[ "$CURRENT_SWAP_TOTAL" -gt "$MIN_SWAP_KB" ]]; then
    CURRENT_HUMAN=$(free -h | grep -i Swap | awk '{print $2}')
    echo -e "${GREEN}OK: Swap da du dung ($CURRENT_HUMAN).${NC}"
else
    # Logic an toàn: Kiểm tra xem có tắt được swap cũ không?
    if [[ "$CURRENT_SWAP_TOTAL" -gt 0 ]]; then
        echo -e "${YELLOW}Swap cu qua nho (< 1.5GB). Can tai tao.${NC}"
        
		# Thay đổi thành công thức gọn hơn, xác định lượng RAM đang rảnh rỗi
        AVAILABLE_RAM_KB=$(free | grep -i Mem | awk '{print $7}')
        
        # Nếu swap đang dùng nhiều hơn RAM có thể chứa -> STOP
        if [[ "$CURRENT_SWAP_USED" -gt "$AVAILABLE_RAM_KB" ]]; then
            echo -e "${RED}NGUY HIEM: Swap dang dung ($CURRENT_SWAP_USED KB) lon hon RAM trong ($AVAILABLE_RAM_KB KB).${NC}"
            echo -e "${RED}Khong the tat Swap cu vi se gay crash he thong (OOM).${NC}"
            echo "Giai phap: Hay restart VPS hoac tat bot service truoc khi chay script nay."
            exit 1
        fi

        echo "Tat swap cu..."
        swapoff -a
        
        # Xóa sạch sẽ
        if [[ -f "$SWAP_FILE" ]]; then
            rm -f "$SWAP_FILE"
        fi
        sed -i "\#$SWAP_FILE#d" /etc/fstab
    fi

    # Tạo swap mới
    echo "Tao Swap moi ${SWAP_SIZE_GB}GB..."
    
    # Check disk space
    FREE_DISK=$(df --output=avail -B 1G / | tail -n 1 | tr -d 'G')
    if [[ "$FREE_DISK" -lt 5 ]]; then
        echo -e "${RED}Loi: O cung chi con ${FREE_DISK}GB (Can > 5GB).${NC}"
        exit 1
    fi

    # Tạo file
    if ! fallocate -l "${SWAP_SIZE_GB}G" "$SWAP_FILE"; then
        echo "Fallocate failed. Fallback to DD..."
        dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$((SWAP_SIZE_GB * 1024)) status=progress
    fi

    chmod 600 "$SWAP_FILE"
    mkswap "$SWAP_FILE"
    swapon "$SWAP_FILE"

    # Fstab Safe Update
    cp /etc/fstab /etc/fstab.bak."$(date +%F_%H%M)"
    if ! grep -q "$SWAP_FILE" /etc/fstab; then
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
    fi
    
    echo -e "${GREEN}Da tao Swap moi thanh cong!${NC}"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- TUNING ---
echo -e "${GREEN}>>> [SWAP] Toi uu sysctl (swappiness & vfs_cache_pressure). ${NC}"
SYSCTL_D_FILE="/etc/sysctl.d/99-wpsila-swap.conf"

# Swappiness=10: Tốt cho VPS chạy Web Server (MariaDB thích RAM thật hơn)
# VFS Cache=50: Cân bằng giữa việc cache file và giải phóng RAM
cat > "$SYSCTL_D_FILE" <<EOF
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF

sysctl -p "$SYSCTL_D_FILE" > /dev/null

echo -e "${GREEN}DONE. Trang thai hien tai:${NC}"
free -h
echo "-------------------------------------------------------------"
# -------------------------------------------------------------------------------------------------------------------------------