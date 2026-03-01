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
  bool _isLoading = true;

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

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _alwaysShowTopBar = prefs.getBool('always_show_top_bar') ?? false;
        _isLoading = false;
      });
      
    } catch (e) {
      log('Error loading configuration: $e');
      setState(() {
        _isLoading = false;
      });
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
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
