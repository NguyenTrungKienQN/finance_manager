import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_persona.dart';
import '../models/settings_model.dart';
import '../models/transaction_model.dart';
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

  // Mesh gradient animation
  late AnimationController _meshController;

  // Pulse "thinking" animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final _userAuthor = const types.User(id: 'user', firstName: 'Bạn');
  types.User get _aiAuthor => types.User(
        id: 'ai',
        firstName: _geminiService.currentPersona.displayName,
        imageUrl: _geminiService.currentPersona.imagePath,
      );

  @override
  void initState() {
    super.initState();

    // Slow, subtle mesh gradient rotation
    _meshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Soft pulse for "thinking"
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _geminiService.switchPersona(ChatPersona.expert);
    _geminiService.refresh();
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

  @override
  void dispose() {
    _meshController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ============================================================
  // PERSONA COLOR MAPPING
  // ============================================================
  List<Color> _personaColors() {
    switch (_geminiService.currentPersona) {
      case ChatPersona.expert:
        return [
          const Color(0xFF667EEA).withValues(alpha: 0.08),
          const Color(0xFF764BA2).withValues(alpha: 0.06),
          const Color(0xFF6B8DD6).withValues(alpha: 0.05),
        ];
      case ChatPersona.strictMom:
        return [
          const Color(0xFFFF6B6B).withValues(alpha: 0.07),
          const Color(0xFFEE5A24).withValues(alpha: 0.05),
          const Color(0xFFFFBE76).withValues(alpha: 0.06),
        ];
      case ChatPersona.sassyFriend:
        return [
          const Color(0xFFE056A0).withValues(alpha: 0.08),
          const Color(0xFFF8CDDA).withValues(alpha: 0.06),
          const Color(0xFFD980FA).withValues(alpha: 0.05),
        ];
    }
  }

  // ============================================================
  // CONTEXT-AWARE SMART SUGGESTIONS
  // ============================================================
  List<_SmartChip> _buildSmartChips() {
    final chips = <_SmartChip>[];

    // Always show wallet analysis
    chips.add(_SmartChip(
      icon: Icons.auto_awesome,
      label: 'Phân tích ví',
      prompt:
          'Phân tích tình hình tài chính của tôi tháng này. Cho tôi biết tôi đang chi tiêu thế nào, những danh mục nào tốn nhiều nhất, và lời khuyên cụ thể để cải thiện.',
    ));

    // Context-aware chips based on real data
    try {
      final txBox = Hive.box<Transaction>('transactions');
      final settingsBox = Hive.box<AppSettings>('settings');
      final settings = settingsBox.get('appSettings') ?? AppSettings();
      final now = DateTime.now();
      final fmt = NumberFormat('#,###', 'vi_VN');

      final todayTxs = txBox.values.where((tx) =>
          tx.date.year == now.year &&
          tx.date.month == now.month &&
          tx.date.day == now.day);
      final todaySpent =
          todayTxs.fold<double>(0, (sum, tx) => sum + tx.amount);
      final dailyLimit = settings.computedDailyLimit;
      final remaining = dailyLimit - todaySpent;

      if (remaining > 0) {
        chips.add(_SmartChip(
          icon: Icons.restaurant,
          label: 'Còn ${fmt.format(remaining.toInt())}đ hôm nay',
          prompt:
              'Tôi còn ${fmt.format(remaining.toInt())}đ cho ngày hôm nay. Tôi nên chi tiêu gì hợp lý? Gợi ý cho tôi bữa tối phù hợp túi tiền.',
        ));
      } else {
        chips.add(_SmartChip(
          icon: Icons.healing_rounded,
          label: 'Cứu ví tháng này?',
          prompt:
              'Tôi đã vượt quá hạn mức chi tiêu hôm nay ${fmt.format((-remaining).toInt())}đ. Phân tích xem tôi nên xử lý thế nào cho phần còn lại của tháng.',
        ));
      }

      // Days remaining forecast
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final daysRemaining = daysInMonth - now.day;
      if (daysRemaining > 0 && daysRemaining <= 10) {
        chips.add(_SmartChip(
          icon: Icons.calendar_today,
          label: 'Còn $daysRemaining ngày',
          prompt:
              'Còn $daysRemaining ngày nữa là hết tháng. Dự báo cho tôi xem mình có đủ tiền sống thoải mái không, hay cần thắt chặt chi tiêu.',
        ));
      }

      // Category-based suggestion
      final monthTxs = txBox.values.where((tx) =>
          tx.date.year == now.year && tx.date.month == now.month);
      final catMap = <String, double>{};
      for (final tx in monthTxs) {
        catMap[tx.category] = (catMap[tx.category] ?? 0) + tx.amount;
      }
      if (catMap.isNotEmpty) {
        final topCat =
            catMap.entries.reduce((a, b) => a.value > b.value ? a : b);
        chips.add(_SmartChip(
          icon: Icons.pie_chart_outline,
          label: 'Giảm chi ${topCat.key}?',
          prompt:
              'Danh mục "${topCat.key}" đang chiếm nhiều nhất: ${fmt.format(topCat.value.toInt())}đ tháng này. Phân tích chi tiết cho tôi và gợi ý cách giảm bớt.',
        ));
      }
    } catch (_) {
      // Fallback if Hive not accessible
      chips.add(_SmartChip(
        icon: Icons.tips_and_updates_outlined,
        label: 'Mẹo tiết kiệm',
        prompt: 'Cho tôi 3 mẹo tiết kiệm tiền thực tế nhất cho người Việt.',
      ));
    }

    return chips;
  }

  // ============================================================
  // PERSONA SWITCHER & MODEL PICKER
  // ============================================================
  void _onPersonaChanged(ChatPersona? persona) {
    if (persona == null || persona == _geminiService.currentPersona) return;
    _geminiService.switchPersona(persona);
    setState(() {
      _messages.clear();
    });
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

  // ============================================================
  // MESSAGE HANDLING
  // ============================================================
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
    _pulseController.repeat(reverse: true);

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
    _pulseController.stop();
    _pulseController.reset();
    setState(() {
      _isTyping = false;
      _messages.insert(0, aiMsg);
    });
  }

  void _sendSmartPrompt(String prompt) {
    _handleSendPressed(types.PartialText(text: prompt));
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remaining = _geminiService.remainingFreeUses;
    final hasMessages = _messages.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
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
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onPersonaChanged,
                ),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: _showModelPicker,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.softPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
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
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Transaction>('transactions').listenable(),
        builder: (context, Box<Transaction> txBox, _) {
          final smartChips = _buildSmartChips();

          return Stack(
            children: [
              // ── Animated Mesh Gradient Background ──
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _meshController,
                  builder: (context, _) {
                    final colors = _personaColors();
                    final t = _meshController.value * 2 * pi;
                    return CustomPaint(
                      painter: _MeshGradientPainter(
                        colors: colors,
                        time: t,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
              ),

              // ── Main Content: Empty State OR Chat ──
              if (!hasMessages)
                _buildEmptyState(smartChips, isDark)
              else
                Column(
                  children: [
                    // Chat messages
                    Expanded(
                      child: Chat(
                        messages: _messages,
                        onSendPressed: _handleSendPressed,
                        user: _userAuthor,
                        showUserAvatars: true,
                        showUserNames: true,
                        customBottomWidget: const SizedBox.shrink(),
                        avatarBuilder: (user) {
                          if (user.id == 'ai' && user.imageUrl != null) {
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  Image.asset(
                                    user.imageUrl!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: AppTheme.softPurple
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.face,
                                          size: 32, color: AppTheme.softPurple),
                                    ),
                                  ),
                                  // Soft pulse aura when thinking
                                  if (_isTyping)
                                    Positioned.fill(
                                      child: AnimatedBuilder(
                                        animation: _pulseAnimation,
                                        builder: (context, _) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppTheme.softPurple
                                                      .withValues(
                                                          alpha: 0.3 *
                                                              _pulseAnimation
                                                                  .value),
                                                  blurRadius: 12 *
                                                      _pulseAnimation.value,
                                                  spreadRadius: 2 *
                                                      _pulseAnimation.value,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        bubbleBuilder: (child,
                            {required message, required nextMessageInGroup}) {
                          final isUser = message.author.id == 'user';
                          if (isUser) {
                            // Solid user bubble
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.softPurple,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft: const Radius.circular(20),
                                  bottomRight: nextMessageInGroup
                                      ? const Radius.circular(20)
                                      : const Radius.circular(4),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.softPurple
                                        .withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: child,
                            );
                          } else {
                            // Glass AI bubble
                            return ClipRRect(
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomRight: const Radius.circular(20),
                                bottomLeft: nextMessageInGroup
                                    ? const Radius.circular(20)
                                    : const Radius.circular(4),
                              ),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.white.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(20),
                                      topRight: const Radius.circular(20),
                                      bottomRight: const Radius.circular(20),
                                      bottomLeft: nextMessageInGroup
                                          ? const Radius.circular(20)
                                          : const Radius.circular(4),
                                    ),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : Colors.white.withValues(alpha: 0.5),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: child,
                                ),
                              ),
                            );
                          }
                        },
                        typingIndicatorOptions: TypingIndicatorOptions(
                          typingUsers: _isTyping ? [_aiAuthor] : [],
                        ),
                        theme: isDark
                            ? DarkChatTheme(
                                backgroundColor: Colors.transparent,
                                inputBackgroundColor:
                                    Colors.white.withValues(alpha: 0.08),
                                inputTextColor: Colors.white,
                                inputBorderRadius: BorderRadius.circular(24),
                                messageBorderRadius: 20,
                                primaryColor: Colors.transparent,
                                secondaryColor: Colors.transparent,
                                sentMessageBodyTextStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                                receivedMessageBodyTextStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                                inputTextStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                                inputPadding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
                                inputMargin:
                                    const EdgeInsets.symmetric(horizontal: 16),
                              )
                            : DefaultChatTheme(
                                backgroundColor: Colors.transparent,
                                inputBackgroundColor: Colors.grey.shade100,
                                inputTextColor: AppTheme.textPrimary,
                                inputBorderRadius: BorderRadius.circular(24),
                                messageBorderRadius: 20,
                                primaryColor: Colors.transparent,
                                secondaryColor: Colors.transparent,
                                sentMessageBodyTextStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                                receivedMessageBodyTextStyle: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                                inputTextStyle: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                ),
                                inputPadding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
                                inputMargin:
                                    const EdgeInsets.symmetric(horizontal: 16),
                              ),
                        l10n: const ChatL10nEn(
                          inputPlaceholder: 'Nhập tin nhắn...',
                          emptyChatPlaceholder: '',
                        ),
                      ),
                    ),

                    // ── Smart Suggestion Chips (above input) ──
                    _buildSmartChipBar(smartChips, isDark),

                    // AI disclaimer
                    _buildAIDisclaimer(isDark),

                    // ── Actual Input Bar ──
                    Padding(
                      padding: const EdgeInsets.only(bottom: 80),
                      child: _buildInputBar(isDark),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // EMPTY STATE — Mascot + Quick Prompts
  // ============================================================
  Widget _buildEmptyState(List<_SmartChip> chips, bool isDark) {
    final persona = _geminiService.currentPersona;

    return Column(
      children: [
        const Spacer(flex: 2),
        // Mascot with soft pulse
        AnimatedBuilder(
          animation: _meshController,
          builder: (context, child) {
            final breathe =
                1.0 + 0.015 * sin(_meshController.value * 2 * pi);
            return Transform.scale(scale: breathe, child: child);
          },
          child: Image.asset(
            persona.imagePath,
            height: 140,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.smart_toy_outlined,
              size: 100,
              color: AppTheme.softPurple.withValues(alpha: 0.3),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Greeting text
        Text(
          persona.welcomeMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : AppTheme.textPrimary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hãy thử một gợi ý bên dưới 👇',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 28),

        // Context-aware prompt grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: chips.map((chip) {
              return _buildEmptyStateChip(chip, isDark);
            }).toList(),
          ),
        ),
        const Spacer(flex: 3),

        // AI disclaimer
        _buildAIDisclaimer(isDark),
        const SizedBox(height: 4),

        // Input bar at the bottom
        Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: _buildInputBar(isDark),
        ),
      ],
    );
  }

  Widget _buildEmptyStateChip(_SmartChip chip, bool isDark) {
    return GestureDetector(
      onTap: () => _sendSmartPrompt(chip.prompt),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : AppTheme.softPurple.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(chip.icon,
                size: 16,
                color: isDark ? Colors.white70 : AppTheme.softPurple),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                chip.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SMART CHIP BAR (above input when in chat)
  // ============================================================
  Widget _buildSmartChipBar(List<_SmartChip> chips, bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.only(bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          return GestureDetector(
            onTap: _isTyping ? null : () => _sendSmartPrompt(chip.prompt),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isTyping ? 0.4 : 1.0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppTheme.softPurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppTheme.softPurple.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chip.icon,
                        size: 14,
                        color:
                            isDark ? Colors.white60 : AppTheme.softPurple),
                    const SizedBox(width: 6),
                    Text(
                      chip.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? Colors.white60 : AppTheme.softPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // AI DISCLAIMER
  // ============================================================
  Widget _buildAIDisclaimer(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'AI có thể mắc sai sót. Hãy kiểm tra thông tin quan trọng.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: isDark
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  // ============================================================
  // INPUT BAR
  // ============================================================
  Widget _buildInputBar(bool isDark) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.darkBackground.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.85),
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      onSubmitted: (text) {
                        if (text.trim().isNotEmpty) {
                          _handleSendPressed(
                              types.PartialText(text: text.trim()));
                        }
                      },
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    // Send via controller if needed
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.softPurple,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.softPurple.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 20,
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
}

// ============================================================
// SMART CHIP DATA CLASS
// ============================================================
class _SmartChip {
  final IconData icon;
  final String label;
  final String prompt;

  const _SmartChip({
    required this.icon,
    required this.label,
    required this.prompt,
  });
}

// ============================================================
// MESH GRADIENT PAINTER — Subtle, slow, low-opacity persona atmosphere
// ============================================================
class _MeshGradientPainter extends CustomPainter {
  final List<Color> colors;
  final double time;
  final bool isDark;

  _MeshGradientPainter({
    required this.colors,
    required this.time,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the base background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
    );

    // Draw 3 blurred colored orbs moving slowly
    for (int i = 0; i < colors.length; i++) {
      final phase = time + (i * 2.1);
      final cx = size.width * (0.3 + 0.4 * sin(phase * 0.3 + i));
      final cy = size.height * (0.2 + 0.3 * cos(phase * 0.25 + i * 1.5));
      final radius = size.width * (0.4 + 0.15 * sin(phase * 0.2));

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [colors[i], colors[i].withValues(alpha: 0)],
        ).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeshGradientPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.isDark != isDark;
}
