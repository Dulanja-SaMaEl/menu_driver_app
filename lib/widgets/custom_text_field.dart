import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final VoidCallback? onClear;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;
  final bool autocorrect;
  final bool enableSuggestions;
  final Iterable<String>? autofillHints;
  final bool readOnly;
  final int maxLines;
  final String? Function(String?)? validator;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.onClear,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.onFieldSubmitted,
    this.focusNode,
    this.autocorrect = false,
    this.enableSuggestions = false,
    this.autofillHints,
    this.readOnly = false,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          autocorrect: autocorrect,
          enableSuggestions: enableSuggestions,
          autofillHints: autofillHints,
          readOnly: readOnly,
          maxLines: maxLines,
          validator: validator,
          style: GoogleFonts.plusJakartaSans(
            color: theme.colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                prefixIcon,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            suffixIcon: _buildSuffixIcon(theme),
            suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF1E2330)
                : const Color(0xFFF8FAFC),
          ),
        ),
      ],
    );
  }

  Widget? _buildSuffixIcon(ThemeData theme) {
    if (suffixIcon != null) {
      return IconButton(
        onPressed: onSuffixTap,
        icon: Icon(
          suffixIcon,
          size: 20,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        splashRadius: 20,
      );
    }
    if (onClear != null && controller.text.isNotEmpty) {
      return IconButton(
        onPressed: () {
          controller.clear();
          onClear?.call();
        },
        icon: Icon(
          Icons.clear_rounded,
          size: 18,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        splashRadius: 20,
      );
    }
    return null;
  }
}
