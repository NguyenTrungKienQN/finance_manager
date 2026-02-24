# 🔧 Quick Reference & Troubleshooting

## ⚡ Các Lệnh Thường Dùng

```bash
# Cài đặt dependencies
flutter pub get

# Generate Hive adapters
flutter pub run build_runner build

# Chạy ứng dụng trên thiết bị
flutter run

# Chạy với log chi tiết
flutter run -v

# Xóa cache build
flutter clean

# Build APK (Android)
flutter build apk --release

# Build iOS
flutter build ios --release
```

---

## 🐛 Giải Pháp Sự Cố Thường Gặp

### ❌ Lỗi: "TransactionAdapter not found"
```
ERROR: Unable to generate [...]
```

**Giải pháp:**
```bash
flutter clean
flutter pub get
flutter pub run build_runner build
flutter run
```

---

### ❌ Lỗi: "Box not open 'transactions'"
```
HiveError: Box not found. Did you forget to call Hive.openBox()?
```

**Giải pháp:**
Kiểm tra `lib/main.dart` có đoạn này không:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TransactionAdapter());
  await Hive.openBox<Transaction>('transactions');  // ← Cần có dòng này
  runApp(const MyApp());
}
```

---

### ❌ Lỗi: "Camera permission denied"
```
E/AndroidRuntime: Permission Denied
```

**Giải pháp Android:**
Mở `android/app/src/main/AndroidManifest.xml` thêm:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

**Giải pháp iOS:**
Mở `ios/Runner/Info.plist` thêm:
```xml
<key>NSCameraUsageDescription</key>
<string>Ứng dụng cần quyền camera để quét hóa đơn</string>
```

---

### ❌ Lỗi: "google_mlkit_text_recognition not found"
```
Package google_mlkit_text_recognition not found
```

**Giải pháp:**
```bash
flutter pub get
flutter pub run build_runner build
```

---

### ❌ Lỗi: "No device found"
```
Error: No devices found
```

**Giải pháp:**
```bash
# Kiểm tra thiết bị kết nối
flutter devices

# Chạy emulator
flutter emulators --launch <emulator_id>

# Hoặc kết nối USB và bật USB Debugging
```

---

### ❌ Lỗi: "Null safety error"
```
The argument type 'Null' can't be assigned to the parameter type
```

**Giải pháp:**
Thêm `?` nếu biến có thể null:
```dart
String? statusMessage;  // Thay vì String statusMessage
```

---

## 📝 Chỉnh Sửa Hạn Mức Chi Tiêu

Mở `lib/main.dart` tìm dòng:
```dart
final double _dailyLimit = 500000; // 500k/ngày
```

Thay số `500000` bằng hạn mức bạn muốn (đơn vị: VNĐ)

**Ví dụ:**
```dart
final double _dailyLimit = 1000000;  // 1 triệu/ngày
final double _dailyLimit = 300000;   // 300k/ngày
```

---

## 🎨 Thay Đổi Màu Sắc

### Màu chính của app
Mở `lib/main.dart` tìm:
```dart
colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
```

Thay `Colors.teal`:
```dart
Colors.blue        // Xanh dương
Colors.green       // Xanh lá
Colors.purple      // Tím
Colors.orange      // Cam
Colors.indigo      // Chàm
Colors.cyan        // Xanh ngọc
```

### Màu nút bấm
Tìm `ElevatedButton` hoặc `FloatingActionButton` thay `backgroundColor`:
```dart
backgroundColor: Colors.teal,  // Thay thành màu khác
```

### Màu biểu đồ
Mở `lib/widgets/weekly_chart_widget.dart` tìm:
```dart
color: isOver ? Colors.redAccent : Colors.green,
```

---

## 📱 Kiểm Tra Permission

### Android
Mở `android/app/src/main/AndroidManifest.xml` và kiểm tra:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### iOS
Mở `ios/Runner/Info.plist` và kiểm tra:

```xml
<key>NSCameraUsageDescription</key>
<string>Ứng dụng cần quyền camera để quét hóa đơn</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Ứng dụng cần quyền thư viện ảnh</string>
```

---

## 🗑️ Xóa Dữ Liệu

Để xóa tất cả dữ liệu Hive:

**Cách 1: Xóa app**
- Dỡ cài đặt ứng dụng
- Cài lại từ đầu

**Cách 2: Thêm nút trong UI**
```dart
// Thêm vào home screen
TextButton(
  onPressed: () async {
    await Hive.box<Transaction>('transactions').clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Đã xóa tất cả dữ liệu")),
    );
  },
  child: Text("Xóa tất cả"),
)
```

---

## 📊 Dữ Liệu Hive Lưu Ở Đâu?

### Android
```
/data/data/com.example.finance_manager/app_flutter/
```

Xem bằng:
```bash
adb shell
cd /data/data/com.example.finance_manager
```

### iOS
```
/Documents/ folder
```

Xem bằng Xcode hoặc iTunes File Sharing

---

## 🔍 Debug Mode

Thêm vào `lib/main.dart` để xem dữ liệu Hive:

```dart
// Trong main() sau khi openBox
var box = Hive.box<Transaction>('transactions');
print('Total transactions: ${box.length}');
for (var transaction in box.values) {
  print('${transaction.date}: ${transaction.amount} - ${transaction.category}');
}
```

---

## 🆘 Khi Nào Nên Sử Dụng `flutter clean`?

**Nên dùng khi:**
- ✅ Thay đổi dependencies
- ✅ Thay đổi native code (Android/iOS)
- ✅ Xóa file generated (`.g.dart`)
- ✅ Gặp lỗi غريب
- ✅ Build không thành công

**Không cần dùng khi:**
- ❌ Chỉ thay đổi Dart code
- ❌ Chỉ thay đổi UI

---

## 📦 Dependencies Chính

| Package | Phiên Bản | Dùng Cho |
|---------|----------|---------|
| intl | ^0.19.0 | Định dạng tiền tệ |
| uuid | ^4.3.3 | Tạo ID duy nhất |
| hive | ^2.2.3 | Database cục bộ |
| hive_flutter | ^1.1.0 | Hive cho Flutter |
| google_mlkit_text_recognition | ^0.11.0 | Quét text OCR |
| image_picker | ^1.0.7 | Chụp ảnh |
| fl_chart | ^0.66.2 | Biểu đồ |
| build_runner | ^2.4.6 | Generate code |
| hive_generator | ^2.0.1 | Generate Hive adapter |

---

## ✨ Tips Hiệu Suất

1. **Giảm kích thước app:**
   ```bash
   flutter build apk --split-per-abi
   ```

2. **Tối ưu hình ảnh:**
   - Dùng `.webp` thay vì `.png`
   - Nén trước khi import

3. **Lazy load data:**
   - Không load tất cả giao dịch một lần
   - Dùng pagination

4. **Cache image:**
   ```dart
   Image.asset('assets/image.png',
     cacheHeight: 300,
     cacheWidth: 300,
   );
   ```

---

## 🔐 Bảo Mật

**Lưu ý:**
- ⚠️ Hive không mã hóa, dùng cho dữ liệu không nhạy cảm
- ⚠️ Không lưu mật khẩu hoặc token
- ⚠️ Nếu cần bảo mật, dùng Encrypted Hive:

```dart
var encryptionKey = Hive.generateSecureKey();
var box = await Hive.openBox<Transaction>(
  'transactions',
  encryptionKey: encryptionKey,
);
```

---

## 📞 Liên Hệ & Hỗ Trợ

- **Flutter Docs:** https://flutter.dev
- **Hive Docs:** https://pub.dev/packages/hive
- **ML Kit Docs:** https://pub.dev/packages/google_mlkit_text_recognition

---

**Cập nhật lần cuối: 5 tháng 2 năm 2026**
