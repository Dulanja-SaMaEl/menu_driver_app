import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _vehicleNumberCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _vehicleNumberFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPassFocus = FocusNode();

  String _vehicleType = 'Motorcycle';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _localError;

  final List<String> _vehicleTypes = [
    'Motorcycle',
    'Bicycle',
    'Scooter',
    'Car',
    'Van',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
    _vehicleNumberCtrl.dispose();

    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _vehicleNumberFocus.dispose();
    _passwordFocus.dispose();
    _confirmPassFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _localError = null);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passwordCtrl.text,
      passwordConfirmation: _confirmPassCtrl.text,
      vehicleType: _vehicleType,
      vehicleNumber: _vehicleNumberCtrl.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Account created! Please log in.',
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      setState(() {
        _localError = auth.errorMessage ?? 'Registration failed. Please check details.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.status == AuthStatus.loading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Driver Registration',
                    style: GoogleFonts.plusJakartaSans(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Join The Menu delivery fleet and earn on your schedule',
                    style: GoogleFonts.plusJakartaSans(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Card container
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

                        _sectionTitle('Personal Details'),
                        const SizedBox(height: 14),

                        CustomTextField(
                          controller: _nameCtrl,
                          focusNode: _nameFocus,
                          label: 'Full Name',
                          hint: 'e.g. Saman Kumara',
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icons.person_outline_rounded,
                          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocus),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Full name is required' : null,
                        ),
                        const SizedBox(height: 14),

                        CustomTextField(
                          controller: _emailCtrl,
                          focusNode: _emailFocus,
                          label: 'Email Address',
                          hint: 'driver@themenu.com',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          prefixIcon: Icons.alternate_email_rounded,
                          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_phoneFocus),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Email is required';
                            if (!val.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        CustomTextField(
                          controller: _phoneCtrl,
                          focusNode: _phoneFocus,
                          label: 'Phone Number',
                          hint: '077 123 4567',
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icons.phone_outlined,
                          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_vehicleNumberFocus),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Phone number is required' : null,
                        ),

                        const SizedBox(height: 24),
                        _sectionTitle('Vehicle Details'),
                        const SizedBox(height: 14),

                        // Vehicle Type Dropdown
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vehicle Type',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _vehicleType,
                              dropdownColor: Theme.of(context).colorScheme.surface,
                              style: GoogleFonts.plusJakartaSans(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E2330) : const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Icon(
                                    Icons.two_wheeler_rounded,
                                    size: 20,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                              ),
                              items: _vehicleTypes
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                  .toList(),
                              onChanged: (val) => setState(() => _vehicleType = val ?? _vehicleType),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        CustomTextField(
                          controller: _vehicleNumberCtrl,
                          focusNode: _vehicleNumberFocus,
                          label: 'License Plate / Plate Number',
                          hint: 'BBG 6326',
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icons.badge_outlined,
                          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Plate number is required' : null,
                        ),

                        const SizedBox(height: 24),
                        _sectionTitle('Security'),
                        const SizedBox(height: 14),

                        CustomTextField(
                          controller: _passwordCtrl,
                          focusNode: _passwordFocus,
                          label: 'Password',
                          hint: '••••••••',
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          prefixIcon: Icons.lock_outline_rounded,
                          suffixIcon: _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_confirmPassFocus),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Password is required';
                            if (val.length < 8) return 'At least 8 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        CustomTextField(
                          controller: _confirmPassCtrl,
                          focusNode: _confirmPassFocus,
                          label: 'Confirm Password',
                          hint: '••••••••',
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          enableSuggestions: false,
                          prefixIcon: Icons.lock_outline_rounded,
                          suffixIcon: _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          onSuffixTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          onFieldSubmitted: (_) => _register(),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Please confirm your password';
                            if (val != _passwordCtrl.text) return 'Passwords do not match';
                            return null;
                          },
                        ),

                        const SizedBox(height: 28),

                        CustomButton(
                          label: 'Create Driver Account',
                          icon: Icons.person_add_alt_1_rounded,
                          isLoading: isLoading,
                          onPressed: isLoading ? null : _register,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already registered? ',
                          style: GoogleFonts.plusJakartaSans(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Text(
                            'Sign In',
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

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
