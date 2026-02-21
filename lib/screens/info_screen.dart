import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/logger.dart';
import '../generated/l10n/app_localizations.dart';
import 'error_page.dart';

class InfoScreen extends StatefulWidget {
  final String appVersion;
  final String deviceName;

  const InfoScreen({
    super.key,
    required this.appVersion,
    required this.deviceName,
  });

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  static const platform = MethodChannel('devicegate.app/shortcut');
  String? _ipAddress;
  List<Map<String, dynamic>> _bluetoothDevices = [];
  String? _androidDeviceModel;
  bool _isLoadingBluetooth = true;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      // Get IP address from WiFi info
      final wifiInfo = await platform.invokeMethod('getWifiInfo');
      String? ipAddress;
      
      if (wifiInfo != null && wifiInfo is Map) {
        if (wifiInfo['currentNetwork'] != null) {
          final currentNetwork = wifiInfo['currentNetwork'];
          if (currentNetwork['ipAddress'] != null) {
            final ip = currentNetwork['ipAddress'];
            // Convert integer IP to string format
            if (ip is int) {
              ipAddress = '${(ip & 0xff)}.${(ip >> 8 & 0xff)}.${(ip >> 16 & 0xff)}.${(ip >> 24 & 0xff)}';
            } else {
              ipAddress = ip.toString();
            }
          }
        }
      }

      // Get Bluetooth devices
      List<Map<String, dynamic>> bluetoothDevices = [];
      try {
        final devices = await platform.invokeMethod('getBluetoothDevices');
        if (devices != null && devices is List) {
          bluetoothDevices = devices.map((device) {
            return Map<String, dynamic>.from(device as Map);
          }).toList();
        }
      } catch (e) {
        log('Error getting Bluetooth devices: $e');
      }

      // Get Android device model
      String? androidDeviceModel;
      try {
        final deviceModel = await platform.invokeMethod('getDeviceModel');
        if (deviceModel != null && deviceModel is Map) {
          final manufacturer = deviceModel['manufacturer'] ?? '';
          final model = deviceModel['model'] ?? '';
          androidDeviceModel = '$manufacturer $model'.trim();
        }
      } catch (e) {
        log('Error getting device model: $e');
      }

      if (mounted) {
        setState(() {
          _ipAddress = ipAddress;
          _bluetoothDevices = bluetoothDevices;
          _androidDeviceModel = androidDeviceModel;
          _isLoadingBluetooth = false;
        });
      }
    } catch (error, stackTrace) {
      log('Error loading device info: $error');
      if (mounted) {
        setState(() {
          _ipAddress = null;
          _bluetoothDevices = [];
          _androidDeviceModel = null;
          _isLoadingBluetooth = false;
        });
        final l10n = AppLocalizations.of(context)!;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ErrorPage(
              errorTitle: l10n.errorLoadingDeviceInfo,
              errorMessage: l10n.couldNotLoadDeviceInfo,
              error: error,
              stackTrace: stackTrace,
              onRetry: () {
                Navigator.of(context).pop();
                _loadDeviceInfo();
              },
            ),
          ),
        );
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.information,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color.fromRGBO(51, 61, 71, 1),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Text(
                l10n.deviceInfo,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Info rows
            _buildInfoRow(l10n.appVersion, widget.appVersion.isNotEmpty ? widget.appVersion : l10n.loadingApps),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildInfoRow(l10n.deviceName, widget.deviceName),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildInfoRow(l10n.androidModel, _androidDeviceModel ?? l10n.notAvailable),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildInfoRow(l10n.ipAddress, _ipAddress ?? l10n.notAvailable),
            const Divider(height: 1, indent: 16, endIndent: 16),
            
            // Bluetooth Devices Section
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 160,
                        child: Text(
                          l10n.bluetoothDevices,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _isLoadingBluetooth
                            ? Text(
                                l10n.loadingApps,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              )
                            : _bluetoothDevices.isEmpty
                                ? Text(
                                    l10n.noBluetooth,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: _bluetoothDevices.map((device) {
                                      final name = device['name'] ?? l10n.unknown;
                                      final type = device['type'] ?? '';
                                      final connected = device['connected'] ?? l10n.unknown;
                                      final isConnected = connected == l10n.connected;
                                      
                                      // Determine icon based on type or device name
                                      IconData deviceIcon;
                                      final nameLower = name.toLowerCase();
                                      if (nameLower.contains('scan') || nameLower.contains('barcode') || nameLower.contains('powerscan')) {
                                        deviceIcon = Icons.document_scanner;
                                      } else if (type == l10n.deviceTypeKeyboard) {
                                        deviceIcon = Icons.keyboard;
                                      } else if (type == l10n.deviceTypeScanner) {
                                        deviceIcon = Icons.document_scanner;
                                      } else if (type == l10n.deviceTypeMouse) {
                                        deviceIcon = Icons.mouse;
                                      } else if (type == l10n.deviceTypeAudio) {
                                        deviceIcon = Icons.headphones;
                                      } else {
                                        deviceIcon = Icons.bluetooth;
                                      }
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          children: [
                                            Icon(
                                              deviceIcon,
                                              size: 20,
                                              color: isConnected ? Colors.green.shade700 : Colors.grey.shade500,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        name,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          color: Colors.black87,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: isConnected ? Colors.green : Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (type.isNotEmpty)
                                                    Text(
                                                      '$type • $connected',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
