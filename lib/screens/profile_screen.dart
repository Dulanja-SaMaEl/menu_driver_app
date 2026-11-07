import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _currentPassFocus = FocusNode();
  final _newPassFocus = FocusNode();
  final _confirmPassFocus = FocusNode();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    _currentPassFocus.dispose();
    _newPassFocus.dispose();
    _confirmPassFocus.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordReset() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final result = await auth.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
      newPasswordConfirmation: _confirmPasswordController.text,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Password updated successfully',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Failed to update password',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to sign out of your driver account?',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(88, 40),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = context.read<AuthProvider>();
              await auth.logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final driver = authProvider.driver;
    final allOrders = context.watch<OrderProvider>().allOrders;
    final deliveredOrders = allOrders.where((o) => o.status.toLowerCase() == 'delivered').length;

    final rawStatus = (driver?.status ?? (driver?.isActive == true ? 'available' : 'offline')).toLowerCase();
    final bool isOnline = rawStatus != 'offline';

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
          ),
          title: Text(
            'DRIVER PROFILE',
            style: GoogleFonts.plusJakartaSans(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              fontSize: 15,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              // Profile Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar with status ring
                    Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.primaryDark],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              driver?.name.isNotEmpty == true
                                  ? driver!.name.substring(0, 1).toUpperCase()
                                  : 'D',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF0F172A),
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      driver?.name ?? 'Driver Name',
                      style: GoogleFonts.plusJakartaSans(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      driver?.email ?? 'driver@themenu.com',
                      style: GoogleFonts.plusJakartaSans(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Vehicle Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.two_wheeler_rounded, size: 16, color: AppTheme.primaryDark),
                          const SizedBox(width: 6),
                          Text(
                            '${driver?.vehicleType ?? 'Vehicle'} • ${driver?.vehicleNumber ?? 'No Plate'}',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.primaryDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Driver Performance Metrics
              Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      label: 'Total Completed',
                      value: '$deliveredOrders Orders',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniMetric(
                      label: 'Driver Status',
                      value: rawStatus.toUpperCase(),
                      icon: Icons.shield_outlined,
                      color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Personal Details Section
              _sectionHeader('Account Details'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  children: [
                    _ProfileRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Full Name',
                      value: driver?.name ?? '-',
                    ),
                    Divider(color: Theme.of(context).dividerColor, height: 22),
                    _ProfileRow(
                      icon: Icons.email_outlined,
                      label: 'Email Address',
                      value: driver?.email ?? '-',
                    ),
                    Divider(color: Theme.of(context).dividerColor, height: 22),
                    _ProfileRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone Number',
                      value: driver?.phone ?? '-',
                    ),
                    Divider(color: Theme.of(context).dividerColor, height: 22),
                    _ProfileRow(
                      icon: Icons.two_wheeler_rounded,
                      label: 'Vehicle Model',
                      value: driver?.vehicleType ?? '-',
                    ),
                    Divider(color: Theme.of(context).dividerColor, height: 22),
                    _ProfileRow(
                      icon: Icons.badge_outlined,
                      label: 'License Plate',
                      value: driver?.vehicleNumber ?? '-',
                    ),
                    Divider(color: Theme.of(context).dividerColor, height: 22),
                    _ProfileRow(
                      icon: Icons.dns_rounded,
                      label: 'Server Endpoint',
                      value: ApiService.baseUrl.contains('render') ? 'Render Production (Online)' : ApiService.baseUrl,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Change Password Section
              _sectionHeader('Security & Password'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      CustomTextField(
                        controller: _currentPasswordController,
                        focusNode: _currentPassFocus,
                        label: 'Current Password',
                        hint: '••••••••',
                        obscureText: _obscureCurrent,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        prefixIcon: Icons.lock_outline_rounded,
                        suffixIcon: _obscureCurrent
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        onSuffixTap: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_newPassFocus),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Enter current password' : null,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        controller: _newPasswordController,
                        focusNode: _newPassFocus,
                        label: 'New Password',
                        hint: '••••••••',
                        obscureText: _obscureNew,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        prefixIcon: Icons.password_rounded,
                        suffixIcon: _obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        onSuffixTap: () => setState(() => _obscureNew = !_obscureNew),
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_confirmPassFocus),
                        validator: (value) =>
                            value == null || value.length < 8 ? 'Password must be at least 8 chars' : null,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        controller: _confirmPasswordController,
                        focusNode: _confirmPassFocus,
                        label: 'Confirm New Password',
                        hint: '••••••••',
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        prefixIcon: Icons.check_circle_outline,
                        suffixIcon: _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        onSuffixTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        onFieldSubmitted: (_) => _handlePasswordReset(),
                        validator: (value) =>
                            value != _newPasswordController.text ? 'Passwords do not match' : null,
                      ),
                      const SizedBox(height: 22),
                      CustomButton(
                        label: 'Update Password',
                        icon: Icons.lock_reset_rounded,
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _handlePasswordReset,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _showLogoutDialog,
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.error, size: 20),
                  label: Text(
                    'Sign Out of Driver Account',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.error, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryDark, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
