import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

Future<String> loadAppVersion() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  } catch (e) {
    log('Error fetching app version: $e');
    return 'Unknown';
  }
}

Future<String> loadAppDeviceName() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_name') ?? 'DeviceGate';
  } catch (e) {
    log('Error loading device name: $e');
    return 'DeviceGate';
  }
}

Future<void> saveAppDeviceName(String name) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_name', name);
  } catch (error) {
    log('Error saving device name: $error');
  }
}
