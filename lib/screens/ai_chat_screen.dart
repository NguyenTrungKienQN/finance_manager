import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_persona.dart';
import '../services/gemini_chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with TickerProviderStateMixin {
  final GeminiChatService _geminiService = GeminiChatService();
  final List<types.Message> _messages = [];
  bool _isTyping = false;
  List<String> _availableModels = [];
  bool _loadingModels = false;

  final _userAuthor = const types.User(id: 'user', firstName: 'Bạn');
  types.User get _aiAuthor => types.User(
        id: 'ai',
        firstName: _geminiService.currentPersona.displayName,
      );

  @override
  void initState() {
    super.initState();
    _geminiService.switchPersona(ChatPersona.expert);
    _addWelcomeMessage();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _loadingModels = true);
    final models = await _geminiService.fetchAvailableModels();
    if (mounted) {
      setState(() {
        _availableModels = models;
        _loadingModels = false;
      });
    }
  }

  void _addWelcomeMessage() {
    final welcome = types.TextMessage(
      author: _aiAuthor,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: _geminiService.currentPersona.welcomeMessage,
    );
    setState(() => _messages.insert(0, welcome));
  }

  void _onPersonaChanged(ChatPersona? persona) {
    if (persona == null || persona == _geminiService.currentPersona) return;
    _geminiService.switchPersona(persona);
    setState(() {
      _messages.clear();
    });
    _addWelcomeMessage();
  }

  void _showModelPicker() {
    final models = _availableModels.isNotEmpty
        ? _availableModels
        : ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.0-flash'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return LiquidGlassContainer(
          borderRadius: 28,
          blurSigma: 30,
          opacity: 0.08,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.memory_rounded, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Chọn Model AI',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    if (_loadingModels)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _loadModels().then((_) => _showModelPicker());
                      },
                      tooltip: 'Tải lại danh sách',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: models.length,
                  itemBuilder: (ctx, i) {
                    final m = models[i];
                    final isSelected = m == _geminiService.currentModel;
                    // Determine badge
                    String badge = '';
                    if (m.contains('flash')) badge = '⚡';
                    if (m.contains('pro')) badge = '💎';

                    return ListTile(
                      leading:
                          Text(badge, style: const TextStyle(fontSize: 18)),
                      title: Text(
                        m,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? AppTheme.softPurple
                              : Theme.of(ctx).textTheme.bodyLarge?.color,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded,
                              color: Colors.green, size: 20)
                          : null,
                      onTap: () {
                        _geminiService.switchModel(m);
                        setState(() {
                          _messages.clear();
                        });
                        _addWelcomeMessage();
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSendPressed(types.PartialText message) async {
    final userMsg = types.TextMessage(
      author: _userAuthor,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text,
    );
    setState(() {
      _messages.insert(0, userMsg);
      _isTyping = true;
    });

    try {
      final reply = await _geminiService.sendMessage(message.text);
      _addAIReply(reply);
    } on RateLimitException {
      _addAIReply(
        '⚠️ Bạn đã hết 5 lượt dùng thử miễn phí!\n\n'
        'Để tiếp tục trò chuyện, hãy vào **Cài đặt** → **AI Assistant** '
        'và nhập API Key Gemini của bạn (miễn phí tại aistudio.google.com).',
      );
    } catch (e) {
      _addAIReply('❌ $e');
    }
  }

  void _addAIReply(String text) {
    final aiMsg = types.TextMessage(
      author: _aiAuthor,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: text,
    );
    setState(() {
      _isTyping = false;
      _messages.insert(0, aiMsg);
    });
  }

  Future<void> _analyzeWallet() async {
    final userMsg = types.TextMessage(
      author: _userAuthor,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: '🔍 Phân tích ví tiền của tôi',
    );
    setState(() {
      _messages.insert(0, userMsg);
      _isTyping = true;
    });

    try {
      final reply = await _geminiService.analyzeWallet();
      _addAIReply(reply);
    } on RateLimitException {
      _addAIReply(
        '⚠️ Bạn đã hết 5 lượt dùng thử miễn phí!\n\n'
        'Để tiếp tục, hãy vào **Cài đặt** và nhập API Key Gemini của bạn.',
      );
    } catch (e) {
      _addAIReply('❌ $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remaining = _geminiService.remainingFreeUses;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Trợ lý AI',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.softPurple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ChatPersona>(
                  value: _geminiService.currentPersona,
                  isDense: true,
                  icon: Icon(
                    Icons.expand_more,
                    size: 18,
                    color: AppTheme.softPurple,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.softPurple,
                  ),
                  items: ChatPersona.values
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            p.displayName,
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onPersonaChanged,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Model selector icon
            InkWell(
              onTap: _showModelPicker,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.softPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.memory_rounded,
                  size: 18,
                  color: AppTheme.softPurple,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (remaining >= 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: remaining > 2
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$remaining lượt',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: remaining > 2 ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 105),
            child: Chat(
              messages: _messages,
              onSendPressed: _handleSendPressed,
              user: _userAuthor,
              showUserAvatars: true,
              showUserNames: true,
              typingIndicatorOptions: TypingIndicatorOptions(
                typingUsers: _isTyping ? [_aiAuthor] : [],
              ),
              theme: isDark
                  ? DarkChatTheme(
                      backgroundColor: AppTheme.darkBackground,
                      inputBackgroundColor:
                          Colors.white.withValues(alpha: 0.08),
                      inputTextColor: Colors.white,
                      inputBorderRadius: BorderRadius.circular(24),
                      messageBorderRadius: 16,
                      primaryColor: AppTheme.softPurple,
                      secondaryColor: Colors.white.withValues(alpha: 0.08),
                      sentMessageBodyTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      receivedMessageBodyTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      inputTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      inputPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      inputMargin: const EdgeInsets.symmetric(horizontal: 16),
                    )
                  : DefaultChatTheme(
                      backgroundColor: AppTheme.lightBackground,
                      inputBackgroundColor: Colors.grey.shade100,
                      inputTextColor: AppTheme.textPrimary,
                      inputBorderRadius: BorderRadius.circular(24),
                      messageBorderRadius: 16,
                      primaryColor: AppTheme.softPurple,
                      secondaryColor: Colors.grey.shade100,
                      sentMessageBodyTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      receivedMessageBodyTextStyle: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                      ),
                      inputTextStyle: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                      ),
                      inputPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      inputMargin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
              l10n: const ChatL10nEn(
                inputPlaceholder: 'Nhập tin nhắn...',
                emptyChatPlaceholder: '',
              ),
            ),
          ),
          // Floating "Analyze Wallet" button
          Positioned(
            right: 16,
            bottom: 180,
            child: AnimatedScale(
              scale: _isTyping ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: FloatingActionButton.extended(
                heroTag: 'fab_ai_chat',
                onPressed: _isTyping ? null : _analyzeWallet,
                backgroundColor: AppTheme.softPurple,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.auto_awesome, size: 20),
                label: const Text(
                  'Phân tích ví',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
