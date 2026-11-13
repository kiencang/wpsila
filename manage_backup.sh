#!/bin/bash

# -------------------------------------------------------------------------------------------------------------------------------
# MODULE: Quản lý Sao lưu & Khôi phục cấp độ Local (Local Backup & Restore)
# File: manage_backup.sh (Mục 20 trên Menu & Chạy ngầm qua Cron --auto)
# -------------------------------------------------------------------------------------------------------------------------------
# Thiết kế:
#   - Lưu trữ tại: /var/www/$DOMAIN/backups/ (An toàn trước trình duyệt, tải về được qua SFTP)
#   - Giới hạn giữ lại: Tối đa 2 bản mới nhất / mỗi website (MAX_BACKUPS=2)
#   - Lịch tự động: 03:00 sáng Chủ Nhật hàng tuần theo giờ Việt Nam (Asia/Ho_Chi_Minh)
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
set -euo pipefail
export LC_ALL=C.UTF-8
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   sudo -E "$0" "$@"
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# Cấu hình cốt lõi
MAX_BACKUPS=2                # Giữ lại tối đa 2 bản backup gần nhất cho mỗi website
MIN_FREE_DISK_MB=2048        # Yêu cầu ổ cứng còn trống tối thiểu 2GB (2048MB) mới chạy backup
MAX_DISK_PERCENT=85          # Nếu ổ cứng đã dùng quá 85% thì dừng backup để bảo vệ MariaDB

SCRIPT_WPSILA_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
WPSILA_CONFIG_FILE="$SCRIPT_WPSILA_DIR/wpsila.conf"
BACKUP_LOG_FILE="/var/log/wpsila_backup.log"

if [[ -f "$WPSILA_CONFIG_FILE" ]]; then
    source "$WPSILA_CONFIG_FILE"
fi
PHP_VER="${PHP_VER:-8.3}"

# Biến lưu đường dẫn file tạm để dọn dẹp nếu script bị ngắt giữa chừng
ACTIVE_TMP_SQL=""
ACTIVE_TMP_TAR=""
ACTIVE_RESTORE_TMP=""

cleanup_on_exit() {
    [[ -n "$ACTIVE_TMP_SQL" && -f "$ACTIVE_TMP_SQL" ]] && rm -f "$ACTIVE_TMP_SQL"
    [[ -n "$ACTIVE_TMP_TAR" && -f "$ACTIVE_TMP_TAR" ]] && rm -f "$ACTIVE_TMP_TAR"
    [[ -n "$ACTIVE_RESTORE_TMP" && -d "$ACTIVE_RESTORE_TMP" ]] && rm -rf "$ACTIVE_RESTORE_TMP"
}
trap cleanup_on_exit EXIT INT TERM
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# CÁC HÀM XỬ LÝ LÕI (CORE FUNCTIONS)

# 1. Kiểm tra an toàn dung lượng ổ cứng trước khi Backup
check_disk_safety() {
    local avail_mb used_pct
    avail_mb=$(df -BM --output=avail / | tail -n 1 | tr -d ' M')
    used_pct=$(df --output=pcent / | tail -n 1 | tr -d ' %')

    if (( avail_mb < MIN_FREE_DISK_MB || used_pct > MAX_DISK_PERCENT )); then
        echo -e "${RED}[CANH BAO AN TOAN] O cung chi con trong ${avail_mb}MB (Da dung ${used_pct}%).${NC}"
        echo -e "${YELLOW}He thong tu dong DUNG Backup de tranh lam day o cung gay sap MariaDB!${NC}"
        return 1
    fi
    return 0
}

# 2. Lấy tên Database từ wp-config.php (Ưu tiên WP-CLI, có grep dự phòng nếu PHP web đang lỗi)
extract_db_name() {
    local wp_path="$1"
    local db_name=""
    if command -v wp &>/dev/null; then
        db_name=$(wp config get DB_NAME --path="$wp_path" --allow-root --quiet --skip-plugins --skip-themes 2>/dev/null | tr -d '\r\n' || true)
    fi
    if [[ -z "$db_name" && -f "$wp_path/wp-config.php" ]]; then
        db_name=$(grep -E "define\(\s*['\"]DB_NAME['\"]" "$wp_path/wp-config.php" | sed -E "s/.*['\"]DB_NAME['\"]\s*,\s*['\"]([^'\"]+)['\"].*/\1/" | head -n 1 | tr -d '\r\n' || true)
    fi
    echo "$db_name"
}

# 3. Thực hiện Backup cho 1 Website cụ thể
backup_single_site() {
    local domain="$1"
    local web_root="/var/www/$domain"
    local wp_path="$web_root/public_html"
    local backup_dir="$web_root/backups"

    if [[ ! -d "$wp_path" || ! -f "$wp_path/wp-config.php" ]]; then
        echo -e "${RED}Loi: Khong tim thay website WordPress tai $wp_path${NC}"
        return 1
    fi

    # Kiểm tra ổ cứng trước khi chạy
    if ! check_disk_safety; then
        return 1
    fi

    echo -e "${YELLOW}>>> Dang sao luu website: ${GREEN}${domain}${NC} ..."

    # Tạo thư mục backups (nằm ngoài public_html để chặn truy cập web, nhưng SFTP tải về được)
    mkdir -p "$backup_dir"
    chown root:www-data "$backup_dir"
    chmod 750 "$backup_dir"

    # B1: Xuất Database bằng mariadb-dump (--single-transaction không gây khóa bảng)
    local db_name
    db_name=$(extract_db_name "$wp_path")
    if [[ -z "$db_name" ]]; then
        echo -e "${RED}Loi: Khong the lay ten Database cua $domain!${NC}"
        return 1
    fi

    ACTIVE_TMP_SQL="$backup_dir/database.sql"
    echo "  - [1/3] Dang xuat Database ($db_name)..."
    if ! mariadb-dump --single-transaction --quick "$db_name" > "$ACTIVE_TMP_SQL"; then
        echo -e "${RED}Loi: Khong the xuat Database $db_name!${NC}"
        rm -f "$ACTIVE_TMP_SQL"
        ACTIVE_TMP_SQL=""
        return 1
    fi

    # B2: Nén chung database.sql và public_html (Loại trừ thư mục cache và backup của plugin)
    local timestamp
    timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    local final_archive="$backup_dir/${domain}_${timestamp}.tar.gz"
    ACTIVE_TMP_TAR="${final_archive}.tmp"

    echo "  - [2/3] Dang nen ma nguon & Database (Che do tiet kiem CPU/Disk)..."
    if nice -n 19 ionice -c 3 tar -czf "$ACTIVE_TMP_TAR" \
        --exclude="public_html/wp-content/cache/*" \
        --exclude="public_html/wp-content/updraft/*" \
        --exclude="public_html/wp-content/ai1wm-backups/*" \
        --exclude="public_html/wp-content/backups/*" \
        --exclude="public_html/wp-content/debug.log" \
        -C "$backup_dir" database.sql \
        -C "$web_root" public_html 2>/dev/null; then

        # Xóa file SQL lẻ sau khi đã đưa vào trong gói nén
        rm -f "$ACTIVE_TMP_SQL"
        ACTIVE_TMP_SQL=""

        # Kiểm tra file nén có dữ liệu không rồi đổi tên chính thức
        if [[ -s "$ACTIVE_TMP_TAR" ]]; then
            mv "$ACTIVE_TMP_TAR" "$final_archive"
            ACTIVE_TMP_TAR=""
            # Phân quyền 640 (root:www-data) để SFTP có thể tải về máy tính cá nhân
            chown root:www-data "$final_archive"
            chmod 640 "$final_archive"
        else
            echo -e "${RED}Loi: File backup tao ra bi rong!${NC}"
            rm -f "$ACTIVE_TMP_TAR"
            ACTIVE_TMP_TAR=""
            return 1
        fi
    else
        echo -e "${RED}Loi trong qua trinh nen du lieu cho $domain!${NC}"
        rm -f "$ACTIVE_TMP_SQL" "$ACTIVE_TMP_TAR"
        ACTIVE_TMP_SQL=""
        ACTIVE_TMP_TAR=""
        return 1
    fi

    # B3: Xoay vòng giữ tối đa 2 bản mới nhất (Safe Rotation)
    echo "  - [3/3] Dang kiem tra xoay vong (Chi giu lai toi da $MAX_BACKUPS ban moi nhat)..."
    # Liệt kê các bản backup theo thứ tự thời gian từ mới nhất -> cũ nhất, xóa từ bản thứ 3 trở đi
    ls -1t "$backup_dir"/${domain}_*.tar.gz 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm -f

    local archive_size
    archive_size=$(du -sh "$final_archive" 2>/dev/null | awk '{print $1}')
    echo -e "${GREEN}  -> THANH CONG! File: $(basename "$final_archive") (Dung luong: $archive_size)${NC}"
    echo -e "     Duong dan: ${YELLOW}$final_archive${NC} (Co the tai ve qua SFTP)"
    return 0
}

# 4. Thực hiện Backup cho TOÀN BỘ các website trên VPS
backup_all_sites() {
    local count=0
    local success=0

    for config_path in /var/www/*/public_html/wp-config.php; do
        [[ -e "$config_path" ]] || continue
        count=$((count + 1))
        local domain
        domain=$(echo "$config_path" | cut -d'/' -f4)
        if backup_single_site "$domain"; then
            success=$((success + 1))
        fi
        echo "--------------------------------------------------------"
    done

    if (( count == 0 )); then
        echo -e "${YELLOW}Chua co website WordPress nao tren VPS de sao luu.${NC}"
    else
        echo -e "${GREEN}HOAN TAT SAO LUU: Thanh cong $success/$count website (Giu toi da $MAX_BACKUPS ban/web).${NC}"
    fi
}
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# CHẾ ĐỘ CHẠY TỰ ĐỘNG NGẦM QUA CRON (--auto)
if [[ "${1:-}" == "--auto" ]]; then
    echo "========================================================" >> "$BACKUP_LOG_FILE"
    echo "[AUTO BACKUP START] $(date '+%Y-%m-%d %H:%M:%S %Z')" >> "$BACKUP_LOG_FILE"
    backup_all_sites >> "$BACKUP_LOG_FILE" 2>&1 || true
    echo "[AUTO BACKUP END] $(date '+%Y-%m-%d %H:%M:%S %Z')" >> "$BACKUP_LOG_FILE"
    exit 0
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# CÁC HÀM TƯƠNG TÁC TRÊN MENU (INTERACTIVE FUNCTIONS)

# 5. Khôi phục (Restore) Website từ bản Backup
restore_website_interactive() {
    echo -e "${YELLOW}=== KHOI PHUC (RESTORE) WEBSITE TU BAN BACKUP ===${NC}"
    read -r -p "Nhap ten mien website muon khoi phuc (VD: example.com): " input_domain < /dev/tty
    local domain
    domain=$(echo "$input_domain" | tr '[:upper:]' '[:lower:]' | tr -d ' ' | sed -E 's|^https?://||; s|/.*$||; s|:[0-9]+$||')

    if [[ -z "$domain" ]]; then
        echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"
        return
    fi

    local web_root="/var/www/$domain"
    local wp_path="$web_root/public_html"
    local backup_dir="$web_root/backups"

    if [[ ! -d "$web_root" ]]; then
        echo -e "${RED}Loi: Thu muc website $web_root khong ton tai tren VPS!${NC}"
        return
    fi

    # Lấy danh sách các bản backup đang có của tên miền này
    mapfile -t backup_files < <(ls -1t "$backup_dir"/${domain}_*.tar.gz 2>/dev/null || true)

    if [[ ${#backup_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}Khong tim thay ban backup nao cho website $domain tai $backup_dir${NC}"
        return
    fi

    echo "--------------------------------------------------------"
    echo -e "Cac ban Backup hien co cua ${GREEN}$domain${NC}:"
    local i=0
    for bfile in "${backup_files[@]}"; do
        i=$((i + 1))
        local bsize bdate
        bsize=$(du -sh "$bfile" 2>/dev/null | awk '{print $1}')
        bdate=$(stat -c '%y' "$bfile" | cut -d'.' -f1)
        echo -e "  ${YELLOW}${i}.${NC} $(basename "$bfile") | Dung luong: ${GREEN}$bsize${NC} | Tao luc: $bdate"
    done
    echo "--------------------------------------------------------"

    read -r -p "Chon so thu tu ban Backup muon khoi phuc (1-${#backup_files[@]}), hoac Enter de huy: " choice_num < /dev/tty
    if [[ ! "$choice_num" =~ ^[0-9]+$ ]] || (( choice_num < 1 || choice_num > ${#backup_files[@]} )); then
        echo -e "${YELLOW}Da huy thao tac khoi phuc.${NC}"
        return
    fi

    local selected_archive="${backup_files[$((choice_num - 1))]}"
    echo ""
    echo -e "${RED}CANH BAO: Du lieu hien tai cua $domain se bi GHI DE boi ban backup:${NC}"
    echo -e " -> ${YELLOW}$(basename "$selected_archive")${NC}"
    read -r -p "Ban co chac chan muon KHOI PHUC ngay bay gio khong? (y/n): " confirm < /dev/tty
    if [[ ! "$confirm" =~ ^[yY](es)?$ ]]; then
        echo -e "${YELLOW}Da huy thao tac khoi phuc.${NC}"
        return
    fi

    # Tiến hành giải nén ra thư mục tạm để kiểm tra toàn vẹn trước khi đè vào web thật
    ACTIVE_RESTORE_TMP="$backup_dir/.restore_tmp_$$"
    mkdir -p "$ACTIVE_RESTORE_TMP"

    echo -e "${YELLOW}[1/4] Dang giai nen va kiem tra du lieu backup...${NC}"
    if ! tar -xzf "$selected_archive" -C "$ACTIVE_RESTORE_TMP"; then
        echo -e "${RED}Loi: File backup bi hong, khong the giai nen! Huy khoi phuc.${NC}"
        rm -rf "$ACTIVE_RESTORE_TMP"
        ACTIVE_RESTORE_TMP=""
        return
    fi

    if [[ ! -f "$ACTIVE_RESTORE_TMP/database.sql" || ! -d "$ACTIVE_RESTORE_TMP/public_html" ]]; then
        echo -e "${RED}Loi: Cau truc file backup khong hop le (thieu database.sql hoac public_html)!${NC}"
        rm -rf "$ACTIVE_RESTORE_TMP"
        ACTIVE_RESTORE_TMP=""
        return
    fi

    # Lấy tên DB hiện tại và quyền wp-config.php hiện tại
    local db_name current_wpconfig_perm
    db_name=$(extract_db_name "$wp_path")
    if [[ -z "$db_name" ]]; then
        db_name=$(extract_db_name "$ACTIVE_RESTORE_TMP/public_html")
    fi
    if [[ -z "$db_name" ]]; then
        echo -e "${RED}Loi: Khong the xac dinh ten Database de khoi phuc!${NC}"
        rm -rf "$ACTIVE_RESTORE_TMP"
        ACTIVE_RESTORE_TMP=""
        return
    fi
    current_wpconfig_perm=$(stat -c '%a' "$wp_path/wp-config.php" 2>/dev/null || echo "660")

    echo -e "${YELLOW}[2/4] Dang khoi phuc Database ($db_name)...${NC}"
    if ! mariadb "$db_name" < "$ACTIVE_RESTORE_TMP/database.sql"; then
        echo -e "${RED}Loi: Khong the nap lai Database!${NC}"
        rm -rf "$ACTIVE_RESTORE_TMP"
        ACTIVE_RESTORE_TMP=""
        return
    fi

    echo -e "${YELLOW}[3/4] Dang khoi phuc ma nguon (public_html)...${NC}"
    # Xóa code cũ và chuyển code từ bản backup vào
    rm -rf "$wp_path"
    mv "$ACTIVE_RESTORE_TMP/public_html" "$wp_path"

    echo -e "${YELLOW}[4/4] Dang chuan hoa lai phân quyen va lam moi Cache...${NC}"
    chown root:root "$web_root"
    chmod 755 "$web_root"
    chown -R root:www-data "$wp_path"
    find "$wp_path" -type d -exec chmod 2775 {} +
    find "$wp_path" -type f -exec chmod 664 {} +
    chmod "$current_wpconfig_perm" "$wp_path/wp-config.php"

    # Xóa thư mục tạm
    rm -rf "$ACTIVE_RESTORE_TMP"
    ACTIVE_RESTORE_TMP=""

    # Xóa Object Cache (nếu có) và Reload PHP-FPM để làm mới OPcache
    if command -v wp &>/dev/null; then
        wp cache flush --path="$wp_path" --allow-root --quiet 2>/dev/null || true
    fi
    systemctl reload "php${PHP_VER}-fpm" 2>/dev/null || true

    echo -e "${GREEN}=== KHOI PHUC WEBSITE $domain THANH CONG 100%! ===${NC}"
}

# 6. Bật / Tắt lịch tự động Backup hàng tuần (03:00 sáng Chủ Nhật giờ Việt Nam)
manage_weekly_cron() {
    local cron_cmd="0 3 * * 0 /bin/bash $SCRIPT_WPSILA_DIR/manage_backup.sh --auto >> $BACKUP_LOG_FILE 2>&1"
    local current_tz
    current_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "UTC")

    echo "--------------------------------------------------------"
    if crontab -l 2>/dev/null | grep -Fq "$SCRIPT_WPSILA_DIR/manage_backup.sh --auto"; then
        echo -e "Trang thai hien tai: ${GREEN}DANG BAT (03:00 sang Chu Nhat hang tuan)${NC}"
        echo -e "Mui gio VPS hien tai: ${YELLOW}${current_tz}${NC}"
        echo "--------------------------------------------------------"
        read -r -p "Ban co muon TAT che do tu dong Backup hang tuan khong? (y/n): " off_confirm < /dev/tty
        if [[ "$off_confirm" =~ ^[yY](es)?$ ]]; then
            (crontab -l 2>/dev/null || true) | grep -Fv "$SCRIPT_WPSILA_DIR/manage_backup.sh --auto" | crontab - || true
            echo -e "${YELLOW}>> Da TAT lich tu dong Backup hang tuan.${NC}"
        fi
    else
        echo -e "Trang thai hien tai: ${RED}DANG TAT${NC}"
        echo "--------------------------------------------------------"
        echo "Khi bat, he thong se:"
        echo "  1. Dong bo mui gio VPS ve Gio Viet Nam (Asia/Ho_Chi_Minh - UTC+7)."
        echo "  2. Tu dong sao luu tat ca website vao 03:00 sang Chu Nhat hang tuan."
        echo "  3. Tu dong giu lai toi da 2 ban moi nhat cho moi website."
        read -r -p "Ban co muon BAT tu dong Backup hang tuan khong? (y/n): " on_confirm < /dev/tty
        if [[ "$on_confirm" =~ ^[yY](es)?$ ]]; then
            # Đồng bộ múi giờ về Asia/Ho_Chi_Minh để 3h sáng của VPS đúng chuẩn 3h sáng Việt Nam
            timedatectl set-timezone Asia/Ho_Chi_Minh 2>/dev/null || ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
            systemctl restart cron 2>/dev/null || service cron restart 2>/dev/null || true

            # Thêm vào crontab của root (Idempotent)
            (crontab -l 2>/dev/null | grep -Fv "$SCRIPT_WPSILA_DIR/manage_backup.sh --auto" || true; echo "$cron_cmd") | crontab -
            echo -e "${GREEN}>> DA BAT TU DONG BACKUP HANG TUAN (03:00 sang Chu Nhat - Gio VN)!${NC}"
        fi
    fi
}

# 7. Xem danh sách toàn bộ các bản Backup đang có trên VPS
list_all_backups() {
    echo -e "${GREEN}=== DANH SACH CAC BAN BACKUP HIEN CO TREN VPS ===${NC}"
    echo "-----------------------------------------------------------------------------"
    printf "%-25s | %-34s | %-10s\n" "Website" "Ten file Backup (.tar.gz)" "Dung luong"
    echo "-----------------------------------------------------------------------------"

    local total_files=0
    for bfile in /var/www/*/backups/*.tar.gz; do
        [[ -e "$bfile" ]] || continue
        total_files=$((total_files + 1))
        local bdomain bname bsize
        bdomain=$(echo "$bfile" | cut -d'/' -f4)
        bname=$(basename "$bfile")
        bsize=$(du -sh "$bfile" 2>/dev/null | awk '{print $1}')
        printf "%-25s | %-34s | %-10s\n" "$bdomain" "$bname" "$bsize"
    done

    if (( total_files == 0 )); then
        echo -e "${YELLOW}Chua co ban backup nao duoc luu tren VPS.${NC}"
    fi
    echo "-----------------------------------------------------------------------------"
    echo -e "Tong so file backup tren he thong: ${GREEN}${total_files}${NC} (Toi da ${MAX_BACKUPS} ban/website)"
}
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# HIỂN THỊ MENU QUẢN LÝ BACKUP (MỤC 20)
if crontab -l 2>/dev/null | grep -Fq "$SCRIPT_WPSILA_DIR/manage_backup.sh --auto"; then
    AUTO_STATUS="${GREEN}DANG BAT (03:00 sang CN - Gio VN)${NC}"
else
    AUTO_STATUS="${YELLOW}DANG TAT${NC}"
fi

echo -e "${BLUE}===================================================================${NC}"
echo -e "${GREEN}         QUAN LY SAO LUU & KHOI PHUC LOCAL (BACKUP/RESTORE)        ${NC}"
echo -e "${BLUE}===================================================================${NC}"
echo -e "  Lich Backup tu dong : ${AUTO_STATUS}"
echo -e "  Chinh sach luu tru  : ${YELLOW}Toi da ${MAX_BACKUPS} ban/website${NC} (Tai /var/www/domain/backups)"
echo -e "${BLUE}-------------------------------------------------------------------${NC}"
echo -e "  ${YELLOW}1.${NC} Sao luu (Backup) NGAY LAP TUC cho 1 website cu the"
echo -e "  ${YELLOW}2.${NC} Sao luu (Backup) NGAY LAP TUC cho TOAN BO website tren VPS"
echo -e "  ${YELLOW}3.${NC} Khoi phuc (Restore) website tu ban Backup da luu"
echo -e "  ${YELLOW}4.${NC} Bat / Tat lich tu dong Backup hang tuan (03:00 sang CN - Gio VN)"
echo -e "  ${YELLOW}5.${NC} Xem danh sach & dung luong cac ban Backup hien co"
echo -e "  ${YELLOW}0.${NC} Quay lai Menu chinh"
echo -e "${BLUE}===================================================================${NC}"
read -r -p "Nhap lua chon cua ban (0-5): " sub_choice < /dev/tty
echo ""

case "$sub_choice" in
    1)
        read -r -p "Nhap ten mien website muon sao luu (VD: example.com): " in_dom < /dev/tty
        clean_dom=$(echo "$in_dom" | tr '[:upper:]' '[:lower:]' | tr -d ' ' | sed -E 's|^https?://||; s|/.*$||; s|:[0-9]+$||')
        if [[ -n "$clean_dom" ]]; then
            backup_single_site "$clean_dom"
        else
            echo -e "${RED}Loi: Ten mien khong hop le!${NC}"
        fi
        ;;
    2)
        backup_all_sites
        ;;
    3)
        restore_website_interactive
        ;;
    4)
        manage_weekly_cron
        ;;
    5)
        list_all_backups
        ;;
    0)
        exit 0
        ;;
    *)
        echo -e "${RED}Lua chon khong hop le!${NC}"
        ;;
esac