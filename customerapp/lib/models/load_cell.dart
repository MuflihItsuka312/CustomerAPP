/// Data model for load cell readings from ESP32 devices
class LoadCellReading {
  final String id;
  final String lockerId;
  final double weight;
  final DateTime timestamp;
  final String? deviceId;
  final LoadCellStatus status;

  LoadCellReading({
    required this.id,
    required this.lockerId,
    required this.weight,
    required this.timestamp,
    this.deviceId,
    required this.status,
  });

  factory LoadCellReading.fromJson(Map<String, dynamic> json) {
    return LoadCellReading(
      id: json['id']?.toString() ?? '',
      lockerId: json['lockerId']?.toString() ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now(),
      deviceId: json['deviceId']?.toString(),
      status: LoadCellStatus.fromString(json['status']?.toString() ?? 'unknown'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lockerId': lockerId,
      'weight': weight,
      'timestamp': timestamp.toIso8601String(),
      'deviceId': deviceId,
      'status': status.value,
    };
  }
}

/// Status enum for load cell detection
enum LoadCellStatus {
  empty('empty'),
  loaded('loaded'),
  weightChanged('weight_changed'),
  error('error'),
  unknown('unknown');

  final String value;
  const LoadCellStatus(this.value);

  static LoadCellStatus fromString(String value) {
    return LoadCellStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => LoadCellStatus.unknown,
    );
  }
}

/// Model for load cell events (when package is placed/removed)
class LoadCellEvent {
  final String id;
  final String lockerId;
  final String? customerId;
  final LoadCellEventType eventType;
  final double weightBefore;
  final double weightAfter;
  final DateTime timestamp;
  final String? shipmentId;

  LoadCellEvent({
    required this.id,
    required this.lockerId,
    this.customerId,
    required this.eventType,
    required this.weightBefore,
    required this.weightAfter,
    required this.timestamp,
    this.shipmentId,
  });

  factory LoadCellEvent.fromJson(Map<String, dynamic> json) {
    return LoadCellEvent(
      id: json['id']?.toString() ?? '',
      lockerId: json['lockerId']?.toString() ?? '',
      customerId: json['customerId']?.toString(),
      eventType: LoadCellEventType.fromString(json['eventType']?.toString() ?? 'unknown'),
      weightBefore: (json['weightBefore'] as num?)?.toDouble() ?? 0.0,
      weightAfter: (json['weightAfter'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now(),
      shipmentId: json['shipmentId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lockerId': lockerId,
      'customerId': customerId,
      'eventType': eventType.value,
      'weightBefore': weightBefore,
      'weightAfter': weightAfter,
      'timestamp': timestamp.toIso8601String(),
      'shipmentId': shipmentId,
    };
  }
}

/// Event types for load cell detection
enum LoadCellEventType {
  packagePlaced('package_placed'),
  packageRemoved('package_removed'),
  weightChange('weight_change'),
  unknown('unknown');

  final String value;
  const LoadCellEventType(this.value);

  static LoadCellEventType fromString(String value) {
    return LoadCellEventType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => LoadCellEventType.unknown,
    );
  }
}
