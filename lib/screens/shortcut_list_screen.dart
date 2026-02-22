import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/shortcut_item.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/bluetooth_service.dart';
import 'kiosk_webview_screen.dart';
import 'settings_screen.dart';
import 'password_dialog.dart';
import 'add_shortcut_screen.dart';
import 'add_apps_screen.dart';
import 'error_page.dart';
import '../utils/logger.dart';

class ShortcutListScreen extends StatefulWidget {
  const ShortcutListScreen({super.key});

  @override
  State<ShortcutListScreen> createState() => _ShortcutListScreenState();
}

class _ShortcutListScreenState extends State<ShortcutListScreen> {
  static const platform = MethodChannel('devicegate.app/shortcut');
  List<ShortcutItem> _shortcuts = [];
  bool _isLoading = true;
  String _appVersion = '';
  String _deviceName = 'DeviceGate';
  List<Map<String, dynamic>> _bluetoothDevices = [];
  StreamSubscription? _bluetoothSubscription;
  Timer? _deviceRotationTimer;
  int _currentDeviceIndex = 0;
  bool _alwaysShowTopBar = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadBluetoothDevices();
    // Listen to Bluetooth status changes via BluetoothService
    _bluetoothDevices = BluetoothService().devices;
    _bluetoothSubscription = BluetoothService().deviceStream.listen(
      (devices) {
        if (mounted) {
          setState(() {
            _bluetoothDevices = devices;
          });
        }
      },
    );
    // Rotate through devices every 3 seconds if multiple
    _deviceRotationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_bluetoothDevices.length > 1) {
        setState(() {
          _currentDeviceIndex = (_currentDeviceIndex + 1) % _bluetoothDevices.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _bluetoothSubscription?.cancel();
    _deviceRotationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await Future.wait([
        _loadShortcuts(),
        _loadAppVersion(),
        _loadDeviceName(),
        _loadTopBarSetting(),
      ]);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error, stackTrace) {
      log('Critical error loading data: $error');
      log('Stack trace: $stackTrace');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _isLoading = false;
        });
        // Show error page for critical data loading failures
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ErrorPage(
              errorTitle: l10n.loadingError,
              errorMessage: l10n.cannotLoadAppData,
              error: error,
              stackTrace: stackTrace,
              onRetry: () {
                Navigator.of(context).pop();
                setState(() {
                  _isLoading = true;
                });
                _loadData();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadDeviceName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _deviceName = prefs.getString('device_name') ?? 'DeviceGate';
        });
      }
    } catch (e) {
      log('Error loading device name: $e');
    }
  }

  Future<void> _loadTopBarSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _alwaysShowTopBar = prefs.getBool('always_show_top_bar') ?? false;
        });
      }
    } catch (e) {
      log('Error loading top bar setting: $e');
    }
  }

  Future<void> _loadShortcuts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shortcutsJson = prefs.getString('shortcuts') ?? '';
      final shortcuts = ShortcutItem.decodeList(shortcutsJson);
      
      // Add default SAP_EWM shortcut if no shortcuts exist
      if (shortcuts.isEmpty) {
        shortcuts.add(ShortcutItem(
          id: 'sap_ewm_default',
          name: 'SAP EWM',
          url: 'https://sapcrx102.inapa.group:44300/sap/bc/gui/sap/zcor_ewm01?sap-language=FR',
          iconUrl: 'assets/icon/SAP_EWM.png',
          disableAutoFocus: false,
          useCustomKeyboard: true,
          disableCopyPaste: false,
        ));
        // Save the default shortcut
        await prefs.setString('shortcuts', ShortcutItem.encodeList(shortcuts));
      }
      
      _shortcuts = shortcuts;
      
      // Update lock task packages with any app shortcuts
      await _updateLockTaskPackages();
    } catch (error, stackTrace) {
      log('Error loading shortcuts: $error');
      log('Stack trace: $stackTrace');
      // Initialize with empty list on error
      _shortcuts = [];
      rethrow; // Re-throw to be caught by _loadData
    }
  }

  Future<void> _saveShortcuts() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shortcuts', ShortcutItem.encodeList(_shortcuts));
    } catch (error, stackTrace) {
      log('Error saving shortcuts: $error');
      log('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.saveError(error.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _updateLockTaskPackages() async {
    try {
      // Get all app package names from shortcuts
      final appPackages = _shortcuts
          .where((s) => s.url.startsWith('app://'))
          .map((s) => s.url.substring(6))
          .toList();
      
      await platform.invokeMethod('updateLockTaskPackages', {'packages': appPackages});
      log('Updated lock task packages: $appPackages');
    } catch (e) {
      log('Error updating lock task packages: $e');
    }
  }

  Future<void> _loadBluetoothDevices() async {
    try {
      final devices = await platform.invokeMethod('getBluetoothDevices');
      if (mounted) {
        setState(() {
          _bluetoothDevices = (devices as List)
              .map((device) => Map<String, dynamic>.from(device as Map))
              .toList();
        });
      }
    } catch (e) {
      log('Error loading Bluetooth devices: $e');
    }
  }

  Future<void> _loadAppVersion() async {
    log('Starting to load app version...');
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      log('PackageInfo loaded - version: ${packageInfo.version}, buildNumber: ${packageInfo.buildNumber}');
      final versionString = '${packageInfo.version}+${packageInfo.buildNumber}';
      log('Final version string: $versionString');
      _appVersion = versionString;
      log('App version set to: $_appVersion');
    } catch (e) {
      log('Error fetching app version: $e');
      _appVersion = 'Unknown';
    }
  }

  void _showSettingsMenu() async {
    // Show password dialog first
    final authenticated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PasswordDialog(),
    );

    // Only proceed to settings if authentication successful
    if (authenticated == true) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SettingsScreen(currentShortcuts: _shortcuts),
        ),
      );

      // Reload settings when returning from settings
      await _loadDeviceName();
      await _loadTopBarSetting();

      if (result != null) {
        if (result is ShortcutItem) {
          // Handle single shortcut addition (from Add Shortcut)
          setState(() {
            _shortcuts.add(result);
          });
          
          if (mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${result.name} ${l10n.addedToHome}')),
            );
          }
        } else if (result is Map<String, Map<String, dynamic>>) {
          // Handle multiple app changes (from Add Apps)
          await _handleAppChanges(result);
        }
      }
    }
  }

  Future<void> _handleAppChanges(Map<String, Map<String, dynamic>> changes) async {
    final l10n = AppLocalizations.of(context)!;
    int addedCount = 0;
    int removedCount = 0;

    setState(() {
      for (var entry in changes.entries) {
        final packageName = entry.key;
        final change = entry.value;
        final action = change['action'] as String;

        if (action == 'add') {
          final appName = change['name'] as String;
          final iconBase64 = change['icon'] as String?;
          
          final shortcut = ShortcutItem(
            id: 'app_$packageName',
            name: appName,
            url: 'app://$packageName',
            iconUrl: iconBase64 != null && iconBase64.isNotEmpty ? 'base64://$iconBase64' : '',
            disableAutoFocus: false,
            useCustomKeyboard: false,
            disableCopyPaste: false,
          );
          _shortcuts.add(shortcut);
          addedCount++;
        } else if (action == 'remove') {
          _shortcuts.removeWhere((s) => s.url == 'app://$packageName');
          removedCount++;
        }
      }
    });

    await _saveShortcuts();
    await _updateLockTaskPackages();

    if (mounted) {
      final message = <String>[];
      if (addedCount > 0) message.add(l10n.appsAdded(addedCount.toString()));
      if (removedCount > 0) message.add(l10n.appsRemoved(removedCount.toString()));
      
      if (message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.join(', '))),
        );
      }
    }
  }

  void _exitToHome() async {
    try {
      // Go to Android home
      await platform.invokeMethod('exitToHome');
    } catch (e) {
      log('Error exiting to home: $e');
      // Fallback: just close the app
      SystemNavigator.pop();
    }
  }

  Future<void> _showAddAppsDialog() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      // Get list of installed apps from native
      final List<dynamic> apps = await platform.invokeMethod('getInstalledApps');
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(l10n.selectAppToAdd),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: apps.length,
                itemBuilder: (context, index) {
                  final app = apps[index] as Map;
                  final appName = app['name'] as String;
                  final packageName = app['packageName'] as String;
                  final iconBase64 = app['icon'] as String?;
                  
                  Widget leading;
                  if (iconBase64 != null && iconBase64.isNotEmpty) {
                    try {
                      final bytes = base64Decode(iconBase64);
                      leading = Image.memory(
                        bytes,
                        width: 40,
                        height: 40,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.android);
                        },
                      );
                    } catch (e) {
                      leading = const Icon(Icons.android);
                    }
                  } else {
                    leading = const Icon(Icons.android);
                  }
                  
                  return ListTile(
                    leading: leading,
                    title: Text(appName),
                    subtitle: Text(packageName, style: const TextStyle(fontSize: 10)),
                    onTap: () {
                      Navigator.pop(context);
                      _addAppShortcut(appName, packageName, iconBase64);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
            ],
          );
        },
      );
    } catch (e) {
      log('Error getting installed apps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorLoadingApps}: $e')),
        );
      }
    }
  }

  Future<void> _addAppShortcut(String appName, String packageName, String? iconBase64) async {
    // Create a shortcut for the Android app
    final shortcut = ShortcutItem(
      id: 'app_$packageName',
      name: appName,
      url: 'app://$packageName',
      iconUrl: iconBase64 != null && iconBase64.isNotEmpty ? 'base64://$iconBase64' : '',
      disableAutoFocus: false,
      useCustomKeyboard: false,
      disableCopyPaste: false,
    );
    
    setState(() {
      _shortcuts.add(shortcut);
    });
    
    await _saveShortcuts();
    
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$appName ${l10n.addedToHome}')),
      );
    }
  }

  Future<void> _addShortcut() async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final urlController = TextEditingController(text: 'https://');
    final iconUrlController = TextEditingController();
    bool disableAutoFocus = false;
    bool useCustomKeyboard = false;
    bool disableCopyPaste = false;
    String selectedAssetIcon = '';

    // Available asset icons
    final List<String> availableAssetIcons = [
      '', // Empty option for URL input
      'assets/icon/SAP_EWM.png',
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.addNewShortcut),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.name,
                    hintText: l10n.nameHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: l10n.websiteUrl,
                    hintText: l10n.websiteUrlHint,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedAssetIcon,
                  decoration: InputDecoration(
                    labelText: l10n.icon,
                    border: const OutlineInputBorder(),
                  ),
                  items: availableAssetIcons.map((icon) {
                    return DropdownMenuItem<String>(
                      value: icon,
                      child: Text(icon.isEmpty ? l10n.useUrlBelow : icon.replaceFirst('assets/icon/', '')),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedAssetIcon = value ?? '';
                      if (selectedAssetIcon.isNotEmpty) {
                        iconUrlController.clear(); // Clear URL field when asset is selected
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: iconUrlController,
                  enabled: selectedAssetIcon.isEmpty, // Disable when asset icon is selected
                  decoration: InputDecoration(
                    labelText: l10n.iconUrlOptional,
                    hintText: selectedAssetIcon.isNotEmpty ? l10n.usingAssetIcon : l10n.leaveEmptyForAutoDetect,
                    border: const OutlineInputBorder(),
                    filled: selectedAssetIcon.isNotEmpty,
                    fillColor: selectedAssetIcon.isNotEmpty ? Colors.grey.shade100 : null,
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 8),
                Text(
                  selectedAssetIcon.isNotEmpty
                      ? l10n.usingSelectedAssetIcon
                      : l10n.leaveIconUrlEmpty,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(l10n.useCustomKeyboard),
                  subtitle: Text(
                    l10n.useCustomKeyboardDesc,
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: useCustomKeyboard,
                  onChanged: (value) {
                    setDialogState(() {
                      useCustomKeyboard = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: Text(l10n.disableCopyPaste),
                  subtitle: Text(
                    l10n.disableCopyPasteDesc,
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: disableCopyPaste,
                  onChanged: (value) {
                    setDialogState(() {
                      disableCopyPaste = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.add),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      var url = urlController.text.trim();
      var iconUrl = iconUrlController.text.trim();

      if (name.isEmpty || url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pleaseEnterNameAndUrl)),
        );
        return;
      }

      // Ensure URL has protocol
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }

      // Determine final icon URL
      var finalIconUrl = selectedAssetIcon;
      if (finalIconUrl.isEmpty) {
        finalIconUrl = iconUrlController.text.trim();
        // Try to get website favicon if not provided
        if (finalIconUrl.isEmpty) {
          try {
            final uri = Uri.parse(url);
            finalIconUrl = 'https://www.google.com/s2/favicons?domain=${uri.host}&sz=128';
          } catch (e) {
            finalIconUrl = 'https://www.google.com/s2/favicons?domain=$url&sz=128';
          }
        }
      }

      // Create the shortcut item
      final shortcut = ShortcutItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        url: url,
        iconUrl: finalIconUrl,
        disableAutoFocus: disableAutoFocus,
        useCustomKeyboard: useCustomKeyboard,
        disableCopyPaste: disableCopyPaste,
      );

      // Add to list and save
      setState(() {
        _shortcuts.add(shortcut);
      });
      await _saveShortcuts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.shortcutAdded(name))),
        );
      }
    }
  }

  Future<void> _createHomeScreenShortcut(ShortcutItem shortcut) async {
    try {
      // Load asset icon bytes if it's an asset path
      Uint8List? iconBytes;
      if (shortcut.iconUrl.startsWith('assets/')) {
        try {
          final ByteData data = await rootBundle.load(shortcut.iconUrl);
          iconBytes = data.buffer.asUint8List();
        } catch (e) {
          log('Failed to load asset icon: $e');
          // Continue without icon bytes - Android will use default icon
        }
      }

      await platform.invokeMethod('createShortcut', {
        'shortcutId': 'webkiosk_${shortcut.id}',
        'name': shortcut.name,
        'url': shortcut.url,
        'iconUrl': shortcut.iconUrl,
        'iconBytes': iconBytes,
        'disableAutoFocus': shortcut.disableAutoFocus,
        'useCustomKeyboard': shortcut.useCustomKeyboard,
        'disableCopyPaste': shortcut.disableCopyPaste,
      });
    } catch (e) {
      log('Error creating home screen shortcut: $e');
    }
  }

  Future<void> _deleteHomeScreenShortcut(ShortcutItem shortcut) async {
    try {
      await platform.invokeMethod('deleteShortcut', {
        'shortcutId': 'devicegate_${shortcut.id}',
      });
    } catch (e) {
      log('Error deleting home screen shortcut: $e');
    }
  }

  Future<void> _deleteShortcut(ShortcutItem shortcut) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteShortcut),
        content: Text(l10n.confirmDeleteShortcut(shortcut.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _shortcuts.removeWhere((s) => s.id == shortcut.id);
      });
      await _saveShortcuts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.shortcutDeleted(shortcut.name))),
        );
      }
    }
  }

  void _showShortcutOptions(ShortcutItem shortcut) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: Text(l10n.open),
              onTap: () {
                Navigator.pop(context);
                _openShortcut(shortcut);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteShortcut(shortcut);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openShortcut(ShortcutItem shortcut) async {
    final l10n = AppLocalizations.of(context)!;
    // Check if this is an app shortcut (starts with app://)
    if (shortcut.url.startsWith('app://')) {
      final packageName = shortcut.url.substring(6); // Remove 'app://' prefix
      try {
        final success = await platform.invokeMethod('launchApp', {'packageName': packageName});
        if (!success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.failedToLaunch(shortcut.name))),
            );
          }
        }
      } catch (e) {
        log('Error launching app: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorLaunching(shortcut.name, e.toString()))),
          );
        }
      }
    } else {
      // Regular web shortcut - reload settings from SharedPreferences to get latest values
      final prefs = await SharedPreferences.getInstance();
      final shortcutsJson = prefs.getString('shortcuts') ?? '';
      final shortcuts = ShortcutItem.decodeList(shortcutsJson);
      
      // Find the shortcut with matching URL to get updated settings
      ShortcutItem updatedShortcut = shortcut;
      for (final s in shortcuts) {
        if (s.url == shortcut.url) {
          updatedShortcut = s;
          break;
        }
      }
      
      log('Opening shortcut: ${updatedShortcut.name} with URL: ${updatedShortcut.url}');
      log('Shortcut settings: useCustomKeyboard=${updatedShortcut.useCustomKeyboard}, disableAutoFocus=${updatedShortcut.disableAutoFocus}, disableCopyPaste=${updatedShortcut.disableCopyPaste}');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KioskWebViewScreen(
            initialUrl: updatedShortcut.url,
            disableAutoFocus: updatedShortcut.disableAutoFocus,
            useCustomKeyboard: updatedShortcut.useCustomKeyboard,
            disableCopyPaste: updatedShortcut.disableCopyPaste,
            enableWarningSound: updatedShortcut.enableWarningSound,
            shortcutIconUrl: updatedShortcut.iconUrl,
            shortcutName: updatedShortcut.name,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    log('Building ShortcutListScreen - appVersion: $_appVersion');
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _deviceName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color.fromRGBO(51, 61, 71, 1),
        actions: [
          _buildBluetoothStatus(),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: 56 + (_alwaysShowTopBar ? 24 : 0)),
              child: Image.asset(
                'assets/images/OVOL.png',
                fit: BoxFit.cover,
                alignment: Alignment.topLeft,
              ),
            ),
          ),
          // Logo top right
          LayoutBuilder(
            builder: (context, constraints) {
              final isPortrait = constraints.maxHeight > constraints.maxWidth;
              final shortestSide = MediaQuery.of(context).size.shortestSide;
              final isTablet = shortestSide >= 600;
              final baseLogoSize = isPortrait ? 90.0 : 120.0;
              final coef = isTablet ? isPortrait ? 0.3 : 0 : 1;
              final logoSize = isTablet ? baseLogoSize * 1.9 : baseLogoSize;
              final topBarOffset = _alwaysShowTopBar ? 24.0 : 0.0;
              final topMargin = (isPortrait ? 30.0 * coef : 20.0 * coef) + topBarOffset;
              return Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(top: topMargin, right: 25),
                  child: Image.asset(
                    'assets/images/logo_ovol.png',
                    width: logoSize,
                    height: logoSize,
                  ),
                ),
              );
            },
          ),
          // Content
          _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        strokeWidth: 4,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Loading DeviceGate...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : _shortcuts.isEmpty
                  ? _buildEmptyState()
                  : _buildShortcutGrid(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.web_rounded,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No shortcuts yet',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first shortcut',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothStatus() {
    if (_bluetoothDevices.isEmpty) {
      // No paired devices
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bluetooth_disabled,
            color: Colors.grey.shade400,
            size: 20,
          ),
        ],
      );
    }

    // Priority: Show only connected devices if any exist, otherwise show all paired devices
    final connectedDevices = _bluetoothDevices
        .where((device) => device['isConnected'] == true)
        .toList();
    
    final devicesToShow = connectedDevices.isNotEmpty ? connectedDevices : _bluetoothDevices;
    
    // Get current device to display (rotating through filtered devices)
    final device = devicesToShow[_currentDeviceIndex % devicesToShow.length];
    final name = device['name'] ?? 'Unknown';
    final type = device['type'] ?? '';
    final isConnected = device['isConnected'] == true;
    
    // Determine icon based on type or device name
    IconData deviceIcon;
    // Check device name for scanner keywords
    final nameLower = name.toLowerCase();
    if (nameLower.contains('scan') || nameLower.contains('barcode') || nameLower.contains('powerscan')) {
      deviceIcon = Icons.document_scanner;
    } else if (type == 'Keyboard') {
      deviceIcon = Icons.keyboard;
    } else if (type == 'Scanner') {
      deviceIcon = Icons.document_scanner;
    } else if (type == 'Mouse') {
      deviceIcon = Icons.mouse;
    } else if (type == 'Audio') {
      deviceIcon = Icons.headphones;
    } else {
      deviceIcon = Icons.bluetooth_connected;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          deviceIcon,
          color: isConnected ? Colors.green.shade400 : Colors.grey.shade400,
          size: 20,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConnected ? Colors.green.shade400 : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutGrid() {
    // Determine cross axis count based on screen orientation
    final orientation = MediaQuery.of(context).orientation;
    final crossAxisCount = orientation == Orientation.portrait ? 3 : 6;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: _shortcuts.length + 1, // +1 for settings tile
        itemBuilder: (context, index) {
          // Settings tile at the end
          if (index == _shortcuts.length) {
            return _buildSettingsTile();
          }
          final shortcut = _shortcuts[index];
          return _buildShortcutTile(shortcut);
        },
      ),
    );
  }

  Widget _buildSettingsTile() {
    return GestureDetector(
      onTap: _showSettingsMenu,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.settings,
              size: 40,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Settings',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutTile(ShortcutItem shortcut) {
    return GestureDetector(
      onTap: () => _openShortcut(shortcut),
      onLongPress: () => _showShortcutOptions(shortcut),
      onHorizontalDragStart: (_) {}, // Prevent horizontal swipe gestures
      onHorizontalDragUpdate: (_) {}, // Prevent horizontal swipe gestures
      onHorizontalDragEnd: (_) {}, // Prevent horizontal swipe gestures
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: shortcut.iconUrl.startsWith('base64://')
                ? Builder(
                    builder: (context) {
                      try {
                        final base64String = shortcut.iconUrl.substring(9); // Remove 'base64://'
                        final bytes = base64Decode(base64String);
                        return Image.memory(
                          bytes,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          cacheWidth: 128,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.android,
                              size: 40,
                              color: Colors.grey[600],
                            );
                          },
                        );
                      } catch (e) {
                        return Icon(
                          Icons.android,
                          size: 40,
                          color: Colors.grey[600],
                        );
                      }
                    },
                  )
                : shortcut.iconUrl.startsWith('assets/')
                ? Image.asset(
                    shortcut.iconUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.language,
                        size: 40,
                        color: Colors.grey[600],
                      );
                    },
                  )
                : Image.network(
                    shortcut.iconUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/icon/default.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.language,
                            size: 40,
                            color: Colors.grey[600],
                          );
                        },
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(
                        width: 64,
                        height: 64,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              shortcut.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
