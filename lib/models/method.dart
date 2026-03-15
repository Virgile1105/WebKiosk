import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'device_info.dart';
import '../services/firebaseDataManagement.dart';

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
    
    // Update Firestore with device info
    final trigger = sapUser.isEmpty ? LogTrigger.logout : LogTrigger.login;
    await FirebaseDataManagement.writeDeviceInfo(trigger: trigger);
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
    
    // Check if the ressource has actually changed
    final currentRessource = prefs.getString('sap_ressource') ?? '';
    if (currentRessource == sapRessource) {
      log('SAP ressource unchanged, skipping save: $sapRessource');
      return;
    }
    
    await prefs.setString('sap_ressource', sapRessource);
    // Also update the DeviceInfo singleton
    final deviceInfo = DeviceInfo();
    deviceInfo.sapRessource = sapRessource;
    // Log to Firebase
    await FirebaseDataManagement.writeDeviceInfo(trigger: LogTrigger.newRessource);
    log('SAP ressource saved: $sapRessource');
  } catch (error) {
    log('Error saving SAP ressource: $error');
  }
}

Future<bool> loadUseCustomKeyboard() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('use_custom_keyboard') ?? false;
  } catch (e) {
    log('Error loading useCustomKeyboard: $e');
    return false;
  }
}

Future<void> saveUseCustomKeyboard(bool value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_custom_keyboard', value);
    final deviceInfo = DeviceInfo();
    deviceInfo.useCustomKeyboard = value;
  } catch (error) {
    log('Error saving useCustomKeyboard: $error');
  }
}

Future<bool> loadDisableCopyPaste() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('disable_copy_paste') ?? false;
  } catch (e) {
    log('Error loading disableCopyPaste: $e');
    return false;
  }
}

Future<void> saveDisableCopyPaste(bool value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('disable_copy_paste', value);
    final deviceInfo = DeviceInfo();
    deviceInfo.disableCopyPaste = value;
  } catch (error) {
    log('Error saving disableCopyPaste: $error');
  }
}

Future<bool> loadEnableWarningSound() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('enable_warning_sound') ?? false;
  } catch (e) {
    log('Error loading enableWarningSound: $e');
    return false;
  }
}

Future<void> saveEnableWarningSound(bool value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_warning_sound', value);
    final deviceInfo = DeviceInfo();
    deviceInfo.enableWarningSound = value;
  } catch (error) {
    log('Error saving enableWarningSound: $error');
  }
}
