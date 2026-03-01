import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'device_info.dart';

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

Future<String> loadSapUser() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sap_user') ?? '';
  } catch (e) {
    log('Error loading SAP user: $e');
    return '';
  }
}

Future<void> saveSapUser(String sapUser) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sap_user', sapUser);
    // Also update the DeviceInfo singleton
    final deviceInfo = DeviceInfo();
    deviceInfo.sapUser = sapUser;
    log('SAP user saved: $sapUser');
  } catch (error) {
    log('Error saving SAP user: $error');
  }
}

Future<String> loadSapRessource() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sap_ressource') ?? '';
  } catch (e) {
    log('Error loading SAP ressource: $e');
    return '';
  }
}

Future<void> saveSapRessource(String sapRessource) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sap_ressource', sapRessource);
    // Also update the DeviceInfo singleton
    final deviceInfo = DeviceInfo();
    deviceInfo.sapRessource = sapRessource;
    log('SAP ressource saved: $sapRessource');
  } catch (error) {
    log('Error saving SAP ressource: $error');
  }
}
