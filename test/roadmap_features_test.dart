import 'package:flutter_test/flutter_test.dart';
import 'package:the_menu_driver_app/models/order.dart';
import 'package:the_menu_driver_app/services/location_service.dart';
import 'package:the_menu_driver_app/services/offline_queue_service.dart';

void main() {
  group('Driver Roadmap Features Tests (Without COD)', () {
    test('OfflineQueueAction serializes and deserializes properly', () {
      final action = OfflineQueueAction(
        id: 'action_123',
        orderId: 42,
        actionType: 'complete_delivery',
        payload: {
          'notes': 'Left on doorstep',
          'recipient_name': 'Jane Doe',
          'photo_base64': 'base64testdata',
        },
        timestamp: DateTime(2026, 1, 1, 12, 0, 0),
      );

      final json = action.toJson();
      final revived = OfflineQueueAction.fromJson(json);

      expect(revived.id, 'action_123');
      expect(revived.orderId, 42);
      expect(revived.actionType, 'complete_delivery');
      expect(revived.payload['notes'], 'Left on doorstep');
      expect(revived.payload['recipient_name'], 'Jane Doe');
      expect(revived.payload['photo_base64'], 'base64testdata');
    });

    test('Order POD fields and item verification count', () {
      final order = Order(
        id: 10,
        orderNumber: 'ORD-1010',
        customerName: 'Sam Traveler',
        customerPhone: '0771234567',
        deliveryAddress: '456 Ocean Ave, Colombo',
        totalAmount: 1500.00,
        status: 'on_delivery',
        createdAt: DateTime(2026, 1, 1),
        latitude: 6.9271,
        longitude: 79.8612,
        deliveryNotes: 'Left at reception',
        recipientName: 'Sam',
        proofPhotoBase64: 'base64encodeddummy',
        items: [
          OrderItem(name: 'Burger Combo', quantity: 2),
          OrderItem(name: 'French Fries', quantity: 1),
        ],
      );

      expect(order.isDelivered, isFalse);
      expect(order.deliveryNotes, 'Left at reception');
      expect(order.recipientName, 'Sam');
      expect(order.proofPhotoBase64, 'base64encodeddummy');
      expect(order.items.length, 2);
      expect(order.items[0].isChecked, isFalse);

      order.items[0].isChecked = true;
      expect(order.items.where((i) => i.isChecked).length, 1);
    });

    test('LocationPowerMode provides distinct distance filters and intervals', () {
      expect(LocationPowerMode.highPerformance.distanceFilterMeters, 15);
      expect(LocationPowerMode.highPerformance.telemetryIntervalSeconds, 15);

      expect(LocationPowerMode.balanced.distanceFilterMeters, 50);
      expect(LocationPowerMode.balanced.telemetryIntervalSeconds, 25);

      expect(LocationPowerMode.powerSave.distanceFilterMeters, 0);
      expect(LocationPowerMode.powerSave.telemetryIntervalSeconds, 0);
    });
  });
}
