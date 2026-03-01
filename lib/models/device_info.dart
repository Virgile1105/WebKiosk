import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'method.dart';

/// SAP EWM usage status
enum SapStatus {
  active,   // User is actively using SAP EWM (0 min)
  slow,     // No page change for 5+ minutes
  idle,     // No page change for 10+ minutes
  paused,   // No page change for 15+ minutes
  dormant,  // No page change for 20+ minutes
  inactive, // No page change for 30+ minutes
  off,      // User left SAP EWM
}

class DeviceInfo {
  static final DeviceInfo _instance = DeviceInfo._internal();
  factory DeviceInfo() => _instance;
  DeviceInfo._internal();

  String manufacturer = '';
  String model = '';
  String deviceName = '';
  String serialNumber = '';
  String androidVersion = '';
  String securityPatch = '';
  String appVersion = '';
  String appDeviceName = '';
  String sapUser = '';
  String sapRessource = '';
  Timestamp? lastInputTime;
  SapStatus sapStatus = SapStatus.off;
  DateTime? lastPageChangeTime;
  /// List of paired Bluetooth devices with their connection status
  /// Each entry: {'name': 'Device Name', 'status': 'connected' | 'not connected'}
  List<Map<String, String>> bluetoothDevices = [];

  Future<void> loadFromPlatform() async {
    const platform = MethodChannel('devicegate.app/shortcut');
    try {
      final deviceModel = await platform.invokeMethod('getDeviceModel');
      if (deviceModel != null && deviceModel is Map) {
        manufacturer = deviceModel['manufacturer'] ?? '';
        model = deviceModel['model'] ?? '';
        deviceName = deviceModel['deviceName'] ?? '';
        serialNumber = deviceModel['serialNumber'] ?? '';
        androidVersion = deviceModel['androidVersion'] ?? '';
        securityPatch = deviceModel['securityPatch'] ?? '';
      }
    } catch (_) {}

    // Load app version and device name from shared preferences
    appVersion = await loadAppVersion();
    appDeviceName = await loadAppDeviceName();
    sapUser = await loadSapUser();
    sapRessource = await loadSapRessource();
  }

  String get productName => (manufacturer + ' ' + model).trim();

  /// Convert DeviceInfo to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'manufacturer': manufacturer,
      'model': model,
      'deviceName': deviceName,
      'serialNumber': serialNumber,
      'androidVersion': androidVersion,
      'securityPatch': securityPatch,
      'appVersion': appVersion,
      'appDeviceName': appDeviceName,
      'sapUser': sapUser,
      'sapRessource': sapRessource,
      'productName': productName,
      'lastInputTime': lastInputTime ?? Timestamp.now(),
      'sapStatus': sapStatus.name,
      'bluetoothDevices': bluetoothDevices,
    };
  }
}
