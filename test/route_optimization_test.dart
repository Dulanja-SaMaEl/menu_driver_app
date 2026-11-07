import 'package:flutter_test/flutter_test.dart';
import 'package:the_menu_driver_app/models/order.dart';
import 'package:the_menu_driver_app/services/location_service.dart';

void main() {
  group('Nearest-First Multi-Stop Route Optimization Tests', () {
    test('Calculates distance and sorts orders nearest-first', () {
      // Driver is located at Colombo Fort (6.9344, 79.8428)
      const driverLat = 6.9344;
      const driverLng = 79.8428;

      // Order A: Kollupitiya ~3 km south (6.9080, 79.8510)
      final orderA = Order(
        id: 1,
        orderNumber: 'ORD-001',
        customerName: 'Alice',
        customerPhone: '0771111111',
        deliveryAddress: 'Kollupitiya, Colombo 03',
        latitude: 6.9080,
        longitude: 79.8510,
        totalAmount: 1500.0,
        status: 'on_delivery',
        createdAt: DateTime.now(),
      );

      // Order B: Pettah ~1 km east (6.9380, 79.8520) - CLOSEST!
      final orderB = Order(
        id: 2,
        orderNumber: 'ORD-002',
        customerName: 'Bob',
        customerPhone: '0772222222',
        deliveryAddress: 'Pettah, Colombo 11',
        latitude: 6.9380,
        longitude: 79.8520,
        totalAmount: 2200.0,
        status: 'assigned',
        createdAt: DateTime.now(),
      );

      // Order C: Dehiwala ~11 km south (6.8390, 79.8650) - FURTHEST!
      final orderC = Order(
        id: 3,
        orderNumber: 'ORD-003',
        customerName: 'Charlie',
        customerPhone: '0773333333',
        deliveryAddress: 'Dehiwala',
        latitude: 6.8390,
        longitude: 79.8650,
        totalAmount: 3400.0,
        status: 'on_delivery',
        createdAt: DateTime.now(),
      );

      // Raw unsorted list
      final orders = [orderC, orderA, orderB];

      // Sort by proximity to driver
      orders.sort((a, b) {
        final distA = LocationService.getDistanceBetween(
          driverLat,
          driverLng,
          a.latitude!,
          a.longitude!,
        );
        final distB = LocationService.getDistanceBetween(
          driverLat,
          driverLng,
          b.latitude!,
          b.longitude!,
        );
        return distA.compareTo(distB);
      });

      // Verify sorted order: Pettah (B) -> Kollupitiya (A) -> Dehiwala (C)
      expect(orders[0].id, equals(2)); // Order B is nearest
      expect(orders[1].id, equals(1)); // Order A is 2nd nearest
      expect(orders[2].id, equals(3)); // Order C is furthest
    });

    test('Distance and duration formatting tests', () {
      expect(LocationService.formatDistance(350), equals('350 m'));
      expect(LocationService.formatDistance(1250), equals('1.3 km'));
      expect(LocationService.formatDistance(null), equals('--'));

      expect(LocationService.formatDuration(350), equals('~1 min'));
      expect(LocationService.formatDuration(2500), equals('~6 mins'));
      expect(LocationService.formatDuration(null), equals('--'));
    });
  });
}
