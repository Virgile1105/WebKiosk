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

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  static const platform = MethodChannel('devicegate.app/shortcut');
  bool _alwaysShowTopBar = false;
  bool _isDefaultHome = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _alwaysShowTopBar = prefs.getBool('always_show_top_bar') ?? false;
        _isDefaultHome = prefs.getBool('set_as_default_home') ?? true;
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

  Future<void> _saveDefaultHomeSetting(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('set_as_default_home', value);
      setState(() {
        _isDefaultHome = value;
      });
      
      // Apply the setting immediately
      if (value) {
        await platform.invokeMethod('setAsDefaultHome');

      } else {
        await platform.invokeMethod('clearDefaultHome');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('DeviceGate n\'est plus l\'écran d\'accueil par défaut'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
      
      log('Saved default home setting: $value');
    } catch (error, stackTrace) {
      log('Error saving default home setting: $error');
      log('Stack trace: $stackTrace');
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ErrorPage(
              errorTitle: 'Erreur de configuration',
              errorMessage: 'Impossible de modifier le paramètre d\'écran d\'accueil',
              error: error,
              stackTrace: stackTrace,
              onRetry: () {
                Navigator.of(context).pop();
                _saveDefaultHomeSetting(value);
              },
            ),
          ),
        );
      }
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
                          value: _isDefaultHome,
                          onChanged: _saveDefaultHomeSetting,
                          title: const Text(
                            'Écran d\'accueil par défaut',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            _isDefaultHome
                                ? 'DeviceGate se lance au démarrage et avec le bouton Home'
                                : 'Le lanceur Android par défaut sera utilisé',
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
                              Icons.home,
                              color: Colors.green.shade700,
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
