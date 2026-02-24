// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/debt_record_model.dart';
import '../models/habit_breaker_model.dart';
import '../models/recurring_transaction_model.dart';
import '../models/savings_goal_model.dart';
import '../models/settings_model.dart';
import '../models/transaction_model.dart';

class BackupService {
  /// Khóa và lưu tất cả Hive boxes, nén thành file zip và chia sẻ.
  static Future<void> exportData(BuildContext context) async {
    try {
      // 1. Force boxes to flush to disk
      final boxes = [
        Hive.box<Transaction>('transactions'),
        Hive.box<double>('budgetBox'),
        Hive.box<AppSettings>('settings'),
        Hive.box<SavingsGoal>('savingsGoals'),
        Hive.box<RecurringTransaction>('recurringTransactions'),
        Hive.box<DebtRecord>('debtRecords'),
        Hive.box<HabitBreaker>('habitBreakers'),
        Hive.box('currency_data'),
      ];
      for (final box in boxes) {
        if (box.isOpen) await box.flush();
      }

      // 2. Get Hive directory
      final appDir = await getApplicationDocumentsDirectory();

      // 3. Create zip file
      final tempDir = await getTemporaryDirectory();
      final backupFile = File('${tempDir.path}/finance_manager_backup.zip');

      final encoder = ZipFileEncoder();
      encoder.create(backupFile.path);

      // Add all .hive files to zip
      final dir = Directory(appDir.path);
      dir.listSync().forEach((entity) {
        if (entity is File && entity.path.endsWith('.hive')) {
          encoder.addFile(entity);
        }
      });
      encoder.close();

      // 4. Share the file
      if (context.mounted) {
        final xFile = XFile(backupFile.path, mimeType: 'application/zip');
        await Share.shareXFiles([xFile],
            text: 'Sao lưu dữ liệu Quản lý chi tiêu');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi sao lưu: $e')),
        );
      }
    }
  }

  /// Chọn file backup zip và thay thế dữ liệu hiện tại.
  static Future<void> importData(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;

        // Basic validation
        if (!filePath.toLowerCase().endsWith('.zip')) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Vui lòng chọn file backup .zip hợp lệ!')),
            );
          }
          return;
        }

        // 1. Close all active boxes
        await Hive.close();

        // 2. Extract zip to Hive directory
        final appDir = await getApplicationDocumentsDirectory();
        final bytes = File(filePath).readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);

        for (final file in archive) {
          final filename = file.name;
          if (file.isFile && filename.endsWith('.hive')) {
            final data = file.content as List<int>;
            File('${appDir.path}/$filename')
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
          }
        }

        // 3. Re-open boxes (similar to main.dart)
        await Future.wait([
          Hive.openBox<Transaction>('transactions'),
          Hive.openBox<double>('budgetBox'),
          Hive.openBox<AppSettings>('settings'),
          Hive.openBox<SavingsGoal>('savingsGoals'),
          Hive.openBox<RecurringTransaction>('recurringTransactions'),
          Hive.openBox<DebtRecord>('debtRecords'),
          Hive.openBox<HabitBreaker>('habitBreakers'),
          Hive.openBox('currency_data'),
        ]);

        if (context.mounted) {
          // Show success and require restart
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.check_circle_rounded, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(child: Text('Khôi phục thành công!')),
                ],
              ),
              content: const Text('Dữ liệu đã được khôi phục.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // close dialog
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khôi phục: $e')),
        );
      }
      // Attempt to reopen boxes if failed midway to prevent app crash
      await Future.wait([
        Hive.openBox<Transaction>('transactions'),
        Hive.openBox<double>('budgetBox'),
        Hive.openBox<AppSettings>('settings'),
        Hive.openBox<SavingsGoal>('savingsGoals'),
        Hive.openBox<RecurringTransaction>('recurringTransactions'),
        Hive.openBox<DebtRecord>('debtRecords'),
        Hive.openBox<HabitBreaker>('habitBreakers'),
        Hive.openBox('currency_data'),
      ]);
    }
  }
}
