import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/export_service.dart';
import '../services/app_time_service.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';
import '../utils/app_toast.dart';

class ExportSettingsPage extends StatefulWidget {
  const ExportSettingsPage({super.key});

  @override
  State<ExportSettingsPage> createState() => _ExportSettingsPageState();
}

class _ExportSettingsPageState extends State<ExportSettingsPage> {
  DateTime _startDate = AppTimeService.instance.now();
  DateTime _endDate = AppTimeService.instance.now();
  String _format = 'Excel'; // 'Excel' or 'PDF'
  bool _isExporting = false;

  void _setRange(String preset) {
    final now = AppTimeService.instance.now();
    setState(() {
      switch (preset) {
        case 'today':
          _startDate = now;
          _endDate = now;
          break;
        case 'month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0);
          break;
        case 'year':
          _startDate = DateTime(now.year, 1, 1);
          _endDate = DateTime(now.year, 12, 31);
          break;
      }
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppTheme.softPurple,
              primary: AppTheme.softPurple,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      if (_format == 'Excel') {
        await ExportService.exportToExcel(_startDate, _endDate);
      } else {
        await ExportService.exportToPdf(_startDate, _endDate);
      }
      if (mounted) {
        AppToast.show(context, 'Xuất file thành công!');
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Lỗi khi xuất file: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Xuất dữ liệu', style: theme.textTheme.titleLarge),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GlassBackButton(onPressed: () => Navigator.pop(context)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header Info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.description_rounded, color: Colors.white, size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Chọn định dạng và khoảng thời gian bạn muốn xuất báo cáo chi tiêu.',
                    style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Format Picker
          Text('Định dạng tệp', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _FormatButton(
                label: 'Excel (.xlsx)',
                icon: Icons.table_view_rounded,
                selected: _format == 'Excel',
                onTap: () => setState(() => _format = 'Excel'),
              ),
              const SizedBox(width: 12),
              _FormatButton(
                label: 'PDF (.pdf)',
                icon: Icons.picture_as_pdf_rounded,
                selected: _format == 'PDF',
                onTap: () => setState(() => _format = 'PDF'),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Date presets
          Text('Khoảng thời gian', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PresetChip(label: 'Hôm nay', onTap: () => _setRange('today')),
              _PresetChip(label: 'Tháng này', onTap: () => _setRange('month')),
              _PresetChip(label: 'Năm nay', onTap: () => _setRange('year')),
              _PresetChip(label: 'Tùy chọn', isAction: true, onTap: _pickRange),
            ],
          ),
          const SizedBox(height: 24),

          // Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Từ ngày', style: theme.textTheme.bodySmall),
                    Text(DateFormat('dd/MM/yyyy').format(_startDate), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Đến ngày', style: theme.textTheme.bodySmall),
                    Text(DateFormat('dd/MM/yyyy').format(_endDate), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Export Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isExporting ? null : _handleExport,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isExporting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.share_rounded),
                        SizedBox(width: 10),
                        Text('Chia sẻ báo cáo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FormatButton({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? theme.primaryColor.withValues(alpha: 0.1) : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? theme.primaryColor : theme.dividerColor.withValues(alpha: 0.1), width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? theme.primaryColor : theme.iconTheme.color?.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: selected ? theme.primaryColor : theme.textTheme.bodyMedium?.color, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isAction;

  const _PresetChip({required this.label, required this.onTap, this.isAction = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: isAction ? theme.primaryColor.withValues(alpha: 0.1) : theme.cardColor,
      labelStyle: TextStyle(color: isAction ? theme.primaryColor : theme.textTheme.bodyMedium?.color),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
