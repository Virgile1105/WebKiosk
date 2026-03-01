import 'package:cloud_firestore/cloud_firestore.dart';

class NetworkIssue {
  final String networkWiFiName;
  final String networkWiFiStatus;
  final String networSignalStrength;
  final String internetStatus;
  final String errorDescription;
  final Timestamp eventTime;
  final String deviceName;
  final String productName;

  NetworkIssue({
    required this.networkWiFiName,
    required this.networkWiFiStatus,
    required this.networSignalStrength,
    required this.internetStatus,
    required this.errorDescription,
    required this.eventTime,
    required this.deviceName,
    required this.productName,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'networkWiFiName': networkWiFiName,
      'networkWiFiStatus': networkWiFiStatus,
      'networSignalStrength': networSignalStrength,
      'internetStatus': internetStatus,
      'errorDescription': errorDescription,
      'eventTime': eventTime,
      'deviceName': deviceName,
      'productName': productName,
    };
  }
}
