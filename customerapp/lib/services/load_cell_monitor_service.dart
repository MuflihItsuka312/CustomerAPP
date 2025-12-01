import 'dart:async';
import 'dart:convert';
import 'notification_service.dart';
import 'api_client.dart';

class LoadCellMonitorService {
  static final LoadCellMonitorService _instance = LoadCellMonitorService._internal();
  factory LoadCellMonitorService() => _instance;
  LoadCellMonitorService._internal();

  Timer? _pollingTimer;
  bool _isMonitoring = false;
  Map<String, dynamic>? _lastShipment;

  /// Start monitoring load cell changes
  void startMonitoring() {
    if (_isMonitoring) return;

    print('[LOAD_CELL] Starting monitoring...');
    _isMonitoring = true;

    // Poll every 5 seconds for shipment updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkLoadCellUpdates();
    });
  }

  /// Stop monitoring
  void stopMonitoring() {
    print('[LOAD_CELL] Stopping monitoring...');
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isMonitoring = false;
  }

  /// Check for load cell updates
  Future<void> _checkLoadCellUpdates() async {
    try {
      final resp = await ApiClient.get('/api/customer/shipments', auth: true);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data['data'] as List?) ?? [];

        if (list.isNotEmpty) {
          final currentShipment = list.first as Map<String, dynamic>;
          
          // Check if this is a new shipment or status changed
          if (_lastShipment != null) {
            await _detectChanges(_lastShipment!, currentShipment);
          }

          _lastShipment = currentShipment;
        }
      }
    } catch (e) {
      print('[LOAD_CELL] Error checking updates: $e');
    }
  }

  /// Detect changes between shipments
  Future<void> _detectChanges(
    Map<String, dynamic> oldShipment,
    Map<String, dynamic> newShipment,
  ) async {
    final oldWeight = oldShipment['weight'] as double?;
    final newWeight = newShipment['weight'] as double?;
    final oldStatus = oldShipment['status'] as String?;
    final newStatus = newShipment['status'] as String?;
    final lockerStatus = newShipment['lockerStatus'] as String?;

    final resi = newShipment['resi'] as String;
    final lockerId = newShipment['lockerId'] as String? ?? 'Unknown';

    // Weight changed - package detected or removed
    if (oldWeight != newWeight && newWeight != null) {
      if (newWeight > 0 && (oldWeight == null || oldWeight == 0)) {
        // Package detected (placed in locker)
        print('[LOAD_CELL] Package detected: $resi, weight: $newWeight kg');
        await NotificationService().showPackageDetectedNotification(
          resi: resi,
          lockerId: lockerId,
          weight: newWeight,
        );
      } else if (newWeight == 0 && oldWeight != null && oldWeight > 0) {
        // Package removed (taken from locker)
        print('[LOAD_CELL] Package removed: $resi');
        await NotificationService().showPackageRemovedNotification(
          resi: resi,
          lockerId: lockerId,
        );
      }
    }

    // Status changed to delivered
    if (oldStatus != newStatus && newStatus == 'delivered') {
      print('[LOAD_CELL] Package delivered: $resi');
      await NotificationService().showPackageDeliveredNotification(
        resi: resi,
        lockerId: lockerId,
      );
    }

    // Locker status changed
    if (oldShipment['lockerStatus'] != lockerStatus) {
      if (lockerStatus == 'open') {
        print('[LOAD_CELL] Locker opened: $lockerId');
        await NotificationService().showLockerOpenedNotification(
          resi: resi,
          lockerId: lockerId,
        );
      } else if (lockerStatus == 'closed') {
        print('[LOAD_CELL] Locker closed: $lockerId');
        await NotificationService().showLockerClosedNotification(
          resi: resi,
          lockerId: lockerId,
        );
      }
    }
  }

  /// Check if monitoring is active
  bool get isMonitoring => _isMonitoring;
}
