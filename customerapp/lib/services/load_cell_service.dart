import 'dart:convert';
import '../models/load_cell.dart';
import 'api_client.dart';

/// Service for handling load cell detection from ESP32 devices
class LoadCellService {
  /// Get current load cell reading for a specific locker
  static Future<LoadCellReading?> getReading(String lockerId) async {
    try {
      final resp = await ApiClient.get(
        '/api/loadcell/reading/$lockerId',
        auth: true,
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['data'] != null) {
          return LoadCellReading.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get load cell events for a specific locker
  static Future<List<LoadCellEvent>> getEvents({
    String? lockerId,
    int limit = 50,
  }) async {
    try {
      final query = <String, dynamic>{
        'limit': limit.toString(),
      };
      if (lockerId != null) {
        query['lockerId'] = lockerId;
      }

      final resp = await ApiClient.get(
        '/api/loadcell/events',
        query: query,
        auth: true,
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data['data'] as List?) ?? [];
        return list.map((e) => LoadCellEvent.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Submit a load cell reading (typically called by ESP32 device)
  /// This endpoint would be called by the backend when ESP32 sends data
  static Future<bool> submitReading({
    required String lockerId,
    required double weight,
    String? deviceId,
  }) async {
    try {
      final resp = await ApiClient.post(
        '/api/loadcell/reading',
        {
          'lockerId': lockerId,
          'weight': weight,
          'deviceId': deviceId,
          'timestamp': DateTime.now().toIso8601String(),
        },
        auth: true,
      );

      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  /// Get the current status based on weight reading
  static LoadCellStatus determineStatus(double weight, {double threshold = 0.1}) {
    if (weight < threshold) {
      return LoadCellStatus.empty;
    }
    return LoadCellStatus.loaded;
  }

  /// Check if locker has package based on load cell reading
  static Future<bool> hasPackage(String lockerId, {double threshold = 0.1}) async {
    final reading = await getReading(lockerId);
    if (reading == null) return false;
    return reading.weight >= threshold;
  }

  /// Get load cell status for multiple lockers
  static Future<Map<String, LoadCellReading>> getBulkReadings(
    List<String> lockerIds,
  ) async {
    try {
      final resp = await ApiClient.post(
        '/api/loadcell/bulk-readings',
        {'lockerIds': lockerIds},
        auth: true,
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final readings = <String, LoadCellReading>{};
        final list = (data['data'] as Map<String, dynamic>?) ?? {};
        
        for (final entry in list.entries) {
          readings[entry.key] = LoadCellReading.fromJson(entry.value);
        }
        return readings;
      }
      return {};
    } catch (e) {
      return {};
    }
  }
}
