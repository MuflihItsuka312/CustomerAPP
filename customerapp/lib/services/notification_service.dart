import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  bool _initialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('[NOTIFICATION] User granted permission');
      } else {
        print('[NOTIFICATION] User declined or has not accepted permission');
      }
    } catch (e) {
      print('[NOTIFICATION] Error requesting permissions: $e');
      return; // Exit if Firebase is not configured
    }

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'smart_locker_channel',
      'Smart Locker Notifications',
      description: 'Notifications for locker events and package updates',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundNotificationTap);

    // Get FCM token
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      print('[NOTIFICATION] FCM Token: $token');
      await _saveFcmToken(token);
    }

    // Listen to token refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveFcmToken);

    _initialized = true;
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('[NOTIFICATION] Foreground message: ${message.notification?.title}');

    final notification = message.notification;

    if (notification != null) {
      await _showLocalNotification(
        id: message.hashCode,
        title: notification.title ?? 'Smart Locker',
        body: notification.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// Handle notification tap when app is in background
  void _handleBackgroundNotificationTap(RemoteMessage message) {
    print('[NOTIFICATION] Background notification tapped: ${message.data}');
    // Navigate to appropriate page based on message data
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('[NOTIFICATION] Notification tapped: ${response.payload}');
    // Navigate to appropriate page based on payload
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'smart_locker_channel',
      'Smart Locker Notifications',
      channelDescription: 'Notifications for locker events and package updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  /// Show notification for locker opened
  Future<void> showLockerOpenedNotification({
    required String resi,
    required String lockerId,
  }) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🔓 Loker Terbuka',
      body: 'Loker $lockerId untuk paket $resi telah dibuka',
      payload: 'locker_opened:$resi',
    );
  }

  /// Show notification for locker closed
  Future<void> showLockerClosedNotification({
    required String resi,
    required String lockerId,
  }) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🔒 Loker Tertutup',
      body: 'Loker $lockerId untuk paket $resi telah ditutup',
      payload: 'locker_closed:$resi',
    );
  }

  /// Show notification for package detected (load cell)
  Future<void> showPackageDetectedNotification({
    required String resi,
    required String lockerId,
    required double weight,
  }) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '📦 Paket Terdeteksi',
      body: 'Paket $resi (${weight.toStringAsFixed(1)} kg) terdeteksi di loker $lockerId',
      payload: 'package_detected:$resi',
    );
  }

  /// Show notification for package removed (load cell)
  Future<void> showPackageRemovedNotification({
    required String resi,
    required String lockerId,
  }) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '✅ Paket Diambil',
      body: 'Paket $resi telah diambil dari loker $lockerId',
      payload: 'package_removed:$resi',
    );
  }

  /// Show notification for package delivered
  Future<void> showPackageDeliveredNotification({
    required String resi,
    required String lockerId,
  }) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🎉 Paket Diterima',
      body: 'Paket $resi telah diterima di loker $lockerId. Silakan ambil paket Anda!',
      payload: 'package_delivered:$resi',
    );
  }

  /// Save FCM token
  Future<void> _saveFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    print('[NOTIFICATION] FCM Token saved: $token');
  }

  /// Get FCM token
  Future<String?> getFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    print('[NOTIFICATION] Subscribed to topic: $topic');
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    print('[NOTIFICATION] Unsubscribed from topic: $topic');
  }
}

/// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('[NOTIFICATION] Background message: ${message.notification?.title}');
}
