import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/ocr_service.dart';
import '../models/transaction_model.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit_breaker_model.dart';
import '../widgets/currency_converter_sheet.dart';
import '../utils/web_compatibility_helper.dart';

class AddTransactionScreen extends StatefulWidget {
  final double dailyLimit;

  const AddTransactionScreen({super.key, required this.dailyLimit});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  OcrService? _ocrService;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  int _quantity = 1;
  String _selectedCategory = "Mua sắm";
  String _statusMessage = "";
  bool _isScanning = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Ăn uống', 'icon': Icons.restaurant, 'color': Colors.orange},
    {'name': 'Mua sắm', 'icon': Icons.shopping_bag, 'color': Colors.teal},
    {'name': 'Giao thông', 'icon': Icons.directions_car, 'color': Colors.blue},
    {'name': 'Giáo dục', 'icon': Icons.school, 'color': Colors.purple},
    {'name': 'Giải trí', 'icon': Icons.movie, 'color': Colors.pink},
    {'name': 'Y tế', 'icon': Icons.medical_services, 'color': Colors.red},
    {'name': 'Khác', 'icon': Icons.receipt, 'color': Colors.grey},
  ];

  double get _unitPrice =>
      double.tryParse(_priceController.text.replaceAll(RegExp(r'[,.]'), '')) ??
      0;
  double get _totalAmount => _unitPrice * _quantity;

  void _checkAndSave() async {
    if (_totalAmount <= 0) {
      setState(() => _statusMessage = "Vui lòng nhập số tiền hợp lệ");
      return;
    }

    var box = Hive.box<Transaction>('transactions');
    DateTime now = DateTime.now();
    double todaySpent = box.values
        .where(
          (t) =>
              t.date.year == now.year &&
              t.date.month == now.month &&
              t.date.day == now.day,
        )
        .fold(0, (sum, t) => sum + t.amount);

    bool isOverLimit = (todaySpent + _totalAmount) > widget.dailyLimit;

    if (isOverLimit) {
      HapticFeedback.heavyImpact();
      bool? confirm = await _showOverLimitDialog(todaySpent);
      if (confirm != true) return;
    }

    final transaction = Transaction(
      id: const Uuid().v4(),
      amount: _totalAmount,
      category: _selectedCategory,
      date: DateTime.now(),
      isOverBudget: isOverLimit,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      unitPrice: _unitPrice,
      quantity: _quantity,
    );

    await box.add(transaction);

    // Check if this transaction matches any active habit breaker
    HabitBreaker? matchedHabit;
    final habitBox = Hive.box<HabitBreaker>('habitBreakers');
    for (var habit in habitBox.values) {
      if (!habit.isActive) continue;

      final habitName = habit.habitName.trim().toLowerCase();
      final categoryName = _selectedCategory.trim().toLowerCase();
      final noteText = _notesController.text.trim().toLowerCase();

      // Check if habit name appears in category or notes, or vice versa
      if (habitName.isNotEmpty &&
          (categoryName.contains(habitName) ||
              noteText.contains(habitName) ||
              habitName.contains(categoryName))) {
        matchedHabit = habit;
        break;
      }
    }

    if (mounted) {
      HapticFeedback.lightImpact();
      Navigator.pop(context, matchedHabit);
      if (matchedHabit == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã lưu giao dịch!'),
            backgroundColor: Theme.of(context).primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<bool?> _showOverLimitDialog(double todaySpent) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Vượt hạn mức!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Khoản này sẽ khiến chi tiêu hôm nay vượt hạn mức.',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Đã tiêu', todaySpent),
                  Divider(color: Theme.of(context).dividerColor, height: 16),
                  _buildInfoRow('Khoản mới', _totalAmount),
                  Divider(color: Theme.of(context).dividerColor, height: 16),
                  _buildInfoRow(
                    'Tổng cộng',
                    todaySpent + _totalAmount,
                    isTotal: true,
                  ),
                  Divider(color: Theme.of(context).dividerColor, height: 16),
                  _buildInfoRow('Hạn mức', widget.dailyLimit, isLimit: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                        color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.3) ??
                            Colors.grey,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Hủy', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Vẫn lưu',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    double amount, {
    bool isTotal = false,
    bool isLimit = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        Text(
          NumberFormat.currency(
            locale: 'vi',
            symbol: '₫',
            decimalDigits: 0,
          ).format(amount),
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 18 : 16,
            color: isTotal
                ? Theme.of(context).colorScheme.error
                : (isLimit
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).textTheme.bodyLarge?.color),
          ),
        ),
      ],
    );
  }

  Future<void> _scanReceipt() async {
    if (kIsWeb) {
      WebCompatibilityHelper.showUnsupportedMessage(context);
      return;
    }
    if (Platform.isWindows) {
      setState(() => _statusMessage = 'OCR không hỗ trợ trên nền tảng này');
      return;
    }

    _ocrService ??= OcrService();
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _isScanning = true;
        _statusMessage = 'Đang quét hóa đơn...';
      });

      try {
        double detectedAmount = await _ocrService!.scanReceipt(photo.path);
        setState(() {
          _isScanning = false;
          if (detectedAmount > 0) {
            _priceController.text = detectedAmount.toStringAsFixed(0);
            _statusMessage =
                'Đã nhận diện: ${NumberFormat.currency(locale: 'vi', symbol: '₫', decimalDigits: 0).format(detectedAmount)}';
          } else {
            _statusMessage = 'Không tìm thấy số tiền, vui lòng nhập tay';
          }
        });
      } catch (e) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Lỗi quét: Vui lòng nhập tay';
        });
      }
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    _ocrService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Thêm giao dịch',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Scan Button
                    GestureDetector(
                      onTap: _isScanning ? null : _scanReceipt,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isScanning)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            else
                              const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 28,
                              ),
                            const SizedBox(width: 12),
                            Text(
                              _isScanning ? 'Đang quét...' : 'Quét hóa đơn',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_statusMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Price Input
                    const Text(
                      'Đơn giá',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                        ),
                        suffixText: 'VNĐ',
                        suffixIcon: IconButton(
                          onPressed: () {
                            CurrencyConverterSheet.show(
                              context,
                              targetController: _priceController,
                            ).then((_) => setState(() {}));
                          },
                          icon: Icon(
                            Icons.currency_exchange,
                            color: Theme.of(context).primaryColor,
                          ),
                          tooltip: 'Quy đổi tiền tệ',
                        ),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Quantity
                    const Text(
                      'Số lượng',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (_quantity > 1) setState(() => _quantity--);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.remove,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              '$_quantity',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _quantity++),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.add, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Total
                    if (_unitPrice > 0 && _quantity > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${NumberFormat.currency(locale: 'vi', symbol: '₫', decimalDigits: 0).format(_unitPrice)} × $_quantity',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              Text(
                                NumberFormat.currency(
                                  locale: 'vi',
                                  symbol: '₫',
                                  decimalDigits: 0,
                                ).format(_totalAmount),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Category
                    const Text(
                      'Phân loại',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        bool isSelected = _selectedCategory == cat['name'];
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategory = cat['name']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? cat['color'].withValues(alpha: 0.2)
                                  : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? cat['color']
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat['icon'],
                                  size: 20,
                                  color: isSelected
                                      ? cat['color']
                                      : Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  cat['name'],
                                  style: TextStyle(
                                    color: isSelected
                                        ? cat['color']
                                        : Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Notes
                    const Text(
                      'Ghi chú',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Smart Suggestions for Notes
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            // Get all transactions to find frequent notes
                            final box = Hive.box<Transaction>('transactions');
                            final noteCounts = <String, int>{};

                            for (var tx in box.values) {
                              if (tx.notes != null && tx.notes!.isNotEmpty) {
                                final note = tx.notes!.trim();
                                if (note.isNotEmpty) {
                                  noteCounts[note] =
                                      (noteCounts[note] ?? 0) + 1;
                                }
                              }
                            }

                            final query = textEditingValue.text.toLowerCase();
                            final matches = noteCounts.keys.where((note) {
                              return note.toLowerCase().contains(query);
                            }).toList();

                            // Sort by frequency (descending)
                            matches.sort(
                              (a, b) => (noteCounts[b] ?? 0).compareTo(
                                noteCounts[a] ?? 0,
                              ),
                            );

                            // Return top 5
                            return matches.take(5);
                          },
                          onSelected: (String selection) {
                            _notesController.text = selection;
                          },
                          fieldViewBuilder: (
                            context,
                            textEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            // Sync with our main controller if needed, or just use the one from Autocomplete
                            // Actually, Autocomplete's controller is separate.
                            // We need to listen to it to update _notesController, OR use it directly.
                            // Better: Use the passed textEditingController as our main controller?
                            // No, _notesController is used elsewhere (e.g. saving).
                            // Only one controller can be attached.
                            // We should use textEditingController for the UI, and listener to update _notesController.

                            if (textEditingController.text !=
                                _notesController.text) {
                              textEditingController.text =
                                  _notesController.text;
                            }

                            textEditingController.addListener(() {
                              _notesController.value =
                                  textEditingController.value;
                            });

                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                hintText:
                                    'Ví dụ: Cà phê Highlands, Chợ Bà Chiểu...',
                                hintStyle: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withValues(alpha: 0.5),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).cardColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(16),
                                color: Theme.of(context).cardColor,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: 200,
                                    maxWidth: constraints.maxWidth,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      final String option =
                                          options.elementAt(index);
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        borderRadius: BorderRadius.circular(
                                          16,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(
                                            16.0,
                                          ),
                                          child: Text(
                                            option,
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).textTheme.bodyLarge?.color,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Save Button
            Container(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _checkAndSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _totalAmount > 0
                        ? 'Lưu ${NumberFormat.currency(locale: 'vi', symbol: '₫', decimalDigits: 0).format(_totalAmount)}'
                        : 'Lưu giao dịch',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
