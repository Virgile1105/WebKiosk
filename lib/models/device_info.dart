import 'package:flutter/services.dart';
import 'method.dart';

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
  }

  String get productName => (manufacturer + ' ' + model).trim();
}
