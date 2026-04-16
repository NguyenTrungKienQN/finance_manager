// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:typed_data';
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

      // 2. Get the ACTUAL Hive directory from an open box
      final boxPath = Hive.box<Transaction>('transactions').path;
      print("BACKUP DEBUG: boxPath = $boxPath");
      if (boxPath == null) throw Exception('Không tìm thấy đường dẫn Hive storage');
      final appDir = Directory(File(boxPath).parent.path);

      // Add all .hive files to zip in-memory. Use recursive listing.
      final dir = Directory(appDir.path);
      int fileCount = 0;
      final archive = Archive();
      
      print("BACKUP DEBUG: searching in ${dir.path}");
      dir.listSync(recursive: true).forEach((entity) {
        if (entity is File && entity.path.endsWith('.hive')) {
          final fileName = entity.uri.pathSegments.last;
          final bytes = entity.readAsBytesSync();
          print("BACKUP DEBUG: Adding $fileName (${bytes.length} bytes)");
          archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
          fileCount++;
        }
      });

      if (fileCount == 0) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy dữ liệu để sao lưu.')),
          );
        }
        return;
      }

      print("BACKUP DEBUG: Encoding zip with $fileCount files...");
      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) throw Exception('Lỗi mã hóa file zip');

      // 4. Save the file using FilePicker (Save UI) instead of Share
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Lưu bản sao lưu',
        fileName: 'finance_manager_backup.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: Uint8List.fromList(zipData), // Pass bytes to let FilePicker handle SAF writing
      );

      if (outputFile != null) {
        // FilePicker automatically writes the bytes to the picked location on Android/Web
        // We just need to notify the user of success.
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Đã lưu sao lưu thành công tại: $outputFile')),
          );
        }
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

        // 1. Get the ACTUAL Hive directory from an open box BEFORE closing
        final boxPath = Hive.box<Transaction>('transactions').path;
        if (boxPath == null) throw Exception('Không tìm thấy đường dẫn Hive storage');
        final appDir = Directory(File(boxPath).parent.path);

        // 2. Close all active boxes so we can safely overwrite files
        await Hive.close();

        // 3. Extract zip to Hive directory
        final bytes = File(filePath).readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);

        int filesRestored = 0;
        for (final file in archive) {
          final filename = file.name;
          if (file.isFile && filename.endsWith('.hive')) {
            final data = file.content as List<int>;
            File('${appDir.path}/$filename')
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
            filesRestored++;
          }
        }

        if (filesRestored == 0) {
           if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File backup trống hoặc không hợp lệ.')),
             );
           }
           // Must reopen the boxes if we aborted after closing them!
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
           return;
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
              content: const Text('Ứng dụng sẽ đóng để áp dụng dữ liệu. Vui lòng mở lại ứng dụng sau đó.'),
              actions: [
                TextButton(
                  onPressed: () {
                    exit(0); // Force close app so Hive re-reads from disk on next launch
                  },
                  child: const Text('Đóng ứng dụng'),
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
