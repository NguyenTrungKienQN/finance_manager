# Hướng dẫn tạo Adaptive Icon (Sửa lỗi viền trắng)

Adaptive Icons (Biểu tượng thích ứng) giúp icon của bạn hiển thị đẹp mắt trên mọi thiết bị Android, tự động thay đổi hình dạng (tròn, vuông bo góc, giọt nước...) tùy theo giao diện của hãng sản xuất.

## 1. Tại sao lại bị viền trắng?
Android 8.0 trở lên yêu cầu icon phải có 2 lớp riêng biệt:
1.  **Lớp nền (Background)**: Một màu hoặc hình ảnh đặc.
2.  **Lớp hình (Foreground)**: Logo hoặc biểu tượng chính nằm ở giữa, có nền trong suốt.

Nếu bạn chỉ cung cấp một hình vuông duy nhất (`app_icon.png`), Android sẽ ép nó vào giữa một hình tròn trắng mặc định để đảm bảo kích thước chuẩn -> Gây ra viền trắng xấu xí.

## 2. Cách khắc phục
Bạn cần tách icon hiện tại thành 2 phần:

### Bước 1: Chuẩn bị file
1.  **Foreground**: Tách lấy logo chính (ví dụ: hình cái ví tiền), xóa sạch nền xung quanh để thành trong suốt. Lưu file này là `assets/icon/adaptive_foreground.png`. (Kích thước khuyên dùng: 1024x1024).
2.  **Background**: Bạn có 2 lựa chọn:
    *   **Dùng màu đơn sắc**: Chọn mã màu (ví dụ: `#00BFA6`, `#FFFFFF`).
    *   **Dùng hình ảnh**: Tạo file ảnh nền (ví dụ: gradient, pattern...) và lưu là `assets/icon/adaptive_background.png` (kích thước: 1024x1024).

### Bước 2: Cấu hình `pubspec.yaml`
Mở file `pubspec.yaml` và sửa phần `flutter_launcher_icons`:

**Cách 1: Dùng màu đơn sắc làm background**
```yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/icon/app_icon.png" # Giữ lại icon cũ cho Android đời thấp & iOS
  min_sdk_android: 21
  
  # Adaptive Icon với màu nền:
  adaptive_icon_background: "#00BFA6"  # Thay bằng mã màu nền của bạn
  adaptive_icon_foreground: "assets/icon/adaptive_foreground.png"
```

**Cách 2: Dùng hình ảnh làm background (gradient, pattern...)**
```yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/icon/app_icon.png"
  min_sdk_android: 21
  
  # Adaptive Icon với hình ảnh nền:
  adaptive_icon_background: "assets/icon/adaptive_background.png"  # File ảnh nền của bạn
  adaptive_icon_foreground: "assets/icon/adaptive_foreground.png"
```

### Bước 3: Chạy lệnh tạo icon
Mở terminal và chạy lệnh sau để Flutter tự động tạo các file icon mới:

```bash
dart run flutter_launcher_icons
```

Sau khi chạy xong, hãy xóa app cũ trên máy ảo/điện thoại và cài lại (`flutter run`) để thấy thay đổi.
