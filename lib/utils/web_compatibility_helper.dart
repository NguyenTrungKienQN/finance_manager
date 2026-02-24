import 'package:flutter/material.dart';

class WebCompatibilityHelper {
  static void showUnsupportedMessage(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blueAccent),
              SizedBox(width: 12),
              Expanded(child: Text('Thông báo')),
            ],
          ),
          content: const Text(
            'Tính năng này không hỗ trợ trên nền tảng Web. Vui lòng cài đặt và sử dụng phiên bản mobile đầy đủ.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đã hiểu',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
