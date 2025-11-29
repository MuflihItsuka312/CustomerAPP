import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification.dart';
import 'api_client.dart';

/// Service for handling in-app notifications and push notification infrastructure
class NotificationService {
  static const String _notificationsKey = 'notifications';
  static const String _fcmTokenKey = 'fcm_token';
  
  // Stream controller for notification updates
  static final StreamController<List<AppNotification>> _notificationController =
      StreamController<List<AppNotification>>.broadcast();
  
  /// Stream of notifications for listening to updates
  static Stream<List<AppNotification>> get notificationStream =>
      _notificationController.stream;

  // In-memory cache of notifications
  static List<AppNotification> _notifications = [];

  /// Initialize the notification service
  static Future<void> initialize() async {
    await _loadNotificationsFromStorage();
  }

  /// Load notifications from local storage
  static Future<void> _loadNotificationsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_notificationsKey);
      if (stored != null) {
        final list = jsonDecode(stored) as List;
        _notifications = list.map((e) => AppNotification.fromJson(e)).toList();
        _notificationController.add(_notifications);
      }
    } catch (e) {
      _notifications = [];
    }
  }

  /// Save notifications to local storage
  static Future<void> _saveNotificationsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _notifications.map((n) => n.toJson()).toList();
      await prefs.setString(_notificationsKey, jsonEncode(jsonList));
    } catch (e) {
      // Handle storage error silently
    }
  }

  /// Get all notifications
  static List<AppNotification> getNotifications() {
    return List.unmodifiable(_notifications);
  }

  /// Get unread notification count
  static int getUnreadCount() {
    return _notifications.where((n) => !n.isRead).length;
  }

  /// Add a new notification locally
  static Future<void> addNotification(AppNotification notification) async {
    _notifications.insert(0, notification);
    
    // Keep only last 100 notifications
    if (_notifications.length > 100) {
      _notifications = _notifications.take(100).toList();
    }
    
    _notificationController.add(_notifications);
    await _saveNotificationsToStorage();
  }

  /// Mark a notification as read
  static Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _notificationController.add(_notifications);
      await _saveNotificationsToStorage();
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead() async {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _notificationController.add(_notifications);
    await _saveNotificationsToStorage();
  }

  /// Clear all notifications
  static Future<void> clearAll() async {
    _notifications = [];
    _notificationController.add(_notifications);
    await _saveNotificationsToStorage();
  }

  /// Delete a specific notification
  static Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    _notificationController.add(_notifications);
    await _saveNotificationsToStorage();
  }

  /// Fetch notifications from server
  static Future<List<AppNotification>> fetchFromServer() async {
    try {
      final resp = await ApiClient.get('/api/notifications', auth: true);
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data['data'] as List?) ?? [];
        final serverNotifications = list.map((e) => AppNotification.fromJson(e)).toList();
        
        // Merge with local notifications
        for (final notification in serverNotifications) {
          final existingIndex = _notifications.indexWhere((n) => n.id == notification.id);
          if (existingIndex == -1) {
            _notifications.add(notification);
          }
        }
        
        // Sort by timestamp descending
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        _notificationController.add(_notifications);
        await _saveNotificationsToStorage();
        
        return _notifications;
      }
      return _notifications;
    } catch (e) {
      return _notifications;
    }
  }

  /// Create a locker opened notification
  static Future<void> notifyLockerOpened({
    required String lockerId,
    String? customerId,
    String? customerName,
    String? loadCellStatus,
    double? currentWeight,
  }) async {
    final notification = AppNotification(
      id: 'locker_${lockerId}_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Locker Opened',
      body: 'Locker $lockerId has been opened${customerName != null ? ' by $customerName' : ''}',
      type: NotificationType.lockerOpened,
      timestamp: DateTime.now(),
      data: {
        'lockerId': lockerId,
        'customerId': customerId,
        'customerName': customerName,
        'loadCellStatus': loadCellStatus,
        'currentWeight': currentWeight,
      },
    );
    
    await addNotification(notification);
  }

  /// Create a package delivered notification
  static Future<void> notifyPackageDelivered({
    required String lockerId,
    required String resi,
    String? courierType,
  }) async {
    final notification = AppNotification(
      id: 'delivery_${lockerId}_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Package Delivered',
      body: 'Package $resi has been delivered to locker $lockerId',
      type: NotificationType.packageDelivered,
      timestamp: DateTime.now(),
      data: {
        'lockerId': lockerId,
        'resi': resi,
        'courierType': courierType,
      },
    );
    
    await addNotification(notification);
  }

  /// Create a load cell alert notification
  static Future<void> notifyLoadCellAlert({
    required String lockerId,
    required String message,
    double? weight,
  }) async {
    final notification = AppNotification(
      id: 'loadcell_${lockerId}_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Load Cell Alert',
      body: message,
      type: NotificationType.loadCellAlert,
      timestamp: DateTime.now(),
      data: {
        'lockerId': lockerId,
        'weight': weight,
      },
    );
    
    await addNotification(notification);
  }

  /// Save FCM token for push notifications
  static Future<void> saveFcmToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fcmTokenKey, token);
      
      // Register token with backend
      await ApiClient.post(
        '/api/notifications/register-token',
        {'fcmToken': token},
        auth: true,
      );
    } catch (e) {
      // Handle error silently
    }
  }

  /// Get stored FCM token
  static Future<String?> getFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fcmTokenKey);
  }

  /// Dispose the service
  static void dispose() {
    _notificationController.close();
  }
}

/// Widget to display notification badge
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final int count;
  final Color? badgeColor;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.count,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -8,
          top: -8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: badgeColor ?? Colors.red,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(
              minWidth: 18,
              minHeight: 18,
            ),
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
