import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class OfflineQueueAction {
  final String id;
  final int? orderId;
  final String actionType;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  OfflineQueueAction({
    required this.id,
    this.orderId,
    required this.actionType,
    required this.payload,
    required this.timestamp,
  });

  factory OfflineQueueAction.fromJson(Map<String, dynamic> json) {
    return OfflineQueueAction(
      id: json['id']?.toString() ?? 'action_${DateTime.now().millisecondsSinceEpoch}',
      orderId: json['order_id'] is int ? json['order_id'] : int.tryParse(json['order_id']?.toString() ?? ''),
      actionType: json['type']?.toString() ?? json['action_type']?.toString() ?? 'status_update',
      payload: json['payload'] is Map ? Map<String, dynamic>.from(json['payload']) : {},
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'type': actionType,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
      };
}

class OfflineQueueService {
  static const String _storageKey = 'offline_pending_actions';
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  Future<void> init() async {
    final count = await getPendingCount();
    pendingCountNotifier.value = count;
  }

  /// Get pending queue from SharedPreferences
  Future<List<Map<String, dynamic>>> getQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      if (kDebugMode) print('Error reading offline queue: $e');
    }
    return [];
  }

  Future<int> getPendingCount() async {
    final queue = await getQueue();
    return queue.length;
  }

  /// Enqueue an action when device is offline
  Future<void> enqueueAction({
    required String type,
    required Map<String, dynamic> payload,
    int? orderId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = await getQueue();

      final action = OfflineQueueAction(
        id: 'act_${DateTime.now().millisecondsSinceEpoch}',
        orderId: orderId,
        actionType: type,
        payload: payload,
        timestamp: DateTime.now(),
      );

      queue.add(action.toJson());

      await prefs.setString(_storageKey, jsonEncode(queue));
      pendingCountNotifier.value = queue.length;
      if (kDebugMode) {
        print('Offline action enqueued: $type (Pending: ${queue.length})');
      }
    } catch (e) {
      if (kDebugMode) print('Error enqueuing offline action: $e');
    }
  }

  /// Sync all queued actions when connection is restored
  Future<int> syncPendingActions(String token, ApiService api) async {
    final queue = await getQueue();
    if (queue.isEmpty) return 0;

    int syncedCount = 0;
    final List<Map<String, dynamic>> remainingQueue = [];

    for (final item in queue) {
      final action = OfflineQueueAction.fromJson(item);
      final payload = action.payload;

      bool success = false;
      try {
        if (action.actionType == 'status_update' || action.actionType == 'complete_delivery') {
          final res = await api.updateOrderStatus(
            token: token,
            orderId: action.orderId ?? (payload['order_id'] as int? ?? 0),
            status: payload['status'] as String? ?? 'delivered',
            reason: payload['reason'] as String?,
            notes: payload['notes'] as String?,
            photoBase64: payload['photo_base64'] as String?,
            recipientName: payload['recipient_name'] as String?,
          );
          success = res['success'] == true;
        } else if (action.actionType == 'telemetry') {
          success = await api.sendDriverTelemetry(
            token: token,
            latitude: (payload['latitude'] as num).toDouble(),
            longitude: (payload['longitude'] as num).toDouble(),
            heading: (payload['heading'] as num?)?.toDouble(),
            speed: (payload['speed'] as num?)?.toDouble(),
            accuracy: (payload['accuracy'] as num?)?.toDouble(),
          );
        }
      } catch (e) {
        success = false;
      }

      if (success) {
        syncedCount++;
      } else {
        remainingQueue.add(item);
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (remainingQueue.isEmpty) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setString(_storageKey, jsonEncode(remainingQueue));
      }
      pendingCountNotifier.value = remainingQueue.length;
    } catch (_) {}

    return syncedCount;
  }
}
