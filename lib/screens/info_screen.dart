import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/logger.dart';
import '../widgets/battery_indicator.dart';

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
  String _ipAddress = 'Loading...';
  String _connectedDevice = 'None';

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      // Get IP address from WiFi info
      final wifiInfo = await platform.invokeMethod('getWifiInfo');
      String ipAddress = 'Not available';
      
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

      // Check for connected devices (keyboard/scanner)
      String connectedDevice = 'None';
      try {
        final hasKeyboard = await platform.invokeMethod('hasPhysicalKeyboard');
        if (hasKeyboard == true) {
          connectedDevice = 'Physical Keyboard / Scanner';
        }
      } catch (e) {
        log('Error checking keyboard: $e');
      }

      if (mounted) {
        setState(() {
          _ipAddress = ipAddress;
          _connectedDevice = connectedDevice;
        });
      }
    } catch (e) {
      log('Error loading device info: $e');
      if (mounted) {
        setState(() {
          _ipAddress = 'Error loading';
          _connectedDevice = 'Error checking';
        });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Information',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color.fromRGBO(51, 61, 71, 1),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: const [
          BatteryIndicator(),
        ],
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
              child: const Text(
                'Device & Application Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Info rows
            _buildInfoRow('Application Name', 'DeviceGate'),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildInfoRow('Version', widget.appVersion.isNotEmpty ? widget.appVersion : 'Loading...'),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildInfoRow('Device Name', widget.deviceName),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildInfoRow('IP Address', _ipAddress),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildInfoRow('Connected Device', _connectedDevice),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
