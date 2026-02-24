import 'dart:ui';
import 'package:flutter/material.dart';

/// A reusable Liquid Glass container inspired by Apple's Liquid Glass design.
/// Wraps content in a frosted, translucent surface with optional glowing border.
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final double opacity;
  final Color? borderGlow;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.blurSigma = 25,
    this.opacity = 0.12,
    this.borderGlow,
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Adaptive glass colors
    final glassBase = isDark
        ? Colors.white.withValues(alpha: opacity)
        : Colors.white.withValues(alpha: opacity + 0.55);

    final glassBorder = borderGlow ??
        (isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.6));

    final refractionGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Colors.white.withValues(alpha: 0.08),
              Colors.purple.withValues(alpha: 0.04),
              Colors.teal.withValues(alpha: 0.06),
              Colors.white.withValues(alpha: 0.03),
            ]
          : [
              Colors.white.withValues(alpha: 0.5),
              Colors.purple.withValues(alpha: 0.03),
              Colors.teal.withValues(alpha: 0.04),
              Colors.white.withValues(alpha: 0.3),
            ],
    );

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: glassBase,
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: refractionGradient,
              border: Border.all(color: glassBorder, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                // Inner glow effect
                BoxShadow(
                  color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.2),
                  blurRadius: 1,
                  spreadRadius: -1,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A frosted glass circular back button.
class GlassBackButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final double size;

  const GlassBackButton({super.key, this.onPressed, this.size = 40});

  @override
  State<GlassBackButton> createState() => _GlassBackButtonState();
}

class _GlassBackButtonState extends State<GlassBackButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: LiquidGlassContainer(
          borderRadius: widget.size / 2,
          blurSigma: 15,
          opacity: 0.1,
          width: widget.size,
          height: widget.size,
          child: Center(
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Theme.of(context).iconTheme.color,
            ),
          ),
        ),
      ),
    );
  }
}
