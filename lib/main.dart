import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/shortcut_list_screen.dart';
import 'screens/kiosk_webview_screen.dart';
import 'models/shortcut_item.dart';
import 'utils/logger.dart';

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
        } else if (url == null) {
          // Main app launch, reset to shortcut list
          log('Main app launch detected, resetting to shortcut list');
          setState(() {
            _initialUrl = null;
            _launchedFromShortcut = false;
          });
          // Push the shortcut list screen
          Future.microtask(() {
            _navigatorKey.currentState?.pushAndRemoveUntil(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const ShortcutListScreen(),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
              (route) => false,
            );
          });
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
    log('Starting initial URL check...');
    try {
      final String? url = await platform.invokeMethod('getUrl');
      log('Got initial URL: $url');
      if (url != null && url.isNotEmpty) {
        // Look up the shortcut settings for this URL
        final settings = await _getShortcutSettings(url);
        log('Setting initial URL to: $url');
        setState(() {
          _initialUrl = url;
          _disableAutoFocus = settings['disableAutoFocus'] ?? false;
          _useCustomKeyboard = settings['useCustomKeyboard'] ?? false;
          _disableCopyPaste = settings['disableCopyPaste'] ?? false;
          _initialUrlCheckComplete = true;
          _launchedFromShortcut = true;
        });
        // Push the webview screen
        Future.microtask(() {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => KioskWebViewScreen(
                initialUrl: _initialUrl!,
                disableAutoFocus: _disableAutoFocus,
                useCustomKeyboard: _useCustomKeyboard,
                disableCopyPaste: _disableCopyPaste,
                shortcutName: settings['shortcutName'],
                shortcutIconUrl: settings['shortcutIconUrl'],
              ),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
            (route) => false,
          );
        });
      } else {
        log('No initial URL found, showing shortcut list');
        setState(() {
          _initialUrlCheckComplete = true;
          _launchedFromShortcut = false;
        });
        // Push the shortcut list screen
        Future.microtask(() {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const ShortcutListScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
            (route) => false,
          );
        });
      }
    } catch (e) {
      log('Error getting initial URL: $e');
      setState(() {
        _initialUrlCheckComplete = true;
        _launchedFromShortcut = false;
      });
      // Push the shortcut list screen on error
      Future.microtask(() {
        _navigatorKey.currentState?.pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const ShortcutListScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
          (route) => false,
        );
      });
    }
  }

  Future<Map<String, dynamic>> _getShortcutSettings(String url) async {
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
            'shortcutName': shortcut.name,
            'shortcutIconUrl': shortcut.iconUrl,
          };
        }
      }
    } catch (e) {
      log('Error getting shortcut settings: $e');
    }
    return {
      'disableAutoFocus': false, 
      'useCustomKeyboard': false, 
      'disableCopyPaste': false,
      'shortcutName': null,
      'shortcutIconUrl': null,
    };
  }

  Future<void> _checkForNewUrl() async {
    try {
      final String? url = await platform.invokeMethod('getUrl');
      if (url != null && url.isNotEmpty && url != _initialUrl) {
        _navigateToUrl(url);
      }
    } catch (e) {
      log('Error checking for new URL: $e');
    }
  }

  void _navigateToUrl(String url) async {
    log('Navigating to URL: $url');
    
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
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => KioskWebViewScreen(
          initialUrl: url,
          disableAutoFocus: _disableAutoFocus,
          useCustomKeyboard: _useCustomKeyboard,
          disableCopyPaste: _disableCopyPaste,
          shortcutName: settings['shortcutName'],
          shortcutIconUrl: settings['shortcutIconUrl'],
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      (route) => false, // Remove all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    log('Building app - initialUrlCheckComplete: $_initialUrlCheckComplete, initialUrl: $_initialUrl, launchedFromShortcut: $_launchedFromShortcut');
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'WebKiosk Builder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: _initialUrlCheckComplete
          ? Container() // Screens are pushed via navigator
          : const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
    );
  }
}
