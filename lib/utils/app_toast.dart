import 'package:flutter/material.dart';

class AppToast {
  static void show(BuildContext context, String message) {
    if (!context.mounted) return;

    final theme = Theme.of(context);
    
    // Clear any existing snackbars before showing a new one
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: theme.primaryColor.withValues(alpha: 0.95),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.only(
          bottom: 100, // Float above the dock (height 70)
          left: 20,
          right: 20,
        ),
        elevation: 6,
      ),
    );
  }
}
