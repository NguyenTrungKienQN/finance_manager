import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../models/debt_record_model.dart';
import '../services/notification_service.dart';
import '../services/gemini_chat_service.dart';
import '../services/ocr_service.dart';
import '../widgets/currency_converter_sheet.dart';
import '../utils/app_toast.dart';
import '../utils/split_helper.dart';

class DebtTrackerScreen extends StatefulWidget {
  const DebtTrackerScreen({super.key});

  @override
  State<DebtTrackerScreen> createState() => _DebtTrackerScreenState();
}

class _DebtTrackerScreenState extends State<DebtTrackerScreen> {
  late Box<DebtRecord> _debtBox;

  @override
  void initState() {
    super.initState();
    _debtBox = Hive.box<DebtRecord>('debtRecords');
  }

  void _markAsPaid(DebtRecord debt) async {
    await debt.delete();
    await NotificationService().scheduleAllSmartNotifications();
    if (mounted) {
      AppToast.show(context, '${debt.debtorName} đã trả tiền');
    }
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _SplitBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Sổ nợ', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: ValueListenableBuilder(
        valueListenable: _debtBox.listenable(),
        builder: (context, Box<DebtRecord> box, _) {
          if (box.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('Chưa có khoản nợ nào',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                ],
              ),
            );
          }

          final items = box.values.toList();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Dismissible(
                key: Key(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Theme.of(context).primaryColor,
                  child: const Icon(Icons.check, color: Colors.white),
                ),
                onDismissed: (_) => _markAsPaid(item),
                child: Opacity(
                  opacity: item.isPaid ? 0.6 : 1.0,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: item.isPaid
                          ? Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: item.isPaid
                                ? Colors.green.withValues(alpha: 0.1)
                                : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.isPaid ? Icons.check_circle : Icons.person,
                            color: item.isPaid ? Colors.green : Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.debtorName,
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                  fontSize: 16, fontWeight: FontWeight.bold,
                                  decoration: item.isPaid ? TextDecoration.lineThrough : null,
                                )),
                              const SizedBox(height: 4),
                              Text('${item.description} • ${DateFormat('dd/MM').format(item.date)}',
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13)),
                            ],
                          ),
                        ),
                        Text(
                          NumberFormat.simpleCurrency(locale: 'vi_VN').format(item.amount),
                          style: TextStyle(
                            color: item.isPaid ? Colors.green : Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold, fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!item.isPaid)
                          IconButton(
                            icon: Icon(Icons.check_box_outline_blank,
                              color: Theme.of(context).textTheme.bodyMedium?.color),
                            onPressed: () => _markAsPaid(item),
                            tooltip: 'Đã trả',
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.done_all, color: Colors.green, size: 20),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 120),
        child: FloatingActionButton(
          heroTag: 'addDebt',
          onPressed: _showAddDialog,
          backgroundColor: Theme.of(context).primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

/// Separate StatefulWidget for the bottom sheet to avoid
/// full rebuild on every keyboard animation frame.
class _SplitBottomSheet extends StatefulWidget {
  const _SplitBottomSheet();

  @override
  State<_SplitBottomSheet> createState() => _SplitBottomSheetState();
}

class _SplitBottomSheetState extends State<_SplitBottomSheet> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final List<TextEditingController> _nameControllers = [TextEditingController()];
  final List<TextEditingController> _splitAmountControllers = [TextEditingController()];
  bool _isAiSplitting = false;
  String _statusMessage = '';
  OcrService? _ocrService;
  final _picker = ImagePicker();
  late List<String> _knownPeople;

  @override
  void initState() {
    super.initState();
    _knownPeople = SplitHelper.getKnownPeople();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    for (var c in _nameControllers) { c.dispose(); }
    for (var c in _splitAmountControllers) { c.dispose(); }
    _ocrService?.dispose();
    super.dispose();
  }

  double get _totalAmount =>
      double.tryParse(_amountController.text.replaceAll(RegExp(r'[,.]'), '')) ?? 0;

  double get _currentSplitTotal {
    double total = 0;
    for (var c in _splitAmountControllers) {
      total += double.tryParse(c.text.replaceAll(RegExp(r'[,.]'), '')) ?? 0;
    }
    return total;
  }

  bool get _isTotalMatched =>
      _totalAmount > 0 && (_currentSplitTotal - _totalAmount).abs() < 1;

  void _addPerson([String name = '']) {
    setState(() {
      _nameControllers.add(TextEditingController(text: name));
      _splitAmountControllers.add(TextEditingController());
    });
  }

  void _removePerson(int index) {
    setState(() {
      _nameControllers[index].dispose();
      _splitAmountControllers[index].dispose();
      _nameControllers.removeAt(index);
      _splitAmountControllers.removeAt(index);
    });
  }

  void _applySplitResult(Map<String, dynamic> result) {
    setState(() {
      for (var c in _nameControllers) { c.dispose(); }
      for (var c in _splitAmountControllers) { c.dispose(); }
      _nameControllers.clear();
      _splitAmountControllers.clear();

      final List<dynamic> people = result['people'] ?? [];
      final Map<String, dynamic> splits = result['splits'] ?? {};

      for (var person in people) {
        final n = person.toString();
        final amt = (splits[n] ?? 0).toDouble();
        _nameControllers.add(TextEditingController(text: n));
        _splitAmountControllers.add(TextEditingController(text: amt.toStringAsFixed(0)));
      }
      _isAiSplitting = false;
    });
  }

  /// Local person detection from notes text
  List<String> _detectPeopleFromText(String text) {
    final people = <String>{};
    final pattern = RegExp(r'(?:với|cùng|và|,)\s+([A-ZÀ-Ỹ][a-zà-ỹ]+)', caseSensitive: false);
    for (final match in pattern.allMatches(text)) {
      final name = match.group(1)?.trim();
      if (name != null && name.length >= 2) {
        people.add(name);
      }
    }
    return people.toList();
  }

  Future<void> _triggerAiSplit() async {
    if (_totalAmount <= 0) {
      setState(() => _statusMessage = 'Nhập tổng tiền trước');
      return;
    }
    setState(() {
      _isAiSplitting = true;
      _statusMessage = '';
    });

    final existingPeople = _nameControllers
        .map((c) => c.text).where((t) => t.isNotEmpty).toList();

    final ai = GeminiChatService();
    final result = await ai.analyzeBillForSplit(
      totalAmount: _totalAmount,
      description: _descController.text,
      existingPeople: existingPeople,
    );

    if (result != null && mounted) {
      _applySplitResult(result);
    } else if (mounted) {
      // Local fallback
      List<String> detected = _detectPeopleFromText(_descController.text);
      if (detected.isEmpty && existingPeople.isNotEmpty) {
        detected = existingPeople;
      }
      if (detected.isNotEmpty) {
        final perPerson = (_totalAmount / detected.length).roundToDouble();
        final splits = <String, dynamic>{};
        for (var p in detected) { splits[p] = perPerson; }
        _applySplitResult({'people': detected, 'splits': splits});
      } else {
        setState(() {
          _isAiSplitting = false;
          _statusMessage = 'Nhập tên người hoặc ghi chú (VD: với Minh và Lan)';
        });
      }
    }
  }

  Future<void> _scanReceipt() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;
    setState(() {
      _isAiSplitting = true;
      _statusMessage = 'Đang đọc hóa đơn...';
    });
    _ocrService ??= OcrService();
    try {
      final rawText = await _ocrService!.extractRawText(photo.path);
      if (rawText.isEmpty) {
        setState(() {
          _isAiSplitting = false;
          _statusMessage = 'Không đọc được chữ trên ảnh.';
        });
        return;
      }
      setState(() => _statusMessage = 'AI đang phân tích...');
      final ai = GeminiChatService();
      final receiptResult = await ai.parseReceiptText(rawText);
      if (receiptResult != null && mounted) {
        final double amt = (receiptResult['amount'] ?? 0).toDouble();
        if (amt > 0) {
          setState(() => _amountController.text = amt.toStringAsFixed(0));
        }
        final notes = receiptResult['notes'] ?? '';
        if (notes.isNotEmpty && _descController.text.isEmpty) {
          setState(() => _descController.text = notes);
        }
      }
      if (_totalAmount > 0) {
        await _triggerAiSplit();
      } else {
        if (mounted) {
          setState(() {
            _isAiSplitting = false;
            _statusMessage = 'Đã đọc xong. Nhập tổng tiền rồi bấm AI gợi ý.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAiSplitting = false;
          _statusMessage = 'Lỗi quét hóa đơn';
        });
      }
    }
  }

  void _save() {
    final desc = _descController.text;
    final people = _nameControllers.map((c) => c.text.trim()).where((n) => n.isNotEmpty).toList();
    final amounts = _splitAmountControllers.map((c) =>
      double.tryParse(c.text.replaceAll(RegExp(r'[,.]'), '')) ?? 0.0
    ).toList();

    if (desc.isNotEmpty && people.isNotEmpty && amounts.any((a) => a > 0)) {
      SplitHelper.processSplit(
        names: people,
        amounts: amounts,
        description: desc,
        date: DateTime.now(),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 20,
        left: 20, right: 20, top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Chia tiền & Ghi nợ',
              style: TextStyle(
                color: theme.textTheme.titleLarge?.color,
                fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // Description
            TextField(
              controller: _descController,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                labelText: 'Nội dung (VD: Ăn lẩu với Minh và Lan)',
                labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: theme.dividerColor.withValues(alpha: 0.05),
              ),
            ),
            const SizedBox(height: 12),
            // Amount
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 22, fontWeight: FontWeight.bold),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Tổng tiền cần chia',
                labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: theme.dividerColor.withValues(alpha: 0.05),
                suffixText: 'đ',
                suffixIcon: IconButton(
                  onPressed: () => CurrencyConverterSheet.show(context, targetController: _amountController),
                  icon: Icon(Icons.currency_exchange, color: theme.primaryColor, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAiSplitting ? null : _scanReceipt,
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Quét hóa đơn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.withValues(alpha: 0.1),
                      foregroundColor: theme.textTheme.bodyLarge?.color,
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAiSplitting ? null : _triggerAiSplit,
                    icon: _isAiSplitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('AI chia tiền'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                      foregroundColor: theme.primaryColor,
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
            if (_statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_statusMessage, style: TextStyle(color: theme.primaryColor, fontSize: 12)),
              ),
            const SizedBox(height: 12),
            // Known people chips
            if (_knownPeople.isNotEmpty) ...[
              const Text('Người quen:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _knownPeople.map((name) {
                    final isSelected = _nameControllers.any((c) => c.text == name);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(name, style: const TextStyle(fontSize: 13)),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            _addPerson(name);
                          } else {
                            final idx = _nameControllers.indexWhere((c) => c.text == name);
                            if (idx != -1) _removePerson(idx);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // People list
            ...List.generate(_nameControllers.length, (idx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _nameControllers[idx],
                        style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                        decoration: InputDecoration(
                          hintText: 'Tên người ${idx + 1}',
                          isDense: true,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: theme.dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _splitAmountControllers[idx],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.end,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                        decoration: InputDecoration(
                          hintText: 'Số tiền',
                          suffixText: 'đ',
                          isDense: true,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: theme.dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    if (_nameControllers.length > 1)
                      IconButton(
                        icon: Icon(Icons.remove_circle, color: theme.colorScheme.error, size: 20),
                        onPressed: () => _removePerson(idx),
                      ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: _addPerson,
              icon: Icon(Icons.add, color: theme.primaryColor, size: 18),
              label: Text('Thêm người', style: TextStyle(color: theme.primaryColor)),
            ),
            // Total matching bar
            if (_totalAmount > 0)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _isTotalMatched ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text(
                      _isTotalMatched ? 'Đã khớp ✅' : 'Chưa khớp',
                      style: TextStyle(color: _isTotalMatched ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      '${NumberFormat.currency(locale: 'vi', symbol: '₫', decimalDigits: 0).format(_currentSplitTotal)} / ${NumberFormat.currency(locale: 'vi', symbol: '₫', decimalDigits: 0).format(_totalAmount)}',
                      style: TextStyle(color: _isTotalMatched ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            // Save button
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Lưu nợ'),
            ),
          ],
        ),
      ),
    );
  }
}
