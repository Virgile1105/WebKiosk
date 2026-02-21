import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/logger.dart' as logger;
import 'advanced_settings_info_screen.dart';

class AdvancedSettingsScreen extends StatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  State<AdvancedSettingsScreen> createState() => _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState extends State<AdvancedSettingsScreen> {
  static const platform = MethodChannel('devicegate.app/shortcut');
  
  bool _isLoading = true;
  bool _isDeviceOwner = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceOwnerStatus();
  }

  Future<void> _loadDeviceOwnerStatus() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final isOwner = await platform.invokeMethod<bool>('isDeviceOwner');

      if (mounted) {
        setState(() {
          _isDeviceOwner = isOwner ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      logger.log('Error loading device owner status: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _removeDeviceOwner() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device Owner?'),
        content: const Text(
          'This will remove Device Owner status and allow factory reset.\n\n'
          'The device will no longer be in kiosk mode.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final success = await platform.invokeMethod('removeDeviceOwner');
        
        // Reload device owner status after removal
        await _loadDeviceOwnerStatus();
        
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Device Owner removed. You can now factory reset.'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to remove Device Owner'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        logger.log('Error removing device owner: $e');
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

  void _uninstallDeviceGate() async {
    try {
      // Trigger uninstall - opens app settings
      final uninstalled = await platform.invokeMethod('uninstallApp');
      
      if (!uninstalled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open app settings. Please uninstall manually from Settings.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      logger.log('Error uninstalling DeviceGate: $e');
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

  void _factoryDataReset() async {
    try {
      // Open factory reset settings
      final resetStarted = await platform.invokeMethod('factoryReset');
      
      if (!resetStarted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open settings. Please factory reset manually from Settings.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      logger.log('Error opening factory reset settings: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Settings'),
        backgroundColor: const Color.fromRGBO(51, 61, 71, 1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Device Owner Mode Section
                Card(
                  margin: const EdgeInsets.all(16),
                  child: ListTile(
                    leading: Icon(
                      Icons.admin_panel_settings,
                      color: _isDeviceOwner ? Colors.green : Colors.red,
                      size: 32,
                    ),
                    title: Row(
                      children: [
                        const Text(
                          'Device Owner Mode',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isDeviceOwner ? Colors.green[100] : Colors.red[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isDeviceOwner ? 'ENABLED' : 'DISABLED',
                            style: TextStyle(
                              color: _isDeviceOwner ? Colors.green[900] : Colors.red[900],
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      _isDeviceOwner 
                        ? 'Click to remove Device Owner mode' 
                        : 'Device Owner mode is disabled',
                    ),
                    trailing: _isDeviceOwner ? const Icon(Icons.chevron_right) : null,
                    onTap: _isDeviceOwner ? _removeDeviceOwner : null,
                  ),
                ),
                
                const Divider(height: 1),
                
                // Uninstall DeviceGate Section
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_forever,
                      color: _isDeviceOwner ? Colors.grey : Colors.red,
                    ),
                    title: Text(
                      'Uninstall DeviceGate',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isDeviceOwner ? Colors.grey : null,
                      ),
                    ),
                    subtitle: Text(
                      _isDeviceOwner
                          ? 'Remove Device Owner mode first to enable'
                          : 'Uninstall DeviceGate from this device',
                      style: TextStyle(
                        color: _isDeviceOwner ? Colors.grey : null,
                      ),
                    ),
                    trailing: _isDeviceOwner
                        ? null
                        : const Icon(Icons.chevron_right),
                    onTap: _isDeviceOwner ? null : _uninstallDeviceGate,
                  ),
                ),
                
                const Divider(height: 1),
                
                // Factory Data Reset Section
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Icon(
                      Icons.restore_outlined,
                      color: _isDeviceOwner ? Colors.grey : Colors.red,
                    ),
                    title: Text(
                      'Factory Data Reset',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isDeviceOwner ? Colors.grey : null,
                      ),
                    ),
                    subtitle: Text(
                      _isDeviceOwner
                          ? 'Remove Device Owner mode first to enable'
                          : 'Erase all data and restore factory settings',
                      style: TextStyle(
                        color: _isDeviceOwner ? Colors.grey : null,
                      ),
                    ),
                    trailing: _isDeviceOwner
                        ? null
                        : const Icon(Icons.chevron_right),
                    onTap: _isDeviceOwner ? null : _factoryDataReset,
                  ),
                ),
                
                const Divider(height: 1),
                
                // Advanced Settings Information Section
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.blue),
                    title: const Text(
                      'Advanced Settings Information',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('View system developer and USB settings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdvancedSettingsInfoScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
