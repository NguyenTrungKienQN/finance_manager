import 'dart:io';
import 'package:excel/excel.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction_model.dart';

class ExportService {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi',
    symbol: '₫',
    decimalDigits: 0,
  );

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  /// Filters transactions based on date range
  static List<Transaction> _getFilteredTransactions(DateTime start, DateTime end) {
    final box = Hive.box<Transaction>('transactions');
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);

    return box.values.where((tx) {
      return tx.date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
             tx.date.isBefore(endDate.add(const Duration(seconds: 1)));
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Exports to Excel (.xlsx)
  static Future<void> exportToExcel(DateTime start, DateTime end) async {
    final transactions = _getFilteredTransactions(start, end);
    final excel = Excel.createExcel();
    final sheet = excel['Giao dịch'];
    excel.delete('Sheet1');

    final headers = ['Ngày', 'Số tiền (VNĐ)', 'Danh mục', 'Ghi chú', 'Lấy từ Két sắt', 'Vượt ngân sách'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (var tx in transactions) {
      sheet.appendRow([
        TextCellValue(_dateFormat.format(tx.date)),
        IntCellValue(tx.amount.toInt()),
        TextCellValue(tx.category),
        TextCellValue(tx.notes ?? ''),
        IntCellValue(tx.safeAmount.toInt()),
        TextCellValue(tx.isOverBudget ? 'Có' : 'Không'),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) return;

    final fileName = 'Bao_cao_chi_tieu_${DateFormat('ddMMyy').format(start)}_den_${DateFormat('ddMMyy').format(end)}.xlsx';
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Báo cáo chi tiêu từ Finance Manager'));
  }

  /// Exports to PDF (.pdf)
  static Future<void> exportToPdf(DateTime start, DateTime end) async {
    final transactions = _getFilteredTransactions(start, end);
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('BÁO CÁO CHI TIÊU', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text('Finance Manager', style: pw.TextStyle(color: PdfColors.grey)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Thời gian: ${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}'),
          pw.Text('Số lượng giao dịch: ${transactions.length}'),
          pw.Text('Tổng cộng: ${_currencyFormat.format(transactions.fold(0.0, (sum, tx) => sum + tx.amount))}'),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Ngày', 'Số tiền', 'Danh mục', 'Ghi chú', 'Két sắt'],
            data: transactions.map((tx) => [
              DateFormat('dd/MM/yy').format(tx.date),
              _currencyFormat.format(tx.amount),
              tx.category,
              tx.notes ?? '',
              tx.safeAmount > 0 ? 'Có' : 'Không',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellHeight: 30,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.center,
            },
          ),
        ],
      ),
    );

    final fileName = 'Bao_cao_chi_tieu_${DateFormat('ddMMyy').format(start)}_den_${DateFormat('ddMMyy').format(end)}.pdf';
    final bytes = await pdf.save();
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Báo cáo chi tiêu PDF từ Finance Manager'));
  }
}
