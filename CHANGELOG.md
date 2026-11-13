# Changelog

Tất cả những thay đổi đáng chú ý của dự án wpsila sẽ được ghi lại trong file này.

Định dạng dựa trên [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
và dự án này tuân thủ [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.1] - 2025-11-13
### Added
- Triển khai kiến trúc Snippet dùng chung `/etc/caddy/snippets/wp_common.conf` cho toàn bộ website trên VPS (kèm cơ chế tự động khởi tạo tương thích ngược trong `install_caddyserver.sh`, `caddyfile.sh` và `caddyfile_subdomain.sh`): chỉ cần chỉnh sửa 1 file duy nhất để cập nhật đồng loạt rule bảo mật, chặn bot và cấu hình cache cho mọi tên miền;
- Nâng cấp cơ chế dự phòng đa tầng (Multi-tier Fallback) và chống Rate-Limit API cho toàn bộ các thành phần tải từ Internet:
  - **PHP (`install_php.sh`)**: 3 tầng dự phòng (PPA Ondrej Launchpad -> Sury Direct CDN kèm gói `.deb` keyring dự phòng -> Kho Ubuntu mặc định kèm cơ chế tự động nhận diện phiên bản PHP hệ thống và đồng bộ vào `wpsila.conf`);
  - **MariaDB (`install_mariadb.sh`)**: 3 tầng dự phòng (MariaDB Dynamic GeoIP Mirror với 2 nguồn GPG key -> MariaDB Official CDN `dlm.mariadb.com` -> Kho Ubuntu mặc định);
  - **Caddy (`install_caddyserver.sh`)**: 3 tầng dự phòng (Cloudsmith APT Repo -> Gói `.deb` chính thức từ GitHub Releases `caddyserver/caddy` qua HTTP Redirect chống Rate-Limit API -> Kho Ubuntu mặc định);
  - **WordPress Core & WP-CLI (`wordpress.sh`)**: 2 tầng dự phòng cho WP-CLI (`raw.githubusercontent.com` có kiểm tra SHA-512 -> `github.com/wp-cli/wp-cli/releases/latest`) và 2 tầng cho WordPress Core (`wordpress.org` có kiểm tra SHA-1 -> Bản phát hành Stable Tag mới nhất từ GitHub Mirror `WordPress/WordPress` để chống lỗi HTTP 429 trên IP VPS);
  - **Adminer (`setup_adminer.sh`)**: 2 tầng dự phòng (`www.adminer.org` -> GitHub `vrana/adminer` release qua HTTP Redirect) kèm kiểm tra tính hợp lệ của mã nguồn PHP tải về;
  - **Redis Object Cache (`install_redis_cache.sh`)**: Dự phòng cài plugin từ gói `.zip` trực tiếp trên `downloads.wordpress.org` nếu kho API của WP-CLI gặp sự cố.
### Fixed
- Sửa lỗi quên điều chỉnh phiên bản mới nhất ở `check_for_update.sh`, bổ sung lọc hậu tố phiên bản (`-beta`, `-rc`) trước phép toán `10#` và lấy tag qua HTTP Redirect;
- Bổ sung `Match all` vào cuối file `/etc/ssh/sshd_config.d/05-sftp-jail.conf` (đổi từ `99-sftp-jail.conf` sang tiền tố `05-` để đọc trước `50-cloud-init.conf` trên VPS Cloud, giúp SFTP vẫn đăng nhập bằng mật khẩu được trong khi vẫn bảo toàn `PasswordAuthentication no` toàn cục) trong `setup_sftp.sh`;
- Bổ sung cờ `CREATED_CADDY_FILE` vào cơ chế Rollback trong `install_wp.sh` để không xóa nhầm file `.caddy` của website đang hoạt động khi người dùng nhập trùng tên miền cũ;
- Bổ sung kiểm tra dự phòng bằng `pgrep` trong `anti_apt_lock.sh` phòng trường hợp bản Ubuntu Minimal chưa cài sẵn gói `psmisc` (`fuser`);
- Sửa lỗi thứ tự nạp file cấu hình PHP-FPM Pool trong `tune_pool.sh` (đổi tiền tố `99-` sang `zz-wpsila-pool-tune.conf` để được đọc sau `www.conf`, tránh bị `www.conf` ghi đè ngược), bổ sung `request_terminate_timeout = 300s`, và cân đối lại ngân sách `pm.max_children` đồng bộ với MariaDB/Redis trên VPS 1GB/2GB/4GB/8GB/16GB+ để chống tràn RAM (OOM);
- Loại bỏ biến `innodb_buffer_pool_instances` đã bị gỡ khỏi MariaDB 10.6+, tắt `performance_schema`, hạ `key_buffer_size = 8M` (giải phóng 120MB RAM lãng phí cho MyISAM mặc định của Ubuntu), cân đối lại `innodb_buffer_pool_size` ưu tiên cho WordPress Blog trên VPS 1GB–2GB, và bổ sung `thread_cache_size`, `table_open_cache`, `table_definition_cache`, `innodb_log_buffer_size` trong `tune_mariadb.sh`;
- Tối ưu `tune_php.sh` và `wordpress.sh` chuyên biệt cho WordPress Blog trên VPS 1GB–2GB: tự động co giãn `opcache.memory_consumption` (`96M`/`128M`/`192M`), `opcache.max_accelerated_files` (`10000`/`16229`/`32531`), `memory_limit` (`192M` trên 1GB, `256M` trên 2GB+), nâng `opcache.revalidate_freq=10` giảm tải đọc đĩa, giới hạn `WP_POST_REVISIONS=5` & `AUTOSAVE_INTERVAL=120` chống phình Database, và đồng bộ `post_max_size=105M` (PHP) với `max_size 105MB` (Caddy);
- Tối ưu Redis Object Cache chạy 100% In-Memory (`save ""`, `appendonly no`), bật giải phóng bộ nhớ bất đồng bộ (`lazyfree-lazy-*`), bật `vm.overcommit_memory=1`, và tránh khởi động lại Redis/PHP-FPM không cần thiết khi cài thêm cho các website tiếp theo trong `install_redis_cache.sh`;
- Nâng cấp toàn diện rule bảo mật trong `wp_common.conf`: chặn thực thi PHP kèm chống bypass `PATH_INFO` (`(/|$)`) trong `/wp-content/uploads/`, chặn truy cập `.git`/`.env`/file ẩn ở mọi cấp thư mục con (nhưng vẫn mở `/.well-known/*` cho SSL), chặn gọi `/wp-cron.php` qua HTTP, và chặn dò danh sách user nặc danh qua cả `/wp-json/wp/v2/users*` lẫn `/?rest_route=/wp/v2/users*` nhưng vẫn cho phép Admin đã đăng nhập (`wordpress_logged_in_` cookie) sử dụng Gutenberg Editor bình thường;
- Bổ sung `allow_url_include = 0` và `session.cookie_samesite = Lax` trong `tune_php.sh` (vẫn giữ `allow_url_fopen = 1` để đảm bảo cài đặt Plugin/Theme tự động mượt mà);
- Kiểm tra tương thích phiên bản Caddy (`>= 2.7`) khi ghi khối `trusted_proxies static`, bổ sung tường minh gói `python3-systemd` cho Fail2Ban trên Ubuntu 22.04 Minimal (`install_caddyserver.sh`, `setup_fail2ban_core.sh`), mở `/.well-known/*` và nhận tag 2 số cho Adminer (`setup_adminer.sh`);
- Khắc phục lỗi thoát ngang khi nhấn `Ctrl+C` trong `view_logs.sh`, neo đầu dòng `^[[:space:]]*define\(` chống khớp nhầm comment khi trích xuất `wp-config.php`, kiểm tra quyền `ionice` trong `manage_backup.sh` trên môi trường LXC/OpenVZ, lưu bền vững `vm.overcommit_memory=1` vào `/etc/sysctl.d/99-wpsila-redis.conf` (`install_redis_cache.sh`), đảm bảo `/usr/sbin` trong `PATH` khi gọi `php-fpm -t` (`tune_php.sh`, `tune_pool.sh`), và tải cập nhật an toàn dạng Atomic Staging trong `install_wpsila.sh`;
- Chuyển toàn bộ các lệnh WP-CLI trên website đang hoạt động sang chạy dưới quyền `www-data` (`runuser -u www-data -- wp ...`) và ưu tiên đọc tĩnh `wp-config.php` trong `manage_backup.sh`, `remove_web.sh`, `get_db_info.sh` nhằm triệt tiêu nguy cơ leo thang đặc quyền lên `root`;
- Bổ sung cờ bất biến `chattr +i` / `chattr -i` khi khóa/mở khóa `wp-config.php` (`manage_wp_config.sh`, `install_redis_cache.sh`, `uninstall_redis_cache.sh`, `manage_backup.sh`, `remove_web.sh`) và hiển thị trạng thái `640+i` trong `list_websites.sh`;
- Bổ sung cờ `--force-confdef` và `--force-confold` khi cập nhật bản vá trong `list_websites.sh` để không hiện hộp thoại hỏi ghi đè cấu hình làm gián đoạn người dùng;
- Thay `swapoff -a` bằng `swapoff "$SWAP_FILE"` trong `setup_swap.sh` để không làm gián đoạn phân vùng Swap/ZRAM sẵn có của VPS;
- Bổ sung cơ chế tự động Rollback (`trap`) trong `install_wp.sh` nếu quá trình cài đặt WordPress gặp sự cố giữa chừng, và cho phép chạy tiếp `install_lcmp.sh` nếu lần cài trước bị gián đoạn;
- Xác thực mã băm toàn vẹn SHA-1 cho gói WordPress (`latest.tar.gz`) và SHA-512 cho `wp-cli.phar`;
- Chuẩn hóa kiểm tra định dạng tên miền (Regex RFC 1035), bảo vệ quyền sở hữu `root:root` cho mã nguồn Adminer (`setup_adminer.sh`), và tạo các file mật khẩu với `umask 077`.

## [1.4.0] - 2025-11-13
### Added
- Thêm tính năng Backup local;
- Thêm tính năng liệt kê danh sách website và tên các phiên bản cụ thể của PHP, MySQL, Caddy, Redis đang cài trên server;
- Thêm các dự phòng khi tải các gói PHP và MariaDB, để tránh trường hợp một nguồn quá tải không thể thực hiện được cài đặt (bổ sung thêm 2 nguồn, một của Ubuntu, một là trang CDN của tác giả gốc);

## [1.3.0] - 2025-02-23
### Added
- Thêm tính năng xóa file mật khẩu để tăng cường bảo mật.

## [1.2.9] - 2025-02-16
### Fixed
- Cập nhật Caddyfile chặn thêm một số bot SEO và rác tốn tài nguyên nhưng hầu như không hữu dụng.
- Chặn thêm dò user trang quản trị ?author=
- Điều chỉnh comment, thông báo ở một vài file cho hợp lý hơn.

## [1.2.7] - 2025-02-14
### Fixed
- Chuyển qua Unix Socket với mã an toàn hơn phiên bản 1.2.4.
- Bổ sung gỡ cài đặt Redis cache để giải quyết vấn đề các cài đặt cũ ảnh hưởng lên cài đặt mới.

## [1.2.6] - 2025-02-13
### Fixed
- Quay về sử dụng TCP, vì việc chuyển từ TCP lên Unix Socket có vấn đề, mặc dù mỗi cái cài mới thì không sao.
- Ưu tiên ổn định, quay về bản cũ.

## [1.2.5] - 2025-02-13
### Fixed
- Chuyển Redis cache sang kết nối Unix Socket thay cho TCP để nhanh và an toàn hơn.

## [1.2.4] - 2025-02-12
### Fixed
- Chỉnh lại mã một số file mới tạo cho dễ đọc hơn.

## [1.2.3] - 2025-02-11
### Fixed
- Chỉnh sửa mã redis cache cho dễ đọc & comment chuẩn xác hơn.

## [1.2.0] - 2025-02-11
### Added
- Thêm tính năng redis cache cho website có traffic lớn.

## [1.1.10] - 2025-02-10
### Fixed
- Thêm tính năng lấy thông tin database của một website cụ thể.

## [1.1.9] - 2025-02-09
### Fixed
- Xóa cronjob hệ thống khi xóa website.

## [1.1.8] - 2025-02-09
### Fixed
- Khắc phục lỗi liên quan đến tắt cronjob mặc định trong WP.

## [1.1.7] - 2025-02-09
### Fixed
- Thêm tính năng khôi phục lại mật khẩu WP.

## [1.1.6] - 2025-02-09
### Fixed
- Dùng cronjob hệ thống thay vì cronjob mặc định của WordPress.

## [1.1.5] - 2025-02-09
### Fixed
- Khắc phục lỗi EOL Conversion.

## [1.1.4] - 2025-02-09
### Fixed
- Tách code dài dòng ra khỏi menu.

## [1.1.3] - 2025-02-09
### Fixed
- Bổ sung tính năng xem file log ngay qua giao diện.

## [1.1.2] - 2025-02-08
### Fixed
- Cho phép quản lý chặt hơn wp-config.php.

## [1.1.1] - 2025-01-31
### Fixed
- Bổ sung dải IP của Cloudflare. Cả ở phần Fail2Ban SSH và Global CaddyFile.
