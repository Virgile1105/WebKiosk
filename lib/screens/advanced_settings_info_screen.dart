import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/logger.dart' as logger;
import '../generated/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.advancedSettingsInfo),
        backgroundColor: const Color.fromRGBO(51, 61, 71, 1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [

                
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    l10n.systemStatus,
                    style: const TextStyle(
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
                  title: Text(l10n.developerMode),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _developerModeEnabled ? Colors.green[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _developerModeEnabled ? l10n.on : l10n.off,
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
                  title: Text(l10n.usbDebugging),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _usbDebuggingEnabled ? Colors.green[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _usbDebuggingEnabled ? l10n.on : l10n.off,
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
                  title: Text(l10n.usbFileTransfer),
                
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _usbFileTransferEnabled ? Colors.green[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _usbFileTransferEnabled ? l10n.on : l10n.off,
                      style: TextStyle(
                        color: _usbFileTransferEnabled ? Colors.green[900] : Colors.grey[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const Divider(height: 1),
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    l10n.locationPermissions,
                    style: const TextStyle(
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
                  title: Text(l10n.locationAccess),
                  subtitle: Text(
                    _locationPermissionGranted 
                      ? l10n.locationPermissionGranted
                      : l10n.locationPermissionDenied,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _locationPermissionGranted ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _locationPermissionGranted ? l10n.granted : l10n.denied,
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
                  title: Text(l10n.allowAllTheTime),
                  subtitle: Text(
                    _backgroundLocationGranted 
                      ? l10n.backgroundLocationGranted
                      : l10n.onlyWhileUsingApp,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _backgroundLocationGranted ? Colors.green[100] : Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _backgroundLocationGranted ? l10n.always : l10n.limited,
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
                  title: Text(l10n.usePreciseLocation),
                  subtitle: Text(
                    _preciseLocationEnabled 
                      ? l10n.preciseGpsEnabled
                      : l10n.approximateLocationOnly,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _preciseLocationEnabled ? Colors.green[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _preciseLocationEnabled ? l10n.precise : l10n.approx,
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
                      label: Text(l10n.grantLocationPermissions),
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
    final l10n = AppLocalizations.of(context)!;
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
                ? l10n.locationPermissionsGranted
                : l10n.grantLocationPermissionsManually,
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
            content: Text('${l10n.errorLabel} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
