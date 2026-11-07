import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order.dart';
import 'web_launcher_stub.dart'
    if (dart.library.html) 'web_launcher_web.dart';

class MapService {
  /// Opens Google Maps with driving directions to a single order's delivery location
  /// starting from the user's current GPS location.
  static Future<void> openDirections(BuildContext context, Order order) async {
    final address = order.deliveryAddress.trim();
    final bool hasValidAddress =
        address.isNotEmpty && address != '-' && address.toLowerCase() != 'delivery address';

    final String destination;
    if (order.latitude != null && order.longitude != null) {
      destination = '${order.latitude},${order.longitude}';
    } else if (hasValidAddress) {
      destination = Uri.encodeComponent(address);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid delivery location found for this order.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Google Maps universal turn-by-turn directions URL
    final String urlString =
        'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving';

    await _launchUrlString(context, urlString);
  }

  /// Opens Google Maps with a sequential multi-stop optimized route
  /// Example: Current Location -> Stop 1 -> Stop 2 -> ... -> Final Stop
  static Future<void> openMultiStopBatchDirections(
    BuildContext context,
    List<Order> orderedStops,
  ) async {
    if (orderedStops.isEmpty) return;
    if (orderedStops.length == 1) {
      return openDirections(context, orderedStops.first);
    }

    // Build destinations and waypoints
    final List<String> stopCoordinates = [];
    for (final order in orderedStops) {
      if (order.latitude != null && order.longitude != null) {
        stopCoordinates.add('${order.latitude},${order.longitude}');
      } else if (order.deliveryAddress.trim().isNotEmpty &&
          order.deliveryAddress != '-' &&
          order.deliveryAddress.toLowerCase() != 'delivery address') {
        stopCoordinates.add(Uri.encodeComponent(order.deliveryAddress.trim()));
      }
    }

    if (stopCoordinates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid locations found for batch navigation.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Destination is the final stop in the optimized sequence
    final String destination = stopCoordinates.last;
    // Intermediate waypoints are stops 0 to N-1
    final List<String> intermediateWaypoints =
        stopCoordinates.sublist(0, stopCoordinates.length - 1);

    String urlString =
        'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving';

    if (intermediateWaypoints.isNotEmpty) {
      urlString += '&waypoints=${intermediateWaypoints.join('|')}';
    }

    await _launchUrlString(context, urlString);
  }

  static Future<void> _launchUrlString(
    BuildContext context,
    String urlString,
  ) async {
    if (kIsWeb) {
      final success = launchWebUrl(urlString);
      if (success) return;
    }

    try {
      final Uri googleMapsUrl = Uri.parse(urlString);
      final launched = await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await launchUrl(googleMapsUrl);
      }
    } catch (e) {
      if (context.mounted) {
        final errorMsg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Google Maps: $errorMsg'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
