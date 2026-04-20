import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/settings_model.dart';

/// Fetches real-time financial data from Hive to inject as AI context.
class ChatContextService {
  static String buildContext() {
    final txBox = Hive.box<Transaction>('transactions');
    final settingsBox = Hive.box<AppSettings>('settings');
    final settings = settingsBox.get('appSettings') ?? AppSettings();

    final now = DateTime.now();
    final fmt = NumberFormat('#,###', 'vi_VN');

    // Current Month Range
    final currentMonthStart = DateTime(now.year, now.month, 1);
    
    // Previous Month Range
    final prevMonthStart = DateTime(now.year, now.month - 1, 1);
    final prevMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

    // Weekly Ranges (Assuming Monday is start of week)
    final daysToSubtract = (now.weekday - 1);
    final thisWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = thisWeekStart.subtract(const Duration(seconds: 1));

    final allTxs = txBox.values.toList();

    // Filter transactions
    final currentMonthTxs = allTxs.where((tx) => 
      tx.date.isAfter(currentMonthStart.subtract(const Duration(seconds: 1))) && 
      tx.date.isBefore(now.add(const Duration(minutes: 1)))
    ).toList();

    final prevMonthTxs = allTxs.where((tx) => 
      tx.date.isAfter(prevMonthStart.subtract(const Duration(seconds: 1))) && 
      tx.date.isBefore(prevMonthEnd)
    ).toList();

    final thisWeekTxs = allTxs.where((tx) => 
      tx.date.isAfter(thisWeekStart.subtract(const Duration(seconds: 1))) && 
      tx.date.isBefore(now.add(const Duration(minutes: 1)))
    ).toList();

    final lastWeekTxs = allTxs.where((tx) => 
      tx.date.isAfter(lastWeekStart.subtract(const Duration(seconds: 1))) && 
      tx.date.isBefore(lastWeekEnd)
    ).toList();

    // Calculate totals
    final currentTotal = currentMonthTxs.fold<double>(0, (sum, tx) => sum + tx.amount);
    final prevTotal = prevMonthTxs.fold<double>(0, (sum, tx) => sum + tx.amount);
    final thisWeekTotal = thisWeekTxs.fold<double>(0, (sum, tx) => sum + tx.amount);
    final lastWeekTotal = lastWeekTxs.fold<double>(0, (sum, tx) => sum + tx.amount);
    
    final income = settings.monthlySalary;
    final remaining = income - currentTotal;
    final dailyLimit = settings.computedDailyLimit;

    // Today's spending
    final todayTxs = currentMonthTxs.where((tx) =>
      tx.date.year == now.year && tx.date.month == now.month && tx.date.day == now.day
    );
    final todaySpent = todayTxs.fold<double>(0, (sum, tx) => sum + tx.amount);

    // Category Breakdowns
    Map<String, double> getCategoryMap(List<Transaction> txs) {
      final map = <String, double>{};
      for (final tx in txs) {
        map[tx.category] = (map[tx.category] ?? 0) + tx.amount;
      }
      return map;
    }

    final currentCats = getCategoryMap(currentMonthTxs);
    final prevCats = getCategoryMap(prevMonthTxs);

    String formatCategoryStats() {
      if (currentCats.isEmpty && prevCats.isEmpty) return "Chưa có dữ liệu.";
      
      final buffer = StringBuffer();
      final allKeys = {...currentCats.keys, ...prevCats.keys}.toList();
      
      for (final cat in allKeys) {
        final cur = currentCats[cat] ?? 0;
        final prv = prevCats[cat] ?? 0;
        buffer.write("- $cat: ${fmt.format(cur.toInt())}₫ (Tháng trước: ${fmt.format(prv.toInt())}₫)\n");
      }
      return buffer.toString();
    }

    // Recent transactions with notes (last 20 for context)
    final recentTxs = List<Transaction>.from(currentMonthTxs)
      ..sort((a, b) => b.date.compareTo(a.date));
    final topRecent = recentTxs.take(20).toList();

    String formatRecentTransactions() {
      if (topRecent.isEmpty) return "Chưa có giao dịch.";
      final buffer = StringBuffer();
      for (final tx in topRecent) {
        final dateStr = '${tx.date.day}/${tx.date.month}';
        final note = (tx.notes != null && tx.notes!.isNotEmpty) ? ' — "${tx.notes}"' : '';
        buffer.write('- [$dateStr] ${tx.category}: ${fmt.format(tx.amount.toInt())}₫$note\n');
      }
      return buffer.toString();
    }

    // Days remaining in month
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = daysInMonth - now.day;

    return '''
DỮ LIỆU TÀI CHÍNH CỦA NGƯỜI DÙNG (${settings.userName}):

THỜI GIAN HIỆN TẠI: ${now.day}/${now.month}/${now.year} (Thứ ${now.weekday})

THÁNG NÀY (${now.month}/${now.year}):
- Thu nhập: ${fmt.format(income.toInt())}₫
- Tổng chi: ${fmt.format(currentTotal.toInt())}₫
- Còn lại: ${fmt.format(remaining.toInt())}₫
- Chi hôm nay: ${fmt.format(todaySpent.toInt())}₫
- Hạn mức ngày: ${fmt.format(dailyLimit.toInt())}₫

TUẦN NÀY VS TUẦN TRƯỚC:
- Chi tiêu tuần này: ${fmt.format(thisWeekTotal.toInt())}₫
- Chi tiêu tuần trước: ${fmt.format(lastWeekTotal.toInt())}₫

THÁNG TRƯỚC (${prevMonthStart.month}/${prevMonthStart.year}):
- Tổng chi: ${fmt.format(prevTotal.toInt())}₫

CHI TIẾT THEO DANH MỤC (THÁNG):
${formatCategoryStats()}

GIAO DỊCH GẦN ĐÂY (có ghi chú):
${formatRecentTransactions()}

THỐNG KÊ KHÁC:
- Số giao dịch tháng này: ${currentMonthTxs.length}
- Còn $daysRemaining ngày trong tháng

NHIỆM VỤ:
Sử dụng dữ liệu trên để so sánh và phân tích. Nếu người dùng hỏi về tuần, hãy dùng dữ liệu tuần. Nếu hỏi về tháng, dùng dữ liệu tháng. ĐẶC BIỆT chú ý ghi chú của giao dịch để hiểu ngữ cảnh chi tiêu (ví dụ: "du lịch Thái Lan" không phải chi tiêu thường ngày). Đưa ra lời khuyên tài chính thông minh dựa trên biến động chi tiêu.
''';
  }
}
