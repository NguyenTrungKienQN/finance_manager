import 'package:flutter/material.dart';

Future<void> showShieldAbsorbedDialog(
  BuildContext context, {
  required String habitName,
}) {
  return _showMascotDialog(
    context,
    mascotAsset: 'assets/mascots/mascotwshock.png',
    mascotFallbackIcon: Icons.shield_outlined,
    borderColor: const Color(0xFF7E57C2),
    title: 'Lá chắn đã bảo vệ bạn!',
    titleColor: const Color(0xFF7E57C2),
    body:
        'Chuỗi "$habitName" vẫn được giữ nguyên, nhưng lá chắn đã bị tiêu hao. '
        'Lần tới sẽ không có bảo vệ nữa — hãy cẩn thận nhé!',
    buttonLabel: 'Tôi hiểu rồi',
    buttonIcon: Icons.check_circle_outline,
    buttonColor: const Color(0xFF7E57C2),
  );
}

Future<void> showStreakFrozenDialog(
  BuildContext context, {
  required String habitName,
}) {
  return _showMascotDialog(
    context,
    mascotAsset: 'assets/mascots/mascotwait.png',
    mascotFallbackIcon: Icons.ac_unit,
    borderColor: const Color(0xFF42A5F5),
    title: 'Chuỗi bị đóng băng! 🧊',
    titleColor: const Color(0xFF1E88E5),
    body: 'Bạn có 3 ngày để hồi phục. Không mua "$habitName" trong 3 ngày tới '
        'và chuỗi sẽ được khôi phục.',
    subText:
        '⚠️ Nếu mua lại trong thời gian đóng băng, chuỗi sẽ bị xóa hoàn toàn về 0!',
    buttonLabel: 'Tôi sẽ cố gắng',
    buttonIcon: Icons.ac_unit,
    buttonColor: const Color(0xFF1E88E5),
  );
}

Future<void> showFullResetDialog(
  BuildContext context, {
  required String habitName,
  required int lostStreak,
}) {
  return _showMascotDialog(
    context,
    mascotAsset: 'assets/mascots/mascotsad.png',
    mascotFallbackIcon: Icons.sentiment_very_dissatisfied,
    borderColor: const Color(0xFFFF6B6B),
    title: 'OH NO!',
    titleColor: const Color(0xFFFF6B6B),
    body:
        'Bạn đã mua "$habitName" trong thời gian đóng băng. Chuỗi $lostStreak ngày '
        'đã bị xóa hoàn toàn.',
    subText: 'Đừng bỏ cuộc, hãy bắt đầu lại từ ngày mai!',
    buttonLabel: 'Bắt đầu lại từ đầu',
    buttonIcon: Icons.refresh,
    buttonColor: const Color(0xFFFF6B6B),
  );
}

Future<void> _showMascotDialog(
  BuildContext context, {
  required String mascotAsset,
  required IconData mascotFallbackIcon,
  required Color borderColor,
  required String title,
  required Color titleColor,
  required String body,
  String? subText,
  required String buttonLabel,
  required IconData buttonIcon,
  required Color buttonColor,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.86, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: borderColor, width: 4),
            boxShadow: [
              BoxShadow(
                color: borderColor.withValues(alpha: 0.28),
                blurRadius: 22,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                mascotAsset,
                height: 120,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(mascotFallbackIcon, color: borderColor, size: 52),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  height: 1.4,
                ),
              ),
              if (subText != null) ...[
                const SizedBox(height: 10),
                Text(
                  subText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.78),
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(buttonIcon, size: 22),
                label: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
