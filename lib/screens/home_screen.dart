import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/side_menu.dart';
import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../services/location_service.dart';
import '../services/map_service.dart';
import '../services/notification_service.dart';
import '../services/offline_queue_service.dart';
import '../widgets/order_checklist_sheet.dart';
import '../widgets/proof_of_delivery_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _pollingTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  DateTime? _lastSyncedAt;
  bool _isManualRefreshing = false;

  @override
  void initState() {
    super.initState();
    NotificationService.init(
      onMarkDelivered: (orderId) {
        if (mounted) {
          _fetchData();
        }
      },
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
      _startLiveBackgroundSync();
      _initLocation();
    });
  }

  Future<void> _initLocation() async {
    if (!mounted) return;
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    await orderProvider.refreshLocation();

    LocationService().startLocationTracking(
      onPositionChanged: (position) {
        if (mounted) {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          final driver = auth.driver;
          final isOnline = (driver?.status ?? '').toLowerCase() != 'offline';
          orderProvider.updateCurrentPosition(
            position,
            token: driver?.token,
            isOnline: isOnline,
          );
        }
      },
    );
  }

  void _startLiveBackgroundSync() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _quietPoll();
    });
  }

  Future<void> _quietPoll() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final driver = auth.driver;
    if (driver?.token != null) {
      final isOnline = (driver?.status ?? '').toLowerCase() != 'offline';
      if (!isOnline) return;

      await auth.refreshProfile();
      if (mounted) {
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        await orderProvider.fetchLatestOrders(driver!.token!);
        await orderProvider.fetchAllOrders(driver.token!);
        await orderProvider.refreshLocation();
        await orderProvider.syncLocationTelemetry(driver.token!, isOnline: true);
        await orderProvider.syncOfflineQueue(driver.token!);
        orderProvider.adjustLocationPowerMode(isOnline);
        NotificationService.syncActiveOrdersNotification(orderProvider.allOrders);
        setState(() {
          _lastSyncedAt = DateTime.now();
        });
      }
    }
  }

  Future<void> _fetchData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final driver = auth.driver;
    if (driver?.token != null) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final isOnline = (driver?.status ?? '').toLowerCase() != 'offline';
      await Future.wait([
        auth.refreshProfile(),
        orderProvider.fetchLatestOrders(driver!.token!),
        orderProvider.fetchAllOrders(driver.token!),
        orderProvider.refreshLocation(),
        if (isOnline) orderProvider.syncLocationTelemetry(driver.token!, isOnline: true),
        orderProvider.syncOfflineQueue(driver.token!),
      ]);
      orderProvider.adjustLocationPowerMode(isOnline);
      if (mounted) {
        NotificationService.syncActiveOrdersNotification(orderProvider.allOrders);
        setState(() {
          _lastSyncedAt = DateTime.now();
        });
      }
    }
  }

  Future<void> _handleManualRefresh() async {
    if (_isManualRefreshing) return;
    setState(() => _isManualRefreshing = true);
    await _fetchData();
    if (mounted) {
      setState(() => _isManualRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'Updated (${_formatTime(_lastSyncedAt ?? DateTime.now())})',
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final min = time.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  @override
  void dispose() {
    LocationService().stopLocationTracking();
    _pollingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _showStatusPicker(BuildContext context, String currentStatus) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set Your Status',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _StatusOptionTile(
                  title: 'Available (Online)',
                  subtitle: 'Ready to receive new orders dispatched from admin',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF10B981),
                  isSelected: currentStatus == 'available',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await auth.setStatus('available');
                    _fetchData();
                  },
                ),
                _StatusOptionTile(
                  title: 'Busy',
                  subtitle: 'Temporarily paused from receiving dispatches',
                  icon: Icons.pause_circle_filled_rounded,
                  color: const Color(0xFFF59E0B),
                  isSelected: currentStatus == 'busy',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await auth.setStatus('busy');
                    _fetchData();
                  },
                ),
                _StatusOptionTile(
                  title: 'Offline',
                  subtitle: 'Not taking any orders right now',
                  icon: Icons.offline_bolt_rounded,
                  color: Colors.grey,
                  isSelected: currentStatus == 'offline',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await auth.setStatus('offline');
                    _fetchData();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final driver = authProvider.driver;
    final driverName = (driver?.name != null && driver!.name.trim().isNotEmpty)
        ? driver.name
        : 'Driver';

    final rawStatus = (driver?.status ?? (driver?.isActive == true ? 'available' : 'offline')).toLowerCase();
    final bool isOnline = rawStatus != 'offline';

    final allOrders = orderProvider.allOrders;
    final activeOrders = orderProvider.optimizedActiveOrders;
    final deliveredOrders = orderProvider.deliveredOrders;
    final incomingAlert = orderProvider.incomingDispatchAlert;

    final totalOrdersCount = allOrders.length;
    final doneOrdersCount = deliveredOrders.length;
    final activeOrdersCount = activeOrders.length;

    // Status Styling
    Color statusPrimaryColor;
    Color statusSecondaryColor;
    Color statusTextColor;
    String statusTitle;
    String statusSubtitle;
    IconData statusIcon;

    if (rawStatus == 'on_delivery') {
      statusPrimaryColor = const Color(0xFF2563EB);
      statusSecondaryColor = const Color(0xFF1D4ED8);
      statusTextColor = Colors.white;
      statusTitle = 'On Delivery';
      statusSubtitle = 'Active delivery • GPS tracking';
      statusIcon = Icons.two_wheeler_rounded;
    } else if (rawStatus == 'busy') {
      statusPrimaryColor = const Color(0xFFF59E0B);
      statusSecondaryColor = const Color(0xFFD97706);
      statusTextColor = Colors.black87;
      statusTitle = 'Busy';
      statusSubtitle = 'Paused from new assignments';
      statusIcon = Icons.pause_circle_rounded;
    } else if (isOnline) {
      statusPrimaryColor = AppTheme.primary;
      statusSecondaryColor = AppTheme.primaryDark;
      statusTextColor = Colors.black;
      statusTitle = 'Online & Connected';
      statusSubtitle = 'Ready for dispatches from admin';
      statusIcon = Icons.electric_bolt_rounded;
    } else {
      statusPrimaryColor = Theme.of(context).colorScheme.surface;
      statusSecondaryColor = Theme.of(context).colorScheme.surface;
      statusTextColor = Theme.of(context).colorScheme.onSurface;
      statusTitle = 'You are Offline';
      statusSubtitle = 'Switch on to receive dispatches';
      statusIcon = Icons.power_settings_new_rounded;
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: const SideMenu(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleManualRefresh,
          color: AppTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Menu, Manual Refresh & Profile
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: IconButton(
                        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.menu_rounded,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: GoogleFonts.plusJakartaSans(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  driverName,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              RepaintBoundary(
                                child: FadeTransition(
                                  opacity: isOnline ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                                      boxShadow: isOnline
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                                blurRadius: 6,
                                                spreadRadius: 2,
                                              )
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Manual Refresh Button
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: IconButton(
                            tooltip: 'Manual Refresh',
                            onPressed: _isManualRefreshing ? null : _handleManualRefresh,
                            padding: EdgeInsets.zero,
                            icon: _isManualRefreshing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(
                                    Icons.refresh_rounded,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    size: 18,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Profile Avatar Button
                        InkWell(
                          onTap: () => Navigator.pushNamed(context, '/profile'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                            ),
                            child: Center(
                              child: Text(
                                driver?.name.isNotEmpty == true ? driver!.name.substring(0, 1).toUpperCase() : 'D',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.primaryDark,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Sync status indicator bar with GPS & Server Connection Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.sync_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _lastSyncedAt != null
                              ? 'Live sync ${_formatTime(_lastSyncedAt!)}'
                              : 'Auto-syncs every 30s',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    // GPS status badge
                    GestureDetector(
                      onTap: () => orderProvider.refreshLocation(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: orderProvider.isLocationPermissionGranted
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: orderProvider.isLocationPermissionGranted
                                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                : Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              orderProvider.isLocationPermissionGranted
                                  ? Icons.gps_fixed_rounded
                                  : Icons.gps_not_fixed_rounded,
                              size: 12,
                              color: orderProvider.isLocationPermissionGranted
                                  ? const Color(0xFF10B981)
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              orderProvider.isLocationPermissionGranted ? 'Adaptive GPS' : 'Enable GPS',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: orderProvider.isLocationPermissionGranted
                                    ? const Color(0xFF10B981)
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Offline Queue Banner
                ValueListenableBuilder<int>(
                  valueListenable: OfflineQueueService().pendingCountNotifier,
                  builder: (ctx, count, _) {
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$count offline action(s) stored locally. Tap Sync to retry.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              if (driver?.token != null) {
                                final synced = await orderProvider.syncOfflineQueue(driver!.token!);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Synced $synced offline action(s)!')),
                                  );
                                }
                              }
                            },
                            child: const Text('Sync Now', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Realtime Driver Status Card
                GestureDetector(
                  onTap: () => _showStatusPicker(context, rawStatus),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [statusPrimaryColor, statusSecondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: !isOnline
                          ? Border.all(color: Theme.of(context).dividerColor)
                          : null,
                      boxShadow: isOnline
                          ? [
                              BoxShadow(
                                color: statusPrimaryColor.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? Colors.black.withValues(alpha: 0.12)
                                      : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  statusIcon,
                                  color: statusTextColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          statusTitle,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: statusTextColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_drop_down_rounded,
                                          color: statusTextColor,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      statusSubtitle,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: isOnline
                                            ? statusTextColor.withValues(alpha: 0.8)
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6),
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: isOnline,
                          activeThumbColor: Colors.black,
                          activeTrackColor: Colors.black26,
                          onChanged: (value) async {
                            final nextStatus = value ? 'available' : 'offline';
                            final success = await authProvider.setStatus(nextStatus);
                            if (success) {
                              _fetchData();
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not update shift status. Please try again.')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Incoming Dispatch Alert Banner
                if (incomingAlert != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.notifications_active_rounded,
                                    color: Color(0xFF10B981), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'New Dispatch from Admin!',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => orderProvider.dismissIncomingAlert(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${incomingAlert.orderNumber} • ${incomingAlert.customerName}',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          incomingAlert.deliveryAddress,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => orderProvider.declineOrder(
                                driver!.token!,
                                incomingAlert.id,
                                reason: 'Driver busy',
                              ),
                              child: const Text('Decline', style: TextStyle(color: Colors.redAccent)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => orderProvider.acceptOrder(
                                driver!.token!,
                                incomingAlert.id,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Accept Order'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // Today's Summary Header with Tap to Earnings
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Today's Overview",
                      style: GoogleFonts.plusJakartaSans(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/earnings'),
                      icon: const Icon(Icons.insights_rounded, size: 16, color: Color(0xFF10B981)),
                      label: const Text(
                        'Earnings & Stats',
                        style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Stats Row with Overflow-Proof Fitted Layout
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.receipt_long_rounded,
                        label: 'Total Orders',
                        value: totalOrdersCount.toString(),
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.delivery_dining_rounded,
                        label: 'Active Drops',
                        value: activeOrdersCount.toString(),
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Delivered',
                        value: doneOrdersCount.toString(),
                        color: AppTheme.success,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                // Nearest-First Multi-Stop Route Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Delivery Route',
                          style: GoogleFonts.plusJakartaSans(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (activeOrdersCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$activeOrdersCount Stops',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (activeOrdersCount > 1)
                      GestureDetector(
                        onTap: () => orderProvider.toggleProximitySorting(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: orderProvider.sortByProximity
                                ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                                : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: orderProvider.sortByProximity
                                  ? const Color(0xFF2563EB)
                                  : Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.near_me_rounded,
                                size: 13,
                                color: orderProvider.sortByProximity
                                    ? const Color(0xFF2563EB)
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                orderProvider.sortByProximity ? 'Nearest First' : 'Queue Order',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: orderProvider.sortByProximity
                                      ? const Color(0xFF2563EB)
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/orders'),
                        child: const Text('View All'),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Multi-Stop Route Batch Header Card (when 2 or more stops active)
                if (activeOrdersCount > 1) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                          const Color(0xFF2563EB).withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.alt_route_rounded, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Multi-Stop Route Optimized',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    orderProvider.sortByProximity
                                        ? 'Ordered closest to furthest from your current GPS position'
                                        : 'Ordered by dispatch creation time',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.straighten_rounded,
                                        size: 14,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Total: ${orderProvider.totalRouteDistanceFormatted}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 14,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        orderProvider.totalRouteDurationFormatted,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => MapService.openMultiStopBatchDirections(
                                context,
                                activeOrders,
                              ),
                              icon: const Icon(Icons.navigation_rounded, size: 14),
                              label: const Text('Open Batch Map'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Permission Warning Banner if GPS disabled
                if (!orderProvider.isLocationPermissionGranted && activeOrdersCount > 0) ...[
                  GestureDetector(
                    onTap: () => orderProvider.refreshLocation(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_disabled_rounded, color: Colors.amber, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Location access is off. Tap here to enable GPS so orders sort by nearest first.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.amber),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Orders List
                if (orderProvider.isLoading && activeOrders.isEmpty && allOrders.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (activeOrders.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.task_alt_rounded,
                          size: 48,
                          color: const Color(0xFF10B981).withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'All deliveries completed!',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isOnline
                              ? 'Waiting for new orders dispatched by Admin'
                              : 'Turn on online status to become available for dispatches',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeOrders.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final order = activeOrders[index];
                      final isNextStop = index == 0;
                      final stopNumber = index + 1;
                      final distance = orderProvider.getDistanceFormatted(order);
                      final duration = orderProvider.getDurationFormatted(order);

                      return _OrderCard(
                        order: order,
                        token: driver?.token,
                        isNextStop: isNextStop,
                        stopNumber: stopNumber,
                        distanceFormatted: distance,
                        durationFormatted: duration,
                        onStatusUpdated: _fetchData,
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withValues(alpha: 0.12)
            : Theme.of(context).dividerColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? color : Theme.of(context).dividerColor,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 28),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle_rounded, color: color)
            : null,
        onTap: onTap,
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final Order order;
  final String? token;
  final bool isNextStop;
  final int stopNumber;
  final String distanceFormatted;
  final String durationFormatted;
  final VoidCallback onStatusUpdated;

  const _OrderCard({
    required this.order,
    required this.token,
    required this.isNextStop,
    required this.stopNumber,
    required this.distanceFormatted,
    required this.durationFormatted,
    required this.onStatusUpdated,
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _isUpdating = false;

  Future<void> _handleTransition(
    String nextStatus, {
    String? reason,
    String? notes,
    String? photoBase64,
    String? recipientName,
  }) async {
    if (widget.token == null) return;
    setState(() => _isUpdating = true);

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final success = await orderProvider.updateStatus(
      widget.token!,
      widget.order.id,
      nextStatus,
      reason: reason,
      notes: notes,
      photoBase64: photoBase64,
      recipientName: recipientName,
    );

    if (mounted) {
      setState(() => _isUpdating = false);
      if (success) {
        widget.onStatusUpdated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update order status')),
        );
      }
    }
  }

  void _showDeclineDialog() {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Decline Order Dispatch',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason to notify the admin panel for re-dispatch:',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g., Heavy rain, Vehicle issue, Out of range',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _handleTransition('cancelled', reason: reasonCtrl.text);
            },
            child: const Text('Confirm Decline', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isNext = widget.isNextStop;
    final hasValidCoords = order.hasCoordinates;

    // Status Pill Colors
    Color statusBgColor;
    Color statusTextColor;
    if (order.isDelivered) {
      statusBgColor = AppTheme.success.withValues(alpha: 0.15);
      statusTextColor = AppTheme.success;
    } else if (order.isAssigned) {
      statusBgColor = Colors.amber.withValues(alpha: 0.15);
      statusTextColor = Colors.amber[800] ?? Colors.amber;
    } else if (order.isAccepted) {
      statusBgColor = const Color(0xFF2563EB).withValues(alpha: 0.15);
      statusTextColor = const Color(0xFF2563EB);
    } else if (order.isAtStore) {
      statusBgColor = Colors.purple.withValues(alpha: 0.15);
      statusTextColor = Colors.purple;
    } else if (order.isOnDelivery) {
      statusBgColor = const Color(0xFF10B981).withValues(alpha: 0.15);
      statusTextColor = const Color(0xFF10B981);
    } else {
      statusBgColor = Colors.grey.withValues(alpha: 0.15);
      statusTextColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isNext
              ? const Color(0xFF10B981)
              : Theme.of(context).dividerColor,
          width: isNext ? 2 : 1,
        ),
        boxShadow: isNext
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Stop Badge & Order Number
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isNext
                          ? const Color(0xFF10B981)
                          : const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isNext ? Icons.navigation_rounded : Icons.location_pin,
                          color: isNext ? Colors.white : const Color(0xFF2563EB),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isNext ? 'NEXT STOP • #1' : 'STOP #${widget.stopNumber}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isNext ? Colors.white : const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    order.orderNumber,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.displayStatus,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusTextColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Customer details & Proximity chip
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.customerName,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasValidCoords && widget.distanceFormatted != '--')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isNext
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : Theme.of(context).dividerColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.near_me_rounded,
                        size: 11,
                        color: isNext ? const Color(0xFF10B981) : Colors.grey,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${widget.distanceFormatted} • ${widget.durationFormatted}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isNext
                              ? const Color(0xFF10B981)
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Delivery Address Row (Full Width)
          InkWell(
            onTap: () => MapService.openDirections(context, order),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on_rounded, size: 14, color: Colors.redAccent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.deliveryAddress,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Action Pills Meta-Bar (Checklist & Map Buttons)
          Row(
            children: [
              GestureDetector(
                onTap: () => OrderChecklistSheet.show(context, order: order),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.checklist_rounded, size: 13, color: Colors.purple),
                      const SizedBox(width: 4),
                      Text(
                        '${order.items.length} items to check',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => MapService.openDirections(context, order),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_rounded, size: 13, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Text(
                        'Directions',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Lifecycle Actions & Total Amount Row (Overflow Proof)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Total (Prepaid)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    'Rs. ${order.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              if (_isUpdating)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Flexible(
                  child: _buildActionButtons(order),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Order order) {
    if (order.isAssigned) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _showDeclineDialog,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 38),
            ),
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () => _handleTransition('accepted'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 38),
            ),
            child: const Text('Accept Order'),
          ),
        ],
      );
    } else if (order.isAccepted) {
      return ElevatedButton.icon(
        onPressed: () => _handleTransition('at_store'),
        icon: const Icon(Icons.storefront_rounded, size: 16),
        label: const Text('At Store'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: const Size(0, 38),
        ),
      );
    } else if (order.isAtStore) {
      return ElevatedButton.icon(
        onPressed: () => _handleTransition('on_delivery'),
        icon: const Icon(Icons.check_box_outlined, size: 16),
        label: const Text('Picked Up'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: const Size(0, 38),
        ),
      );
    } else {
      // on_delivery
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: () => MapService.openDirections(context, order),
            icon: const Icon(Icons.directions_rounded, size: 14),
            label: const Text('Nav'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF2563EB)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(0, 38),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              ProofOfDeliverySheet.show(
                context,
                order: order,
                onConfirm: ({notes, photoBase64, recipientName}) {
                  _handleTransition(
                    'delivered',
                    notes: notes,
                    photoBase64: photoBase64,
                    recipientName: recipientName,
                  );
                },
              );
            },
            icon: const Icon(Icons.verified_rounded, size: 14),
            label: const Text('Delivered'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 38),
            ),
          ),
        ],
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
