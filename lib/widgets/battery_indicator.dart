import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

// Singleton battery stream manager to share battery updates across all widgets
class BatteryStreamManager {
  static final BatteryStreamManager _instance = BatteryStreamManager._internal();
  factory BatteryStreamManager() => _instance;
  BatteryStreamManager._internal();

  static const batteryChannel = EventChannel('devicegate.app/battery');
  final StreamController<Map<String, dynamic>> _controller = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription? _batterySubscription;
  bool _isInitialized = false;

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    _batterySubscription = batteryChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event != null && event is Map) {
          _controller.add(Map<String, dynamic>.from(event));
        }
      },
      onError: (dynamic error) {
        log('Error in battery stream: $error');
      },
    );
  }

  void dispose() {
    _batterySubscription?.cancel();
    _controller.close();
    _isInitialized = false;
  }
}

class BatteryIndicator extends StatefulWidget {
  const BatteryIndicator({super.key});

  @override
  State<BatteryIndicator> createState() => _BatteryIndicatorState();
}

class _BatteryIndicatorState extends State<BatteryIndicator> {
  static const platform = MethodChannel('devicegate.app/shortcut');
  
  int? _batteryLevel;
  bool _isCharging = false;
  StreamSubscription<Map<String, dynamic>>? _batterySubscription;
  final _streamManager = BatteryStreamManager();

  @override
  void initState() {
    super.initState();
    _streamManager.initialize();
    _loadBatteryLevel();
    _startBatteryMonitoring();
  }

  Future<void> _loadBatteryLevel() async {
    try {
      final result = await platform.invokeMethod('getBatteryLevel');
      if (mounted && result != null) {
        setState(() {
          _batteryLevel = result['level'] as int;
          _isCharging = result['isCharging'] as bool;
        });
      }
    } catch (e) {
      log('Error loading battery level: $e');
    }
  }

  void _startBatteryMonitoring() {
    _batterySubscription?.cancel();
    _batterySubscription = _streamManager.stream.listen(
      (event) {
        if (mounted) {
          setState(() {
            _batteryLevel = event['level'] as int;
            _isCharging = event['isCharging'] as bool;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _batterySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything until battery level is loaded
    if (_batteryLevel == null) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isCharging 
              ? Icons.battery_charging_full 
              : (_batteryLevel! > 20 ? Icons.battery_std : Icons.battery_alert),
            color: _batteryLevel! > 20 ? Colors.white : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            '$_batteryLevel%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
