#!/bin/bash

# -----------------------------------------------------------
# MODULE: Tạo và Cấu hình Swap (Bộ nhớ ảo) - ENHANCED VERSION
# File: setup_swap.sh
# Mục đích: Ngăn chặn OOM Killer, tối ưu MariaDB/Caddy trên VPS
# Cập nhật: Tự động xử lý swap cũ quá nhỏ, chuẩn hóa sysctl.d
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Dừng script ngay lập tức nếu có lệnh bị lỗi
set -euo pipefail
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# A. Màu sắc & Cấu hình
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SWAP_SIZE_GB=2
SWAP_FILE="/swapfile"
MIN_SWAP_KB=1500000 # ~1.5GB. Nếu tổng swap nhỏ hơn mức này sẽ tạo mới.
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# B. Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Lỗi: Script nay can chay duoi quyen Root.${NC}"
   exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# C. KIỂM TRA & XỬ LÝ SWAP
echo -e "${GREEN}>>> Dang kiem tra trang thai Swap hien tai...${NC}"

# Lấy tổng dung lượng Swap hiện tại (đơn vị KB)
CURRENT_SWAP_TOTAL=$(free | grep -i Swap | awk '{print $2}')

# Logic: Nếu đã có Swap và dung lượng > 1.5GB thì giữ nguyên.
# Nếu Swap < 1.5GB (ví dụ Cloud-init tạo sẵn 512MB) thì tắt đi làm lại.
if [[ "$CURRENT_SWAP_TOTAL" -gt "$MIN_SWAP_KB" ]]; then
    CURRENT_HUMAN=$(free -h | grep -i Swap | awk '{print $2}')
    echo -e "${YELLOW}He thong da co Swap du dung: $CURRENT_HUMAN${NC}"
    echo -e "${YELLOW}Bo qua buoc tao Swap. Chuyen sang toi uu Swappiness...${NC}"
else
    if [[ "$CURRENT_SWAP_TOTAL" -gt 0 ]]; then
        echo -e "${YELLOW}Phat hien Swap cu qua nho (< 1.5GB). Dang tien hanh tai cau truc...${NC}"
        # Tắt toàn bộ swap để an toàn
        swapoff -a
        # Nếu file swap cũ tồn tại, xóa nó đi để giải phóng dung lượng
        if [[ -f "$SWAP_FILE" ]]; then
            rm -f "$SWAP_FILE"
            echo "Da xoa file swap cu: $SWAP_FILE"
        fi
        # Xóa dòng cấu hình cũ trong fstab để tránh lỗi boot (làm sạch)
        sed -i "\#$SWAP_FILE#d" /etc/fstab
    fi

    echo "Dang tien hanh tao Swap moi dung luong ${SWAP_SIZE_GB}GB..."

    # 1. Kiểm tra dung lượng ổ cứng (Chính xác hơn dùng grep)
    # Lấy dung lượng trống của thư mục root /, đơn vị GB
    FREE_DISK=$(df --output=avail -B 1G / | tail -n 1 | tr -d 'G')
    
    # Yêu cầu tối thiểu 5GB trống
    if [[ "$FREE_DISK" -lt 5 ]]; then
        echo -e "${RED}Loi: Dung luong o cung khong du (Con lai ${FREE_DISK}GB).${NC}"
        echo "Can toi thieu 5GB trong de tao Swap an toan."
        exit 1
    fi

    # 2. Tạo file Swap
    # Ưu tiên fallocate, fallback sang dd
    if ! fallocate -l "${SWAP_SIZE_GB}G" $SWAP_FILE; then
        echo "Fallocate that bai, chuyen sang dung DD (se mat mot luc)..."
        dd if=/dev/zero of=$SWAP_FILE bs=1M count=$((SWAP_SIZE_GB * 1024)) status=progress
    fi

    # 3. Phân quyền bảo mật (600 - Chỉ root đọc ghi)
    chmod 600 $SWAP_FILE

    # 4. Kích hoạt Swap
    mkswap $SWAP_FILE
    swapon $SWAP_FILE

    # 5. Backup & Cập nhật fstab (An toàn)
    echo "Dang cau hinh fstab..."
    # Backup fstab trước khi ghi
    cp /etc/fstab /etc/fstab.bak.$(date +%F_%H%M)
    
    # Kiểm tra kỹ trước khi append để tránh duplicate
    if ! grep -q "$SWAP_FILE" /etc/fstab; then
        echo "$SWAP_FILE none swap sw 0 0" | tee -a /etc/fstab
        echo "Da cap nhat fstab."
    fi

    echo -e "${GREEN}Da tao Swap ${SWAP_SIZE_GB}GB thanh cong!${NC}"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# D. TỐI ƯU SWAPPINESS (TUNING - UBUNTU STANDARD)
# Thay vì sửa trực tiếp sysctl.conf, ta tạo file config riêng trong /etc/sysctl.d/
# Cách này chuẩn hơn, dễ quản lý và không bị ghi đè khi update OS.

echo -e "${GREEN}>>> Dang toi uu thong so Swappiness (High Performance)...${NC}"

SYSCTL_D_FILE="/etc/sysctl.d/99-wpsila-swap.conf"
SWAPPINESS=20
VFS_CACHE_PRESSURE=50

# 1. Tạo file cấu hình riêng biệt
cat > $SYSCTL_D_FILE <<EOF
# --- WPSILA SWAP TUNING ---
# Giam su dung Swap, uu tien RAM toc do cao
vm.swappiness=$SWAPPINESS
# Giu cache file system lau hon (Tot cho WordPress nhieu file nho)
vm.vfs_cache_pressure=$VFS_CACHE_PRESSURE
EOF

# 2. Áp dụng cấu hình ngay lập tức từ file vừa tạo
sysctl -p $SYSCTL_D_FILE

echo -e "${GREEN}Da toi uu: Swappiness = $SWAPPINESS | Cache Pressure = $VFS_CACHE_PRESSURE${NC}"
echo -e "${GREEN}Cau hinh luu tai: $SYSCTL_D_FILE (Chuan Ubuntu)${NC}"
echo "-------------------------------------------------------------"
# -------------------------------------------------------------------------------------------------------------------------------