import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  void _showServerConfigDialog(BuildContext context) {
    final textCtrl = TextEditingController(text: ApiService.baseUrl);
    bool isTesting = false;
    bool? testResult;
    String? statusMessage;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.dns_rounded, color: Color(0xFF2563EB), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Server Configuration',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected the-menu-admin endpoint:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: textCtrl,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'https://menusrilanka.com/api/driver-app-api',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Quick Presets:',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          label: const Text('Live Production', style: TextStyle(fontSize: 10)),
                          onPressed: () {
                            setDialogState(() {
                              textCtrl.text = ApiService.defaultBaseUrl;
                              testResult = null;
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text('Localhost (Emulator)', style: TextStyle(fontSize: 10)),
                          onPressed: () {
                            setDialogState(() {
                              textCtrl.text = 'http://10.0.2.2:8000/api';
                              testResult = null;
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text('Localhost (iOS/Web)', style: TextStyle(fontSize: 10)),
                          onPressed: () {
                            setDialogState(() {
                              textCtrl.text = 'http://127.0.0.1:8000/api';
                              testResult = null;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (statusMessage != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (testResult == true ? Colors.green : Colors.red)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              testResult == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                              size: 16,
                              color: testResult == true ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                statusMessage!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: testResult == true ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isTesting
                      ? null
                      : () async {
                          setDialogState(() {
                            isTesting = true;
                            statusMessage = 'Testing connectivity...';
                          });
                          final ok = await ApiService.testServerConnection(textCtrl.text);
                          setDialogState(() {
                            isTesting = false;
                            testResult = ok;
                            statusMessage = ok
                                ? 'Server is reachable!'
                                : 'Could not reach server endpoint';
                          });
                        },
                  child: isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Test Ping'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final newUrl = textCtrl.text.trim();
                    if (newUrl.isNotEmpty) {
                      await ApiService.setBaseUrl(newUrl);
                      if (context.mounted) {
                        final auth = context.read<AuthProvider>();
                        final order = context.read<OrderProvider>();
                        if (auth.driver?.token != null) {
                          order.fetchAllOrders(auth.driver!.token!);
                        }
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Connected to: $newUrl'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save & Connect'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final driver = authProvider.driver;
    final rawStatus = (driver?.status ?? (driver?.isActive == true ? 'available' : 'offline')).toLowerCase();

    Color statusDotColor;
    if (rawStatus == 'on_delivery') {
      statusDotColor = const Color(0xFF2563EB);
    } else if (rawStatus == 'available' || driver?.isActive == true) {
      statusDotColor = const Color(0xFF10B981);
    } else if (rawStatus == 'busy') {
      statusDotColor = const Color(0xFFF59E0B);
    } else {
      statusDotColor = Colors.grey;
    }

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // Drawer Header
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0F172A),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
              ),
              child: Center(
                child: Text(
                  driver?.name.isNotEmpty == true ? driver!.name.substring(0, 1).toUpperCase() : 'D',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            accountName: Row(
              children: [
                Expanded(
                  child: Text(
                    driver?.name ?? 'Driver Name',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusDotColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rawStatus.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF0F172A),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            accountEmail: Text(
              driver?.email ?? 'driver@freshbox.com',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Menu Items
          _buildMenuItem(
            context,
            icon: Icons.home_rounded,
            title: 'Dashboard',
            onTap: () => Navigator.pop(context),
          ),
          _buildMenuItem(
            context,
            icon: Icons.receipt_long_rounded,
            title: 'Order History',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/orders');
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.person_rounded,
            title: 'Driver Profile',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/profile');
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.dns_rounded,
            title: 'Server Settings',
            onTap: () {
              Navigator.pop(context);
              _showServerConfigDialog(context);
            },
          ),

          const Divider(indent: 20, endIndent: 20, height: 28),

          _buildMenuItem(
            context,
            icon: Icons.logout_rounded,
            title: 'Sign Out',
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text(
                    'Sign Out',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                  ),
                  content: Text(
                    'Are you sure you want to log out of your driver account?',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
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
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
              }
            },
            color: AppTheme.error,
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'The Menu Driver v1.2.0',
              style: GoogleFonts.plusJakartaSans(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: effectiveColor, size: 22),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          color: effectiveColor,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
    );
  }
}
