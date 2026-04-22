import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/debt_record_model.dart';
import '../services/notification_service.dart';

class SplitHelper {
  /// Processes split results: accumulates into existing debts or creates new ones.
  /// - selfIndex: if >= 0, that person is the user (payment history, isPaid=true)
  static Future<void> processSplit({
    required List<String> names,
    required List<double> amounts,
    required String description,
    required DateTime date,
    int selfIndex = -1,
  }) async {
    final box = Hive.box<DebtRecord>('debtRecords');

    for (int i = 0; i < names.length; i++) {
      final name = names[i].trim();
      final amount = amounts[i];
      if (name.isEmpty || amount <= 0) continue;

      final isSelf = (i == selfIndex);

      if (isSelf) {
        // Self -> create payment history record
        final debt = DebtRecord(
          id: const Uuid().v4(),
          debtorName: '$name (Tôi)',
          amount: amount,
          description: description,
          date: date,
          isPaid: true,
        );
        await box.add(debt);
        continue;
      }

      // Find existing unpaid debt for this person
      DebtRecord? existing;
      for (final record in box.values) {
        if (record.debtorName == name && !record.isPaid) {
          existing = record;
          break;
        }
      }

      if (existing != null) {
        // ACCUMULATE: add to existing debt
        existing.amount += amount;
        existing.description = '$description (+${amount.toStringAsFixed(0)}đ)';
        await existing.save();
      } else {
        // CREATE NEW: no existing debt for this person
        final debt = DebtRecord(
          id: const Uuid().v4(),
          debtorName: name,
          amount: amount,
          description: description,
          date: date,
        );
        await box.add(debt);
      }
    }

    await NotificationService().scheduleAllSmartNotifications();
  }

  /// Returns list of unique debtor names from existing records (for the people picker).
  static List<String> getKnownPeople() {
    final box = Hive.box<DebtRecord>('debtRecords');
    final names = <String>{};
    for (final record in box.values) {
      final cleanName = record.debtorName.replaceAll(' (Tôi)', '');
      names.add(cleanName);
    }
    return names.toList()..sort();
  }
}
