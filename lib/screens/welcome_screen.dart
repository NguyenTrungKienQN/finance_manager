import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/settings_model.dart';
import '../main.dart'; // To navigate to MyHomePage

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
    // Stage 0: Landing (Minimalist Geometric)
    // Stage 1: Name Setup
    // Stage 2: Completion Splash
    int _currentStage = 0;
  
    // Stage 1 State
    String? _selectedPronoun;
    final TextEditingController _nameController = TextEditingController();
    final List<String> _pronouns = ["Mẹ", "Bố", "Em", "Anh", "Chị", "Bé"];
    bool _isCustomName = false;
  
    void _nextStage() {
      setState(() {
        _currentStage = 1;
      });
    }
  
    void _completeSetup() {
      String finalName = _isCustomName
          ? _nameController.text.trim()
          : (_selectedPronoun ?? "Bạn");
  
      if (finalName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Vui lòng chọn cách xưng hô hoặc nhập tên"),
          ),
        );
        return;
      }
  
      // Prepare Settings, but defer Hive DB commit to prevent instantly triggering main.dart's listenable
      final settingsBox = Hive.box<AppSettings>('settings');
      AppSettings settings = settingsBox.get('appSettings') ?? AppSettings();
      settings.isFirstInstall = false;
      settings.userName = finalName;
  
      // Move to Completion Stage UI immediately
      setState(() {
        _currentStage = 2;
      });
  
      // Wait 1.5s then navigate with blur-like fade
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        
        // Commit settings NOW, right as we navigate away
        settingsBox.put('appSettings', settings);

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MyHomePage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final blurValue = (1.0 - animation.value) * 20.0;
              return BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 1000),
          ),
        );
      });
    }
  
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: _currentStage == 0
              ? _buildLandingStage()
              : _currentStage == 1
                  ? _buildNameSetupStage()
                  : _buildCompletionStage(),
        ),
      );
    }

  // ---------------------------------------------------------------------------
  // STAGE 0: Landing (Minimalist Geometric)
  // ---------------------------------------------------------------------------
  Widget _buildLandingStage() {
    return Stack(
      key: const ValueKey("landing_stage"),
      children: [
        // --- Abstract Geometric Background ---
        Positioned(
          top: -100,
          right: -100,
          child: _buildBlurShape(300, const Color(0xFFE0E5FF)), // Soft Blue
        ),
        Positioned(
          top: 100,
          left: -50,
          child: _buildBlurShape(250, const Color(0xFFF3E5F5)), // Soft Purple
        ),
        Positioned(
          top: 300,
          right: -20,
          child: _buildBlurShape(200, const Color(0xFFE8EAF6)), // Light Indigo
        ),

        // --- Content ---
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 1), 
                // Mascot Image
                Image.asset(
                  'assets/mascots/defaultpose.png',
                  height: 250,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 32),
                // Headline
                const Text(
                  "Chào mừng\nFinance Manager", // Updated Text
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Subtitle
                Text(
                  "Theo dõi thu chi dễ dàng và hiệu quả.\nĐạt mục tiêu tiết kiệm nhanh chóng.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),

                const Spacer(flex: 2),

                // Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _nextStage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF0F172A,
                      ), // Dark Slate/Navy
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Bắt đầu ngay",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlurShape(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.7),
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STAGE 1: Name Setup
  // ---------------------------------------------------------------------------
  Widget _buildNameSetupStage() {
    return Stack(
      key: const ValueKey("setup_stage"),
      children: [
        // --- Abstract Geometric Background (Consistent with Stage 0) ---
        Positioned(
          top: -100,
          right: -100,
          child: _buildBlurShape(300, const Color(0xFFE0E5FF)),
        ),
        Positioned(
          top: 100,
          left: -50,
          child: _buildBlurShape(250, const Color(0xFFF3E5F5)),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentStage = 0;
                    });
                  },
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.black,
                  ),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                const Spacer(),
                const Text(
                  "Thông tin cơ bản 📝",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black, // Enforce Black for white bg
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Để bắt đầu, hãy cho biết mình nên gọi bạn là gì nhé?",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800], // Enforce Dark Grey
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  "Chọn cách xưng hô",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ..._pronouns.map((pronoun) => _buildPronounChip(pronoun)),
                    _buildCustomNameOption(),
                  ],
                ),

                if (_isCustomName) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.black),
                    cursorColor: Colors.black,
                    decoration: InputDecoration(
                      hintText: "Nhập tên của bạn...",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: Colors.grey[100], // Light grey fill
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.black,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],

                const Spacer(),
                
                // Final Setup Mascot
                Center(
                  child: Image.asset(
                    'assets/mascots/mascotsetup.png',
                    height: 160,
                    fit: BoxFit.contain,
                  ),
                ),
                
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _completeSetup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Hoàn tất setup",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPronounChip(String pronoun) {
    bool isSelected = !_isCustomName && _selectedPronoun == pronoun;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isCustomName = false;
          _selectedPronoun = pronoun;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0F172A) // Dark select
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          pronoun,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomNameOption() {
    bool isSelected = _isCustomName;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isCustomName = true;
          _selectedPronoun = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit,
              size: 18,
              color: isSelected ? Colors.white : Colors.black,
            ),
            const SizedBox(width: 8),
            Text(
              "Khác",
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionStage() {
    return Stack(
      key: const ValueKey("completion_stage"),
      children: [
        // Background consistency
        Positioned(
          bottom: -100,
          left: -100,
          child: _buildBlurShape(300, const Color(0xFFE0E5FF)),
        ),
        Positioned(
          top: 50,
          right: -50,
          child: _buildBlurShape(250, const Color(0xFFF3E5F5)),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Thiết lập hoàn tất!",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),
              Image.asset(
                'assets/mascots/mascotcomplete.png',
                height: 280,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
