import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit_breaker_model.dart';
import '../services/gemini_chat_service.dart';
import '../services/notification_service.dart';
import '../utils/app_toast.dart';
import '../widgets/liquid_glass.dart'; 

class HabitHelper {
  static const Map<String, IconData> iconOptions = {
    'local_cafe': Icons.local_cafe_rounded,
    'smoke_free': Icons.smoke_free_rounded,
    'shopping_cart': Icons.shopping_cart_rounded,
    'sports_esports': Icons.sports_esports_rounded,
    'restaurant': Icons.restaurant_rounded,
    'local_bar': Icons.local_bar_rounded,
    'fastfood': Icons.fastfood_rounded,
    'smartphone': Icons.smartphone_rounded,
  };

  static IconData getIcon(String name) => iconOptions[name] ?? Icons.help_outline_rounded;

  static void showAddHabitSheet(BuildContext context, {String? initialName, String? initialIcon}) {
    final nameController = TextEditingController(text: initialName);
    String selectedIcon = initialIcon ?? 'local_cafe';
    bool isIndefinite = true;
    double durationDays = 7;
    String selectedPersona = 'expert';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final theme = Theme.of(ctx);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 90),
                  child: LiquidGlassContainer(
                    borderRadius: 28,
                    blurSigma: 30,
                    opacity: 0.08,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: theme.dividerColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Thêm thử thách mới',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                labelText: 'Tên thói quen cần bỏ',
                                hintText: 'Ví dụ: Trà sữa, Cà phê, ...',
                                filled: true,
                                fillColor: theme.canvasColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: Icon(
                                  getIcon(selectedIcon),
                                  color: theme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chọn biểu tượng',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: iconOptions.entries.map((entry) {
                                final isSelected = entry.key == selectedIcon;
                                return GestureDetector(
                                  onTap: () {
                                    setSheetState(() => selectedIcon = entry.key);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.primaryColor.withValues(
                                              alpha: 0.15,
                                            )
                                          : theme.canvasColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: isSelected
                                          ? Border.all(
                                              color: theme.primaryColor,
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    child: Icon(
                                      entry.value,
                                      color: isSelected
                                          ? theme.primaryColor
                                          : theme.iconTheme.color,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Text(
                                  'Mục tiêu thử thách',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  isIndefinite ? 'Vô hạn' : '${durationDays.round()} ngày',
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Switch(
                                  value: isIndefinite,
                                  activeTrackColor: theme.primaryColor.withValues(alpha: 0.5),
                                  activeThumbColor: theme.primaryColor,
                                  onChanged: (val) => setSheetState(() => isIndefinite = val),
                                ),
                              ],
                            ),
                            if (!isIndefinite)
                              Slider(
                                value: durationDays,
                                min: 1,
                                max: 90,
                                divisions: 89,
                                activeColor: theme.primaryColor,
                                onChanged: (val) => setSheetState(() => durationDays = val),
                              ),
                            const SizedBox(height: 16),
                            Text(
                              'Người bạn đồng hành AI',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'expert',
                                  label: Text('Chuyên gia', style: TextStyle(fontSize: 12)),
                                ),
                                ButtonSegment(
                                  value: 'best_friend',
                                  label: Text('Bạn thân', style: TextStyle(fontSize: 12)),
                                ),
                                ButtonSegment(
                                  value: 'strict_mother',
                                  label: Text('Mẹ khắt khe', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                              selected: {selectedPersona},
                              onSelectionChanged: (set) {
                                setSheetState(() => selectedPersona = set.first);
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (nameController.text.trim().isEmpty) return;
                                  final box = Hive.box<HabitBreaker>('habitBreakers');
                                  final duration = isIndefinite ? null : durationDays.round();
                                  final habitName = nameController.text.trim();
                                  
                                  final habit = HabitBreaker(
                                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                                    habitName: habitName,
                                    iconName: selectedIcon,
                                    targetDuration: duration,
                                    aiPersona: selectedPersona,
                                  );
                                  
                                  box.add(habit);
                                  Navigator.pop(ctx);
                                  
                                  if (duration != null) {
                                    if (context.mounted) {
                                      AppToast.show(context, "Đang nhờ AI lên lịch thử thách...");
                                    }
                                    final aiMessages = await GeminiChatService().generateHabitPersonaSchedule(
                                      habitName: habitName,
                                      duration: duration,
                                      persona: selectedPersona,
                                    );

                                    List<String> finalMessages = aiMessages ?? [];
                                    
                                    if (finalMessages.isEmpty) {
                                      final fallbacks = {
                                        'expert': [
                                          "Hãy kiên trì, mục tiêu tài chính của bạn đang ở rất gần.",
                                          "Mỗi ngày không $habitName là một bước tiến tới sự tự do tài chính.",
                                          "Kỷ luật là chìa khóa. Đừng để cám dỗ nhất thời làm lung lay kế hoạch."
                                        ],
                                        'best_friend': [
                                          "Ê, nhớ kèo bỏ $habitName chưa? Đừng để tui khinh nha!",
                                          "Cố lên bồ tèo, sắp thành công rùi nè. Ráng lênnn!",
                                          "Hết thử thách này tui bao đi chơi (nhớ là phải thắng đó)!"
                                        ],
                                        'strict_mother': [
                                          "Mẹ bảo rồi, bỏ cái thói $habitName đi không là đừng có trách!",
                                          "Tiền không phải vỏ hến, con lo mà giữ mình cho tốt vào.",
                                          "Chưa bỏ được à? Học tập gương người tốt việc tốt đi con!"
                                        ],
                                      };
                                      
                                      final personaFallbacks = fallbacks[selectedPersona] ?? fallbacks['expert']!;
                                      for (int i = 0; i < duration; i++) {
                                        finalMessages.add(personaFallbacks[i % personaFallbacks.length]);
                                      }
                                    }

                                    if (finalMessages.isNotEmpty) {
                                      await NotificationService().scheduleHabitChallengeEncouragements(habit, finalMessages);
                                      if (context.mounted) {
                                        AppToast.show(context, "Đã lên lịch thành công!");
                                      }
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Bắt đầu thử thách 🔥',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 28,
                  child: Image.asset(
                    'assets/mascots/mascotask.png',
                    height: 130,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static void showAiSuggestionDialog(BuildContext context, Map<String, dynamic> suggestion) {
    final String habitName = suggestion['habit_name'] ?? 'Mua sắm lặt vặt';
    final String reason = suggestion['reason'] ?? 'Dựa trên chi tiêu gần đây';
    
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Expanded(child: Text('Gợi ý từ AI', style: theme.textTheme.titleLarge)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gợi ý: Bỏ $habitName',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(reason, style: theme.textTheme.bodyMedium),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Để sau', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                showAddHabitSheet(context, initialName: habitName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Tạo thử thách'),
            ),
          ],
        );
      },
    );
  }
}
