import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../generated/l10n/app_localizations.dart';
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
  
  // Update state
  bool _isCheckingUpdate = false;
  bool _isDownloading = false;
  bool _hasUpdate = false;
  String _currentVersion = '';
  String _latestVersion = '';
  String _downloadUrl = '';
  String? _updateError;

  @override
  void initState() {
    super.initState();
    _loadDeviceOwnerStatus();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    if (_isCheckingUpdate) return;
    
    setState(() {
      _isCheckingUpdate = true;
      _updateError = null;
    });
    
    try {
      final result = await platform.invokeMethod<Map>('checkForUpdate');
      if (mounted && result != null) {
        setState(() {
          _hasUpdate = result['hasUpdate'] == true;
          _currentVersion = result['currentVersion']?.toString() ?? '';
          _latestVersion = result['latestVersion']?.toString() ?? '';
          _downloadUrl = result['downloadUrl']?.toString() ?? '';
          _updateError = result['error']?.toString();
          _isCheckingUpdate = false;
        });
      }
    } catch (e) {
      logger.log('Error checking for update: $e');
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
          _updateError = e.toString();
        });
      }
    }
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
    final l10n = AppLocalizations.of(context)!;
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeDeviceOwner),
        content: Text(l10n.removeDeviceOwnerWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final success = await platform.invokeMethod('removeDeviceOwner');
        
        // Reload status after removal
        await _loadDeviceOwnerStatus();
        
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.deviceOwnerRemoved),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.failedToRemoveDeviceOwner),
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
              content: Text('${l10n.settings}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _uninstallDeviceGate() async {
    final l10n = AppLocalizations.of(context)!;
    
    try {
      // Trigger uninstall - opens app settings
      final uninstalled = await platform.invokeMethod('uninstallApp');
      
      if (!uninstalled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.couldNotOpenAppSettings),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      logger.log('Error uninstalling DeviceGate: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.settings}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _factoryDataReset() async {
    final l10n = AppLocalizations.of(context)!;
    
    try {
      // Open factory reset settings
      final resetStarted = await platform.invokeMethod('factoryReset');
      
      if (!resetStarted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.couldNotOpenSettings),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      logger.log('Error opening factory reset settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.settings}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmAndInstallUpdate() async {
    final l10n = AppLocalizations.of(context)!;
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.updateAvailable),
        content: Text(l10n.updateConfirmation(_currentVersion, _latestVersion)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.update, style: const TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isDownloading = true;
      });
      
      try {
        final success = await platform.invokeMethod<bool>(
          'downloadAndInstallUpdate',
          {'downloadUrl': _downloadUrl},
        );
        
        if (mounted) {
          setState(() {
            _isDownloading = false;
          });
          
          if (success != true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.updateFailed),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        logger.log('Error installing update: $e');
        if (mounted) {
          setState(() {
            _isDownloading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.updateFailed}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.advancedSettings),
        backgroundColor: const Color.fromRGBO(51, 61, 71, 1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // App Update Section
                Card(
                  margin: const EdgeInsets.all(16),
                  child: ListTile(
                    leading: _isCheckingUpdate || _isDownloading
                        ? const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : Icon(
                            _hasUpdate ? Icons.system_update : Icons.check_circle,
                            color: _hasUpdate ? Colors.orange : Colors.green,
                            size: 32,
                          ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            l10n.appUpdate,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!_isCheckingUpdate && !_isDownloading)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _hasUpdate ? Colors.orange[100] : Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _hasUpdate ? l10n.updateAvailable : l10n.upToDate,
                              style: TextStyle(
                                color: _hasUpdate ? Colors.orange[900] : Colors.green[900],
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: _isCheckingUpdate
                        ? Text(l10n.checkingForUpdate)
                        : _isDownloading
                            ? Text(l10n.downloadingUpdate)
                            : _updateError != null
                                ? Text(_updateError!, style: const TextStyle(color: Colors.red))
                                : Text(
                                    _hasUpdate
                                        ? l10n.newVersionAvailable(_latestVersion)
                                        : l10n.currentVersion(_currentVersion),
                                  ),
                    trailing: _hasUpdate && !_isCheckingUpdate && !_isDownloading
                        ? const Icon(Icons.download)
                        : IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _isCheckingUpdate ? null : _checkForUpdate,
                          ),
                    onTap: _hasUpdate && !_isCheckingUpdate && !_isDownloading
                        ? _confirmAndInstallUpdate
                        : null,
                  ),
                ),
                
                const Divider(height: 1),
                
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
                        Flexible(
                          child: Text(
                            l10n.deviceOwnerMode,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isDeviceOwner ? Colors.green[100] : Colors.red[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isDeviceOwner ? l10n.enabled : l10n.disabled,
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
                        ? l10n.deviceOwnerEnabledDesc 
                        : l10n.deviceOwnerDisabledDesc,
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
                      l10n.uninstallDeviceGate,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isDeviceOwner ? Colors.grey : null,
                      ),
                    ),
                    subtitle: Text(
                      _isDeviceOwner
                          ? l10n.removeDeviceOwnerFirst
                          : l10n.uninstallDeviceGateDesc,
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
                      l10n.factoryDataReset,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isDeviceOwner ? Colors.grey : null,
                      ),
                    ),
                    subtitle: Text(
                      _isDeviceOwner
                          ? l10n.removeDeviceOwnerFirst
                          : l10n.factoryDataResetDesc,
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
                    title: Text(
                      l10n.advancedSettingsInfo,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(l10n.advancedSettingsInfoDesc),
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
