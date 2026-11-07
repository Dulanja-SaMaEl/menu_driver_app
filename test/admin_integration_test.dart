import 'package:flutter_test/flutter_test.dart';
import 'package:the_menu_driver_app/models/order.dart';
import 'package:the_menu_driver_app/services/api_service.dart';

void main() {
  group('Admin Integration & Order Lifecycle Tests', () {
    test('Correctly maps and detects order lifecycle states', () {
      final assignedOrder = Order(
        id: 101,
        orderNumber: 'ORD-101',
        customerName: 'John Doe',
        customerPhone: '0770000000',
        deliveryAddress: 'Colombo 03',
        totalAmount: 2500,
        status: 'assigned',
        createdAt: DateTime.now(),
      );

      expect(assignedOrder.isAssigned, isTrue);
      expect(assignedOrder.isActive, isTrue);
      expect(assignedOrder.isDelivered, isFalse);
      expect(assignedOrder.displayStatus, equals('NEW DISPATCH'));

      final acceptedOrder = Order(
        id: 102,
        orderNumber: 'ORD-102',
        customerName: 'Jane Smith',
        customerPhone: '0771111111',
        deliveryAddress: 'Colombo 07',
        totalAmount: 1800,
        status: 'accepted',
        createdAt: DateTime.now(),
      );

      expect(acceptedOrder.isAccepted, isTrue);
      expect(acceptedOrder.isActive, isTrue);
      expect(acceptedOrder.displayStatus, equals('ACCEPTED'));

      final atStoreOrder = Order(
        id: 103,
        orderNumber: 'ORD-103',
        customerName: 'Bob Brown',
        customerPhone: '0772222222',
        deliveryAddress: 'Nugegoda',
        totalAmount: 3200,
        status: 'at_store',
        createdAt: DateTime.now(),
      );

      expect(atStoreOrder.isAtStore, isTrue);
      expect(atStoreOrder.isActive, isTrue);
      expect(atStoreOrder.displayStatus, equals('AT STORE'));

      final onDeliveryOrder = Order(
        id: 104,
        orderNumber: 'ORD-104',
        customerName: 'Charlie',
        customerPhone: '0773333333',
        deliveryAddress: 'Rajagiriya',
        totalAmount: 4100,
        status: 'on_delivery',
        createdAt: DateTime.now(),
      );

      expect(onDeliveryOrder.isOnDelivery, isTrue);
      expect(onDeliveryOrder.isActive, isTrue);
      expect(onDeliveryOrder.displayStatus, equals('ON DELIVERY'));

      final deliveredOrder = Order(
        id: 105,
        orderNumber: 'ORD-105',
        customerName: 'David',
        customerPhone: '0774444444',
        deliveryAddress: 'Battaramulla',
        totalAmount: 1500,
        status: 'delivered',
        createdAt: DateTime.now(),
      );

      expect(deliveredOrder.isDelivered, isTrue);
      expect(deliveredOrder.isActive, isFalse);
      expect(deliveredOrder.displayStatus, equals('DELIVERED'));
    });

    test('ApiService baseUrl defaults to production API', () {
      expect(ApiService.baseUrl, contains('driver-app-api'));
    });
  });
}
