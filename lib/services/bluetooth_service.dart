import 'dart:async';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// Singleton service that manages Bluetooth EventChannel subscription
/// and broadcasts updates to multiple listeners.
class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  
  BluetoothService._internal();
  
  static const _eventChannel = EventChannel('devicegate.app/bluetooth_events');
  
  StreamSubscription? _subscription;
  final _controller = StreamController<List<Map<String, dynamic>>>.broadcast();
  List<Map<String, dynamic>> _lastDevices = [];
  
  /// Stream of Bluetooth device updates
  Stream<List<Map<String, dynamic>>> get deviceStream => _controller.stream;
  
  /// Get the last known devices list
  List<Map<String, dynamic>> get devices => _lastDevices;
  
  /// Initialize the service (call once at app startup)
  void initialize() {
    if (_subscription != null) return; // Already initialized
    
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is List) {
          _lastDevices = event.map((device) {
            return Map<String, dynamic>.from(device as Map);
          }).toList();
          _controller.add(_lastDevices);
          log('BluetoothService: Received ${_lastDevices.length} devices');
        }
      },
      onError: (error) {
        log('BluetoothService error: $error');
      },
    );
    log('BluetoothService initialized');
  }
  
  /// Dispose the service (call when app is closing)
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller.close();
  }
}
