import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models/customer_info.dart';


class SolydCache {
  // Use a singleton approach or static helper
  static const _storage = FlutterSecureStorage();

  // Namespace keys to avoid collisions
  static String _getKey(String userID) => "solydflow_v1_$userID";
  static String _getTimestampKey(String userID) => "solydflow_v1_time_$userID";

  /// Save Customer Info to Secure Storage
  static Future<void> save(String userID, CustomerInfo info) async {
    try {
      final jsonString = jsonEncode(info.toJson());
      await _storage.write(key: _getKey(userID), value: jsonString);
      // Save Timestamp to manage staleness
      await _storage.write(key: _getTimestampKey(userID), value: DateTime.now().toIso8601String());
    } catch (e) {
      print("SolydFlow Cache Write Error: $e");
    }
  }

  /// Load from Secure Storage
  static Future<CustomerInfo?> load(String userID) async {
    try {
      final jsonString = await _storage.read(key: _getKey(userID));
      if (jsonString == null) return null;

      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return CustomerInfo.fromJson(jsonMap);
    } catch (e) {
      print("SolydFlow Cache Read Error: $e");
      return null;
    }
  }

  /// Check if cache is "Stale" (older than 24 hours)
  static Future<bool> isStale(String userID) async {
    try {
      final timeStr = await _storage.read(key: _getTimestampKey(userID));
      if (timeStr == null) return true; // No timestamp = stale

      final savedTime = DateTime.parse(timeStr);
      final diff = DateTime.now().difference(savedTime);
      return diff.inHours > 24; // Stale after 24 hours
    } catch (e) {
      return true;
    }
  }

  /// Clear specific user cache (useful on logout)
  static Future<void> clear(String userID) async {
    await _storage.delete(key: _getKey(userID));
    await _storage.delete(key: _getTimestampKey(userID));
  }
}
