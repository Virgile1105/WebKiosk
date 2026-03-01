import 'package:cloud_firestore/cloud_firestore.dart';

/// Error types for categorizing different error sources
enum ErrorType {
  networkError,    // Network/WiFi connectivity issues
  httpError,       // HTTP status code errors (4xx, 5xx)
  devicegateError, // Internal DeviceGate app errors
  sapError,        // SAP-specific server errors
}

/// Comprehensive error report class for logging all types of errors to Firestore
class ErrorReport {
  // Error identification
  final ErrorType errorType;
  final String errorDescription;
  final String errorTitle;
  
  // Timing
  final Timestamp eventTime;
  final String serverTime;          // SAP server time if available
  
  // HTTP details
  final int? httpStatusCode;        // HTTP status code (e.g., 500, 404)
  final String httpStatusMessage;   // HTTP status message (e.g., "Internal Server Error")
  final String url;                 // URL that caused the error
  final String serverMessage;       // Server response message
  
  // Network status at time of error
  final String networkWiFiName;
  final String networkWiFiStatus;   // "up" or "down"
  final String networkSignalStrength;
  final String internetStatus;      // "up" or "down"
  
  // Device information
  final String deviceName;
  final String productName;
  
  // User context
  final String sapUser;
  final String sapRessource;
  
  // Technical details (for DeviceGate errors)
  final String stackTrace;
  final String errorClass;          // Error class/type name

  ErrorReport({
    required this.errorType,
    required this.errorDescription,
    this.errorTitle = '',
    required this.eventTime,
    this.serverTime = '',
    this.httpStatusCode,
    this.httpStatusMessage = '',
    this.url = '',
    this.serverMessage = '',
    this.networkWiFiName = '',
    this.networkWiFiStatus = '',
    this.networkSignalStrength = '',
    this.internetStatus = '',
    this.deviceName = '',
    this.productName = '',
    this.sapUser = '',
    this.sapRessource = '',
    this.stackTrace = '',
    this.errorClass = '',
  });

  String get errorTypeString {
    switch (errorType) {
      case ErrorType.networkError:
        return 'network_error';
      case ErrorType.httpError:
        return 'http_error';
      case ErrorType.devicegateError:
        return 'devicegate_error';
      case ErrorType.sapError:
        return 'sap_error';
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'errorType': errorTypeString,
      'errorDescription': errorDescription,
      'errorTitle': errorTitle,
      'eventTime': eventTime,
      'serverTime': serverTime,
      'httpStatusCode': httpStatusCode,
      'httpStatusMessage': httpStatusMessage,
      'url': url,
      'serverMessage': serverMessage,
      'networkWiFiName': networkWiFiName,
      'networkWiFiStatus': networkWiFiStatus,
      'networkSignalStrength': networkSignalStrength,
      'internetStatus': internetStatus,
      'deviceName': deviceName,
      'productName': productName,
      'sapUser': sapUser,
      'sapRessource': sapRessource,
      'stackTrace': stackTrace,
      'errorClass': errorClass,
    };
  }
}
