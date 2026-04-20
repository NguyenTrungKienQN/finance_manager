import 'dart:ui' as ui;
import 'dart:async';
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
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/settings_model.dart';

import '../theme/app_theme.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit_breaker_model.dart';
import '../widgets/currency_converter_sheet.dart';
import '../utils/web_compatibility_helper.dart';
import '../services/app_time_service.dart';
import '../services/gemini_chat_service.dart';
import '../services/notification_service.dart';
import '../utils/app_toast.dart';

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

  Timer? _debounce;
  bool _isAiParsing = false;
  String _aiErrorMessage = '';

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

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

  @override
  void dispose() {
    _ocrService?.dispose();
    _priceController.dispose();
    _notesController.dispose();
    _debounce?.cancel();
    _speech.stop();
    super.dispose();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            if (mounted) {
              setState(() => _isListening = false);
              _triggerAiParsing(_notesController.text);
            }
          }
        },
        onError: (val) => debugPrint('onSpeechError: $val'),
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _notesController.text = val.recognizedWords;
            });
            // If it's a final result, we can trigger parsing faster
            if (val.finalResult) {
              _triggerAiParsing(val.recognizedWords);
            }
          },
          localeId: 'vi_VN',
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.confirmation,
          ),
          pauseFor: const Duration(seconds: 2),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      // Manually trigger parsing after clicking stop
      _triggerAiParsing(_notesController.text);
    }
  }

  void _triggerAiParsing(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (text.trim().isEmpty) return;

    _debounce = Timer(const Duration(milliseconds: 800), () async {
      setState(() {
        _isAiParsing = true;
        _aiErrorMessage = '';
      });
      final ai = GeminiChatService();
      try {
        final result = await ai.parseTransactionText(text);
        if (result != null && mounted) {
          setState(() {
            if (result['amount'] != null &&
                double.tryParse(result['amount'].toString()) != null) {
              double amt = double.parse(result['amount'].toString());
              if (amt > 0) {
                _priceController.text = amt.toStringAsFixed(0);
              }
            }
            if (result['category'] != null) {
              final cat = result['category'].toString();
              if (_categories.any((c) => c['name'] == cat)) {
                _selectedCategory = cat;
              }
            }
            _isAiParsing = false;
          });
        } else if (mounted) {
          setState(() => _isAiParsing = false);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isAiParsing = false;
            if (e is ApiBusyException) {
              _aiErrorMessage = e.toString();
            }
          });
        }
      }
    });
  }

  void _checkAndSave() async {
    if (_totalAmount <= 0) {
      setState(() => _statusMessage = "Vui lòng nhập số tiền hợp lệ");
      return;
    }

    var box = Hive.box<Transaction>('transactions');
    var settingsBox = Hive.box<AppSettings>('settings');
    AppSettings settings = settingsBox.get('appSettings') ?? AppSettings();

    DateTime now = AppTimeService.instance.now();
    double todaySpent = 0;
    double monthSpentSoFar = 0;

    for (var t in box.values) {
      if (t.date.year == now.year && t.date.month == now.month) {
        monthSpentSoFar += t.amount;
        if (t.date.day == now.day) {
          todaySpent += t.amount;
        }
      }
    }

    // 1. Calculate Daily Limit for logic/notifications
    final dynamicDailyLimit = settings.calculateDailyLimitForDate(
      now,
      box.values,
    );

    // 2. MONTHLY CHECK (Emergency Reserve Trigger)
    // Always check totalMonthlySpent (with new tx) against monthly salary
    double totalPredictedMonthSpent = monthSpentSoFar + _totalAmount;
    double shortfall = totalPredictedMonthSpent - settings.monthlySalary;
    double safeAmountToUse = 0;

    if (totalPredictedMonthSpent > settings.monthlySalary) {
      HapticFeedback.vibrate();

      // If Safe has money, offer to cover the shortfall
      if (settings.safeBalance > 0) {
        double maxCoverable = shortfall;
        bool? useSafe =
            await _showSafeUsePrompt(maxCoverable, settings.safeBalance);

        if (useSafe == true) {
          safeAmountToUse = maxCoverable > settings.safeBalance
              ? settings.safeBalance
              : maxCoverable;
          settings.safeBalance -= safeAmountToUse;
          await settings.save();

          double remainingAfterSafe = shortfall - safeAmountToUse;
          if (remainingAfterSafe > 0.01) {
            // Floating point buffer
            await _showUltimateIntervention();
          }
        } else {
          // User declined Safe -> Proceed to intervention
          await _showUltimateIntervention();
        }
      } else {
        // Safe is empty -> Intervention
        await _showUltimateIntervention();
      }
    }
    // 3. DAILY CHECK (Discipline Trigger - Only if Monthly is OK)
    else {
      bool isOverDailyLimit = (todaySpent + _totalAmount) > dynamicDailyLimit;

      if (isOverDailyLimit) {
        HapticFeedback.heavyImpact();
        bool? confirm =
            await _showOverLimitDialog(todaySpent, dynamicDailyLimit);
        if (confirm != true) return;

        // PUNISHMENT: Show Angry Mascot
        if (mounted) {
          await _showAngrySplash();
        }
      }
    }

    final transaction = Transaction(
      id: const Uuid().v4(),
      amount: _totalAmount,
      category: _selectedCategory,
      date: AppTimeService.instance.now(),
      isOverBudget: (todaySpent + _totalAmount) > dynamicDailyLimit,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      unitPrice: _unitPrice,
      quantity: _quantity,
      safeAmount: safeAmountToUse,
    );

    await box.add(transaction);

    final updatedSpent = todaySpent + _totalAmount;
    await NotificationService().fireOverspendAlert(
      spentAmount: updatedSpent,
      dailyLimit: dynamicDailyLimit,
    );
    await NotificationService().scheduleAllSmartNotifications();

    // Helper to normalize Vietnamese text for fuzzy matching
    String normalize(String input) {
      if (input.isEmpty) return '';
      var result = input.toLowerCase();
      const str1 =
          "áàảãạăắằẳẵặâấầẩẫậđéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵ";
      const str2 =
          "aaaaaaaaaaaaaaaaadeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyy";
      for (int i = 0; i < str1.length; i++) {
        result = result.replaceAll(str1[i], str2[i]);
      }
      return result.replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    // Check if this transaction matches any active habit breaker
    HabitBreaker? matchedHabit;
    final habitBox = Hive.box<HabitBreaker>('habitBreakers');

    final normalizedCategory = normalize(_selectedCategory);
    final normalizedNote = normalize(_notesController.text);

    // 1. FAST STATIC MATCHING
    for (var habit in habitBox.values) {
      if (!habit.isActive) continue;

      final normalizedHabit = normalize(habit.habitName);

      if (normalizedHabit.isNotEmpty &&
          (normalizedCategory.contains(normalizedHabit) ||
              normalizedNote.contains(normalizedHabit) ||
              normalizedHabit.contains(normalizedCategory))) {
        matchedHabit = habit;
        break;
      }
    }

    // 2. AI SEMANTIC MATCHING (if static didn't catch it)
    if (matchedHabit == null) {
      final aiService = GeminiChatService();
      if (aiService.canSendMessage()) {
        setState(() => _statusMessage = "AI đang kiểm tra...");
        for (var habit in habitBox.values) {
          if (!habit.isActive) continue;

          final isAiMatch = await aiService.doesTransactionBreakHabit(
            habit.habitName,
            _selectedCategory,
            _notesController.text,
          );

          if (isAiMatch) {
            matchedHabit = habit;
            break;
          }
        }
        setState(() => _statusMessage = "");
      }
    }

    if (mounted) {
      HapticFeedback.lightImpact();
      Navigator.pop(context, matchedHabit);
      if (matchedHabit == null) {
        AppToast.show(context, 'Đã lưu giao dịch!');
      }
    }
  }

  Future<bool?> _showOverLimitDialog(double todaySpent, double dailyLimit) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 80), // Space for Mascot
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).dividerColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
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
                        Divider(
                            color: Theme.of(context).dividerColor, height: 16),
                        _buildInfoRow('Khoản mới', _totalAmount),
                        Divider(
                            color: Theme.of(context).dividerColor, height: 16),
                        _buildInfoRow(
                          'Tổng cộng',
                          todaySpent + _totalAmount,
                          isTotal: true,
                        ),
                        Divider(
                            color: Theme.of(context).dividerColor, height: 16),
                        _buildInfoRow('Hạn mức', dailyLimit, isLimit: true),
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
                          child:
                              const Text('Hủy', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
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
          ),
          Positioned(
            top: 0,
            right: 20,
            child: Image.asset(
              'assets/mascots/mascotmad.png',
              height: 130,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showSafeUsePrompt(double shortfall, double balance) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Colors.blue),
            SizedBox(width: 10),
            Text('Sử dụng Két sắt?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bạn đã vượt quá ngân sách tháng!'),
            const SizedBox(height: 12),
            Text(
                'Số tiền vượt: ${NumberFormat.simpleCurrency(locale: "vi_VN", decimalDigits: 0).format(shortfall)}'),
            Text(
                'Số dư Két sắt: ${NumberFormat.simpleCurrency(locale: "vi_VN", decimalDigits: 0).format(balance)}'),
            const SizedBox(height: 16),
            const Text('Bạn có muốn rút từ Két sắt để bù vào không?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bỏ qua'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sử dụng'),
          ),
        ],
      ),
    );
  }

  Future<void> _showUltimateIntervention() async {
    if (!mounted) return;
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (ctx, anim1, anim2) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/mascots/strict_mom.png', height: 280),
                    const SizedBox(height: 32),
                    const Text(
                      'DỪNG LẠI!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Bạn đã tiêu hết cả ngân sách tháng lẫn quỹ dự phòng. Không còn gì để tựa lưng nữa rồi. Đã đến lúc phải dừng lại và nghiêm túc xem xét lại cách chi tiêu của mình.',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Tôi đã hiểu',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
            opacity: anim1, child: ScaleTransition(scale: anim1, child: child));
      },
    );
  }

  Future<void> _showAngrySplash() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/mascots/mascotangry.png', height: 250),
                  const SizedBox(height: 24),
                  const Text(
                    'Đã cảnh báo rồi mà!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.redAccent,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curvedValue = Curves.elasticOut.transform(anim1.value) - 1.0;
        return Transform.translate(
          offset: Offset(0, curvedValue * 200),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );

    await Future.delayed(const Duration(seconds: 2));
    if (navigator.canPop()) {
      navigator.pop();
    }
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

                    // AI Quick Notes
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Ghi chú nhanh',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_isAiParsing)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '✨ AI phân tích và tự động hoá quá trình',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _GeminiGlowWrapper(
                      isParsing: _isAiParsing,
                      child: TextField(
                        controller: _notesController,
                        style: const TextStyle(fontSize: 16),
                        maxLines: 2,
                        minLines: 1,
                        onChanged: (text) {
                          _triggerAiParsing(text);
                        },
                        decoration: InputDecoration(
                          hintText: 'VD: Grab ra sân bay hết 150 cành...',
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
                          suffixIcon: IconButton(
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                key: ValueKey(_isListening),
                                color: _isListening
                                    ? Colors.red
                                    : AppTheme.softPurple,
                              ),
                            ),
                            onPressed: _listen,
                          ),
                        ),
                      ),
                    ),

                    if (_aiErrorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _aiErrorMessage,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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

class _GeminiGlowWrapper extends StatefulWidget {
  final Widget child;
  final bool isParsing;

  const _GeminiGlowWrapper({required this.child, required this.isParsing});

  @override
  State<_GeminiGlowWrapper> createState() => _GeminiGlowWrapperState();
}

class _GeminiGlowWrapperState extends State<_GeminiGlowWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isParsing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_GeminiGlowWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isParsing != oldWidget.isParsing) {
      if (widget.isParsing) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: widget.isParsing
                ? [
                    BoxShadow(
                      color: const Color(0xFF4285F4).withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: CustomPaint(
            painter: widget.isParsing
                ? _GeminiGlowPainter(
                    animationValue: _controller.value,
                    borderRadius: 18,
                  )
                : null,
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _GeminiGlowPainter extends CustomPainter {
  final double animationValue;
  final double borderRadius;

  _GeminiGlowPainter(
      {required this.animationValue, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final RRect rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final paint = Paint()
      ..shader = SweepGradient(
        colors: const [
          Color(0xFF4285F4), // Blue
          Color(0xFF9B51E0), // Purple
          Color(0xFFE91E63), // Pink
          Color(0xFFF2994A), // Orange
          Color(0xFF4285F4), // Back to Blue
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        transform: GradientRotation(animationValue * 2 * 3.1415),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GeminiGlowPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
