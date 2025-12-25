Version của bash script: v0.3.0
---
Website: https://wpsila.com

Đây là công cụ **cài nhanh blog WordPress trên VPS** (chỉ blog & nói chung là website không bao gồm giỏ hàng).

- Yêu cầu hệ thống: **Ubuntu LTS 24.04** hoặc 22.04, cài mới trên VPS (tức là bạn chưa có bất cứ website nào hoặc cài bất cứ chương trình gì ngoài Ubuntu trên VPS đó).
- RAM tối thiểu 1GB.

Các đoạn mã đang trong giai đoạn thử nghiệm, chỉ cài nó trên website demo của bạn.

Cài đặt với quyền root: 

```bash
curl -sL https://vps.wpsila.com | sudo bash
```

Quá trình viết code có tham khảo gợi ý từ Gemini.

## Chức năng của các file trong chương trình

a. Tải về cấu hình version php & mariadb wpsila
- wpsila.conf 

b. Tải về menu cho chương trình quản trị wpsila
- wpsila_menu.sh 

c. Tải về các file phục vụ cho cài đặt LCMP
- install_lcmp.sh
- anti_apt_lock.sh
- install_caddyserver.sh
- install_php.sh
- install_mariadb.sh 

d. Tải về các file phục vụ cho việc cài đặt WordPress
- install_wp.sh
- domain_check.sh
- database_user_wp.sh
- wordpress.sh
- caddyfile.sh
- caddyfile_subdomain.sh

e. Tải về các file để thiết lập cấu hình cho MariaDB và PHP INI cũng như Pool Tune
- tune_mariadb.sh
- tune_php.sh
- tune_pool.sh 

f. Tải về file phục vụ chức năng xóa website
- remove_web.sh

g. Tải về file tạo tài khoản sFTP
- setup_sftp.sh

h. Tải về file cài adminer để tạo trang quản trị database (không cài nếu không cần)
- setup_adminer.sh
  
i. File để hiển thị mật khẩu 
- show_pass.sh

j. Kiểm tra cập nhật cho wpsila
- check_for_update.sh

## Gợi ý các theme & plugin nên dùng cùng với wpsila

wpsila có thể dùng kèm với *bất kỳ theme & plugin nào*, tuy vậy chúng tôi gợi ý bạn nên dùng các theme & plugin dưới đây để đảm bảo website an toàn & có hiệu suất cao:

- Giao diện: GeneratePress (https://wordpress.org/themes/generatepress/)
- Plugin tăng tốc (cache): Cache Enabler (https://wordpress.org/plugins/cache-enabler/)
- Plugin tối ưu máy tìm kiếm: The SEO Framework (https://wordpress.org/plugins/autodescription/)
- Plugin backup: UpdraftPlus (https://wordpress.org/plugins/updraftplus/)

Ngoài ra các tính năng bảo mật miễn phí của Cloudflare (https://www.cloudflare.com/) cũng rất hợp với người dùng WordPress làm blog, nó dễ triển khai và có chất lượng cao.

**Chú ý**: Các công cụ trên chỉ là gợi ý, wpsila không có bất cứ ràng buộc nào là bạn phải dùng theme hay plugin cụ thể nào đó.

## Tuyên bố miễn trừ trách nhiệm (Disclaimer)

Script này được cung cấp miễn phí và mã nguồn mở. Mặc dù tôi đã cố gắng hết sức để kiểm tra kỹ lưỡng, nhưng việc sử dụng script này hoàn toàn thuộc về rủi ro của bạn (Use at your own risk).

Tác giả không chịu trách nhiệm cho bất kỳ thiệt hại nào liên quan đến:

- Mất mát dữ liệu.

- Lỗi cấu hình hệ thống.

- Các vấn đề bảo mật phát sinh.

Tuyên bố miễn trừ trách nhiệm đầy đủ được tôi công bố tại đây: https://wpsila.com/disclaimer

