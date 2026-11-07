import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

class OrderProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final LocationService _locationService = LocationService();

  List<Order> _allOrders = [];
  List<Order> _latestOrders = [];
  bool _isLoading = false;
  String? _errorMessage;

  Position? _currentPosition;
  bool _isLocationPermissionGranted = false;
  bool _sortByProximity = true; // Nearest-first enabled by default

  List<Order> get allOrders => _allOrders;
  List<Order> get latestOrders => _latestOrders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Position? get currentPosition => _currentPosition;
  bool get isLocationPermissionGranted => _isLocationPermissionGranted;
  bool get sortByProximity => _sortByProximity;

  void toggleProximitySorting() {
    _sortByProximity = !_sortByProximity;
    notifyListeners();
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
  void updateCurrentPosition(Position position) {
    _currentPosition = position;
    _isLocationPermissionGranted = true;
    notifyListeners();
  }

  /// Active orders (assigned or on_delivery)
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
        _allOrders = ordersJson.map((json) => Order.fromJson(json)).toList();
        NotificationService.syncActiveOrdersNotification(_allOrders);
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
        _latestOrders = ordersJson.map((json) => Order.fromJson(json)).toList();
        if (_allOrders.isEmpty) {
          NotificationService.syncActiveOrdersNotification(_latestOrders);
        }
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

  Future<bool> updateStatus(String token, int orderId, String status) async {
    try {
      final result = await _api.updateOrderStatus(
        token: token,
        orderId: orderId,
        status: status,
      );

      if (result['success'] == true) {
        // Refresh orders locally
        await fetchLatestOrders(token);
        await fetchAllOrders(token);
        // Refresh location immediately to dynamically re-evaluate the next nearest stop
        await refreshLocation();
        NotificationService.syncActiveOrdersNotification(_allOrders);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
