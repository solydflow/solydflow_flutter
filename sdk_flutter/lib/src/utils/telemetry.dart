import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';

class SolydTelemetry {
  static Future<Map<String, dynamic>> collect() async {
    // 1. Network Type
    String netType = 'unknown';
    try {
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.contains(ConnectivityResult.mobile)) netType = 'mobile';
      else if (connectivityResult.contains(ConnectivityResult.wifi)) netType = 'wifi';
      else if (connectivityResult.contains(ConnectivityResult.none)) netType = 'none';
    } catch (_) {}

    // 2. Latency (Ping) - The most important metric for Africa
    int latency = 0;
    try {
      final stopwatch = Stopwatch()..start();
      // Ping Cloudflare DNS (fast & reliable globally)
      await InternetAddress.lookup('1.1.1.1'); 
      stopwatch.stop();
      latency = stopwatch.elapsedMilliseconds;
    } catch (_) {
      latency = -1; // Offline
    }

    // 3. Device Info
    String os = Platform.isAndroid ? 'android' : 'ios';
    String model = 'unknown';
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        model = "${androidInfo.brand} ${androidInfo.model}";
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        model = iosInfo.utsname.machine;
      }
    } catch (_) {}

    // 4. Battery
    int battery = 0;
    try {
      battery = await Battery().batteryLevel;
    } catch (_) {}

    return {
      "network_type": netType,
      "latency_ms": latency,
      "device_os": os,
      "device_model": model,
      "battery_level": battery
    };
  }
}
