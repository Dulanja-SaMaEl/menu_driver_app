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
      _start15MinBackgroundSync();
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
          orderProvider.updateCurrentPosition(position);
        }
      },
    );
  }

  // 15-minute automatic background heartbeat sync
  void _start15MinBackgroundSync() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (!mounted) return;
      _quietPoll();
    });
  }

  Future<void> _quietPoll() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final driver = auth.driver;
    if (driver?.token != null) {
      await auth.refreshProfile();
      if (mounted) {
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        await orderProvider.fetchLatestOrders(driver!.token!);
        await orderProvider.fetchAllOrders(driver.token!);
        await orderProvider.refreshLocation();
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
      await Future.wait([
        auth.refreshProfile(),
        orderProvider.fetchLatestOrders(driver!.token!),
        orderProvider.fetchAllOrders(driver.token!),
        orderProvider.refreshLocation(),
      ]);
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
                'Synced with server (${_formatTime(_lastSyncedAt ?? DateTime.now())})',
                style: GoogleFonts.lato(color: Colors.white),
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
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _StatusOptionTile(
                  title: 'Available (Online)',
                  subtitle: 'Ready to receive new orders',
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
      statusSubtitle = 'Active delivery order in progress';
      statusIcon = Icons.two_wheeler_rounded;
    } else if (rawStatus == 'busy') {
      statusPrimaryColor = const Color(0xFFF59E0B);
      statusSecondaryColor = const Color(0xFFD97706);
      statusTextColor = Colors.black87;
      statusTitle = 'Busy';
      statusSubtitle = 'Paused from new order assignments';
      statusIcon = Icons.pause_circle_rounded;
    } else if (isOnline) {
      statusPrimaryColor = AppTheme.primary;
      statusSecondaryColor = AppTheme.primaryDark;
      statusTextColor = Colors.black;
      statusTitle = 'Online & Available';
      statusSubtitle = 'Ready for new order assignments';
      statusIcon = Icons.electric_bolt_rounded;
    } else {
      statusPrimaryColor = Theme.of(context).colorScheme.surface;
      statusSecondaryColor = Theme.of(context).colorScheme.surface;
      statusTextColor = Theme.of(context).colorScheme.onSurface;
      statusTitle = 'You are Offline';
      statusSubtitle = 'Turn on switch to start receiving orders';
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Menu, Manual Refresh & Profile
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: IconButton(
                            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                            icon: Icon(
                              Icons.menu_rounded,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: GoogleFonts.lato(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                                fontSize: 14,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  driverName,
                                  style: GoogleFonts.lato(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Realtime glowing pulse indicator
                                FadeTransition(
                                  opacity: isOnline ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                                  child: Container(
                                    width: 10,
                                    height: 10,
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
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Manual Refresh Button
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: IconButton(
                            tooltip: 'Manual Refresh (Sync Orders & Location)',
                            onPressed: _isManualRefreshing ? null : _handleManualRefresh,
                            icon: _isManualRefreshing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(
                                    Icons.refresh_rounded,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    size: 20,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Profile Button
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: IconButton(
                            onPressed: () => Navigator.pushNamed(context, '/profile'),
                            icon: Icon(
                              Icons.person_outline_rounded,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Sync status indicator bar with GPS Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.sync_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _lastSyncedAt != null
                              ? 'Updated ${_formatTime(_lastSyncedAt!)}'
                              : 'Auto-syncs every 15 min',
                          style: GoogleFonts.lato(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                              orderProvider.isLocationPermissionGranted ? 'GPS Live' : 'Enable GPS',
                              style: GoogleFonts.lato(
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

                const SizedBox(height: 16),

                // Realtime Driver Status Card
                GestureDetector(
                  onTap: () => _showStatusPicker(context, rawStatus),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [statusPrimaryColor, statusSecondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
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
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          statusTitle,
                                          style: GoogleFonts.lato(
                                            color: statusTextColor,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
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
                                      style: GoogleFonts.lato(
                                        color: isOnline
                                            ? statusTextColor.withValues(alpha: 0.8)
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
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
                                const SnackBar(content: Text('Failed to update status on server')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Today's Summary Header
                Text(
                  "Today's Overview",
                  style: GoogleFonts.lato(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),

                // Stats Grid
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.delivery_dining_rounded,
                        label: 'Active Drops',
                        value: activeOrdersCount.toString(),
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 12),
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

                const SizedBox(height: 28),

                // Nearest-First Multi-Stop Route Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Delivery Route',
                          style: GoogleFonts.lato(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 18,
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
                              style: GoogleFonts.lato(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Proximity sort toggle
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
                                style: GoogleFonts.lato(
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
                                    style: GoogleFonts.lato(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    orderProvider.sortByProximity
                                        ? 'Ordered closest to furthest from your current GPS position'
                                        : 'Ordered by dispatch creation time',
                                    style: GoogleFonts.lato(
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
                            Row(
                              children: [
                                Icon(
                                  Icons.straighten_rounded,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Total: ${orderProvider.totalRouteDistanceFormatted}',
                                  style: GoogleFonts.lato(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.timer_outlined,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  orderProvider.totalRouteDurationFormatted,
                                  style: GoogleFonts.lato(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
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
                                textStyle: GoogleFonts.lato(
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
                              style: GoogleFonts.lato(
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
                      borderRadius: BorderRadius.circular(16),
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
                          style: GoogleFonts.lato(
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
                          style: GoogleFonts.lato(
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
          style: GoogleFonts.lato(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.lato(
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

  Future<void> _handleStatusUpdate(String nextStatus) async {
    if (widget.token == null) return;
    setState(() => _isUpdating = true);

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final success = await orderProvider.updateStatus(
      widget.token!,
      widget.order.id,
      nextStatus,
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

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isNext = widget.isNextStop;
    final hasValidCoords = order.hasCoordinates;

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
                          style: GoogleFonts.lato(
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
                    style: GoogleFonts.lato(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),
              // Proximity Chip
              if (hasValidCoords && widget.distanceFormatted != '--')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        style: GoogleFonts.lato(
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

          const SizedBox(height: 12),

          // Customer details
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.customerName,
                  style: GoogleFonts.lato(fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (order.customerPhone.isNotEmpty && order.customerPhone != '-') ...[
                Icon(Icons.phone_outlined, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  order.customerPhone,
                  style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // Delivery Address
          InkWell(
            onTap: () => MapService.openDirections(context, order),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on_rounded, size: 15, color: Colors.redAccent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.deliveryAddress,
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          'Map',
                          style: GoogleFonts.lato(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 24),

          // Bottom Price & Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Total',
                    style: GoogleFonts.lato(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    'Rs. ${order.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.lato(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Navigate Button
                  OutlinedButton.icon(
                    onPressed: () => MapService.openDirections(context, order),
                    icon: const Icon(Icons.directions_rounded, size: 16),
                    label: const Text('Navigate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delivered Button
                  ElevatedButton(
                    onPressed: _isUpdating ? null : () => _handleStatusUpdate('delivered'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(90, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Delivered', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.lato(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.lato(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
