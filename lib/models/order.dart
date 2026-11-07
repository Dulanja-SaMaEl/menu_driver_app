class OrderItem {
  final String name;
  final int quantity;
  final String? notes;
  bool isChecked;

  OrderItem({
    required this.name,
    this.quantity = 1,
    this.notes,
    this.isChecked = false,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: (json['name'] ?? json['item_name'] ?? json['title'] ?? 'Menu Item').toString(),
      quantity: json['quantity'] is int
          ? json['quantity']
          : int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'notes': notes,
      };
}

class Order {
  final int id;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double? latitude;
  final double? longitude;
  final double totalAmount;
  final String status;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String? deliveryNotes;
  final String? proofPhotoBase64;
  final String? recipientName;

  Order({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    this.latitude,
    this.longitude,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    List<OrderItem>? items,
    this.deliveryNotes,
    this.proofPhotoBase64,
    this.recipientName,
  }) : items = items ?? [OrderItem(name: 'FreshBox Meal Order (Packed)', quantity: 1)];

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude != 0.0 &&
      longitude != 0.0;

  bool get isActive {
    final s = status.toLowerCase();
    return s == 'assigned' ||
        s == 'accepted' ||
        s == 'at_store' ||
        s == 'picked_up' ||
        s == 'on_delivery';
  }

  bool get isAssigned => status.toLowerCase() == 'assigned';
  bool get isAccepted => status.toLowerCase() == 'accepted';
  bool get isAtStore => status.toLowerCase() == 'at_store';
  bool get isOnDelivery =>
      status.toLowerCase() == 'on_delivery' ||
      status.toLowerCase() == 'picked_up';
  bool get isDelivered => status.toLowerCase() == 'delivered';
  bool get isCancelled =>
      status.toLowerCase() == 'cancelled' ||
      status.toLowerCase() == 'failed' ||
      status.toLowerCase() == 'rejected';

  String get displayStatus {
    switch (status.toLowerCase()) {
      case 'assigned':
        return 'NEW DISPATCH';
      case 'accepted':
        return 'ACCEPTED';
      case 'at_store':
        return 'AT STORE';
      case 'picked_up':
      case 'on_delivery':
        return 'ON DELIVERY';
      case 'delivered':
        return 'DELIVERED';
      case 'cancelled':
      case 'failed':
      case 'rejected':
        return 'CANCELLED';
      default:
        return status.toUpperCase().replaceAll('_', ' ');
    }
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? rawItems = json['items'] ?? json['order_items'];
    final List<OrderItem> parsedItems;
    if (rawItems != null && rawItems.isNotEmpty) {
      parsedItems = rawItems
          .map((item) => OrderItem.fromJson(
              item is Map<String, dynamic> ? item : {'name': item.toString()}))
          .toList();
    } else {
      parsedItems = [OrderItem(name: 'FreshBox Meal Order (Packed)', quantity: 1)];
    }

    return Order(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      orderNumber: (json['order_number'] ??
              json['order_no'] ??
              json['code'] ??
              'ORD-${json['id']}')
          .toString(),
      customerName: (json['customer_name'] ??
              json['customer']?['name'] ??
              json['name'] ??
              'Customer')
          .toString(),
      customerPhone: (json['customer_phone'] ??
              json['customer']?['phone'] ??
              json['phone'] ??
              '-')
          .toString(),
      deliveryAddress:
          (json['delivery_address'] ?? json['address'] ?? 'Delivery Address')
              .toString(),
      latitude: double.tryParse(
          (json['latitude'] ?? json['lat'] ?? json['delivery_latitude'] ?? '')
              .toString()),
      longitude: double.tryParse(
          (json['longitude'] ?? json['lng'] ?? json['delivery_longitude'] ?? '')
              .toString()),
      totalAmount: double.tryParse(
              json['total_amount']?.toString() ??
                  json['total']?.toString() ??
                  '0') ??
          0.0,
      status: (json['status'] ?? 'assigned').toString().toLowerCase(),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ??
              DateTime.now())
          : DateTime.now(),
      items: parsedItems,
      deliveryNotes: json['delivery_notes']?.toString(),
      proofPhotoBase64: json['proof_photo_base64']?.toString(),
      recipientName: json['recipient_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      'latitude': latitude,
      'longitude': longitude,
      'total_amount': totalAmount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'items': items.map((i) => i.toJson()).toList(),
      'delivery_notes': deliveryNotes,
      'proof_photo_base64': proofPhotoBase64,
      'recipient_name': recipientName,
    };
  }
}
