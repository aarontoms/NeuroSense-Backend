import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppTheme {
  // Colors
  static const Color background = Color(0xFFFDFBF7);
  static const Color accent = Color(0xFFFF6B6B);
  static const Color ink = Color(0xFF2B2D42);
  static const Color offWhite = Color(0xFFF8F9FA); // Slight variation for cards

  // Typography
  static TextStyle headlineStyle({double fontSize = 32, Color? color}) {
    return GoogleFonts.bricolageGrotesque(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.5,
      color: color ?? ink,
    );
  }

  static TextStyle buttonTextStyle({double fontSize = 16, Color? color}) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color ?? ink,
    );
  }

  static TextStyle bodyStyle({double fontSize = 16, Color? color}) {
    return GoogleFonts.outfit(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: (color ?? ink).withOpacity(0.8),
    );
  }

  // Shadows
  static BoxShadow hardShadow({Color color = Colors.black, Offset offset = const Offset(2, 2)}) {
    return BoxShadow(
      color: color,
      offset: offset,
      blurRadius: 0,
      spreadRadius: 0,
    );
  }

  // Borders
  static Border neoBorder() {
    return Border.all(
      color: ink,
      width: 2,
    );
  }
}

// Custom Neo-Brutalist Box (Card/Container replacement)
class NeoBox extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  const NeoBox({
    super.key,
    required this.child,
    this.color,
    this.padding,
    this.margin,
    this.borderRadius = 24.0,
    this.border,
    this.boxShadow,
    this.width,
    this.height,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: alignment,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? AppTheme.neoBorder(),
        boxShadow: boxShadow ?? [AppTheme.hardShadow()],
      ),
      padding: padding ?? const EdgeInsets.all(24),
      child: child,
    );
  }
}

// Custom Neo-Brutalist Button (ElevatedButton replacement)
class NeoButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? color;
  final double borderRadius;
  final bool animate;

  const NeoButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color,
    this.borderRadius = 16.0,
    this.animate = true,
  });

  @override
  State<NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<NeoButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null;
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            color: isDisabled ? Colors.grey[300] : (widget.color ?? AppTheme.accent),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: AppTheme.neoBorder(),
            boxShadow: _isPressed || isDisabled
                ? [] 
                : [AppTheme.hardShadow(offset: const Offset(4, 4))],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}

// Custom Neo-Brutalist Input (TextFormField replacement)
class NeoInput extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int? maxLines;

  const NeoInput({
    super.key,
    this.controller,
    required this.label,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTheme.buttonTextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: AppTheme.neoBorder(),
            boxShadow: [AppTheme.hardShadow(offset: const Offset(2, 2))],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: AppTheme.bodyStyle(color: Colors.black),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}

// Animation Extension globally
extension NeoAnimation on Widget {
  Widget neoEntrance({int delay = 0, Duration duration = const Duration(milliseconds: 400)}) {
    return animate(delay: delay.ms)
        .fadeIn(duration: duration)
        .slideY(begin: 0.2, curve: Curves.easeOutQuad);
  }
}
