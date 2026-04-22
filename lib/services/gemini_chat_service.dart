import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/chat_persona.dart';
import '../models/settings_model.dart';
import 'package:finance_manager/models/transaction_model.dart';
import 'package:finance_manager/services/chat_context_service.dart';
import 'package:finance_manager/services/category_registry.dart';
import 'package:finance_manager/services/app_time_service.dart';

/// Manages the Gemini AI chat session with persona switching and rate limiting.
class GeminiChatService {
  // Default key injected securely at compile-time via --dart-define
  static const String _defaultApiKey = String.fromEnvironment('GEMINI_API_KEY');

  final List<Content> _history = [];
  ChatPersona _currentPersona = ChatPersona.expert;
  String _currentModel = 'gemini-2.0-flash'; 
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
        'gemini-2.0-flash',
        'gemini-2.0-flash-lite-preview-02-05',
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

  /// Private helper to query Gemini via REST with specific configurations
  Future<Map<String, dynamic>?> _queryModel(
    String text, {
    required String modelName,
    bool useSearch = false,
    String? systemPrompt,
  }) async {
    try {
      final apiKey = _getApiKey();
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey');

      final payload = {
        "systemInstruction": {
          "parts": [
            {
              "text": systemPrompt ??
                  "Bạn là trợ lý dữ liệu tài chính.\n"
                      "NHIỆM VỤ: Trích xuất số tiền và phân loại danh mục.\n"
                      "- Các danh mục hợp lệ duy nhất: ${CategoryRegistry.instance.categoryNames().map((n) => "'$n'").join(', ')}.\n"
                      "CHỈ trả về JSON nguyên chất.\n"
                      "Cấu trúc: {\"amount\": number, \"category\": \"string\", \"notes\": \"string\"}"
            }
          ]
        },
        "contents": [
          {
            "role": "user",
            "parts": [
              {"text": text}
            ]
          }
        ],
        if (useSearch)
          "tools": [
            {
              "googleSearch": {}
            }
          ]
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        debugPrint('[AI Parser] HTTP Error ${response.statusCode}: ${response.body}');
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
      debugPrint('[AI Parser] Raw response ($modelName): $rawText');

      var jsonString = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(jsonString);
      if (jsonMatch != null) {
        jsonString = jsonMatch.group(0)!;
      }

      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiBusyException) rethrow;
      debugPrint('[AI Parser] Error with $modelName: $e');
      return null;
    }
  }

  /// Tiered parsing for manual text input: tries Lite first, falls back to Flash+Search if price missing.
  Future<Map<String, dynamic>?> parseTransactionText(String text) async {
    // Stage 1: Try Fast Lite model without search
    final liteResult = await _queryModel(
      text,
      modelName: 'gemini-2.0-flash',
      systemPrompt: "Bạn là trợ lý dữ liệu tài chính.\n"
          "NHIỆM VỤ: Trích xuất số tiền và phân loại danh mục.\n"
          "- Các danh mục hợp lệ duy nhất: ${CategoryRegistry.instance.categoryNames().map((n) => "'$n'").join(', ')}.\n"
          "CHỈ trả về JSON nguyên chất.\n"
          "Cấu trúc: {\"amount\": number, \"category\": \"string\", \"notes\": \"string\"}",
    );

    if (liteResult != null && (liteResult['amount'] ?? 0) > 0) {
      debugPrint('[AI Parser] Success with Tier 1 (Lite)');
      return liteResult;
    }

    // Stage 2: Fallback to Flash + Google Search if no price found
    debugPrint('[AI Parser] Falling back to Tier 2 (Flash + Search)');
    return _queryModel(
      text,
      modelName: 'gemini-2.0-flash',
      useSearch: true,
      systemPrompt: "Bạn là trợ lý dữ liệu tài chính.\n"
          "NHIỆM VỤ: Trích xuất số tiền và phân loại danh mục.\n"
          "- Nếu phát hiện tên sản phẩm/dịch vụ (VD: Xiaomi 17 Ultra, Netflix), HÃY TÌM KIẾM WEB để lấy giá bán hiện tại tại Việt Nam.\n"
          "- Các danh mục hợp lệ duy nhất: ${CategoryRegistry.instance.categoryNames().map((n) => "'$n'").join(', ')}.\n"
          "CHỈ trả về JSON nguyên chất.\n"
          "Cấu trúc: {\"amount\": number, \"category\": \"string\", \"notes\": \"string\"}",
    );
  }

  /// Specialized parsing for Receipts: uses only Lite model for speed.
  Future<Map<String, dynamic>?> parseReceiptText(String rawText) async {
    return _queryModel(
      rawText,
      modelName: 'gemini-2.0-flash',
      systemPrompt: "Bạn là trợ lý phân tích hóa đơn.\n"
          "NHIỆM VỤ: Trích xuất số tiền tổng, danh mục và tóm tắt ghi chú từ văn bản OCR của hóa đơn.\n"
          "- Nếu hóa đơn có nhiều mặt hàng thuộc các danh mục khác nhau, hãy đặt category là 'Khác'.\n"
          "- Các danh mục hợp lệ: ${CategoryRegistry.instance.categoryNames().map((n) => "'$n'").join(', ')}.\n"
          "- Notes: Tóm tắt ngắn gọn các mặt hàng chính.\n"
          "CHỈ trả về JSON nguyên chất.\n"
          "Cấu trúc: {\"amount\": number, \"category\": \"string\", \"notes\": \"string\"}",
    );
  }

  /// Evaluates if a transaction breaks a habit using AI
  Future<bool> doesTransactionBreakHabit(String habitName, String category, String note) async {
    try {
      final whitelist = Hive.box<String>('habitWhitelist').values.toList();
      final whitelistStr = whitelist.join(', ');

      final apiKey = _getApiKey();
      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(
          "Bạn là trợ lý AI phân tích thói quen chi tiêu. "
          "Nhiệm vụ của bạn là xác định xem một khoản chi tiêu có vi phạm thói quen đang cố bỏ của người dùng hay không.\n"
          "DANH SÁCH TRẮNG (WHITELIST): $whitelistStr. Các khoản này là thiết yếu, KHÔNG bao giờ bị coi là vi phạm.\n"
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
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(
          "Bạn là chuyên gia dọn dẹp dữ liệu tài chính.\n"
          "NHIỆM VỤ: Phân loại lại danh sách các giao dịch có danh mục đang bị sai lệch.\n"
          "- Các danh mục hợp lệ DUY NHẤT: ${CategoryRegistry.instance.categoryNames().map((n) => "'$n'").join(', ')}.\n"
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

  /// Generates a schedule of daily notifications for a habit challenge using a specific AI persona.
  Future<List<String>?> generateHabitPersonaSchedule({
    required String habitName,
    required int duration,
    required String persona,
  }) async {
    try {
      final apiKey = _getApiKey();
      
      String personaDescription;
      if (persona == 'strict_mother') {
        personaDescription = 'một người mẹ nghiêm khắc, xét nét, hay mắng mỏ nhưng mục đích tốt';
      } else if (persona == 'best_friend') {
        personaDescription = 'một người bạn thân thiết, lầy lội, hài hước, luôn động viên theo kiểu đùa giỡn';
      } else {
        personaDescription = 'một chuyên gia tài chính điềm đạm, tập trung vào lợi ích dài hạn, sử dụng ngôn từ chuyên nghiệp';
      }

      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(
          "Bạn là $personaDescription.\n"
          "Người dùng đang tham gia thử thách từ bỏ thói quen: $habitName trong vòng $duration ngày.\n"
          "NHIỆM VỤ: Hãy viết ra một mảng JSON chứa chính xác $duration câu nói ngắn (mỗi câu dưới 30 từ) để nhắc nhở người dùng mỗi ngày vào buổi sáng, thể hiện được tính cách của bạn.\n"
          "Câu đầu tiên là ngày bắt đầu đầy hứa hẹn, các câu giữa là sự động viên/răn đe để không từ bỏ, câu cuối cùng là ngày vinh quang.\n"
          "Trả về MẢNG JSON nguyên chất chứa các chuỗi (ví dụ: [\"Câu ngày 1\", \"Câu ngày 2\", ...]). KHÔNG XUẤT RA MARKDOWN HAY BẤT KỲ VĂN BẢN NÀO KHÁC BÊN NGOÀI MẢNG JSON."
        ),
      );

      final response = await model.generateContent([Content.text("Thói quen: $habitName, Số ngày: $duration")]);
      final rawText = response.text?.trim() ?? '';
      
      var jsonString = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      final jsonMatch = RegExp(r'\[.*\]', dotAll: true).firstMatch(jsonString);
      if (jsonMatch != null) {
        jsonString = jsonMatch.group(0)!;
      }
      
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('[AI Persona] ERROR: $e');
      return null;
    }
  }

  /// Nhanh chóng kiểm tra thói quen bằng nội bộ (không tốn API) dùng cho in-app
  Map<String, dynamic>? fastCheckHabits() {
    final box = Hive.box<Transaction>('transactions');
    if (box.isEmpty) return null;
    
    final now = AppTimeService.instance.now();
    final lastMonth = now.subtract(const Duration(days: 30));
    final recentTxns = box.values.where((t) => t.date.isAfter(lastMonth)).toList();
    
    return _localFastSuggest(recentTxns);
  }

  Future<Map<String, dynamic>?> suggestHabitChallenge() async {
    final box = Hive.box<Transaction>('transactions');
    if (box.isEmpty) return null;

    final now = AppTimeService.instance.now();
    // Mở rộng bộ đệm lên 30 ngày vì người dùng xài cỗ máy thời gian nhảy hơi xa
    final lastMonth = now.subtract(const Duration(days: 30));
    
    final recentTxns = box.values.where((t) => t.date.isAfter(lastMonth)).toList();
    debugPrint('[AI Suggest] Cỗ máy thời gian: $now. Tìm thấy ${recentTxns.length} giao dịch trong 30 ngày qua.');
    
    if (recentTxns.isEmpty) return null;

    try {
      final txListJson = recentTxns.map((tx) => {
        "amount": tx.amount,
        "note": (tx.notes != null && tx.notes!.trim().isNotEmpty) ? tx.notes : tx.category,
        "category": tx.category
      }).toList();

      final whitelist = Hive.box<String>('habitWhitelist').values.toList();
      final whitelistStr = whitelist.join(', ');

      final apiKey = _getApiKey();
      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(
          "Bạn là chuyên gia phân tích hành vi tiêu dùng.\n"
          "NHIỆM VỤ: Hãy tìm ra thói quen chi tiêu lặp lại nhiều lần (>= 3 lần) trong mảng dữ liệu.\n"
          "DANH SÁCH TRẮNG (WHITELIST): $whitelistStr. BỎ QUA hoàn toàn các giao dịch chứa từ khóa này.\n"
          "QUY TẮC ĐỘ DÀI (Duration):\n"
          "- Phân tích MỨC ĐỘ TẦN SUẤT và SỐ TIỀN.\n"
          "- Nếu thói quen ít nghiêm trọng (ví dụ: trà đá vỉa hè): đề xuất 3-7 ngày.\n"
          "- Nếu thói quen tốn kém hoặc hại sức khỏe (ví dụ: thuốc lá, nhậu nhẹt): đề xuất 14-30 ngày.\n"
          "TRẢ VỀ JSON: {\"habit_name\": \"Tên thói quen\", \"suggested_duration\": số_ngày, \"reason\": \"lý do ngắn\"}\n"
          "CHỈ trả về 'null' nếu không tìm thấy thói quen xấu nào ngoài whitelist."
        ),
      );

      final prompt = "Giao dịch 14 ngày qua:\n${jsonEncode(txListJson)}";
      final response = await model.generateContent([Content.text(prompt)]);
      
      final rawText = response.text?.trim() ?? '';
      debugPrint('[AI Suggest] Raw Response: $rawText');
      if (rawText == 'null' || rawText.isEmpty) {
        // Fallback local heuristic
        return _localFastSuggest(recentTxns);
      }

      var jsonString = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(jsonString);
      if (jsonMatch != null) {
        jsonString = jsonMatch.group(0)!;
      } else {
        return _localFastSuggest(recentTxns);
      }
      
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[AI Suggest] ERROR: $e');
      return _localFastSuggest(recentTxns);
    }
  }

  /// Fast local frequency heuristic in case AI takes too long or fails to recognize cluster
  Map<String, dynamic>? _localFastSuggest(List<Transaction> txns) {
    final Map<String, int> counts = {};
    for (var tx in txns) {
      String note = (tx.notes?.trim().toLowerCase() ?? '');
      // Bóc tách tên bằng cách gỡ đi các con số, giá tiền (30k, 50đ...)
      note = note.replaceAll(RegExp(r'\d+k?|\d+đ?|\d+'), '').trim();
      if (note.isEmpty) note = tx.category.toLowerCase();
      
      // Chỉ lấy 2 từ đầu (ví dụ: "trà sữa", "cà phê")
      final words = note.split(' ');
      final key = words.take(2).join(' ').trim();
      if (key.isNotEmpty) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    
    debugPrint('[AI Suggest] Phân tích đếm nội bộ: $counts');
    
    String? topHabit;
    int maxFreq = 0;
    counts.forEach((key, val) {
      if (val >= 3 && val > maxFreq) {
        maxFreq = val;
        topHabit = key;
      }
    });

    if (topHabit == null) return null;

    // Capitalize first letter
    final habitName = topHabit![0].toUpperCase() + topHabit!.substring(1);
    
    return {
      "habit_name": habitName,
      "suggested_duration": 7,
      "reason": "Hệ thống phát hiện bạn đã chi tiền cho \"$habitName\" $maxFreq lần gần đây. Bạn có muốn bắt đầu thử thách kiểm soát thói quen này không?"
    };
  }

  /// Analyzes bill context (from OCR text or user notes) and returns split suggestions.
  Future<Map<String, dynamic>?> analyzeBillForSplit({
    required double totalAmount,
    required String description,
    List<String>? existingPeople,
    Map<String, double>? preFilledAmounts,
  }) async {
    debugPrint('[AI Split] Starting... total=$totalAmount, desc="${description.length > 50 ? description.substring(0, 50) : description}", people=$existingPeople, preFilled=$preFilledAmounts');
    
    // If we already have people selected, try local split first for instant response (unless AI is specifically requested)
    if (existingPeople != null && existingPeople.isNotEmpty && description.trim().isEmpty && (preFilledAmounts == null || preFilledAmounts.isEmpty)) {
      debugPrint('[AI Split] No description, using local equal split');
      return _localEqualSplit(totalAmount, existingPeople);
    }

    try {
      final apiKey = _getApiKey();
      
      String peopleContext = existingPeople != null && existingPeople.isNotEmpty
          ? "Danh sách người: ${existingPeople.join(', ')}."
          : "Tìm tên người trong văn bản hóa đơn.";

      if (preFilledAmounts != null && preFilledAmounts.isNotEmpty) {
        final preFilledJson = jsonEncode(preFilledAmounts);
        peopleContext += "\n[DỮ LIỆU CỐ ĐỊNH]: $preFilledJson.\n"
            "YÊU CẦU BẮT BUỘC:\n"
            "1. Giữ nguyên số tiền cho những người có tên trong danh sách CỐ ĐỊNH trên. TUYỆT ĐỐI không được thay đổi dù chỉ 1 đồng.\n"
            "2. Khấu trừ tổng tiền của những người này ra khỏi tổng hóa đơn ($totalAmount).\n"
            "3. Phần tiền còn lại mới được chia cho những người khác dựa trên phân tích hóa đơn.";
      }

      final model = GenerativeModel(
        model: 'gemini-2.0-flash', // Using a more powerful model for complex logic
        apiKey: apiKey,
        systemInstruction: Content.system(
          "Bạn là chuyên gia phân tích hóa đơn và chia nợ.\n"
          "NHIỆM VỤ: Chia tiền hóa đơn cho các cá nhân một cách chính xác.\n"
          "$peopleContext\n"
          "QUY TẮC CỐT LÕI:\n"
          "1. TỔNG CỘNG tất cả các phần chia (bao gồm cả phần cố định và phần bạn tự tính) PHẢI CHÍNH XÁC BẰNG $totalAmount.\n"
          "2. KHÔNG CHIA ĐỀU (Equal Split) một cách máy móc. Nếu không có bằng chứng ai nợ món gì, hãy ưu tiên để họ là 0 hoặc gán cho người có khả năng nhất thay vì chia trung bình.\n"
          "3. Nếu người dùng đã khóa số tiền cho ai đó, bạn phải đưa họ vào kết quả với đúng số tiền đó.\n"
          "4. Trả về kết quả dưới dạng JSON với cấu trúc sau:\n"
          "{\"people\": [\"tên1\", \"tên2\"], \"splits\": {\"tên1\": số, \"tên2\": số}, \"reasoning\": \"lý do ngắn gọn\"}"
        ),
      );

      final prompt = "Tổng hóa đơn: $totalAmount\nNội dung/Hóa đơn: $description";
      debugPrint('[AI Split] Calling API...');
      
      final response = await model.generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 15));
      
      final rawText = response.text?.trim() ?? '';
      debugPrint('[AI Split] Raw response: $rawText');
      
      var jsonString = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(jsonString);
      if (jsonMatch != null) {
        jsonString = jsonMatch.group(0)!;
      }
      
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[AI Split] ERROR: $e');
      return null;
    }
  }

  /// Instant local equal split — no AI needed
  Map<String, dynamic> _localEqualSplit(double total, List<String> people) {
    final perPerson = (total / people.length).roundToDouble();
    final splits = <String, dynamic>{};
    for (var p in people) {
      splits[p] = perPerson;
    }
    // Adjust last person to absorb rounding error
    final remainder = total - (perPerson * people.length);
    if (remainder.abs() > 0.5) {
      splits[people.last] = perPerson + remainder;
    }
    debugPrint('[AI Split] Local fallback: $splits');
    return {
      "people": people,
      "splits": splits,
      "reasoning": "Chia đều (AI không khả dụng)",
    };
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
