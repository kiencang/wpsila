Phần này chỉ dành cho dev, không liên quan đến người dùng cuối.

Mỗi khi ra phiên bản mới cần làm như sau:
- Cập nhật version mới cho check_for_update.sh trong main (ví dụ v0.3.1)
- Trên GitHub, tạo phiên bản mới tương ứng với version vừa nhập trong check_for_update.sh
- Sử dụng generate_checksum để tạo checksum cho các file của phiên bản mới (ví dụ dùng WSL trên Windows bash ./generate_checksum.sh)
- Nhớ thay đổi version tương ứng trong generate_checksum để nó tạo chính xác các file theo version
- Cập nhật các checksum này vào file install_wpsila.sh
- Đẩy file install_wpsila.sh lên vps.wpsila.com
- Cập nhật các thông báo vesion trên README của main và trên website chính wpsila.com

Lúc này vps.wpsila.com sẽ chứa phiên bản mới nhất. Tải có kiểm tra checksum để đảm bảo dữ liệu tải về đầy đủ.

---

File install_wpsila_no_check_sum.sh dùng để test kiểm tra mã trước khi ra phiên bản chính thức, nó không có các ràng buộc về:
- Checksum
- Chặn ghi đè

Do vậy tiện để tải về kiểm tra. Phiên bản chính thức thì không được phép dùng file này.

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
