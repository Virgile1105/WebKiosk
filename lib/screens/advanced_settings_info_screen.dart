import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/logger.dart' as logger;

class AdvancedSettingsInfoScreen extends StatefulWidget {
  const AdvancedSettingsInfoScreen({super.key});

  @override
  State<AdvancedSettingsInfoScreen> createState() => _AdvancedSettingsInfoScreenState();
}

class _AdvancedSettingsInfoScreenState extends State<AdvancedSettingsInfoScreen> {
  static const platform = MethodChannel('devicegate.app/shortcut');
  
  bool _isLoading = true;
  bool _developerModeEnabled = false;
  bool _usbDebuggingEnabled = false;
  bool _usbFileTransferEnabled = false;
  bool _locationPermissionGranted = false;
  bool _backgroundLocationGranted = false;
  bool _preciseLocationEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get developer mode status
      final devMode = await platform.invokeMethod<bool>('isDeveloperModeEnabled');
      
      bool usbDebug = false;
      bool usbTransfer = false;
      
      // Only check USB settings if developer mode is enabled
      if (devMode == true) {
        usbDebug = await platform.invokeMethod<bool>('isUsbDebuggingEnabled') ?? false;
        usbTransfer = await platform.invokeMethod<bool>('isUsbFileTransferEnabled') ?? false;
      }
      
      // Get location permission status
      final locationGranted = await platform.invokeMethod<bool>('isLocationPermissionGranted') ?? false;
      final backgroundGranted = await platform.invokeMethod<bool>('isBackgroundLocationGranted') ?? false;
      final preciseEnabled = await platform.invokeMethod<bool>('isPreciseLocationEnabled') ?? false;

      if (mounted) {
        setState(() {
          _developerModeEnabled = devMode ?? false;
          _usbDebuggingEnabled = usbDebug;
          _usbFileTransferEnabled = usbTransfer;
          _locationPermissionGranted = locationGranted;
          _backgroundLocationGranted = backgroundGranted;
          _preciseLocationEnabled = preciseEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      logger.log('Error loading advanced settings info: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Settings Information'),
        backgroundColor: const Color.fromRGBO(51, 61, 71, 1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [

                
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'System Status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                
                // Developer Mode Status
                ListTile(
                  leading: Icon(
                    Icons.developer_mode,
                    color: _developerModeEnabled ? Colors.orange : Colors.grey,
                  ),
                  title: const Text('Developer Mode'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _developerModeEnabled ? Colors.green[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _developerModeEnabled ? 'ON' : 'OFF',
                      style: TextStyle(
                        color: _developerModeEnabled ? Colors.green[900] : Colors.grey[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const Divider(height: 1),
                
                // USB Debugging Status
                ListTile(
                  leading: Icon(
                    Icons.usb,
                    color: _usbDebuggingEnabled ? Colors.green : Colors.grey,
                  ),
                  title: const Text('USB Debugging'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _usbDebuggingEnabled ? Colors.green[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _usbDebuggingEnabled ? 'ON' : 'OFF',
                      style: TextStyle(
                        color: _usbDebuggingEnabled ? Colors.green[900] : Colors.grey[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const Divider(height: 1),
                
                // USB File Transfer Status
                ListTile(
                  leading: Icon(
                    Icons.folder_open,
                    color: _usbFileTransferEnabled ? Colors.green : Colors.grey,
                  ),
                  title: const Text('USB File Transfer'),
                
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _usbFileTransferEnabled ? Colors.green[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _usbFileTransferEnabled ? 'ON' : 'OFF',
                      style: TextStyle(
                        color: _usbFileTransferEnabled ? Colors.green[900] : Colors.grey[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const Divider(height: 1),
                
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Location Permissions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                
                // Location Permission Status
                ListTile(
                  leading: Icon(
                    Icons.location_on,
                    color: _locationPermissionGranted ? Colors.green : Colors.red,
                  ),
                  title: const Text('Location Access'),
                  subtitle: Text(
                    _locationPermissionGranted 
                      ? 'Location permission granted' 
                      : 'Location permission denied',
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _locationPermissionGranted ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _locationPermissionGranted ? 'GRANTED' : 'DENIED',
                      style: TextStyle(
                        color: _locationPermissionGranted ? Colors.green[900] : Colors.red[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const Divider(height: 1),
                
                // Background Location Status
                ListTile(
                  leading: Icon(
                    Icons.explore,
                    color: _backgroundLocationGranted ? Colors.green : Colors.orange,
                  ),
                  title: const Text('Allow all the time'),
                  subtitle: Text(
                    _backgroundLocationGranted 
                      ? 'Background location access granted' 
                      : 'Only while using the app',
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _backgroundLocationGranted ? Colors.green[100] : Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _backgroundLocationGranted ? 'ALWAYS' : 'LIMITED',
                      style: TextStyle(
                        color: _backgroundLocationGranted ? Colors.green[900] : Colors.orange[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const Divider(height: 1),
                
                // Precise Location Status
                ListTile(
                  leading: Icon(
                    Icons.gps_fixed,
                    color: _preciseLocationEnabled ? Colors.green : Colors.grey,
                  ),
                  title: const Text('Use precise location'),
                  subtitle: Text(
                    _preciseLocationEnabled 
                      ? 'Precise GPS location enabled' 
                      : 'Approximate location only',
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _preciseLocationEnabled ? Colors.green[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _preciseLocationEnabled ? 'PRECISE' : 'APPROX',
                      style: TextStyle(
                        color: _preciseLocationEnabled ? Colors.green[900] : Colors.grey[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const Divider(height: 1),
                
                // Request Location Permission Button
                if (!_locationPermissionGranted || !_backgroundLocationGranted)
                  Container(
                    margin: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      onPressed: _requestLocationPermission,
                      icon: const Icon(Icons.location_on),
                      label: const Text('Grant Location Permissions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
    
              ],
            ),
    );
  }
  
  Future<void> _requestLocationPermission() async {
    try {
      await platform.invokeMethod('requestLocationPermission');
      
      // Wait a moment for permissions to be granted
      await Future.delayed(const Duration(seconds: 1));
      
      // Reload settings to show updated status
      await _loadSettings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _locationPermissionGranted && _backgroundLocationGranted
                ? 'Location permissions granted successfully'
                : 'Please grant location permissions manually in Settings',
            ),
            backgroundColor: _locationPermissionGranted && _backgroundLocationGranted
              ? Colors.green
              : Colors.orange,
          ),
        );
      }
    } catch (e) {
      logger.log('Error requesting location permission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
