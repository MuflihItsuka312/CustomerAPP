/// Data model for app notifications
class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? data;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: NotificationType.fromString(json['type']?.toString() ?? 'general'),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now(),
      isRead: json['isRead'] == true,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.value,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'data': data,
    };
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }
}

/// Notification types
enum NotificationType {
  lockerOpened('locker_opened'),
  lockerClosed('locker_closed'),
  packageDelivered('package_delivered'),
  packagePickedUp('package_picked_up'),
  loadCellAlert('load_cell_alert'),
  general('general');

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.general,
    );
  }
}

/// Model for locker opened notification data
class LockerOpenedData {
  final String lockerId;
  final String? customerId;
  final String? customerName;
  final DateTime timestamp;
  final String? loadCellStatus;
  final double? currentWeight;

  LockerOpenedData({
    required this.lockerId,
    this.customerId,
    this.customerName,
    required this.timestamp,
    this.loadCellStatus,
    this.currentWeight,
  });

  factory LockerOpenedData.fromJson(Map<String, dynamic> json) {
    return LockerOpenedData(
      lockerId: json['lockerId']?.toString() ?? '',
      customerId: json['customerId']?.toString(),
      customerName: json['customerName']?.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now(),
      loadCellStatus: json['loadCellStatus']?.toString(),
      currentWeight: (json['currentWeight'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lockerId': lockerId,
      'customerId': customerId,
      'customerName': customerName,
      'timestamp': timestamp.toIso8601String(),
      'loadCellStatus': loadCellStatus,
      'currentWeight': currentWeight,
    };
  }
}
