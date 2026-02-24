import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/settings_model.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_converter_sheet.dart';
import '../widgets/liquid_glass.dart';
import 'package:flutter/foundation.dart';
import '../utils/web_compatibility_helper.dart';

// ─────────────────────────────────────────────────
// Main Settings Hub
// ─────────────────────────────────────────────────
class SettingsScreen extends StatelessWidget {
  final double currentSalary;

  const SettingsScreen({super.key, required this.currentSalary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Cài đặt', style: theme.textTheme.titleLarge),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GlassBackButton(
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          _SettingsTile(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF00BFA6),
            iconBgColor: const Color(0xFF00BFA6),
            title: 'Đặt ngân sách tháng',
            subtitle: 'Thiết lập hạn mức chi tiêu hàng tháng',
            onTap: () async {
              final result = await Navigator.push<double>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SalarySettingsPage(currentSalary: currentSalary),
                ),
              );
              if (result != null && context.mounted) {
                Navigator.pop(context, result);
              }
            },
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.palette_rounded,
            iconColor: const Color(0xFFFF9800),
            iconBgColor: const Color(0xFFFF9800),
            title: 'Tùy chỉnh giao diện',
            subtitle: 'Chế độ sáng, tối hoặc theo hệ thống',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppearanceSettingsPage()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.smart_toy_rounded,
            iconColor: const Color(0xFF7F7FD5),
            iconBgColor: const Color(0xFF7F7FD5),
            title: 'AI Assistant (Gemini)',
            subtitle: 'Nhập API Key để dùng không giới hạn',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AISettingsPage()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.cloud_sync_rounded,
            iconColor: const Color(0xFF4CAF50),
            iconBgColor: const Color(0xFF4CAF50),
            title: 'Sao lưu & Khôi phục',
            subtitle: 'Xuất hoặc nhập dữ liệu ứng dụng (Zip)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BackupSettingsPage()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF42A5F5),
            iconBgColor: const Color(0xFF42A5F5),
            title: 'Về ứng dụng',
            subtitle: 'Phiên bản, nhà phát triển và thông tin',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutPage()),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Reusable settings tile
// ─────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color:
          isDark ? theme.cardColor : theme.primaryColor.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(AppTheme.expressiveRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.expressiveRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              // Squircle icon container
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: iconBgColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 1. Salary Settings Page
// ─────────────────────────────────────────────────
class SalarySettingsPage extends StatefulWidget {
  final double currentSalary;
  const SalarySettingsPage({super.key, required this.currentSalary});

  @override
  State<SalarySettingsPage> createState() => _SalarySettingsPageState();
}

class _SalarySettingsPageState extends State<SalarySettingsPage> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentSalary.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _parsedSalary =>
      double.tryParse(_controller.text.replaceAll(RegExp(r'[,.]'), '')) ?? 0;

  double get _computedDailyLimit {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    return _parsedSalary > 0 ? _parsedSalary / daysInMonth : 0;
  }

  void _saveAndPop() {
    if (_parsedSalary > 0) {
      final settingsBox = Hive.box<AppSettings>('settings');
      final settings = settingsBox.get('appSettings') ?? AppSettings();
      settings.monthlySalary = _parsedSalary;
      settings.dailyLimit = _computedDailyLimit;
      settingsBox.put('appSettings', settings);
      Navigator.pop(context, _parsedSalary);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(
      locale: 'vi',
      symbol: '₫',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Đặt ngân sách tháng', style: theme.textTheme.titleLarge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          color: theme.iconTheme.color,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 32,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Nhập ngân sách tháng để tự động tính hạn mức chi tiêu hàng ngày.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Label
                  Text(
                    'Ngân sách tháng',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Input
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      suffixText: 'VNĐ',
                      suffixStyle: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          CurrencyConverterSheet.show(
                            context,
                            targetController: _controller,
                          ).then((_) => setState(() {}));
                        },
                        icon: Icon(
                          Icons.currency_exchange,
                          color: theme.primaryColor,
                        ),
                        tooltip: 'Quy đổi tiền tệ',
                      ),
                      filled: true,
                      fillColor: theme.canvasColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Daily limit info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.canvasColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.calculate_rounded,
                            color: theme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hạn mức hàng ngày',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _parsedSalary > 0
                                    ? fmt.format(_computedDailyLimit)
                                    : '—',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text('/ngày', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Save
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saveAndPop,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Lưu thay đổi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 2. Appearance Settings Page
// ─────────────────────────────────────────────────
class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Tùy chỉnh giao diện', style: theme.textTheme.titleLarge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          color: theme.iconTheme.color,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chọn chế độ hiển thị',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder(
              valueListenable: Hive.box<AppSettings>('settings').listenable(),
              builder: (context, Box<AppSettings> box, _) {
                final settings = box.get('appSettings') ?? AppSettings();
                final mode = settings.themeMode;

                return Column(
                  children: [
                    _ThemeCard(
                      icon: Icons.smartphone,
                      title: 'Hệ thống',
                      description: 'Tự động theo cài đặt thiết bị',
                      value: 'system',
                      currentMode: mode,
                    ),
                    const SizedBox(height: 12),
                    _ThemeCard(
                      icon: Icons.light_mode_rounded,
                      title: 'Sáng',
                      description: 'Giao diện nền trắng dễ nhìn',
                      value: 'light',
                      currentMode: mode,
                    ),
                    const SizedBox(height: 12),
                    _ThemeCard(
                      icon: Icons.dark_mode_rounded,
                      title: 'Tối',
                      description: 'Giao diện tối bảo vệ mắt',
                      value: 'dark',
                      currentMode: mode,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String value;
  final String currentMode;

  const _ThemeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.currentMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = value == currentMode;

    return Material(
      color: isSelected
          ? theme.primaryColor.withValues(alpha: 0.1)
          : theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final box = Hive.box<AppSettings>('settings');
          final settings = box.get('appSettings') ?? AppSettings();
          settings.themeMode = value;
          settings.save();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? theme.primaryColor : theme.dividerColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.primaryColor.withValues(alpha: 0.15)
                      : theme.dividerColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? theme.primaryColor
                      : theme.textTheme.bodyMedium?.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? theme.primaryColor : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.primaryColor,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 3. About Page
// ─────────────────────────────────────────────────
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _deviceName = '...';
  String _osVersion = '...';

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        final brand = android.manufacturer;
        final capitalizedBrand = brand.isNotEmpty
            ? '${brand[0].toUpperCase()}${brand.substring(1)}'
            : brand;
        setState(() {
          _deviceName = '$capitalizedBrand ${android.model}';
          _osVersion = 'Android ${android.version.release}';
        });
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        setState(() {
          _deviceName = ios.name;
          _osVersion = '${ios.systemName} ${ios.systemVersion}';
        });
      }
    } catch (_) {
      setState(() {
        _deviceName = 'Unknown';
        _osVersion = 'Unknown';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Về ứng dụng',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          color: theme.brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── Upper hero section (takes most of the screen) ──
          Expanded(
            flex: 7,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: theme.brightness == Brightness.dark
                      ? [
                          const Color(0xFF0D2137),
                          const Color(0xFF0A1A2E),
                          theme.scaffoldBackgroundColor,
                        ]
                      : [
                          const Color(0xFFE8D5F5),
                          const Color(0xFFF3E5F5),
                          theme.scaffoldBackgroundColor,
                        ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App logo
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF00BFA6),
                          const Color(0xFF00897B),
                          const Color(0xFF004D40),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF00BFA6,
                          ).withValues(alpha: 0.35),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // App name
                  Text(
                    'Quản lý chi tiêu',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: theme.textTheme.headlineMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Version
                  Text(
                    '1.0.0',
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom info card section ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildAboutRow(
                    context,
                    'Tác giả',
                    'Therize',
                    showDivider: true,
                  ),
                  _buildAboutRow(
                    context,
                    'Thiết bị',
                    _deviceName,
                    showDivider: true,
                  ),
                  _buildAboutRow(
                    context,
                    'Phiên bản OS',
                    _osVersion,
                    showDivider: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutRow(
    BuildContext context,
    String label,
    String value, {
    bool showDivider = true,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black87,
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: theme.dividerColor.withValues(alpha: 0.15),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// 4. AI Assistant Settings Page
// ─────────────────────────────────────────────────
class AISettingsPage extends StatefulWidget {
  const AISettingsPage({super.key});

  @override
  State<AISettingsPage> createState() => _AISettingsPageState();
}

class _AISettingsPageState extends State<AISettingsPage> {
  late TextEditingController _apiKeyController;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final settings =
        Hive.box<AppSettings>('settings').get('appSettings') ?? AppSettings();
    _apiKeyController =
        TextEditingController(text: settings.geminiApiKey ?? '');
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _saveApiKey() {
    final settingsBox = Hive.box<AppSettings>('settings');
    final settings = settingsBox.get('appSettings') ?? AppSettings();
    final key = _apiKeyController.text.trim();
    settings.geminiApiKey = key.isEmpty ? null : key;
    settingsBox.put('appSettings', settings);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(key.isEmpty ? 'Đã xóa API Key' : 'Đã lưu API Key ✅'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings =
        Hive.box<AppSettings>('settings').get('appSettings') ?? AppSettings();
    final hasCustomKey =
        settings.geminiApiKey != null && settings.geminiApiKey!.isNotEmpty;
    final remaining = settings.freeAiUses;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('AI Assistant', style: theme.textTheme.titleLarge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          color: theme.iconTheme.color,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Status Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: hasCustomKey
                  ? const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)])
                  : remaining > 0
                      ? const LinearGradient(
                          colors: [Color(0xFF7F7FD5), Color(0xFF91EAE4)])
                      : const LinearGradient(
                          colors: [Color(0xFFFF9800), Color(0xFFF44336)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  hasCustomKey
                      ? Icons.verified_rounded
                      : remaining > 0
                          ? Icons.smart_toy_rounded
                          : Icons.warning_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasCustomKey
                            ? 'Không giới hạn ✨'
                            : remaining > 0
                                ? 'Còn $remaining lượt miễn phí'
                                : 'Hết lượt miễn phí',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasCustomKey
                            ? 'Đang dùng API Key cá nhân'
                            : 'Nhập API Key Gemini để dùng không giới hạn',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // API Key Input
          Text(
            'Gemini API Key',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lấy miễn phí tại aistudio.google.com',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureKey,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              color: theme.textTheme.bodyLarge?.color,
            ),
            decoration: InputDecoration(
              hintText: 'AIzaSy...',
              hintStyle: TextStyle(
                color:
                    theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
              ),
              filled: true,
              fillColor: theme.canvasColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureKey ? Icons.visibility_off : Icons.visibility,
                  color:
                      theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                ),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saveApiKey,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.save_rounded),
              label: const Text(
                'Lưu API Key',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          if (hasCustomKey) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                _apiKeyController.clear();
                _saveApiKey();
              },
              child: const Text(
                'Xóa API Key (quay lại dùng miễn phí)',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 5. Backup & Restore Settings Page
// ─────────────────────────────────────────────────
class BackupSettingsPage extends StatelessWidget {
  const BackupSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Sao lưu & Khôi phục', style: theme.textTheme.titleLarge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          color: theme.iconTheme.color,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_sync_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bảo vệ dữ liệu của bạn',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tạo file nén (.zip) chứa toàn bộ chi tiêu, cài đặt và API Key.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Tùy chọn',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.upload_file_rounded,
              iconColor: theme.primaryColor,
              iconBgColor: theme.primaryColor,
              title: 'Xuất dữ liệu (Backup)',
              subtitle: 'Lưu hoặc chia sẻ file backup',
              onTap: () async {
                if (kIsWeb) {
                  WebCompatibilityHelper.showUnsupportedMessage(context);
                  return;
                }
                await BackupService.exportData(context);
              },
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.restore_page_rounded,
              iconColor: Colors.orange,
              iconBgColor: Colors.orange,
              title: 'Nhập dữ liệu (Restore)',
              subtitle: 'Khôi phục từ file .zip đã sao lưu',
              onTap: () async {
                if (kIsWeb) {
                  WebCompatibilityHelper.showUnsupportedMessage(context);
                  return;
                }

                // Warning dialog
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Cảnh báo khôi phục'),
                    content: const Text(
                      'Hành động này sẽ ghi đè toàn bộ dữ liệu hiện tại bằng dữ liệu từ file backup. '
                      'Bạn có chắc chắn muốn tiếp tục?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Khôi phục'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  await BackupService.importData(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
