import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPassFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _localError;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _fadeCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty && _emailCtrl.text.isEmpty) {
      _emailCtrl.text = args;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPassFocus.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    setState(() => _localError = null);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final result = await auth.resetPassword(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      passwordConfirmation: _confirmPassCtrl.text,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result['message'] ?? 'Password reset successfully! Please sign in.',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      Navigator.of(context).pop();
    } else {
      setState(() {
        _localError = result['message'] ?? 'Failed to reset password. Verify email.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.status == AuthStatus.loading;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
          ),
        ),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Icon
                      Center(
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.35),
                                blurRadius: 24,
                                spreadRadius: 2,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            color: Color(0xFF0F172A),
                            size: 38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Center(
                        child: Text(
                          'Reset Password',
                          style: GoogleFonts.plusJakartaSans(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Center(
                        child: Text(
                          'Enter your registered email and choose a new password',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Inputs Card
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Theme.of(context).dividerColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // In-Card Error Banner
                            if (_localError != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _localError!,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: AppTheme.error,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.error),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => setState(() => _localError = null),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Email
                            CustomTextField(
                              controller: _emailCtrl,
                              focusNode: _emailFocus,
                              label: 'Email Address',
                              hint: 'dulanja150abeysinghe@gmail.com',
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              prefixIcon: Icons.alternate_email_rounded,
                              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!val.contains('@')) return 'Enter a valid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // New Password
                            CustomTextField(
                              controller: _passwordCtrl,
                              focusNode: _passwordFocus,
                              label: 'New Password',
                              hint: '••••••••',
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              prefixIcon: Icons.lock_outline_rounded,
                              suffixIcon: _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_confirmPassFocus),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Password is required';
                                }
                                if (val.length < 8) return 'At least 8 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Confirm Password
                            CustomTextField(
                              controller: _confirmPassCtrl,
                              focusNode: _confirmPassFocus,
                              label: 'Confirm New Password',
                              hint: '••••••••',
                              obscureText: _obscureConfirm,
                              textInputAction: TextInputAction.done,
                              autocorrect: false,
                              enableSuggestions: false,
                              prefixIcon: Icons.lock_outline_rounded,
                              suffixIcon: _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              onSuffixTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              onFieldSubmitted: (_) => _resetPassword(),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Please confirm your new password';
                                }
                                if (val != _passwordCtrl.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 24),

                            // Reset Button
                            CustomButton(
                              label: 'Update & Reset Password',
                              icon: Icons.check_circle_outline_rounded,
                              isLoading: isLoading,
                              onPressed: isLoading ? null : _resetPassword,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Back to Login Link
                      Center(
                        child: TextButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            size: 16,
                            color: AppTheme.primaryDark,
                          ),
                          label: Text(
                            'Back to Sign In',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.primaryDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
