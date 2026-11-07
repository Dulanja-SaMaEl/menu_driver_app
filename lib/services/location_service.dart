import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/order.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _lastKnownPosition;
  Position? get lastKnownPosition => _lastKnownPosition;

  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  /// Check and request location permissions
  Future<bool> checkAndRequestPermission() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) print('Location services are disabled.');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) print('Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('Location permissions are permanently denied, cannot request.');
        }
        return false;
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('Error checking location permission: $e');
      return false;
    }
  }

  /// Get current GPS position with timeout and fallback
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) {
      return _lastKnownPosition;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _lastKnownPosition = position;
      return position;
    } catch (e) {
      if (kDebugMode) print('Error obtaining current location, checking last known: $e');
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          _lastKnownPosition = lastKnown;
          return lastKnown;
        }
      } catch (_) {}
      return _lastKnownPosition;
    }
  }

  /// Start continuous tracking stream with 25-meter filter
  void startLocationTracking({void Function(Position)? onPositionChanged}) {
    _positionStreamSubscription?.cancel();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25, // Update every 25 meters
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (Position position) {
        _lastKnownPosition = position;
        _positionController.add(position);
        if (onPositionChanged != null) {
          onPositionChanged(position);
        }
      },
      onError: (e) {
        if (kDebugMode) print('Error in location stream: $e');
      },
    );
  }

  void stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  /// Calculate distance between two coordinates in meters
  static double getDistanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    try {
      return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
    } catch (_) {
      return 0.0;
    }
  }

  /// Format distance into a human-readable string (e.g., '450 m' or '3.2 km')
  static String formatDistance(double? meters) {
    if (meters == null || meters < 0) return '--';
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      final km = meters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  /// Estimated transit duration based on ~25 km/h urban motorcycle delivery speed (~416 m/min)
  static String formatDuration(double? meters) {
    if (meters == null || meters <= 0) return '--';
    const double metersPerMinute = 416.7;
    final int minutes = (meters / metersPerMinute).ceil();
    if (minutes <= 1) {
      return '~1 min';
    } else if (minutes < 60) {
      return '~$minutes mins';
    } else {
      final hours = minutes ~/ 60;
      final remainingMins = minutes % 60;
      return remainingMins == 0 ? '~${hours}h' : '~${hours}h ${remainingMins}m';
    }
  }

  /// Calculate total multi-stop route distance in meters (Driver -> Stop 1 -> Stop 2 -> Stop N)
  static double calculateTotalRouteDistance(
    Position startLocation,
    List<Order> orderedStops,
  ) {
    if (orderedStops.isEmpty) return 0.0;
    double totalMeters = 0.0;
    double currentLat = startLocation.latitude;
    double currentLng = startLocation.longitude;

    for (final order in orderedStops) {
      if (order.latitude != null &&
          order.longitude != null &&
          order.latitude != 0.0 &&
          order.longitude != 0.0) {
        totalMeters += getDistanceBetween(
          currentLat,
          currentLng,
          order.latitude!,
          order.longitude!,
        );
        currentLat = order.latitude!;
        currentLng = order.longitude!;
      }
    }
    return totalMeters;
  }
}
