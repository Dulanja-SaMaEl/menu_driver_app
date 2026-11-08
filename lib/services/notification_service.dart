import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/order.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  if (notificationResponse.actionId == NotificationService.actionMarkDelivered) {
    NotificationService.handleBackgroundDelivered(notificationResponse.payload);
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const int activeNotificationId = 8888;
  static const String channelId = 'active_delivery_channel_v2';
  static const String channelName = 'Active Deliveries Status';
  static const String actionMarkDelivered = 'action_mark_delivered';

  static const String dispatchChannelId = 'dispatch_alert_channel';
  static const String dispatchChannelName = 'New Dispatches';

  static Function(int orderId)? onOrderDeliveredCallback;
  static bool _isInitialized = false;

  /// Initialize local notification plugin and channel
  static Future<void> init({Function(int orderId)? onMarkDelivered}) async {
    if (onMarkDelivered != null) {
      onOrderDeliveredCallback = onMarkDelivered;
    }

    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.actionId == actionMarkDelivered) {
          final payload = response.payload;
          if (payload != null) {
            final orderId = int.tryParse(payload);
            if (orderId != null) {
              handleForegroundDelivered(orderId);
            }
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create Notification Channels for Android
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Remove legacy noisy channel so Android resets to silent importance
      try {
        await androidPlugin.deleteNotificationChannel(channelId: 'active_delivery_channel');
      } catch (_) {}

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'Persistent silent real-time status for active deliveries',
        importance: Importance.low, // Silent, never buzzes or chimes
        playSound: false,
        enableVibration: false,
        showBadge: false,
      );
      await androidPlugin.createNotificationChannel(channel);

      const AndroidNotificationChannel dispatchChannel = AndroidNotificationChannel(
        dispatchChannelId,
        dispatchChannelName,
        description: 'Heads-up alert when admin dispatches a new order',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await androidPlugin.createNotificationChannel(dispatchChannel);

      // Request Android 13+ Notification Permission
      await androidPlugin.requestNotificationsPermission();
    }

    _isInitialized = true;
  }

  /// Alert the driver of a newly assigned order from the admin
  static Future<void> showNewOrderAlert(Order order) async {
    if (kIsWeb) return;
    try {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        dispatchChannelId,
        dispatchChannelName,
        channelDescription: 'Alert for newly assigned orders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        color: const Color(0xFF10B981),
        styleInformation: BigTextStyleInformation(
          'Customer: ${order.customerName}\nAddress: ${order.deliveryAddress}\nTotal: Rs. ${order.totalAmount.toStringAsFixed(2)}',
          contentTitle: '🛵 New Order Assigned: ${order.orderNumber}',
          summaryText: 'Action Required',
        ),
      );

      final NotificationDetails details = NotificationDetails(android: androidDetails);
      await _plugin.show(
        id: order.id,
        title: '🛵 New Order Assigned: ${order.orderNumber}',
        body: '${order.customerName} • ${order.deliveryAddress}',
        notificationDetails: details,
        payload: '${order.id}',
      );
    } catch (_) {}
  }

  static String? _lastNotificationFingerprint;

  /// Syncs the ongoing notification with current active orders in real-time
  static Future<void> syncActiveOrdersNotification(List<Order> orders) async {
    if (kIsWeb) return;

    final activeOrders = orders.where((o) => o.isActive).toList();

    if (activeOrders.isEmpty) {
      _lastNotificationFingerprint = null;
      await cancelActiveNotification();
      return;
    }

    final currentOrder = activeOrders.first;
    final otherOrdersCount = activeOrders.length - 1;

    // Deduplication Fingerprint: If order ID, status, and active queue length haven't changed, do not re-show
    final fingerprint = '${currentOrder.id}_${currentOrder.status}_${activeOrders.length}_${currentOrder.totalAmount}';
    if (_lastNotificationFingerprint == fingerprint) {
      return; // Already up to date, skip notifying Android notification manager
    }
    _lastNotificationFingerprint = fingerprint;

    final String title = '🚚 Stop #1: ${currentOrder.orderNumber}';
    final String address = currentOrder.deliveryAddress.trim();
    final String body =
        '${currentOrder.customerName} • $address\nRs. ${currentOrder.totalAmount.toStringAsFixed(2)}${otherOrdersCount > 0 ? ' (+$otherOrdersCount more in queue)' : ''}';

    const AndroidNotificationAction deliveredAction = AndroidNotificationAction(
      actionMarkDelivered,
      'Mark Delivered',
      showsUserInterface: true,
      cancelNotification: false,
    );

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Persistent notification for ongoing orders',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true, // Alerts only once; updates silently without buzzing/chiming
      playSound: false,
      enableVibration: false,
      showWhen: false,
      color: const Color(0xFF2563EB),
      actions: const <AndroidNotificationAction>[deliveredAction],
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Multi-stop delivery in progress',
      ),
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: activeNotificationId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: '${currentOrder.id}',
    );
  }

  /// Cancel active notification
  static Future<void> cancelActiveNotification() async {
    if (kIsWeb) return;
    _lastNotificationFingerprint = null;
    try {
      await _plugin.cancel(id: activeNotificationId);
    } catch (_) {}
  }

  /// Handles foreground notification action
  static Future<void> handleForegroundDelivered(int orderId) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        final api = ApiService();
        final res = await api.updateOrderStatus(
          token: token,
          orderId: orderId,
          status: 'delivered',
        );

        if (res['success'] == true) {
          Fluttertoast.showToast(
            msg: 'Order marked as Delivered! 🎉',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: const Color(0xFF10B981),
            textColor: Colors.white,
          );

          if (onOrderDeliveredCallback != null) {
            onOrderDeliveredCallback!(orderId);
          }
        } else {
          Fluttertoast.showToast(
            msg: res['message'] ?? 'Failed to update order status',
            toastLength: Toast.LENGTH_SHORT,
            backgroundColor: Colors.redAccent,
            textColor: Colors.white,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error handling notification delivered: $e');
    }
  }

  /// Handles background notification action (when app is minimized or phone locked)
  static Future<void> handleBackgroundDelivered(String? payload) async {
    if (payload == null) return;
    final orderId = int.tryParse(payload);
    if (orderId == null) return;

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      if (token != null) {
        final api = ApiService();
        final res = await api.updateOrderStatus(
          token: token,
          orderId: orderId,
          status: 'delivered',
        );

        if (res['success'] == true) {
          Fluttertoast.showToast(
            msg: 'Order marked as Delivered! 🎉',
            toastLength: Toast.LENGTH_SHORT,
            backgroundColor: const Color(0xFF10B981),
            textColor: Colors.white,
          );

          final plugin = FlutterLocalNotificationsPlugin();
          await plugin.cancel(id: activeNotificationId);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Background delivered action error: $e');
    }
  }
}
