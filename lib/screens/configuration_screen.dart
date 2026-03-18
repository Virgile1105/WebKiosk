import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import '../generated/l10n/app_localizations.dart';
import 'error_page.dart';

class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel('devicegate.app/shortcut');
  bool _alwaysShowTopBar = false;
  bool _isWedgeInput = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableImes = [];
  String? _currentIme;
  bool _isLoadingImes = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Set up method call handler for wedge auto-disable notifications
    platform.setMethodCallHandler(_handleMethodCall);
    
    _loadSettings();
    _checkKeyboardOnStartup();
    _startKeyboardMonitoring();
  }

  @override
  void dispose() {
    _stopKeyboardMonitoring();
    platform.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onWedgeAutoDisabled') {
      // Wedge input was auto-disabled due to keyboard change
      final reasonKey = call.arguments['reasonKey'] as String?;
      log('Wedge auto-disabled: $reasonKey');
      
      // Update UI immediately - we know it was disabled
      setState(() {
        _isWedgeInput = false;
      });
      
      // Show notification to user
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        String reasonText;
        switch (reasonKey) {
          case 'switchedToNonSystemKeyboard':
            reasonText = l10n.switchedToNonSystemKeyboard;
            break;
          case 'nonSystemKeyboardOnStartup':
            reasonText = l10n.nonSystemKeyboardOnStartup;
            break;
          default:
            reasonText = l10n.nonSystemKeyboardDetected;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.scanWedgeDisabled,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  reasonText,
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  Future<void> _checkKeyboardOnStartup() async {
    try {
      await platform.invokeMethod('checkAndDisableWedgeOnStartup');
      // If wedge was disabled, onWedgeAutoDisabled notification will update UI
      // No need to reload here - settings were already loaded in _loadSettings()
    } catch (e) {
      log('Error checking keyboard on startup: $e');
    }
  }
  
  Future<void> _startKeyboardMonitoring() async {
    try {
      await platform.invokeMethod('startKeyboardChangeMonitoring');
      log('Started keyboard change monitoring');
    } catch (e) {
      log('Error starting keyboard monitoring: $e');
    }
  }
  
  Future<void> _stopKeyboardMonitoring() async {
    try {
      await platform.invokeMethod('stopKeyboardChangeMonitoring');
      log('Stopped keyboard change monitoring');
    } catch (e) {
      log('Error stopping keyboard monitoring: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _alwaysShowTopBar = prefs.getBool('always_show_top_bar') ?? false;
        _isWedgeInput = prefs.getBool('wedge_input_enabled') ?? false;
        _isLoading = false;
      });
      
      // Load available IMEs
      await _loadAvailableImes();
      
    } catch (e) {
      log('Error loading configuration: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadAvailableImes() async {
    try {
      setState(() {
        _isLoadingImes = true;
      });
      
      final imes = await platform.invokeMethod('getAvailableImes');
      final currentIme = await platform.invokeMethod('getCurrentIme');
      
      if (mounted) {
        setState(() {
          _availableImes = List<Map<String, dynamic>>.from(
            (imes as List).map((item) => Map<String, dynamic>.from(item))
          );
          _currentIme = currentIme as String?;
          _isLoadingImes = false;
        });
      }
      
      log('Loaded ${_availableImes.length} IMEs, current: $_currentIme');
    } catch (e) {
      log('Error loading IMEs: $e');
      if (mounted) {
        setState(() {
          _isLoadingImes = false;
        });
      }
    }
  }

  Future<void> _saveTopBarSetting(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('always_show_top_bar', value);
      setState(() {
        _alwaysShowTopBar = value;
      });
      
      // Apply the setting immediately
      _applySystemUiMode(value);
      

    } catch (error, stackTrace) {
      log('Error saving top bar setting: $error');
      log('Stack trace: $stackTrace');
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return ErrorPage(
                errorTitle: l10n.configurationError,
                errorMessage: l10n.couldNotSaveTopBarSetting,
                error: error,
                stackTrace: stackTrace,
                onRetry: () {
                  Navigator.of(context).pop();
                  _saveTopBarSetting(value);
                },
              );
            },
          ),
        );
      }
    }
  }

  Future<void> _saveWedgeInputSetting(bool value) async {
    try {
      // If enabling wedge input, check if current keyboard is system keyboard
      if (value) {
        final isSystemKeyboard = await platform.invokeMethod('isCurrentKeyboardSystem');
        
        if (isSystemKeyboard != true) {
          // Current keyboard is not a system keyboard - prevent enabling
          if (mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.systemKeyboardRequired,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      l10n.wedgeInputRequiresSystemKeyboard,
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                backgroundColor: Colors.red.shade700,
                duration: Duration(seconds: 6),
              ),
            );
          }
          // Don't change the toggle state
          return;
        }
      }
      
      // Keyboard is system or disabling wedge input - proceed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('wedge_input_enabled', value);
      setState(() {
        _isWedgeInput = value;
      });
    } catch (e) {
      log('Error saving wedge input setting: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorSavingSetting(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _setDefaultIme(String imeId) async {
    try {
      log('Opening IME picker for: $imeId');
      await platform.invokeMethod('setDefaultIme', {'imeId': imeId});
      
      // Reload after a delay to check if user changed it
      await Future.delayed(Duration(seconds: 2));
      await _loadAvailableImes();
      
      // If wedge was auto-disabled due to keyboard change,
      // onWedgeAutoDisabled notification will update UI
    } catch (e) {
      log('Error opening IME picker: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToOpenKeyboardPicker(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _openImeSettings() async {
    try {
      await platform.invokeMethod('openImeSettings');
      // Reload IMEs when returning from settings
      await Future.delayed(Duration(seconds: 1));
      await _loadAvailableImes();
    } catch (e) {
      log('Error opening IME settings: $e');
    }
  }

  Future<void> _applySystemUiMode(bool alwaysShowTopBar) async {
    try {
      // Call native method to apply system UI with proper auto-hide behavior
      await platform.invokeMethod('applySystemUiMode', {
        'alwaysShowTopBar': alwaysShowTopBar,
      });
      
      log('Applied system UI mode: alwaysShowTopBar=$alwaysShowTopBar');
    } catch (e) {
      log('Error applying system UI mode: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.configuration),
        backgroundColor: const Color.fromRGBO(51, 61, 71, 1),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.shade50,
                        Colors.blue.shade100,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tune,
                            size: 32,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            l10n.customDisplaySettings,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),

                    ],
                  ),
                ),
                
                // Settings list
                Expanded(
                  child: ListView(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 8),

                      ),
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SwitchListTile(
                          value: _alwaysShowTopBar,
                          onChanged: _saveTopBarSetting,
                          title: Text(
                            l10n.topBarAlwaysVisible,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            _alwaysShowTopBar
                                ? l10n.topBarShownDesc
                                : l10n.topBarHiddenDesc,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.smartphone,
                              color: Colors.blue.shade700,
                              size: 24,
                            ),
                          ),
                          activeColor: Colors.blue,
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SwitchListTile(
                          value: _isWedgeInput,
                          onChanged: _saveWedgeInputSetting,
                          title: Text(
                            l10n.scanWedgeEnable,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isWedgeInput
                                    ? l10n.scannerInputEnabled
                                    : l10n.scannerInputDisabled,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (!_isWedgeInput)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Requires system keyboard',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange.shade700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.qr_code_scanner,
                              color: Colors.green.shade700,
                              size: 24,
                            ),
                          ),
                          activeColor: Colors.green,
                        ),
                      ),
                      
                      // Keyboard (IME) Management Section
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Text(
                          'Keyboard Settings',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.keyboard,
                                  color: Colors.purple.shade700,
                                  size: 24,
                                ),
                              ),
                              title: const Text(
                                'Input Method (Keyboard)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                _currentIme != null 
                                  ? 'Current: ${_availableImes.firstWhere((ime) => ime['id'] == _currentIme, orElse: () => {'label': 'Unknown'})['label']}'
                                  : 'Loading...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.refresh, color: Colors.purple.shade700),
                                    onPressed: _loadAvailableImes,
                                    tooltip: 'Refresh keyboard list',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.settings, color: Colors.purple.shade700),
                                    onPressed: _openImeSettings,
                                    tooltip: 'Open keyboard settings',
                                  ),
                                ],
                              ),
                            ),
                            if (_isLoadingImes)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              )
                            else if (_availableImes.isNotEmpty)
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _availableImes.length,
                                itemBuilder: (context, index) {
                                  final ime = _availableImes[index];
                                  final isCurrent = ime['isCurrent'] as bool;
                                  final isSystem = ime['isSystem'] as bool;
                                  final isEnabled = ime['isEnabled'] as bool;
                                  final label = ime['label'] as String;
                                  final imeId = ime['id'] as String;
                                  
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isCurrent ? Colors.purple.shade50 : null,
                                      border: Border(
                                        top: BorderSide(
                                          color: Colors.grey.shade200,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      leading: Icon(
                                        isCurrent 
                                          ? Icons.radio_button_checked 
                                          : Icons.radio_button_unchecked,
                                        color: isCurrent ? Colors.purple.shade700 : Colors.grey,
                                      ),
                                      title: Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                      subtitle: Row(
                                        children: [
                                          if (isSystem)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              margin: const EdgeInsets.only(right: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade100,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'System',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.blue.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          if (!isEnabled)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade100,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Disabled',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.orange.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: isCurrent 
                                        ? Icon(Icons.check_circle, color: Colors.purple.shade700)
                                        : null,
                                      onTap: isEnabled && !isCurrent
                                        ? () => _setDefaultIme(imeId)
                                        : null,
                                    ),
                                  );
                                },
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'No keyboards found',
                                  style: TextStyle(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
