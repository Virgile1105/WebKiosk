import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import '../models/shortcut_item.dart';
import 'add_shortcut_screen.dart';
import 'add_apps_screen.dart';
import 'network_status_screen.dart';
import 'info_screen.dart';
import 'configuration_screen.dart';
import 'advanced_settings_screen.dart';
import 'error_page.dart';

class SettingsScreen extends StatefulWidget {
  final List<ShortcutItem> currentShortcuts;
  
  const SettingsScreen({super.key, required this.currentShortcuts});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const platform = MethodChannel('devicegate.app/shortcut');
  String _appVersion = '';
  String _deviceName = 'DeviceGate';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadDeviceName();
  }

  Future<void> _loadDeviceName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _deviceName = prefs.getString('device_name') ?? 'DeviceGate';
      });
    } catch (e) {
      log('Error loading device name: $e');
    }
  }

  Future<void> _saveDeviceName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_name', name);
      setState(() {
        _deviceName = name;
      });
    } catch (error, stackTrace) {
      log('Error saving device name: $error');
      log('Stack trace: $stackTrace');
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ErrorPage(
              errorTitle: 'Erreur de sauvegarde',
              errorMessage: 'Impossible de sauvegarder le nom de l\'appareil',
              error: error,
              stackTrace: stackTrace,
              onRetry: () {
                Navigator.of(context).pop();
                _saveDeviceName(name);
              },
            ),
          ),
        );
      }
    }
  }

  void _showDeviceNameDialog() {
    final controller = TextEditingController(text: _deviceName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(24),
        content: SizedBox(
          width: 500,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: Title and text field
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Device Name',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Device Name',
                        hintText: 'Enter device name',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 30,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right column: Buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      controller.clear();
                    },
                    child: const Text('Clear'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () {
                      if (controller.text.isNotEmpty) {
                        _saveDeviceName(controller.text.trim());
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      });
    } catch (e) {
      log('Error fetching app version: $e');
      setState(() {
        _appVersion = 'Unknown';
      });
    }
  }

  void _exitToHome() async {
    try {
      await platform.invokeMethod('exitToHome');
    } catch (e) {
      log('Error exiting to home: $e');
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _deviceName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color.fromRGBO(51, 61, 71, 1),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Settings header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: const Text(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          // Settings list
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.devices, color: Colors.blue),
                  title: const Text('Device Name'),
                  subtitle: Text(_deviceName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showDeviceNameDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info, color: Colors.blue),
                  title: const Text('Info'),
                  subtitle: const Text('App and device information'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InfoScreen(
                          appVersion: _appVersion,
                          deviceName: _deviceName,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tune, color: Colors.blue),
                  title: const Text('Configuration'),
                  subtitle: const Text('Custom display and behavior settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ConfigurationScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.add, color: Colors.blue),
                  title: const Text('Add Shortcut'),
                  subtitle: const Text('Add a new web shortcut'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final shortcut = await Navigator.push<ShortcutItem>(
                      context,
                      MaterialPageRoute(builder: (context) => const AddShortcutScreen()),
                    );
                    if (shortcut != null && mounted) {
                      Navigator.pop(context, shortcut);
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.android, color: Colors.green),
                  title: const Text('Add Apps'),
                  subtitle: const Text('Add installed Android apps'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final changes = await Navigator.push<Map<String, Map<String, dynamic>>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddAppsScreen(currentShortcuts: widget.currentShortcuts),
                      ),
                    );
                    if (changes != null && mounted) {
                      Navigator.pop(context, changes);
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.wifi, color: Colors.blue),
                  title: const Text('Network'),
                  subtitle: const Text('View network status and settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NetworkStatusScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_applications, color: Colors.deepPurple),
                  title: const Text('Advanced Settings'),
                  subtitle: const Text('Developer options and USB settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdvancedSettingsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.orange),
                  title: const Text('Exit to Home'),
                  subtitle: const Text('Return to native Android home'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _exitToHome();
                  },
                ),
                const Divider(height: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
