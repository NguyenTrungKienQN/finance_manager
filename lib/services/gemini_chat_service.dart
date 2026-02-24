import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/chat_persona.dart';
import '../models/settings_model.dart';
import 'chat_context_service.dart';

/// Manages the Gemini AI chat session with persona switching and rate limiting.
class GeminiChatService {
  // Default key injected securely at compile-time via --dart-define
  static const String _defaultApiKey = String.fromEnvironment('GEMINI_API_KEY');

  ChatSession? _chatSession;
  ChatPersona _currentPersona = ChatPersona.expert;
  String _currentModel = 'gemini-2.5-flash';

  ChatPersona get currentPersona => _currentPersona;
  String get currentModel => _currentModel;

  /// Gets the active API key (user's key or default).
  String _getApiKey() {
    final settingsBox = Hive.box<AppSettings>('settings');
    final settings = settingsBox.get('appSettings') ?? AppSettings();

    if (settings.geminiApiKey != null && settings.geminiApiKey!.isNotEmpty) {
      return settings.geminiApiKey!;
    }
    return _defaultApiKey;
  }

  /// Checks if the user can still send messages.
  bool canSendMessage() {
    final settingsBox = Hive.box<AppSettings>('settings');
    final settings = settingsBox.get('appSettings') ?? AppSettings();

    if (settings.geminiApiKey != null && settings.geminiApiKey!.isNotEmpty) {
      return true;
    }
    return settings.freeAiUses > 0;
  }

  /// Gets remaining free uses.
  int get remainingFreeUses {
    final settingsBox = Hive.box<AppSettings>('settings');
    final settings = settingsBox.get('appSettings') ?? AppSettings();
    if (settings.geminiApiKey != null && settings.geminiApiKey!.isNotEmpty) {
      return -1; // Unlimited
    }
    return settings.freeAiUses;
  }

  /// Decrements the free usage counter.
  void _decrementUses() {
    final settingsBox = Hive.box<AppSettings>('settings');
    final settings = settingsBox.get('appSettings') ?? AppSettings();

    if (settings.geminiApiKey == null || settings.geminiApiKey!.isEmpty) {
      settings.freeAiUses = (settings.freeAiUses - 1).clamp(0, 999);
      settings.save();
    }
  }

  /// Fetches available Gemini models from the REST API.
  Future<List<String>> fetchAvailableModels() async {
    try {
      final apiKey = _getApiKey();
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
        ),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final json = jsonDecode(body) as Map<String, dynamic>;
      final models = (json['models'] as List<dynamic>?) ?? [];

      final result = <String>[];
      for (final m in models) {
        final name = (m['name'] as String?)?.replaceFirst('models/', '') ?? '';
        final methods =
            (m['supportedGenerationMethods'] as List<dynamic>?) ?? [];
        if (methods.contains('generateContent') && name.startsWith('gemini-')) {
          result.add(name);
        }
      }

      // Sort: flash first, then descending by name
      result.sort((a, b) {
        final aFlash = a.contains('flash') ? 0 : 1;
        final bFlash = b.contains('flash') ? 0 : 1;
        if (aFlash != bFlash) return aFlash.compareTo(bFlash);
        return b.compareTo(a);
      });

      return result;
    } catch (_) {
      return [
        'gemini-2.5-flash',
        'gemini-2.5-pro',
        'gemini-2.0-flash',
        'gemini-1.5-flash',
        'gemini-1.5-pro',
      ];
    }
  }

  /// Switches the active model and reinitializes the session.
  void switchModel(String modelName) {
    _currentModel = modelName;
    _initSession();
  }

  /// Initializes or reinitializes the chat session with the given persona.
  void switchPersona(ChatPersona persona) {
    _currentPersona = persona;
    _initSession();
  }

  /// Creates a fresh Gemini model + chat session.
  void _initSession() {
    final context = ChatContextService.buildContext();
    final systemPrompt = _currentPersona.systemInstruction(context);

    final model = GenerativeModel(
      model: _currentModel,
      apiKey: _getApiKey(),
      systemInstruction: Content.system(systemPrompt),
    );

    _chatSession = model.startChat();
  }

  /// Sends a message and returns the AI response.
  Future<String> sendMessage(String text) async {
    if (!canSendMessage()) {
      throw RateLimitException();
    }

    if (_chatSession == null) {
      _initSession();
    }

    try {
      final response = await _chatSession!.sendMessage(Content.text(text));
      final reply = response.text ?? 'Xin lỗi, tôi không thể trả lời lúc này.';
      _decrementUses();
      return reply;
    } catch (e) {
      if (e is RateLimitException) rethrow;
      _chatSession = null;
      throw Exception('Lỗi kết nối AI: $e');
    }
  }

  /// Auto-sends a wallet analysis prompt.
  Future<String> analyzeWallet() {
    return sendMessage(
      'Phân tích tình hình tài chính của tôi tháng này. '
      'Cho tôi biết tôi đang chi tiêu thế nào, những danh mục nào tốn nhiều nhất, '
      'và lời khuyên cụ thể để cải thiện.',
    );
  }

  /// Resets the session (for when user changes API key).
  void reset() {
    _chatSession = null;
  }
}

/// Custom exception for rate limiting.
class RateLimitException implements Exception {
  @override
  String toString() =>
      'Đã hết lượt dùng thử miễn phí. Vui lòng nhập API Key của bạn trong Cài đặt.';
}
