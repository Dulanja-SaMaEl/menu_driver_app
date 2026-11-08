import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/offline_queue_service.dart';

class OrderProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final LocationService _locationService = LocationService();
  final OfflineQueueService _offlineQueue = OfflineQueueService();

  List<Order> _allOrders = [];
  List<Order> _latestOrders = [];
  bool _isLoading = false;
  String? _errorMessage;

  Position? _currentPosition;
  bool _isLocationPermissionGranted = false;
  bool _sortByProximity = true; // Nearest-first enabled by default

  // Incoming Dispatch Notification State
  final Set<int> _knownOrderIds = {};
  Order? _incomingDispatchAlert;
  DateTime? _lastTelemetrySentAt;

  List<Order> get allOrders => _allOrders;
  List<Order> get latestOrders => _latestOrders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Position? get currentPosition => _currentPosition;
  bool get isLocationPermissionGranted => _isLocationPermissionGranted;
  bool get sortByProximity => _sortByProximity;

  Order? get incomingDispatchAlert => _incomingDispatchAlert;
  int get pendingOfflineActionsCount => _offlineQueue.pendingCountNotifier.value;

  void dismissIncomingAlert() {
    _incomingDispatchAlert = null;
    notifyListeners();
  }

  void toggleProximitySorting() {
    _sortByProximity = !_sortByProximity;
    notifyListeners();
  }

  /// Adaptive GPS power mode based on driver shift and order load
  void adjustLocationPowerMode(bool isOnline) {
    if (!isOnline) {
      _locationService.setPowerMode(LocationPowerMode.powerSave);
    } else if (activeOrders.isNotEmpty) {
      _locationService.setPowerMode(LocationPowerMode.highPerformance);
    } else {
      _locationService.setPowerMode(LocationPowerMode.balanced);
    }
  }

  /// Initialize or refresh the rider's current GPS location
  Future<void> refreshLocation() async {
    try {
      final hasPermission = await _locationService.checkAndRequestPermission();
      _isLocationPermissionGranted = hasPermission;
      if (hasPermission) {
        final position = await _locationService.getCurrentPosition();
        if (position != null) {
          _currentPosition = position;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Update position when stream emits new location
  void updateCurrentPosition(Position position, {String? token, bool isOnline = true}) {
    _currentPosition = position;
    _isLocationPermissionGranted = true;
    notifyListeners();

    // Stream telemetry to the-menu-admin when active
    if (token != null && isOnline) {
      syncLocationTelemetry(token, isOnline: isOnline);
    }
  }

  /// Sends throttled GPS telemetry to the-menu-admin
  Future<void> syncLocationTelemetry(String token, {bool isOnline = true}) async {
    if (!isOnline || _currentPosition == null) return;
    final now = DateTime.now();
    if (_lastTelemetrySentAt != null &&
        now.difference(_lastTelemetrySentAt!).inSeconds < 25) {
      return; // Throttled to 25 seconds interval
    }
    _lastTelemetrySentAt = now;

    try {
      await _api.sendDriverTelemetry(
        token: token,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        heading: _currentPosition!.heading,
        speed: _currentPosition!.speed,
        accuracy: _currentPosition!.accuracy,
      );
    } catch (_) {}
  }

  /// Replay pending offline actions when connection restores
  Future<int> syncOfflineQueue(String token) async {
    try {
      final synced = await _offlineQueue.syncPendingActions(token, _api);
      if (synced > 0) {
        await fetchLatestOrders(token);
        await fetchAllOrders(token);
      }
      return synced;
    } catch (_) {
      return 0;
    }
  }

  /// Active orders (assigned, accepted, at_store, or on_delivery)
  List<Order> get activeOrders {
    return _allOrders.where((o) => o.isActive).toList();
  }

  /// Active orders optimized with Nearest-First sorting
  List<Order> get optimizedActiveOrders {
    final active = activeOrders;
    if (active.isEmpty) return [];

    if (!_sortByProximity || _currentPosition == null) {
      return active;
    }

    final withCoords = active.where((o) => o.hasCoordinates).toList();
    final withoutCoords = active.where((o) => !o.hasCoordinates).toList();

    // Sort by ascending distance from rider's current position
    withCoords.sort((a, b) {
      final distA = LocationService.getDistanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        a.latitude!,
        a.longitude!,
      );
      final distB = LocationService.getDistanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        b.latitude!,
        b.longitude!,
      );
      return distA.compareTo(distB);
    });

    return [...withCoords, ...withoutCoords];
  }

  /// Completed/delivered orders
  List<Order> get deliveredOrders {
    return _allOrders.where((o) => o.isDelivered).toList();
  }

  /// Distance in meters to a specific order from current location
  double? getDistanceToOrder(Order order) {
    if (_currentPosition == null || !order.hasCoordinates) {
      return null;
    }
    return LocationService.getDistanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      order.latitude!,
      order.longitude!,
    );
  }

  /// Formatted distance string (e.g. '850 m' or '2.4 km')
  String getDistanceFormatted(Order order) {
    return LocationService.formatDistance(getDistanceToOrder(order));
  }

  /// Formatted estimated travel time (e.g. '~5 mins')
  String getDurationFormatted(Order order) {
    return LocationService.formatDuration(getDistanceToOrder(order));
  }

  /// Total multi-stop route distance in meters for all active orders
  double get totalRouteDistance {
    if (_currentPosition == null) return 0.0;
    return LocationService.calculateTotalRouteDistance(
      _currentPosition!,
      optimizedActiveOrders,
    );
  }

  String get totalRouteDistanceFormatted {
    return LocationService.formatDistance(totalRouteDistance);
  }

  String get totalRouteDurationFormatted {
    return LocationService.formatDuration(totalRouteDistance);
  }

  Future<void> fetchAllOrders(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.getOrders(token);
      if (result['success'] == true) {
        final List<dynamic> ordersJson = result['orders'];
        final fetched = ordersJson.map((json) => Order.fromJson(json)).toList();

        // Check for new incoming dispatch from admin
        final newDispatches = fetched
            .where((o) => o.isAssigned && !_knownOrderIds.contains(o.id))
            .toList();

        if (_knownOrderIds.isNotEmpty && newDispatches.isNotEmpty) {
          _incomingDispatchAlert = newDispatches.first;
          NotificationService.showNewOrderAlert(newDispatches.first);
        }

        _knownOrderIds.addAll(fetched.map((o) => o.id));
        _allOrders = fetched;
      } else {
        _errorMessage = result['message'] ?? 'Failed to fetch orders';
      }
    } catch (e) {
      _errorMessage = 'Network error. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchLatestOrders(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.getLatestOrders(token);
      if (result['success'] == true) {
        final List<dynamic> ordersJson = result['orders'];
        final fetched = ordersJson.map((json) => Order.fromJson(json)).toList();

        final newDispatches = fetched
            .where((o) => o.isAssigned && !_knownOrderIds.contains(o.id))
            .toList();

        if (_knownOrderIds.isNotEmpty && newDispatches.isNotEmpty && _incomingDispatchAlert == null) {
          _incomingDispatchAlert = newDispatches.first;
          NotificationService.showNewOrderAlert(newDispatches.first);
        }

        _knownOrderIds.addAll(fetched.map((o) => o.id));
        _latestOrders = fetched;
      } else {
        _errorMessage = result['message'] ?? 'Failed to fetch latest orders';
      }
    } catch (e) {
      _errorMessage = 'Network error. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Step-by-Step Order Lifecycle Transitions ---

  Future<bool> acceptOrder(String token, int orderId) async {
    return updateStatus(token, orderId, 'accepted');
  }

  Future<bool> markArrivedAtStore(String token, int orderId) async {
    return updateStatus(token, orderId, 'at_store');
  }

  Future<bool> markPickedUp(String token, int orderId) async {
    return updateStatus(token, orderId, 'on_delivery');
  }

  Future<bool> markDelivered(
    String token,
    int orderId, {
    String? notes,
    String? photoBase64,
    String? recipientName,
  }) async {
    return updateStatus(
      token,
      orderId,
      'delivered',
      notes: notes,
      photoBase64: photoBase64,
      recipientName: recipientName,
    );
  }

  Future<bool> declineOrder(String token, int orderId, {String? reason}) async {
    return updateStatus(token, orderId, 'cancelled', reason: reason);
  }

  Future<bool> updateStatus(
    String token,
    int orderId,
    String status, {
    String? reason,
    String? notes,
    String? photoBase64,
    String? recipientName,
  }) async {
    try {
      final result = await _api.updateOrderStatus(
        token: token,
        orderId: orderId,
        status: status,
        reason: reason,
        notes: notes,
        photoBase64: photoBase64,
        recipientName: recipientName,
      );

      if (result['success'] == true) {
        // Dismiss alert if it was about this order
        if (_incomingDispatchAlert?.id == orderId) {
          _incomingDispatchAlert = null;
        }

        // Refresh orders locally
        await fetchLatestOrders(token);
        await fetchAllOrders(token);

        // Dynamically re-evaluate GPS position & nearest stop
        await refreshLocation();
        NotificationService.syncActiveOrdersNotification(_allOrders);
        return true;
      }
      return false;
    } catch (e) {
      // Offline fallback: queue for sync when internet is restored
      await _offlineQueue.enqueueAction(
        type: 'status_update',
        payload: {
          'order_id': orderId,
          'status': status,
          'reason': reason,
          'notes': notes,
          'photo_base64': photoBase64,
          'recipient_name': recipientName,
        },
      );
      notifyListeners();
      return true;
    }
  }
}
