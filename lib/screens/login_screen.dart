import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  String? _localError;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _localError = null);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() {
        _localError = auth.errorMessage ?? 'Invalid email or password';
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
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // Brand Icon & Badge
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [AppTheme.primary, AppTheme.primaryDark],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(alpha: 0.4),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.delivery_dining_rounded,
                                color: Color(0xFF0F172A),
                                size: 42,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'The Menu',
                              style: GoogleFonts.plusJakartaSans(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'DRIVER PORTAL',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.primaryDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sign In',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Enter your driver credentials to access your route',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // In-Card Error Banner (Replaces squashed bottom snackbar)
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
                              hint: 'courier@themenu.lk',
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [AutofillHints.email],
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

                            // Password
                            CustomTextField(
                              controller: _passwordCtrl,
                              focusNode: _passwordFocus,
                              label: 'Password',
                              hint: '••••••••',
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [AutofillHints.password],
                              prefixIcon: Icons.lock_outline_rounded,
                              suffixIcon: _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                              onFieldSubmitted: (_) => _login(),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Password is required';
                                }
                                if (val.length < 6) return 'At least 6 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),

                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(context).pushNamed(
                                    '/forgot-password',
                                    arguments: _emailCtrl.text.trim(),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot Password?',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.primaryDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Login Button
                            CustomButton(
                              label: 'Sign In to Drive',
                              icon: Icons.login_rounded,
                              isLoading: isLoading,
                              onPressed: isLoading ? null : _login,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Sign up prompt
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "New driver? ",
                              style: GoogleFonts.plusJakartaSans(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pushNamed('/signup'),
                              child: Text(
                                'Register as Driver',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.primaryDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
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
