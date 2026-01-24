import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/shortcut_list_screen.dart';
import 'screens/kiosk_webview_screen.dart';
import 'models/shortcut_item.dart';

const MethodChannel platform = MethodChannel('webkiosk.builder/shortcut');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set the app to fullscreen mode
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  runApp(const KioskBrowserApp());
}

class KioskBrowserApp extends StatefulWidget {
  const KioskBrowserApp({super.key});

  @override
  State<KioskBrowserApp> createState() => _KioskBrowserAppState();
}

class _KioskBrowserAppState extends State<KioskBrowserApp> with WidgetsBindingObserver {
  String? _initialUrl;
  bool _disableAutoFocus = false;
  bool _useCustomKeyboard = false;
  bool _disableCopyPaste = false;
  bool _initialUrlCheckComplete = false;
  bool _launchedFromShortcut = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getInitialUrl();
    
    // Listen for URL changes from native side
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onNewUrl') {
        final String? url = call.arguments as String?;
        if (url != null && url.isNotEmpty && url != _initialUrl && _launchedFromShortcut) {
          _navigateToUrl(url);
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check for new URL when app comes to foreground
      _checkForNewUrl();
    }
  }

  Future<void> _getInitialUrl() async {
    debugPrint('Starting initial URL check...');
    try {
      final String? url = await platform.invokeMethod('getUrl');
      debugPrint('Got initial URL: $url');
      if (url != null && url.isNotEmpty) {
        // Look up the shortcut settings for this URL
        final settings = await _getShortcutSettings(url);
        debugPrint('Setting initial URL to: $url');
        setState(() {
          _initialUrl = url;
          _disableAutoFocus = settings['disableAutoFocus'] ?? false;
          _useCustomKeyboard = settings['useCustomKeyboard'] ?? false;
          _disableCopyPaste = settings['disableCopyPaste'] ?? false;
          _initialUrlCheckComplete = true;
          _launchedFromShortcut = true;
        });
      } else {
        debugPrint('No initial URL found, showing shortcut list');
        setState(() {
          _initialUrlCheckComplete = true;
          _launchedFromShortcut = false;
        });
      }
    } catch (e) {
      debugPrint('Error getting initial URL: $e');
      setState(() {
        _initialUrlCheckComplete = true;
        _launchedFromShortcut = false;
      });
    }
  }

  Future<Map<String, bool>> _getShortcutSettings(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shortcutsJson = prefs.getString('shortcuts') ?? '';
      final shortcuts = ShortcutItem.decodeList(shortcutsJson);
      
      // Find the shortcut matching this URL
      for (final shortcut in shortcuts) {
        if (shortcut.url == url) {
          return {
            'disableAutoFocus': shortcut.disableAutoFocus,
            'useCustomKeyboard': shortcut.useCustomKeyboard,
            'disableCopyPaste': shortcut.disableCopyPaste,
          };
        }
      }
    } catch (e) {
      debugPrint('Error getting shortcut settings: $e');
    }
    return {'disableAutoFocus': false, 'useCustomKeyboard': false, 'disableCopyPaste': false};
  }

  Future<void> _checkForNewUrl() async {
    try {
      final String? url = await platform.invokeMethod('getUrl');
      if (url != null && url.isNotEmpty && url != _initialUrl) {
        _navigateToUrl(url);
      }
    } catch (e) {
      debugPrint('Error checking for new URL: $e');
    }
  }

  void _navigateToUrl(String url) async {
    debugPrint('Navigating to URL: $url');
    
    // Get the shortcut settings BEFORE navigating
    final settings = await _getShortcutSettings(url);
    
    setState(() {
      _initialUrl = url;
      _disableAutoFocus = settings['disableAutoFocus'] ?? false;
      _useCustomKeyboard = settings['useCustomKeyboard'] ?? false;
      _disableCopyPaste = settings['disableCopyPaste'] ?? false;
    });
    
    // Navigate to the new URL with correct settings, clearing all previous routes
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => KioskWebViewScreen(
          initialUrl: url,
          disableAutoFocus: _disableAutoFocus,
          useCustomKeyboard: _useCustomKeyboard,
          disableCopyPaste: _disableCopyPaste,
        ),
      ),
      (route) => false, // Remove all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building app - initialUrlCheckComplete: $_initialUrlCheckComplete, initialUrl: $_initialUrl, launchedFromShortcut: $_launchedFromShortcut');
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'WebKiosk Builder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // TEMPORARILY FORCE SHOW SHORTCUT LIST FOR TESTING
      home: const ShortcutListScreen(),
    );
  }
}
