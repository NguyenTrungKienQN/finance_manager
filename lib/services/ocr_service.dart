import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class OcrService {
  TextRecognizer? _textRecognizer;

  TextRecognizer get textRecognizer {
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _textRecognizer!;
  }

  /// Parse VND amount from various formats:
  /// - 200000 (plain number)
  /// - 200.000 (dot as thousand separator)
  /// - 200,000 (comma as thousand separator)
  /// - 200k or 200K (shorthand for thousands)
  /// - 1.5m or 1,5m (shorthand for millions)
  double? parseVndAmount(String text) {
    try {
      String cleaned = text.trim().toLowerCase();

      // Remove currency symbols and common suffixes
      cleaned = cleaned.replaceAll(RegExp(r'[đdvn₫]'), '');
      cleaned = cleaned.replaceAll('vnd', '');
      cleaned = cleaned.trim();

      if (cleaned.isEmpty) return null;

      // Handle "k" suffix (200k = 200,000)
      if (cleaned.endsWith('k')) {
        String numberPart = cleaned.substring(0, cleaned.length - 1);
        // Replace comma with dot for decimal parsing (1,5k = 1500)
        numberPart = numberPart.replaceAll(',', '.');
        double? value = double.tryParse(numberPart);
        return value != null ? value * 1000 : null;
      }

      // Handle "m" suffix (1m = 1,000,000)
      if (cleaned.endsWith('m')) {
        String numberPart = cleaned.substring(0, cleaned.length - 1);
        numberPart = numberPart.replaceAll(',', '.');
        double? value = double.tryParse(numberPart);
        return value != null ? value * 1000000 : null;
      }

      // Handle thousand separators (200.000 or 200,000)
      // VND typically uses dot as thousand separator: 200.000 = 200000
      // Check if it's a thousand separator pattern (groups of 3 digits)
      if (RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(cleaned)) {
        // Remove all dots and commas (they are thousand separators)
        cleaned = cleaned.replaceAll(RegExp(r'[.,]'), '');
        return double.tryParse(cleaned);
      }

      // Plain number
      return double.tryParse(cleaned);
    } catch (e) {
      return null;
    }
  }

  Future<double> scanReceipt(String imagePath) async {
    try {
      final inputImage = InputImage.fromFile(File(imagePath));
      final recognizedText = await textRecognizer.processImage(inputImage);

      double maxAmount = 0.0;

      // Regex to find potential price patterns in text
      final pricePatterns = [
        RegExp(r'\d{1,3}([.,]\d{3})+'), // 200.000 or 200,000
        RegExp(r'\d+[kK]'), // 200k, 200K
        RegExp(r'\d+[.,]?\d*[mM]'), // 1m, 1.5m
        RegExp(r'\d{4,}'), // Plain numbers with 4+ digits (like 50000)
      ];

      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          String text = line.text;

          // Try each pattern
          for (var pattern in pricePatterns) {
            for (var match in pattern.allMatches(text)) {
              String matchedText = match.group(0) ?? '';
              double? value = parseVndAmount(matchedText);

              if (value != null && value > maxAmount && value >= 1000) {
                maxAmount = value;
              }
            }
          }
        }
      }
      return maxAmount;
    } catch (e) {
      debugPrint("OCR Error: $e");
      return 0.0;
    }
  }

  void dispose() {
    _textRecognizer?.close();
  }
}
