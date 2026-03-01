import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devicegate/models/device_info.dart';
import '../models/class.dart';
import '../utils/logger.dart';

class FirebaseDataManagement {
  /// Write DeviceInfo to Firestore 'Devices/{serialNumber}/Logs' collection
  /// Creates a new document for each input
  static Future<void> writeDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfo();
      
      // Skip if serialNumber is empty
      if (deviceInfo.serialNumber.isEmpty) {
        log('WriteDeviceInfo skipped: serialNumber is empty');
        return;
      }

      // Update lastInputTime
      deviceInfo.lastInputTime = Timestamp.now();

      log('WriteDeviceInfo: serialNumber=${deviceInfo.serialNumber}, '
          'appDeviceName=${deviceInfo.appDeviceName}, '
          'productName=${deviceInfo.productName}, '
          'sapUser=${deviceInfo.sapUser}');

      // Create new document in Devices/{serialNumber}/Logs subcollection
      await FirebaseFirestore.instance
          .collection('Devices')
          .doc(deviceInfo.serialNumber)
          .collection('Logs')
          .add(deviceInfo.toFirestore());
      
      log('WriteDeviceInfo: Successfully written to Firestore');
    } catch (e, stackTrace) {
      log('WriteDeviceInfo ERROR: $e');
      log('WriteDeviceInfo stackTrace: $stackTrace');
    }
  }




  /// Write an error report to Firestore
  /// 
  /// [errorType] - Type of error (network_error, http_error, devicegate_error, sap_error)
  /// [errorDescription] - Main error description
  /// [errorTitle] - Optional error title for display
  /// [httpStatusCode] - HTTP status code if applicable
  /// [httpStatusMessage] - HTTP status message (e.g., "Internal Server Error")
  /// [url] - URL that caused the error
  /// [serverMessage] - Server response message
  /// [serverTime] - Server time (for SAP errors)
  /// [networkWiFiName] - WiFi network name
  /// [networkWiFiStatus] - WiFi status ("up" or "down")
  /// [networkSignalStrength] - WiFi signal strength
  /// [internetStatus] - Internet connectivity status ("up" or "down")
  /// [stackTrace] - Stack trace for DeviceGate errors
  /// [errorClass] - Error class name for DeviceGate errors

  static Future<void> writeError({
    required ErrorType errorType,
    required String errorDescription,
    String errorTitle = '',
    int? httpStatusCode,
    String httpStatusMessage = '',
    String url = '',
    String serverMessage = '',
    String serverTime = '',
    String networkWiFiName = '',
    String networkWiFiStatus = '',
    String networkSignalStrength = '',
    String internetStatus = '',
    String stackTrace = '',
    String errorClass = '',
  }) async {
    // Get device and user info from DeviceInfo singleton
    final deviceInfo = DeviceInfo();
    String deviceName = deviceInfo.appDeviceName.isNotEmpty ? deviceInfo.appDeviceName : "";
    String productName = deviceInfo.productName.isNotEmpty ? deviceInfo.productName : "";
    String sapUser = deviceInfo.sapUser.isNotEmpty ? deviceInfo.sapUser : "";
    String sapRessource = deviceInfo.sapRessource.isNotEmpty ? deviceInfo.sapRessource : "";

    final errorTypeStr = errorType == ErrorType.networkError ? 'network_error' :
                         errorType == ErrorType.httpError ? 'http_error' :
                         errorType == ErrorType.devicegateError ? 'devicegate_error' : 'sap_error';

    log('WriteError called: type=$errorTypeStr, description=$errorDescription, '
        'httpStatus=$httpStatusCode, url=$url, deviceName=$deviceName, '
        'productName=$productName, sapUser=$sapUser, sapRessource=$sapRessource');

    final report = ErrorReport(
      errorType: errorType,
      errorDescription: errorDescription,
      errorTitle: errorTitle,
      eventTime: Timestamp.now(),
      serverTime: serverTime,
      httpStatusCode: httpStatusCode,
      httpStatusMessage: httpStatusMessage,
      url: url,
      serverMessage: serverMessage,
      networkWiFiName: networkWiFiName,
      networkWiFiStatus: networkWiFiStatus,
      networkSignalStrength: networkSignalStrength,
      internetStatus: internetStatus,
      deviceName: deviceName,
      productName: productName,
      sapUser: sapUser,
      sapRessource: sapRessource,
      stackTrace: stackTrace,
      errorClass: errorClass,
    );

    await FirebaseFirestore.instance
        .collection('ErrorReport')
        .add(report.toFirestore());
  }
}
