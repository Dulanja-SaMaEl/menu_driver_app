import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  final double height;
  final bool isOutlined;

  const CustomButton({
    super.key,
    required this.label,
    this.isLoading = false,
    this.onPressed,
    this.color,
    this.textColor,
    this.icon,
    this.height = 52,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = onPressed != null && !isLoading;

    if (isOutlined) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: OutlinedButton(
          onPressed: isEnabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: isEnabled ? effectiveColor : Theme.of(context).dividerColor,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _buildContent(isEnabled ? effectiveColor : Theme.of(context).disabledColor),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: effectiveColor.withValues(alpha: isDark ? 0.35 : 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveColor,
          disabledBackgroundColor: effectiveColor.withValues(alpha: 0.5),
          foregroundColor: textColor ?? const Color(0xFF0F172A),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: _buildContent(textColor ?? const Color(0xFF0F172A)),
      ),
    );
  }

  Widget _buildContent(Color textClr) {
    if (isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          color: textClr,
          strokeWidth: 2.5,
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: textClr),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: textClr,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        color: textClr,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }
}
