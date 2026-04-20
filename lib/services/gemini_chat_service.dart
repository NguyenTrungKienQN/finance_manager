import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/chat_persona.dart';
import '../models/settings_model.dart';
import '../models/transaction_model.dart';
import 'chat_context_service.dart';

/// Manages the Gemini AI chat session with persona switching and rate limiting.
class GeminiChatService {
  // Default key injected securely at compile-time via --dart-define
  static const String _defaultApiKey = String.fromEnvironment('GEMINI_API_KEY');

  final List<Content> _history = [];
  ChatPersona _currentPersona = ChatPersona.expert;
  String _currentModel = 'gemini-2.5-flash'; 
  DateTime? _lastContextUpdate;
  String? _lastContext;

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
        'gemini-3.1-pro-preview',
        'gemini-3-flash-preview',
        'gemini-2.5-flash',
        'gemini-2.5-pro',
        'gemini-2.0-flash',
      ];
    }
  }

  /// Switches the active model and clears history for a fresh start.
  void switchModel(String modelName) {
    _currentModel = modelName;
    reset();
  }

  /// Switches the persona and clears history.
  void switchPersona(ChatPersona persona) {
    _currentPersona = persona;
    reset();
  }

  /// Sends a message and returns the AI response.
  Future<String> sendMessage(String text) async {
    if (!canSendMessage()) {
      throw RateLimitException();
    }

    final now = DateTime.now();

    // Refresh context if it's been more than 10 seconds or session is empty
    if (_lastContextUpdate == null ||
        now.difference(_lastContextUpdate!).inSeconds > 10) {
      _lastContext = ChatContextService.buildContext();
      _lastContextUpdate = now;
    }

    try {
      final systemPrompt = _currentPersona.systemInstruction(_lastContext ?? "");
      final model = GenerativeModel(
        model: _currentModel,
        apiKey: _getApiKey(),
        systemInstruction: Content.system(systemPrompt),
      );

      // Start session with existing history
      final session = model.startChat(history: List.from(_history));

      final response = await session.sendMessage(Content.text(text));
      final reply = response.text ?? 'Xin lỗi, tôi không thể trả lời lúc này.';

      // Update manual history
      _history.add(Content.text(text));
      _history.add(Content.model([TextPart(reply)]));

      _decrementUses();
      return reply;
    } catch (e) {
      if (e is RateLimitException) rethrow;
      throw Exception('Lỗi kết nối AI: $e');
    }
  }

  /// Initializes or reinitializes the context tracking (used on screen entry).
  void refresh() {
    _lastContext = ChatContextService.buildContext();
    _lastContextUpdate = DateTime.now();
  }

  /// Auto-sends a wallet analysis prompt.
  Future<String> analyzeWallet() {
    return sendMessage(
      'Phân tích tình hình tài chính của tôi tháng này. '
      'Cho tôi biết tôi đang chi tiêu thế nào, những danh mục nào tốn nhiều nhất, '
      'và lời khuyên cụ thể để cải thiện.',
    );
  }

  /// Resets the session (for when user changes API key or wants clear).
  void reset() {
    _history.clear();
    _lastContextUpdate = null;
    _lastContext = null;
  }

  /// Extracts amount and category intelligently from unstructured text, USING WEB SEARCH
  Future<Map<String, dynamic>?> parseTransactionText(String text) async {
    try {
      final apiKey = _getApiKey();
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');
      
      final payload = {
        "systemInstruction": {
          "parts": [{"text": "Bạn là trợ lý dữ liệu tài chính.\n"
            "NHIỆM VỤ: Trích xuất số tiền và phân loại danh mục.\n"
            "- Nếu phát hiện tên sản phẩm/dịch vụ (VD: Xiaomi 17 Ultra, Netflix), HÃY TÌM KIẾM WEB để lấy giá bán hiện tại tại Việt Nam.\n"
            "- Các danh mục hợp lệ duy nhất: 'Ăn uống', 'Mua sắm', 'Giao thông', 'Giáo dục', 'Giải trí', 'Y tế', 'Khác'.\n"
            "CHỈ trả về JSON nguyên chất.\n"
            "Cấu trúc: {\"amount\": number, \"category\": \"string\"}"
          }]
        },
        "contents": [
          {"role": "user", "parts": [{"text": text}]}
        ],
        "tools": [
          {"googleSearch": {}}
        ]
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
         debugPrint('[AI Parser Grounding] HTTP Error ${response.statusCode}: ${response.body}');
         if (response.statusCode == 429) {
           final match = RegExp(r'retry in ([\d\.]+)s').firstMatch(response.body);
           if (match != null) {
             final seconds = double.tryParse(match.group(1)!)?.round() ?? 60;
             throw ApiBusyException(seconds);
           }
           throw ApiBusyException(60);
         }
         return null; 
      }

      final responseData = jsonDecode(response.body);
      
      final rawText = responseData['candidates']?[0]?['content']?['parts']?[0]?['text']?.trim() ?? '';
      debugPrint('[AI Parser Grounding] Raw response: $rawText');
      
      var jsonString = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(jsonString);
      if (jsonMatch != null) {
        jsonString = jsonMatch.group(0)!;
      }

      debugPrint('[AI Parser Grounding] Parsed JSON: $jsonString');
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiBusyException) rethrow;
      debugPrint('[AI Parser Grounding] ERROR: $e');
      return null;
    }
  }

  /// Evaluates if a transaction breaks a habit using AI
  Future<bool> doesTransactionBreakHabit(String habitName, String category, String note) async {
    try {
      final apiKey = _getApiKey();
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(
          "Bạn là trợ lý AI phân tích thói quen chi tiêu. "
          "Nhiệm vụ của bạn là xác định xem một khoản chi tiêu có vi phạm thói quen đang cố bỏ của người dùng hay không.\n"
          "Trả lời CHỈ BẰNG 1 TỪ duy nhất: 'YES' nếu vi phạm, hoặc 'NO' nếu không vi phạm."
        ),
      );

      final prompt = "Thói quen cố bỏ: $habitName\n"
          "Khoản chi tiêu vừa thêm: Danh mục: $category, Ghi chú: ${note.isEmpty ? 'Không có' : note}\n"
          "Khoản này có phải là vi phạm hay không?";

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim().toUpperCase() ?? 'NO';
      
      return text.contains('YES');
    } catch (e) {
      return false; // Fallback to safe side
    }
  }

  /// Bulk categorization of messy transactions
  Future<Map<String, String>?> batchCategorizeTransactions(List<Transaction> transactions) async {
    try {
      final apiKey = _getApiKey();
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(
          "Bạn là chuyên gia dọn dẹp dữ liệu tài chính.\n"
          "NHIỆM VỤ: Phân loại lại danh sách các giao dịch có danh mục đang bị sai lệch.\n"
          "- Các danh mục hợp lệ DUY NHẤT: 'Ăn uống', 'Mua sắm', 'Giao thông', 'Giáo dục', 'Giải trí', 'Y tế', 'Khác'.\n"
          "Dựa vào tên/ghi chú của giao dịch (ví dụ 'Grab', 'HaoHao', 'Nhà thuốc'), hãy gán danh mục đúng.\n"
          "CHỈ trả về JSON nguyên chất (không markdown). Khóa là ID giao dịch, giá trị là danh mục mới.\n"
          "Ví dụ: {\"txn_id_123\": \"Ăn uống\", \"txn_id_456\": \"Giao thông\"}"
        ),
      );

      final txListJson = transactions.map((tx) => {
        "id": tx.id,
        "amount": tx.amount,
        "note": tx.notes ?? 'Không rõ'
      }).toList();

      final prompt = "Hành động: Phân loại danh sách giao dịch sau:\n${jsonEncode(txListJson)}";
      
      final response = await model.generateContent([Content.text(prompt)]);
      final rawText = response.text?.trim() ?? '';
      debugPrint('[AI Batch] Raw response: $rawText');
      
      var jsonString = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(jsonString);
      if (jsonMatch != null) {
        jsonString = jsonMatch.group(0)!;
      }
      
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      debugPrint('[AI Batch] ERROR: $e');
      return null;
    }
  }
}

/// Custom exception for rate limiting.
class RateLimitException implements Exception {
  @override
  String toString() =>
      'Đã hết lượt dùng thử miễn phí. Vui lòng nhập API Key của bạn trong Cài đặt.';
}

/// Custom exception for Google AI short-term Rate Limits.
class ApiBusyException implements Exception {
  final int seconds;
  ApiBusyException(this.seconds);

  @override
  String toString() =>
      'API đang bận. Vui lòng thử lại trong $seconds giây.';
}
