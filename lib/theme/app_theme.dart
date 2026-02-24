import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // --- New Soft UI / Glassmorphism Palette ---

  // M3 Expressive corner radius
  static const double expressiveRadius = 28.0;

  // Soft Purple (Primary Brand)
  static const Color softPurple = Color(0xFF7F7FD5);
  static const Color softPurpleDark = Color(0xFF6C63FF);

  // Pastel Pink (Accents/Gradient)
  static const Color pastelPink = Color(0xFFFFD1DC);

  // Airy Blue (Backgrounds/Soft Highlights)
  static const Color airyBlue = Color(0xFFE0E5FF);
  static const Color airyBlueDark = Color(0xFFC5CAE9);

  // Backgrounds
  static const Color lightBackground = Color(
    0xFFF8F9FD,
  ); // Very subtle cool white
  static const Color darkBackground = Color(
    0xFF1E1E2E,
  ); // Deep distinct violet-black

  // Text
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);

  // --- Gradients ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [softPurple, Color(0xFF91EAE4)], // Soft Purple to Soft Teal/Blue
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [
      softPurple,
      Color(0xFF86A8E7),
      Color(0xFF91EAE4),
    ], // "Morning" Gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFFF9A9E), Color(0xFFFF6B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color darkDanger = Color(0xFFD93636);
  static const Color darkPrimary = softPurpleDark; // Alias for compatibility

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Colors.white, Colors.white54],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- Theme Data ---

  static ThemeData get lightTheme {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: lightBackground,
      primaryColor: softPurple,
      cardColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto', // Or standard
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      colorScheme: const ColorScheme.light(
        primary: softPurple,
        secondary: airyBlue,
        surface: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
        titleLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 24,
          letterSpacing: -0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: softPurple,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: softPurple.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(expressiveRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        ),
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      dividerColor: Colors.black.withValues(alpha: 0.05),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: darkBackground,
      primaryColor: softPurple,
      cardColor: const Color(0xFF2D2D44), // Soft dark card
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: darkTextPrimary),
      ),
      colorScheme: const ColorScheme.dark(
        primary: softPurple,
        secondary: softPurpleDark,
        surface: Color(0xFF2D2D44),
        onSurface: darkTextPrimary,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkTextPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: darkTextSecondary, fontSize: 14),
        titleLarge: TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 24,
          letterSpacing: -0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: softPurple,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(expressiveRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        ),
      ),
      iconTheme: const IconThemeData(color: darkTextPrimary),
      dividerColor: Colors.white.withValues(alpha: 0.05),
    );
  }
}
