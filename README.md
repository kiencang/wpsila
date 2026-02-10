Phần này chỉ dành cho dev, không liên quan đến người dùng cuối.
## Cơ chế test
- Sử dụng install_wpsila_no_check_sum.sh để tải các file về mà không cần checksum và các giới hạn khác, nó sẽ ghi đè lên file cũ.
- Kiểm tra mọi thứ hoạt động ổn thỏa mới ra phiên bản mới phụ thuộc version.
- Sử dụng checksum phức tạp hơn nhưng nó là rào cản cần thiết cho chính dev tránh ra các phiên bản vội vàng (nó là gờ giảm tốc).
- Ngoài ra việc phải up lên install_wpsila lên Cloudflare page thay vì trỏ thẳng về địa chỉ trên GitHub cũng là cái phanh để giảm thiểu tốc độ ra phiên bản.

## Ra phiên bản mới
Mỗi khi ra phiên bản mới cần làm như sau:
- Cập nhật version mới cho check_for_update.sh trong main (ví dụ v0.3.1)
- Trên GitHub, tạo phiên bản mới tương ứng với version vừa nhập trong check_for_update.sh
- Sử dụng generate_checksum để tạo checksum cho các file của phiên bản mới (ví dụ dùng WSL trên Windows bash ./generate_checksum.sh)
- Nhớ thay đổi version tương ứng trong generate_checksum để nó tạo chính xác các file theo version
- Cập nhật các checksum này vào file install_wpsila.sh (nhớ điều chỉnh cả phiên bản)
- Đẩy file install_wpsila.sh lên vps.wpsila.com
- Cập nhật các thông báo vesion trên README của main và trên website chính wpsila.com

Lúc này vps.wpsila.com sẽ chứa phiên bản mới nhất. Tải có kiểm tra checksum để đảm bảo dữ liệu tải về đầy đủ.

---

File install_wpsila_no_check_sum.sh dùng để test kiểm tra mã trước khi ra phiên bản chính thức, nó không có các ràng buộc về:
- Checksum
- Chặn ghi đè

Do vậy tiện để tải về kiểm tra. Phiên bản chính thức thì không được phép dùng file này.

## Cập nhật dự kiến
- Cập nhật danh sách IP của Cloudflare một cách tự động

Dải IP của Cloudflare được lưu trữ ở đây: https://www.cloudflare.com/ips/

Nó dường như ít thay đổi, hơn 2 năm qua dải IP đó vẫn giữ nguyên.

## Chức năng của các file trong chương trình

Dùng branch main để đối chiếu với thông tin bên dưới, quan trọng cho dev để dễ nhận diện các chức năng file trong chương trình.

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

k. Cấu hình swap (tăng RAM cho web)
- setup_swap.sh

l. Tăng cường bảo mật
- setup_fail2ban_core.sh

---
## Các file không có trong phần cài đặt chính
- install_wpsila.sh: Nó được đẩy lên VPS làm file để tải toàn bộ script về.
- generate_checksum.sh: Dùng để tạo checksum cho các file (Có thể dùng Visual Studio Code + WSL [Ubuntu] để làm việc này).
- install_wpsila_no_check_sum.sh: Dùng để test bash script trước khi triển khai chính thức (nó không tải wpsila.conf về).
- verify_wpsila.sh: Đang phát triển thêm, dùng để test nhanh trạng thái VPS sau khi cài.
