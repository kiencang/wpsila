# Định nghĩa màu sắc (để đảm bảo script chạy được nếu bạn copy paste riêng lẻ)
RED='\033[0;31m'
NC='\033[0m' # No Color

# Cấu hình số lần thử tối đa
MAX_RETRIES=3
COUNT=0
DOMAIN=""

# Bắt đầu vòng lặp
while [[ $COUNT -lt $MAX_RETRIES ]]; do
    ((COUNT++)) # Tăng biến đếm lên 1
    
    # Hiển thị prompt có kèm số lần thử để user biết
	if [[ $COUNT -eq 1 ]]; then
		read -p "Nhap Domain: " INPUT_DOMAIN < /dev/tty
	else
		echo -e "${RED}Ban vua nhap sai! Hay chu y nhap lai dung nhe.${NC}"
		read -p "Nhap Domain: " INPUT_DOMAIN < /dev/tty
	fi
    # Xử lý chuỗi
    CURRENT_DOMAIN=$(echo "$INPUT_DOMAIN" | tr -d ' ' | tr '[:upper:]' '[:lower:]')

    # --- BẮT ĐẦU KIỂM TRA ---
    
    # 1. Kiểm tra rỗng
    if [[ -z "$CURRENT_DOMAIN" ]]; then
        echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"
    
    # 2. Kiểm tra định dạng (thiếu dấu chấm)
    elif [[ "$CURRENT_DOMAIN" != *"."* ]]; then
        echo -e "${RED}Loi: Ten mien '$CURRENT_DOMAIN' khong hop le (thieu dau cham).${NC}"
        
    # 3. Nếu dữ liệu hợp lệ
    else
        DOMAIN="$CURRENT_DOMAIN"
        break # Thoát khỏi vòng lặp ngay lập tức
    fi

    # Nếu mã chạy xuống đây nghĩa là nhập sai
    if [[ $COUNT -eq $MAX_RETRIES ]]; then
        echo -e "${RED}Ban da nhap sai qua 3 lan. Script se dung lai de bao ve he thong.${NC}"
        exit 1
    else
        echo "Vui long thu lai..."
        echo "-------------------------"
    fi
done

# --- Script tiếp tục chạy từ đây khi dữ liệu đã đúng ---
echo -e "Thanh cong! Domain duoc chap nhan: $DOMAIN"
# Các lệnh xử lý tiếp theo...