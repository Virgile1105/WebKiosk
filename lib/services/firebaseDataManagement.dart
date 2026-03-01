import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devicegate/models/device_info.dart';
import '../models/class.dart';
import 'package:flutter/material.dart';
import '../utils/logger.dart';

class FirebaseDataManagement {
  static Future<void> writeNetworkIssue({
    required String networkWiFiName,
    required String networkWiFiStatus,
    required String networSignalStrength,
    required String internetStatus,
    required String errorDescription,
    BuildContext? context,
  }) async {
    // Get device name and product name
    String deviceName = DeviceInfo().appDeviceName.isNotEmpty ? DeviceInfo().appDeviceName : "";
    String productName = DeviceInfo().productName.isNotEmpty ? DeviceInfo().productName: "";
   
     log('WriteNetworkIssue called with: WiFiName=$networkWiFiName, WiFiStatus=$networkWiFiStatus, SignalStrength=$networSignalStrength, InternetStatus=$internetStatus, ErrorDescription=$errorDescription, DeviceName=$deviceName, ProductName=$productName');

    final event = NetworkIssue(
      networkWiFiName: networkWiFiName,
      networkWiFiStatus: networkWiFiStatus,
      networSignalStrength: networSignalStrength,
      internetStatus: internetStatus,
      eventTime: Timestamp.now(),
      deviceName: deviceName,
      productName: productName,
      errorDescription: errorDescription,
    );
    await FirebaseFirestore.instance
        .collection('NetworkIssue')
        .add(event.toFirestore());
  }
}
