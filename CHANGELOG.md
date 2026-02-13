# Changelog

Tất cả những thay đổi đáng chú ý của dự án wpsila sẽ được ghi lại trong file này.

Định dạng dựa trên [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
và dự án này tuân thủ [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Backup ở cấp độ local, như một dự phòng, nhưng không thay thế UpdraftPlus.
- Tạo file /etc/caddy/snippets/wp_common.conf chứa các cấu hình chung cho toàn bộ website. Chỉ cần sửa ở đây sẽ cập nhật cho toàn bộ (ví dụ như chặn file, cách cache dữ liệu).

## [1.2.7] - 2025-02-14

### Fixed
- Chuyển qua Scoket với mã an toàn hơn.
- Bổ sung gỡ cài đặt Redis cache.

## [1.2.6] - 2025-02-13

### Fixed
- Quay về sử dụng TCP, vì việc chuyển từ TCP lên Unix có vấn đề, mặc dù mỗi cái cài mới thì không sao.
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
