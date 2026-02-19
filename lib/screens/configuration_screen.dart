import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'error_page.dart';

class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel('devicegate.app/shortcut');
  bool _alwaysShowTopBar = false;
  bool _autoRotation = true; // Auto-rotation enabled by default
  String _lockedOrientation = 'landscape'; // Default locked orientation
  int _screenTimeout = 60000; // Default: 1 minute
  bool _isLoading = true;
  int? _deviceMaxTimeout; // Device's maximum supported timeout

  // Base timeout options in milliseconds (without maximum)
  final Map<String, int> _baseTimeoutOptions = {
    '15 secondes': 15000,
    '30 secondes': 30000,
    '1 minute': 60000,
    '2 minutes': 120000,
    '5 minutes': 300000,
    '10 minutes': 600000,
  };
  
  // Dynamic timeout options (includes device maximum)
  Map<String, int> get _timeoutOptions {
    final options = Map<String, int>.from(_baseTimeoutOptions);
    
    // Always include 30 minutes
    options['30 minutes'] = 1800000;
    
    // Add device maximum if detected and greater than 30 minutes
    if (_deviceMaxTimeout != null && _deviceMaxTimeout! > 1800000) {
      final maxLabel = _getTimeoutLabel(_deviceMaxTimeout!);
      options[maxLabel] = _deviceMaxTimeout!;
    }
    
    return options;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh timeout when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _refreshScreenTimeout();
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if this is first run (need to detect max timeout)
      final firstRun = prefs.getBool('timeout_max_detected') ?? true;
      
      // Load current auto-rotation from Android system
      bool systemAutoRotation = true; // Default fallback
      try {
        final autoRotation = await platform.invokeMethod('getAutoRotation');
        if (autoRotation != null && autoRotation is bool) {
          systemAutoRotation = autoRotation;
        }
      } catch (e) {
        log('Error getting system auto-rotation: $e');
      }
      
      if (firstRun) {
        // Detect and set maximum timeout on first run
        final maxTimeout = await _detectAndSetMaxTimeout();
        _deviceMaxTimeout = maxTimeout;
        
        // Save both the device maximum AND set it as current timeout
        await prefs.setInt('device_max_timeout', maxTimeout);
        await prefs.setInt('screen_timeout', maxTimeout);
        await prefs.setBool('timeout_max_detected', false);
        
        setState(() {
          _alwaysShowTopBar = prefs.getBool('always_show_top_bar') ?? false;
          _autoRotation = systemAutoRotation;
          _screenTimeout = maxTimeout;
          _isLoading = false;
        });
        
        // Update SharedPreferences to match system value
        await prefs.setBool('auto_rotation', systemAutoRotation);
        
        // Load locked orientation
        _loadLockedOrientation();
      } else {
        // Load stored maximum timeout
        _deviceMaxTimeout = prefs.getInt('device_max_timeout');
        
        // Load current system timeout from Android
        int systemTimeout = 60000; // Default fallback
        try {
          final timeout = await platform.invokeMethod('getScreenTimeout');
          if (timeout != null && timeout is int) {
            systemTimeout = timeout;
          }
        } catch (e) {
          log('Error getting system timeout: $e');
        }
        
        setState(() {
          _alwaysShowTopBar = prefs.getBool('always_show_top_bar') ?? false;
          _autoRotation = systemAutoRotation;
          _screenTimeout = systemTimeout;
          _isLoading = false;
        });
        
        // Update SharedPreferences to match system values
        await prefs.setInt('screen_timeout', systemTimeout);
        await prefs.setBool('auto_rotation', systemAutoRotation);
        
        // Load locked orientation
        _loadLockedOrientation();
      }
      
    } catch (e) {
      log('Error loading configuration: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<int> _detectAndSetMaxTimeout() async {
    // Try values in descending order: never → 2h → 1h → 30min
    final testValues = [
      2147483647, // Integer.MAX_VALUE (never)
      7200000,    // 2 hours
      3600000,    // 1 hour
      1800000,    // 30 minutes
    ];
    
    log('Detecting device maximum timeout...');
    
    for (final testValue in testValues) {
      try {
        // Try to set the timeout
        await platform.invokeMethod('setScreenTimeout', {'timeout': testValue});
        
        // Wait a bit for the system to apply
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Read back what was actually set
        final actualValue = await platform.invokeMethod('getScreenTimeout');
        
        if (actualValue != null && actualValue is int) {
          // Check if the value was accepted (allow small variance for system adjustments)
          if ((actualValue - testValue).abs() < 1000 || actualValue >= testValue * 0.9) {
            log('Device maximum timeout detected: $testValue ms');
            return testValue;
          }
        }
      } catch (e) {
        log('Error testing timeout $testValue: $e');
      }
    }
    
    // Fallback to 30 minutes if all tests fail
    log('Using fallback maximum timeout: 30 minutes');
    await platform.invokeMethod('setScreenTimeout', {'timeout': 1800000});
    return 1800000;
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
            builder: (context) => ErrorPage(
              errorTitle: 'Erreur de configuration',
              errorMessage: 'Impossible de sauvegarder le paramètre de la barre supérieure',
              error: error,
              stackTrace: stackTrace,
              onRetry: () {
                Navigator.of(context).pop();
                _saveTopBarSetting(value);
              },
            ),
          ),
        );
      }
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

  Future<void> _saveAutoRotationSetting(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_rotation', value);
      setState(() {
        _autoRotation = value;
      });
      
      // Apply the setting immediately
      _applyScreenOrientation(value);

    } catch (error, stackTrace) {
      log('Error saving auto-rotation setting: $error');
      log('Stack trace: $stackTrace');
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ErrorPage(
              errorTitle: 'Erreur de configuration',
              errorMessage: 'Impossible de sauvegarder le paramètre de rotation automatique',
              error: error,
              stackTrace: stackTrace,
              onRetry: () {
                Navigator.of(context).pop();
                _saveAutoRotationSetting(value);
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _applyScreenOrientation(bool autoRotation) async {
    try {
      await platform.invokeMethod('setScreenOrientation', {
        'autoRotation': autoRotation,
      });
      
      // Load the locked orientation after setting
      await _loadLockedOrientation();
      
      log('Applied screen orientation: autoRotation=$autoRotation');
    } catch (e) {
      log('Error applying screen orientation: $e');
    }
  }

  Future<void> _loadLockedOrientation() async {
    try {
      final orientation = await platform.invokeMethod('getLockedOrientation');
      if (orientation != null && orientation is String && mounted) {
        setState(() {
          _lockedOrientation = orientation;
        });
      }
    } catch (e) {
      log('Error loading locked orientation: $e');
    }
  }

  Future<void> _saveScreenTimeout(int timeout) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('screen_timeout', timeout);
      setState(() {
        _screenTimeout = timeout;
      });
      
      // Apply the setting immediately
      await _applyScreenTimeout(timeout);

    } catch (error, stackTrace) {
      log('Error saving screen timeout: $error');
      log('Stack trace: $stackTrace');
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ErrorPage(
              errorTitle: 'Erreur de configuration',
              errorMessage: 'Impossible de sauvegarder le délai de mise en veille de l\'écran',
              error: error,
              stackTrace: stackTrace,
              onRetry: () {
                Navigator.of(context).pop();
                _saveScreenTimeout(timeout);
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _applyScreenTimeout(int timeout) async {
    try {
      await platform.invokeMethod('setScreenTimeout', {
        'timeout': timeout,
      });
      
      log('Applied screen timeout: $timeout ms');
    } catch (e) {
      log('Error applying screen timeout: $e');
    }
  }

  String _getTimeoutLabel(int timeout) {
    // Check for "never" (Integer.MAX_VALUE)
    if (timeout >= 2147483000) { // Close to Integer.MAX_VALUE
      return 'Jamais';
    }
    
    // First check if it matches our predefined options
    for (var entry in _timeoutOptions.entries) {
      if (entry.value == timeout) {
        return entry.key;
      }
    }
    
    // If not in our list, format the actual value from Android
    if (timeout < 1000) {
      return '$timeout ms';
    } else if (timeout < 60000) {
      final seconds = (timeout / 1000).round();
      return '$seconds seconde${seconds > 1 ? 's' : ''}';
    } else if (timeout < 3600000) {
      final minutes = (timeout / 60000).round();
      return '$minutes minute${minutes > 1 ? 's' : ''}';
    } else {
      final hours = (timeout / 3600000).round();
      return '$hours heure${hours > 1 ? 's' : ''}';
    }
  }

  void _showTimeoutDialog() {
    // Build the list of timeout options
    final optionsList = <Widget>[];
    final addedValues = <int>{};
    
    // Add all predefined options
    for (var entry in _timeoutOptions.entries) {
      addedValues.add(entry.value);
      optionsList.add(
        RadioListTile<int>(
          title: Text(entry.key),
          value: entry.value,
          groupValue: _screenTimeout,
          onChanged: (value) {
            Navigator.pop(context);
            if (value != null) {
              _saveScreenTimeout(value);
            }
          },
          activeColor: Colors.blue,
        ),
      );
    }
    
    // If current Android value is not in our list, add it
    if (!addedValues.contains(_screenTimeout)) {
      final customLabel = _getTimeoutLabel(_screenTimeout);
      optionsList.insert(0, 
        RadioListTile<int>(
          title: Text('$customLabel (actuel)'),
          subtitle: const Text('Valeur système actuelle'),
          value: _screenTimeout,
          groupValue: _screenTimeout,
          onChanged: (value) {
            Navigator.pop(context);
            if (value != null) {
              _saveScreenTimeout(value);
            }
          },
          activeColor: Colors.orange,
        ),
      );
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mise en veille de l\'écran'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: optionsList,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    ).then((_) {
      // Refresh timeout value when dialog closes to sync with any external changes
      _refreshScreenTimeout();
    });
  }

  Future<void> _refreshScreenTimeout() async {
    try {
      final timeout = await platform.invokeMethod('getScreenTimeout');
      if (timeout != null && timeout is int && mounted) {
        setState(() {
          _screenTimeout = timeout;
        });
        
        // Update SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('screen_timeout', timeout);
      }
    } catch (e) {
      log('Error refreshing screen timeout: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration'),
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
                            'Paramètres personnalisés',
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
                          title: const Text(
                            'Barre supérieure toujours visible',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            _alwaysShowTopBar
                                ? 'La barre d\'état Android reste toujours affichée'
                                : 'La barre d\'état est masquée (glisser vers le bas pour afficher)',
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
                      const SizedBox(height: 8),
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SwitchListTile(
                          value: _autoRotation,
                          onChanged: _saveAutoRotationSetting,
                          title: const Text(
                            'Rotation automatique',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            _autoRotation
                                ? 'L\'écran pivote automatiquement selon l\'orientation'
                                : 'Verrouillé en ${_lockedOrientation == "landscape" ? "paysage" : "portrait"}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.screen_rotation,
                              color: Colors.green.shade700,
                              size: 24,
                            ),
                          ),
                          activeColor: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          onTap: _showTimeoutDialog,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.screen_lock_portrait,
                              color: Colors.orange.shade700,
                              size: 24,
                            ),
                          ),
                          title: const Text(
                            'Mise en veille de l\'écran',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            'Actuellement: ${_getTimeoutLabel(_screenTimeout)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
                          ),
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
