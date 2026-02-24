import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Reusable currency converter bottom sheet.
/// Uses live rates from api.exchangerate-api.com with Hive caching for offline support.
class CurrencyConverterSheet {
  // Support these currencies
  static const List<String> _supportedCodes = [
    'VND',
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'KRW',
    'CNY',
    'THB',
    'SGD',
    'AUD',
  ];

  static const Map<String, String> _currencyFlags = {
    'VND': '🇻🇳',
    'USD': '🇺🇸',
    'EUR': '🇪🇺',
    'GBP': '🇬🇧',
    'JPY': '🇯🇵',
    'KRW': '🇰🇷',
    'CNY': '🇨🇳',
    'THB': '🇹🇭',
    'SGD': '🇸🇬',
    'AUD': '🇦🇺',
  };

  // Fallback rates (Feb 2026)
  static const Map<String, double> _fallbackRatesToVND = {
    'VND': 1,
    'USD': 25400,
    'EUR': 27200,
    'GBP': 32100,
    'JPY': 167,
    'KRW': 18.5,
    'CNY': 3480,
    'THB': 720,
    'SGD': 18900,
    'AUD': 16200,
  };

  static Future<double?> show(
    BuildContext context, {
    TextEditingController? targetController,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ConverterBody(targetController: targetController),
    );
  }
}

class _ConverterBody extends StatefulWidget {
  final TextEditingController? targetController;
  const _ConverterBody({this.targetController});

  @override
  State<_ConverterBody> createState() => _ConverterBodyState();
}

class _ConverterBodyState extends State<_ConverterBody> {
  final TextEditingController _amountController = TextEditingController();

  // State
  Map<String, double> _rates = {};
  DateTime? _lastUpdated;
  bool _isLoading = false;
  String? _error;

  String _fromCurrency = 'USD';
  String _toCurrency = 'VND';

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    setState(() => _isLoading = true);

    // 1. Try load from Hive
    final box = Hive.box('currency_data');
    final cachedRates = box.get('rates')?.cast<String, double>();
    final cachedTime = box.get('last_updated') as DateTime?;

    if (cachedRates != null && cachedTime != null) {
      if (mounted) {
        setState(() {
          _rates = cachedRates;
          _lastUpdated = cachedTime;
        });
      }
    } else {
      // Use fallback initially if empty
      if (mounted) {
        setState(() => _rates = CurrencyConverterSheet._fallbackRatesToVND);
      }
    }

    // 2. Fetch fresh rates (background)
    await _fetchLiveRates();

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchLiveRates() async {
    try {
      final response = await http
          .get(Uri.parse('https://api.exchangerate-api.com/v4/latest/USD'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final usdRates = data['rates'] as Map<String, dynamic>;

        // Convert to VND-based rates: RateToVND = (1 / RateInUSD) * RateUSDToVND
        // Actually: 1 USD = X Target. 1 USD = Y VND.
        // Value of 1 Target in VND = Y / X.

        final double usdToVnd = (usdRates['VND'] as num).toDouble();
        final Map<String, double> newRates = {};

        for (var code in CurrencyConverterSheet._supportedCodes) {
          if (code == 'USD') {
            newRates[code] = usdToVnd;
          } else if (code == 'VND') {
            newRates[code] = 1.0;
          } else {
            final rateInUsd = (usdRates[code] as num?)?.toDouble();
            if (rateInUsd != null && rateInUsd > 0) {
              newRates[code] = usdToVnd / rateInUsd;
            } else {
              // Keep fallback/old if missing
              newRates[code] =
                  CurrencyConverterSheet._fallbackRatesToVND[code]!;
            }
          }
        }

        // Save to Hive
        final box = Hive.box('currency_data');
        await box.put('rates', newRates);
        await box.put('last_updated', DateTime.now());

        if (mounted) {
          setState(() {
            _rates = newRates;
            _lastUpdated = DateTime.now();
            _error = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Currency fetch error: $e');
      if (mounted) setState(() => _error = 'Offline Mode');
    }
  }

  double get _amount {
    final text = _amountController.text.replaceAll(RegExp(r'[,\s]'), '');
    return double.tryParse(text) ?? 0;
  }

  double get _convertedAmount {
    // Safety check: ensure rates exist
    final fromRate =
        _rates[_fromCurrency] ??
        CurrencyConverterSheet._fallbackRatesToVND[_fromCurrency] ??
        1;
    final toRate =
        _rates[_toCurrency] ??
        CurrencyConverterSheet._fallbackRatesToVND[_toCurrency] ??
        1;

    // Convert: from -> VND -> to
    return (_amount * fromRate) / toRate;
  }

  String get _formattedResult {
    if (_toCurrency == 'VND') {
      return NumberFormat.currency(
        locale: 'vi',
        symbol: '₫',
        decimalDigits: 0,
      ).format(_convertedAmount);
    }
    return NumberFormat.currency(
      locale: 'en',
      symbol: _toCurrency,
      decimalDigits: 2,
    ).format(_convertedAmount);
  }

  String get _updateStatus {
    if (_error != null) return '⚠️ Offline';
    if (_lastUpdated == null) return '';
    final now = DateTime.now();
    final diff = now.difference(_lastUpdated!);
    if (diff.inMinutes < 1) return 'Vừa cập nhật';
    if (diff.inHours < 1) return 'Cập nhật ${diff.inMinutes}p trước';
    if (diff.inHours < 24) return 'Cập nhật ${diff.inHours}h trước';
    return 'Cập nhật ${DateFormat('dd/MM').format(_lastUpdated!)}';
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title Row
            Row(
              children: [
                Icon(
                  Icons.currency_exchange,
                  color: theme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text('Quy đổi tiền tệ', style: theme.textTheme.titleLarge),
                const Spacer(),

                // Status / Refresh
                if (_updateStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      _updateStatus,
                      style: TextStyle(
                        fontSize: 12,
                        color: _error != null
                            ? Colors.orange
                            : theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),

                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isLoading ? null : _fetchLiveRates,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Amount input
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.4,
                  ),
                ),
                filled: true,
                fillColor: theme.canvasColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: Text(
                    CurrencyConverterSheet._currencyFlags[_fromCurrency] ?? '',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Currency selectors row
            Row(
              children: [
                // From currency
                Expanded(
                  child: _buildCurrencyDropdown(
                    value: _fromCurrency,
                    label: 'Từ',
                    onChanged: (v) {
                      if (v != null) setState(() => _fromCurrency = v);
                    },
                  ),
                ),
                // Swap button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        final temp = _fromCurrency;
                        _fromCurrency = _toCurrency;
                        _toCurrency = temp;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.swap_horiz,
                        color: theme.primaryColor,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                // To currency
                Expanded(
                  child: _buildCurrencyDropdown(
                    value: _toCurrency,
                    label: 'Sang',
                    onChanged: (v) {
                      if (v != null) setState(() => _toCurrency = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Result display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor.withValues(alpha: 0.08),
                    theme.primaryColor.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Kết quả',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _amount > 0 ? _formattedResult : '—',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: theme.primaryColor,
                    ),
                  ),
                  if (_amount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '1 $_fromCurrency = ${NumberFormat("#,##0.##").format((_rates[_fromCurrency] ?? 1) / (_rates[_toCurrency] ?? 1))} $_toCurrency',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Apply button
            if (widget.targetController != null)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _amount > 0
                      ? () {
                          // Always write VND amount to the target
                          final fromRate = _rates[_fromCurrency] ?? 1;
                          final vndAmount = _amount * fromRate;

                          final vndInt = vndAmount.round();
                          widget.targetController!.text = '$vndInt';
                          Navigator.pop(context, vndAmount);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: theme.primaryColor.withValues(
                      alpha: 0.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text(
                    'Áp dụng (VNĐ)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyDropdown({
    required String value,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.canvasColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
          ),
          DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: theme.cardColor,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
            items: CurrencyConverterSheet._supportedCodes.map((code) {
              final flag = CurrencyConverterSheet._currencyFlags[code] ?? '';
              return DropdownMenuItem(value: code, child: Text('$flag $code'));
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
