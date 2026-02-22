import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';
import '../models/shortcut_item.dart';
import '../generated/l10n/app_localizations.dart';
import 'password_dialog.dart';
import 'webview_settings_screen.dart';
import 'error_page.dart';
import 'http_error_page.dart';

class KioskWebViewScreen extends StatefulWidget {
  final String initialUrl;
  final bool disableAutoFocus;
  final bool useCustomKeyboard;
  final bool disableCopyPaste;
  final bool enableWarningSound;
  final String? shortcutIconUrl;
  final String? shortcutName;

  const KioskWebViewScreen({
    super.key,
    required this.initialUrl,
    this.disableAutoFocus = false,
    this.useCustomKeyboard = false,
    this.disableCopyPaste = false,
    this.enableWarningSound = false,
    this.shortcutIconUrl,
    this.shortcutName,
  });

  @override
  State<KioskWebViewScreen> createState() => _KioskWebViewScreenState();
}

class _KioskWebViewScreenState extends State<KioskWebViewScreen> with WidgetsBindingObserver {
  late final WebViewController _controller;
  String _currentUrl = '';
  String _websiteName = '';
  String _faviconUrl = '';
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  String _customAppName = '';
  String _customIconUrl = '';
  bool _showCustomKeyboard = false;
  bool _keyboardMinimized = false;
  bool _isExpandedMode = false; // Track if we're showing expanded keyboard (alphabetic + numeric)
  bool _isShift = false; // Track Shift state (temporary, toggles off after use)
  late bool _useCustomKeyboardRuntime; // Runtime setting for custom keyboard
  late bool _disableCopyPasteRuntime; // Runtime setting for copy/paste
  late bool _enableWarningSoundRuntime; // Runtime setting for warning sound
  Offset _keyboardPosition = const Offset(100, 200); // Temporary default, will be adjusted
  Offset _minimizedIconPosition = const Offset(100, 200); // Position for minimized icon
  Offset? _savedExpandedKeyboardPosition; // Saved position for expanded keyboard mode
  Offset? _savedNumericKeyboardPosition; // Saved position for numeric keyboard mode
  bool _keyboardHasBeenPositioned = false; // Track if keyboard has been positioned at least once
  double _keyboardScale = 0.8; // Scaling factor for keyboard size
  String _appVersion = '';
  Orientation? _previousOrientation; // Track previous orientation for reset on rotation
  late AudioPlayer _audioPlayer;
  bool _hasError = false; // Track if there's a webview error
  String _errorDescription = ''; // Store the error description
  Map<String, dynamic>? _wifiInfo; // Store WiFi information for error page
  Map<String, dynamic>? _websiteStatus; // Store live website connection status
  Timer? _networkCheckTimer; // Timer for periodic network status checks
  bool _isCheckingWebsite = false; // Prevent overlapping website status checks
  bool _isResettingInternet = false; // Track if internet reset is in progress

  SharedPreferences? _cachedPrefs; // Cached SharedPreferences instance
  Timer? _keyboardPositionSaveTimer; // Debounce timer for keyboard position save
  Timer? _minimizedIconPositionSaveTimer; // Debounce timer for minimized icon position save
  Timer? _loadingIndicatorDelayTimer; // Delay before showing loading indicator
  bool _showLoadingIndicator = false; // Controls actual visibility of loading overlay
  int _lastReportedProgress = 0; // Track last progress to throttle updates

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenSize = MediaQuery.of(context).size;
    final currentOrientation = MediaQuery.of(context).orientation;
    
    // Check if orientation changed, and reset keyboard to bottom right if so
    if (_previousOrientation != null && _previousOrientation != currentOrientation) {
      // Orientation changed, reset to bottom right
      final keyboardWidth = (_isExpandedMode ? 876.0 : 240.0) * _keyboardScale;
      final keyboardHeight = 352.0 * _keyboardScale;
      final bottomMargin = _isExpandedMode ? 55.0 : 50.0;
      _keyboardPosition = Offset(
        screenSize.width - keyboardWidth - 20.0, // Bottom right x
        screenSize.height - keyboardHeight - bottomMargin, // Bottom right y
      );
      _keyboardHasBeenPositioned = true; // Ensure it's marked as positioned
      
      // Also reset minimized icon to bottom right
      final iconSize = 60.0 * _keyboardScale;
      _minimizedIconPosition = Offset(
        screenSize.width - iconSize - 10.0, // Bottom right x for icon
        screenSize.height - iconSize - 50.0, // Bottom right y for icon
      );
    }
    _previousOrientation = currentOrientation;
    
    // Set initial keyboard position if not yet positioned
    if (!_keyboardHasBeenPositioned) {
      if (_isExpandedMode) {
        if (_savedExpandedKeyboardPosition != null) {
          // Load saved expanded position and clamp to screen bounds
          final keyboardWidth = 876.0 * _keyboardScale;
          final keyboardHeight = 352.0 * _keyboardScale;
          final maxX = screenSize.width - keyboardWidth - 20.0;
          final maxY = screenSize.height - keyboardHeight - 55.0;
          final clampedX = _savedExpandedKeyboardPosition!.dx.clamp(20.0, maxX);
          final clampedY = _savedExpandedKeyboardPosition!.dy.clamp(20.0, maxY);
          _keyboardPosition = Offset(clampedX, clampedY);
        } else {
          // Default to center at bottom for expanded mode
          final keyboardWidth = 876.0 * _keyboardScale;
          final keyboardHeight = 352.0 * _keyboardScale;
          _keyboardPosition = Offset(
            (screenSize.width - keyboardWidth) / 2,
            screenSize.height - keyboardHeight - 55,
          );
        }
      } else {
        if (_savedNumericKeyboardPosition != null) {
          // Load saved numeric position and clamp to screen bounds
          final keyboardWidth = 240.0 * _keyboardScale;
          final keyboardHeight = 352.0 * _keyboardScale;
          final maxX = screenSize.width - keyboardWidth - 20.0;
          final maxY = screenSize.height - keyboardHeight - 50.0;
          final clampedX = _savedNumericKeyboardPosition!.dx.clamp(20.0, maxX);
          final clampedY = _savedNumericKeyboardPosition!.dy.clamp(20.0, maxY);
          _keyboardPosition = Offset(clampedX, clampedY);
        } else {
          // Default to bottom-right for numeric mode
          final keyboardWidth = 240.0 * _keyboardScale;
          final keyboardHeight = 352.0 * _keyboardScale;
          _keyboardPosition = Offset(
            screenSize.width - keyboardWidth - 20,
            screenSize.height - keyboardHeight - 50,
          );
        }
      }
      _keyboardHasBeenPositioned = true;
    } else {
      // Clamp existing position to current screen bounds
      final keyboardWidth = (_isExpandedMode ? 876.0 : 240.0) * _keyboardScale;
      final keyboardHeight = 352.0 * _keyboardScale;
      final minX = 20.0;
      final minY = 20.0;
      final maxX = screenSize.width - keyboardWidth - 20.0;
      final bottomMargin = _isExpandedMode ? 55.0 : 50.0;
      final maxY = screenSize.height - keyboardHeight - bottomMargin;
      final validMaxX = maxX > minX ? maxX : minX;
      final validMaxY = maxY > minY ? maxY : minY;
      
      _keyboardPosition = Offset(
        _keyboardPosition.dx.clamp(minX, validMaxX),
        _keyboardPosition.dy.clamp(minY, validMaxY),
      );
    }
    
    // Always clamp minimized icon position to current screen bounds
    final iconSize = 60.0 * _keyboardScale;
    final maxIconX = screenSize.width - iconSize - 10.0;
    final maxIconY = screenSize.height - iconSize - 50.0;
    
    // If minimized icon position is still the temporary default, set to bottom-right
    if (_minimizedIconPosition == const Offset(100, 200)) {
      _minimizedIconPosition = Offset(
        screenSize.width - 80,  // 60px icon + 20px margin from right
        screenSize.height - 110, // 60px icon + 50px margin from bottom
      );
    } else {
      // Clamp existing minimized icon position to new screen bounds
      // Ensure clamp range is valid (min <= max)
      final minIconX = 10.0;
      final minIconY = 10.0;
      final validMaxIconX = maxIconX > minIconX ? maxIconX : minIconX;
      final validMaxIconY = maxIconY > minIconY ? maxIconY : minIconY;
      
      _minimizedIconPosition = Offset(
        _minimizedIconPosition.dx.clamp(minIconX, validMaxIconX),
        _minimizedIconPosition.dy.clamp(minIconY, validMaxIconY),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    try {
      _useCustomKeyboardRuntime = widget.useCustomKeyboard;
      _disableCopyPasteRuntime = widget.disableCopyPaste;
      _enableWarningSoundRuntime = widget.enableWarningSound;
      _audioPlayer = AudioPlayer();
      _initializeWebView();
      _loadCustomSettings(); // Fire-and-forget async loading
      _loadAppVersion(); // Load app version
      _keyboardMinimized = true; // Show keyboard shortcut by default
      
      // If custom keyboard is enabled, disable system keyboards at device level
      if (_useCustomKeyboardRuntime) {
        log('Custom keyboard enabled - disabling system keyboards');
        _disableSystemKeyboards();
        
        // Aggressive keyboard reset: retry multiple times to ensure it sticks
        // This helps when returning from settings where native keyboard was active
        _startAggressiveKeyboardReset();
      } else {
        log('Custom keyboard NOT enabled - system keyboards allowed');
      }
      
      // Add observer to detect when screen comes back into view
      WidgetsBinding.instance.addObserver(this);
    } catch (error, stackTrace) {
      log('Critical error in initState: $error');
      log('Stack trace: $stackTrace');
      // Show error in UI instead of crashing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ErrorPage(
                errorTitle: l10n.initializationError,
                errorMessage: l10n.cannotInitializeWebBrowser,
                error: error,
                stackTrace: stackTrace,
                onExit: () => Navigator.of(context).pop(),
              ),
            ),
          );
        }
      });
    }
  }
  
  /// Resets keyboard state on initialization
  void _startAggressiveKeyboardReset() {
    _disableSystemKeyboards();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    log('App lifecycle state changed to: $state');
    
    // When app comes back to foreground (resumed), re-apply keyboard settings
    if (state == AppLifecycleState.resumed && _useCustomKeyboardRuntime && mounted) {
      log('App resumed, re-applying keyboard settings');
      Future.delayed(const Duration(milliseconds: 300), () async {
        if (mounted && _useCustomKeyboardRuntime) {
          await _disableSystemKeyboards();
          await _resetAndReapplyCustomKeyboard();
        }
      });
    }
  }
  
  /// Disables system keyboards by hiding IME at window level
  Future<void> _disableSystemKeyboards() async {
    try {
      await platform.invokeMethod('hideImeAggressively');
      log('IME hidden aggressively at window level');
    } catch (e) {
      log('Error disabling system keyboards: $e');
    }
  }
  
  /// Re-enables system keyboards
  Future<void> _enableSystemKeyboards() async {
    try {
      await platform.invokeMethod('restoreImeDefault');
      log('IME behavior restored to default');
    } catch (e) {
      log('Error enabling system keyboards: $e');
    }
  }

  Future<void> _loadCustomSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedPrefs = prefs; // Cache for future use
      if (mounted) {
        setState(() {
          _customAppName = prefs.getString('custom_app_name') ?? '';
          _customIconUrl = widget.shortcutIconUrl ?? prefs.getString('custom_icon_url') ?? '';

          // Load saved expanded keyboard position
          final keyboardX = prefs.getDouble('keyboard_position_x');
          final keyboardY = prefs.getDouble('keyboard_position_y');
          if (keyboardX != null && keyboardY != null) {
            _savedExpandedKeyboardPosition = Offset(keyboardX, keyboardY);
            _keyboardHasBeenPositioned = true; // Mark as positioned since we have a saved position
          }

          // Load saved numeric keyboard position
          final numericX = prefs.getDouble('numeric_keyboard_position_x');
          final numericY = prefs.getDouble('numeric_keyboard_position_y');
          if (numericX != null && numericY != null) {
            _savedNumericKeyboardPosition = Offset(numericX, numericY);
            _keyboardHasBeenPositioned = true; // Mark as positioned since we have a saved position
          }

          // Load minimized icon position only (not keyboard position for numeric mode)
          final iconX = prefs.getDouble('minimized_icon_position_x');
          final iconY = prefs.getDouble('minimized_icon_position_y');
          if (iconX != null && iconY != null) {
            _minimizedIconPosition = Offset(iconX, iconY);
          }
        });
      }
    } catch (error, stackTrace) {
      log('Error loading custom settings: $error');
      log('Stack trace: $stackTrace');
      // Non-critical - use defaults and continue
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';  // e.g., "1.0.0+5"
        });
      }
    } catch (e) {
      log('Error fetching app version: $e');
      if (mounted) {
        setState(() {
          _appVersion = 'Unknown';
        });
      }
    }
  }

  Future<void> _fetchWifiInfo() async {
    log('_fetchWifiInfo called');
    try {
      final wifiInfo = await platform.invokeMethod('getWifiInfo');
      if (mounted) {
        setState(() {
          // Properly cast the map from platform channel
          if (wifiInfo is Map) {
            _wifiInfo = Map<String, dynamic>.from(wifiInfo);
          } else {
            _wifiInfo = {'error': 'Invalid WiFi data format'};
          }
        });
      }
      log('Fetched WiFi info: $wifiInfo');
    } catch (e) {
      log('Error fetching WiFi info: $e');
      if (mounted) {
        setState(() {
          _wifiInfo = {'error': e.toString()};
        });
      }
    }
  }

  Future<void> _saveCustomAppName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_app_name', name);
      setState(() {
        _customAppName = name;
      });
      
      // Ask user if they want to create a home screen shortcut
      if (mounted && name.isNotEmpty) {
        _askToCreateShortcut();
      }
    } catch (error, stackTrace) {
      log('Error saving custom app name: $error');
      log('Stack trace: $stackTrace');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorSavingName(error.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveCustomIconUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_icon_url', url);
      setState(() {
        _customIconUrl = url;
        if (url.isNotEmpty) {
          _faviconUrl = url;
        } else {
          _extractFavicon();
        }
      });
      
      // Ask user if they want to create/update a home screen shortcut with the new icon
      if (mounted && url.isNotEmpty) {
        _askToCreateShortcut();
      }
    } catch (error, stackTrace) {
      log('Error saving custom icon URL: $error');
      log('Stack trace: $stackTrace');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorSavingIcon(error.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveKeyboardPosition() async {
    // Debounce: cancel previous timer and start new one
    _keyboardPositionSaveTimer?.cancel();
    _keyboardPositionSaveTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
        if (_isExpandedMode) {
          await prefs.setDouble('keyboard_position_x', _keyboardPosition.dx);
          await prefs.setDouble('keyboard_position_y', _keyboardPosition.dy);
        } else {
          await prefs.setDouble('numeric_keyboard_position_x', _keyboardPosition.dx);
          await prefs.setDouble('numeric_keyboard_position_y', _keyboardPosition.dy);
        }
      } catch (error, stackTrace) {
        log('Error saving keyboard position: $error');
        log('Stack trace: $stackTrace');
        // Non-critical - silently fail
      }
    });
  }

  Future<void> _saveMinimizedIconPosition() async {
    // Debounce: cancel previous timer and start new one
    _minimizedIconPositionSaveTimer?.cancel();
    _minimizedIconPositionSaveTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
        await prefs.setDouble('minimized_icon_position_x', _minimizedIconPosition.dx);
        await prefs.setDouble('minimized_icon_position_y', _minimizedIconPosition.dy);
      } catch (error, stackTrace) {
        log('Error saving minimized icon position: $error');
        log('Stack trace: $stackTrace');
        // Non-critical - silently fail
      }
    });
  }

  Future<void> _saveWarningSoundSetting(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shortcutsJson = prefs.getString('shortcuts') ?? '';
      if (shortcutsJson.isEmpty) return;
      
      final shortcuts = ShortcutItem.decodeList(shortcutsJson);
      
      // Find and update the shortcut for this URL
      bool found = false;
      for (int i = 0; i < shortcuts.length; i++) {
        if (shortcuts[i].url == widget.initialUrl) {
          shortcuts[i] = ShortcutItem(
            id: shortcuts[i].id,
            name: shortcuts[i].name,
            url: shortcuts[i].url,
            iconUrl: shortcuts[i].iconUrl,
            disableAutoFocus: shortcuts[i].disableAutoFocus,
            useCustomKeyboard: shortcuts[i].useCustomKeyboard,
            disableCopyPaste: shortcuts[i].disableCopyPaste,
            enableWarningSound: enabled,
          );
          found = true;
          break;
        }
      }
      
      if (found) {
        await prefs.setString('shortcuts', ShortcutItem.encodeList(shortcuts));
        log('Warning sound setting saved: $enabled');
      }
    } catch (error, stackTrace) {
      log('Error saving warning sound setting: $error');
      log('Stack trace: $stackTrace');
      // Non-critical - silently fail
    }
  }

  Future<void> _saveCustomKeyboardSetting(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shortcutsJson = prefs.getString('shortcuts') ?? '';
      if (shortcutsJson.isEmpty) return;
      
      final shortcuts = ShortcutItem.decodeList(shortcutsJson);
      
      // Find and update the shortcut for this URL
      bool found = false;
      for (int i = 0; i < shortcuts.length; i++) {
        if (shortcuts[i].url == widget.initialUrl) {
          shortcuts[i] = ShortcutItem(
            id: shortcuts[i].id,
            name: shortcuts[i].name,
            url: shortcuts[i].url,
            iconUrl: shortcuts[i].iconUrl,
            disableAutoFocus: shortcuts[i].disableAutoFocus,
            useCustomKeyboard: enabled,
            disableCopyPaste: shortcuts[i].disableCopyPaste,
            enableWarningSound: shortcuts[i].enableWarningSound,
          );
          found = true;
          break;
        }
      }
      
      if (found) {
        await prefs.setString('shortcuts', ShortcutItem.encodeList(shortcuts));
        log('Custom keyboard setting saved: $enabled');
      }
    } catch (error, stackTrace) {
      log('Error saving custom keyboard setting: $error');
      log('Stack trace: $stackTrace');
      // Non-critical - silently fail
    }
  }

  Future<void> _saveCopyPasteSetting(bool disabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shortcutsJson = prefs.getString('shortcuts') ?? '';
      if (shortcutsJson.isEmpty) return;
      
      final shortcuts = ShortcutItem.decodeList(shortcutsJson);
      
      // Find and update the shortcut for this URL
      bool found = false;
      for (int i = 0; i < shortcuts.length; i++) {
        if (shortcuts[i].url == widget.initialUrl) {
          shortcuts[i] = ShortcutItem(
            id: shortcuts[i].id,
            name: shortcuts[i].name,
            url: shortcuts[i].url,
            iconUrl: shortcuts[i].iconUrl,
            disableAutoFocus: shortcuts[i].disableAutoFocus,
            useCustomKeyboard: shortcuts[i].useCustomKeyboard,
            disableCopyPaste: disabled,
            enableWarningSound: shortcuts[i].enableWarningSound,
          );
          found = true;
          break;
        }
      }
      
      if (found) {
        await prefs.setString('shortcuts', ShortcutItem.encodeList(shortcuts));
        log('Copy/Paste setting saved: $disabled');
      }
    } catch (error, stackTrace) {
      log('Error saving copy/paste setting: $error');
      log('Stack trace: $stackTrace');
      // Non-critical - silently fail
    }
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Clear cache to ensure fresh loading for each shortcut
      ..clearCache()
      ..clearLocalStorage()
      // Add JavaScript channels for custom keyboard
      ..addJavaScriptChannel(
        'showCustomKeyboard',
        onMessageReceived: (JavaScriptMessage message) {
          log('Custom keyboard: SHOW received - ${message.message}');
          
          // Re-disable system keyboards whenever custom keyboard is shown
          // This prevents native keyboard from interfering
          if (_useCustomKeyboardRuntime) {
            _disableSystemKeyboards();
          }
          
          setState(() {
            _showCustomKeyboard = true;
          });
        },
      )
      ..addJavaScriptChannel(
        'hideCustomKeyboard',
        onMessageReceived: (JavaScriptMessage message) {
          log('Custom keyboard: HIDE received - ${message.message}');
          setState(() {
            _showCustomKeyboard = false;
          });
        },
      )
      ..addJavaScriptChannel(
        'debugLog',
        onMessageReceived: (JavaScriptMessage message) {
          log('WebView Debug: ${message.message}');
        },
      )
      ..addJavaScriptChannel(
        'playWarningSound',
        onMessageReceived: (JavaScriptMessage message) {
          log('Warning sound triggered: ${message.message}');
          if (_enableWarningSoundRuntime) {
            _playWarningSound();
          } else {
            log('Warning sound disabled by user setting');
          }
        },
      )
      ..addJavaScriptChannel(
        'playErrorSound',
        onMessageReceived: (JavaScriptMessage message) {
          log('Error sound triggered: ${message.message}');
          if (_enableWarningSoundRuntime) {
            _playErrorSound();
          } else {
            log('Error sound disabled by user setting');
          }
        },
      )
      // Load blank page first, then actual URL
      ..loadHtmlString('<html><head><style>body { background: white; margin: 0; }</style></head><body></body></html>')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            // Only load actual URL after blank page is loaded
            if (url == 'about:blank' || url.contains('data:text/html')) {
              await Future.delayed(const Duration(milliseconds: 50)); // Brief pause
              log('Loading URL from initialUrl: ${widget.initialUrl}');
              final targetUrl = Uri.parse(widget.initialUrl).replace(queryParameters: {
                  ...Uri.parse(widget.initialUrl).queryParameters,
                  '_cache_bust': DateTime.now().millisecondsSinceEpoch.toString(),
                });
              log('Actual URL being loaded: $targetUrl');
              _controller.loadRequest(
                targetUrl,
                headers: {
                  'Cache-Control': 'no-cache, no-store, must-revalidate',
                  'Pragma': 'no-cache',
                  'Expires': '0',
                },
              );
            } else {
              // Actual page finished loading
              if (!mounted) return;
              _loadingIndicatorDelayTimer?.cancel();
              setState(() {
                _isLoading = false;
                _showLoadingIndicator = false;
              });
              _extractFavicon();
              // Prevent auto-focus on input fields to avoid keyboard popup (if option enabled)
              if (widget.disableAutoFocus) {
                _preventAutoFocus();
              }
              // Set up custom keyboard after page loads
              if (_useCustomKeyboardRuntime) {
                _setupCustomKeyboard();
              }
            }
          },
          onPageStarted: (String url) {
            // Only set loading for actual URL, not blank page
            if (!url.contains('data:text/html') && url != 'about:blank') {
              if (!mounted) return;
              _lastReportedProgress = 0;
              _loadingIndicatorDelayTimer?.cancel();
              setState(() {
                _isLoading = true;
                _currentUrl = url;
                _extractWebsiteName(url);
              });
              // Delay showing loading indicator by 150ms - fast pages won't show spinner
              _loadingIndicatorDelayTimer = Timer(const Duration(milliseconds: 150), () {
                if (mounted && _isLoading) {
                  setState(() {
                    _showLoadingIndicator = true;
                  });
                }
              });
            }
          },
          onProgress: (int progress) {
            if (!mounted) return;
            // Only throttle updates when indicator is visible (slow-loading pages)
            if (_showLoadingIndicator) {
              final progressPercent = (progress / 10).floor() * 10;
              if (progressPercent != _lastReportedProgress || progress == 100) {
                _lastReportedProgress = progressPercent;
                setState(() {
                  _loadingProgress = progress / 100;
                });
              }
            } else {
              // Fast update for quick pages (indicator not shown yet)
              setState(() {
                _loadingProgress = progress / 100;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            log('WebView error: ${error.description} (isForMainFrame: ${error.isForMainFrame})');
            // Only show error page for main frame errors (actual page load failures)
            // Ignore sub-resource errors (images, scripts, CSS, etc.)
            if (error.isForMainFrame == true && mounted) {
              // Fetch WiFi information for the error page
              _fetchWifiInfo();
              // Start periodic network check
              _startNetworkCheckTimer();
              setState(() {
                _hasError = true;
                _errorDescription = error.description ?? 'Unknown error';
                _isLoading = false;
                // Hide custom keyboard when error page is shown
                _showCustomKeyboard = false;
              });
            }
          },
          onHttpError: (HttpResponseError error) {
            log('HTTP error: ${error.response?.statusCode} (URL: ${error.response?.uri})');
            // Only handle HTTP errors for the main document, not sub-resources
            // Sub-resources often return 404 for optional things like favicons
            final errorUrl = error.response?.uri?.toString();
            if (errorUrl == null) {
              // Sub-resource error (URL is null), ignore it
              log('Ignoring HTTP error for sub-resource (URL is null)');
              return;
            }
            
            // Check if this error is for our main URL (not a sub-resource like CSS/JS/images)
            final mainUrl = Uri.parse(widget.initialUrl);
            final errUrl = Uri.parse(errorUrl);
            if (mainUrl.host != errUrl.host || mainUrl.path != errUrl.path) {
              // Error is for a sub-resource on a different path, ignore it
              log('Ignoring HTTP error for sub-resource: $errorUrl');
              return;
            }
            
            // Handle HTTP errors like 500, 404, 403, etc. for main document only
            if (mounted) {
              final statusCode = error.response?.statusCode ?? 0;
              final url = error.response?.uri?.toString() ?? 'Unknown URL';
              
              // Navigate to dedicated HTTP error page
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => HttpErrorPage(
                    statusCode: statusCode,
                    url: url,
                    onRetry: () {
                      // Pop the error page and reload the current URL
                      Navigator.of(context).pop();
                      _controller.reload();
                    },
                    onReload: () {
                      // Pop the error page and reload from initial URL (clear cache)
                      Navigator.of(context).pop();
                      _controller.loadRequest(
                        Uri.parse(widget.initialUrl),
                        headers: {
                          'Cache-Control': 'no-cache, no-store, must-revalidate',
                          'Pragma': 'no-cache',
                          'Expires': '0',
                        },
                      );
                    },
                    onExit: () {
                      // Go back to shortcut list
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              );
            }
          },
        ),
      );
  }

  /// Injects JavaScript to prevent automatic focus on page load
  /// but still allows keyboard when user taps on input fields
  void _preventAutoFocus() {
    log('preventAutoFocus called');
    _controller.runJavaScript('''
      // Blur any currently focused element (prevents auto-focus on load)
      if (document.activeElement && document.activeElement.tagName !== 'BODY') {
        document.activeElement.blur();
      }
      
      // Remove autofocus attribute from all elements
      document.querySelectorAll('[autofocus]').forEach(function(elem) {
        elem.removeAttribute('autofocus');
      });
    ''');
  }

  void _playWarningSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(1.0); // Max volume
      await _audioPlayer.setSource(AssetSource('sounds/warning.mp3'));
      
      // Play first time
      await _audioPlayer.resume();
      
      // Wait for the sound to finish (assuming ~1 seconds, adjust as needed)
      await Future.delayed(const Duration(seconds: 1));
      
      // Stop the player
      await _audioPlayer.stop();
      
      // Play second time
      await _audioPlayer.setSource(AssetSource('sounds/warning.mp3'));
      await _audioPlayer.resume();
    } catch (e) {
      log('Error playing warning sound: $e');
      // Fallback: try to play a system sound or vibrate
      // For now, just log the error
    }
  }

  void _playErrorSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(1.0); // Max volume
      await _audioPlayer.setSource(AssetSource('sounds/error.mp3'));
      
      // Play first time
      await _audioPlayer.resume();
      
      // Wait for the sound to finish (assuming ~1 seconds, adjust as needed)
     /* await Future.delayed(const Duration(milliseconds: 500));
      
      // Stop the player
      await _audioPlayer.stop();
      
      // Play second time
      await _audioPlayer.setSource(AssetSource('sounds/error.mp3'));
      await _audioPlayer.resume();*/
    } catch (e) {
      log('Error playing error sound: $e');
      // Fallback: try to play a system sound or vibrate
      // For now, just log the error
    }
  }

  /// Sets up custom keyboard functionality
  /// Note: IME blocking is now handled by hideImeAggressively() at the Android window level
  void _setupCustomKeyboard() {
    log('Setting up custom keyboard for URL: ${widget.initialUrl}');
    _controller.runJavaScript('''
      (function() {
        // Check if custom keyboard is already set up
        if (window.customKeyboardSetup) {
          console.log('Custom keyboard already set up, skipping');
          return;
        }
        window.customKeyboardSetup = true;

        ${_disableCopyPasteRuntime ? '''
        // ===== COPY/PASTE BLOCKING (Global listeners only - capture phase) =====
        ['copy', 'paste', 'cut'].forEach(function(evt) {
          document.addEventListener(evt, function(e) {
            e.preventDefault();
            e.stopPropagation();
            return false;
          }, true);
        });
        
        document.addEventListener('contextmenu', function(e) {
          if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.contentEditable === 'true') {
            e.preventDefault();
            e.stopPropagation();
            return false;
          }
        }, true);
        
        document.addEventListener('keydown', function(e) {
          if ((e.ctrlKey || e.metaKey) && ['c', 'v', 'x', 'a'].includes(e.key)) {
            e.preventDefault();
            e.stopPropagation();
            return false;
          }
        }, true);
        
        // Global CSS to prevent text selection
        if (!document.querySelector('style[data-copy-paste-disabled]')) {
          const cpStyle = document.createElement('style');
          cpStyle.setAttribute('data-copy-paste-disabled', 'true');
          cpStyle.textContent = '* { user-select: none !important; -webkit-user-select: none !important; } input, textarea, [contenteditable="true"] { user-select: text !important; -webkit-user-select: text !important; }';
          document.head.appendChild(cpStyle);
        }
        // ===== END COPY/PASTE BLOCKING =====
        ''' : ''}

        // Add CSS to ensure cursor is visible
        if (!document.querySelector('style[data-custom-keyboard]')) {
          const style = document.createElement('style');
          style.setAttribute('data-custom-keyboard', 'true');
          style.textContent = 'input:focus, textarea:focus, select:focus, [contenteditable]:focus { caret-color: black !important; }';
          document.head.appendChild(style);
        }

        // Set up input listeners (only if not already set up)
        if (!window.inputListenersSetup) {
          window.inputListenersSetup = true;

          function setupInputElement(input) {
            if (input.hasAttribute('data-custom-keyboard')) return;
            input.setAttribute('data-custom-keyboard', 'true');
            
            input.addEventListener('focus', function() {
              showCustomKeyboard.postMessage('show');
            });
            input.addEventListener('blur', function() {
              hideCustomKeyboard.postMessage('hide');
            });
          }

          function setupInputListeners() {
            const inputs = document.querySelectorAll('input:not([type="button"]):not([type="submit"]):not([type="reset"]), textarea, [contenteditable="true"], [role="textbox"], [role="combobox"], [role="searchbox"], select');
            inputs.forEach(setupInputElement);
          }

          // Initial setup
          setupInputListeners();

          // Check if an input field already has focus after page load
          setTimeout(function() {
            if (document.activeElement && 
                (document.activeElement.tagName === 'INPUT' || 
                 document.activeElement.tagName === 'TEXTAREA' || 
                 document.activeElement.contentEditable === 'true' ||
                 document.activeElement.getAttribute('role') === 'textbox')) {
              showCustomKeyboard.postMessage('show');
            }
          }, 100);

          // Watch for new elements
          const observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
              mutation.addedNodes.forEach(function(node) {
                if (node.nodeType === 1) {
                  // Check if node itself is an input
                  if ((node.tagName === 'INPUT' && !['button', 'submit', 'reset'].includes(node.type)) ||
                      node.tagName === 'TEXTAREA' || 
                      node.tagName === 'SELECT' ||
                      node.contentEditable === 'true' || 
                      ['textbox', 'combobox', 'searchbox'].includes(node.getAttribute('role'))) {
                    setupInputElement(node);
                  }
                  // Also check children
                  node.querySelectorAll && node.querySelectorAll('input:not([type="button"]):not([type="submit"]):not([type="reset"]), textarea, [contenteditable="true"], select').forEach(setupInputElement);
                }
              });
            });
          });

          observer.observe(document.body, { childList: true, subtree: true });

          // Handle iframes
          document.querySelectorAll('iframe').forEach(function(iframe) {
            try {
              var doc = iframe.contentDocument || iframe.contentWindow.document;
              if (doc) {
                var script = doc.createElement('script');
                script.textContent = \`
                  function setupInputElement(input) {
                    if (input.hasAttribute('data-custom-keyboard')) return;
                    input.setAttribute('data-custom-keyboard', 'true');
                    input.addEventListener('focus', function() {
                      window.parent.postMessage('showCustomKeyboard', '*');
                    });
                    input.addEventListener('blur', function() {
                      window.parent.postMessage('hideCustomKeyboard', '*');
                    });
                  }
                  
                  function setupInputListeners() {
                    document.querySelectorAll('input:not([type="button"]):not([type="submit"]):not([type="reset"]), textarea, [contenteditable="true"], select').forEach(setupInputElement);
                  }
                  setupInputListeners();
                  
                  setTimeout(function() {
                    if (document.activeElement && 
                        (document.activeElement.tagName === 'INPUT' || 
                         document.activeElement.tagName === 'TEXTAREA' || 
                         document.activeElement.contentEditable === 'true')) {
                      window.parent.postMessage('showCustomKeyboard', '*');
                    }
                  }, 100);
                  
                  const observer = new MutationObserver(function(mutations) {
                    mutations.forEach(function(mutation) {
                      mutation.addedNodes.forEach(function(node) {
                        if (node.nodeType === 1) {
                          if ((node.tagName === 'INPUT' && !['button', 'submit', 'reset'].includes(node.type)) ||
                              node.tagName === 'TEXTAREA' || node.tagName === 'SELECT' || node.contentEditable === 'true') {
                            setupInputElement(node);
                          }
                          node.querySelectorAll && node.querySelectorAll('input:not([type="button"]):not([type="submit"]):not([type="reset"]), textarea, [contenteditable="true"], select').forEach(setupInputElement);
                        }
                      });
                    });
                  });
                  observer.observe(document.body, { childList: true, subtree: true });
                \`;
                doc.head.appendChild(script);
              }
            } catch (e) {
              console.log('Cannot access iframe');
            }
          });

          // Listen for messages from iframes
          window.addEventListener('message', function(e) {
            if (e.data === 'showCustomKeyboard') {
              showCustomKeyboard.postMessage('show');
            } else if (e.data === 'hideCustomKeyboard') {
              hideCustomKeyboard.postMessage('hide');
            } else if (typeof e.data === 'string' && e.data.startsWith('debugLog:')) {
              debugLog.postMessage(e.data.substring(9));
            }
          });
        }

        // Handle MobileEditDisabled fields (SAP specific)
        document.addEventListener('focusin', function(e) {
          if (e.target.classList.contains('MobileEditDisabled')) {
            e.target.blur();
          }
        });
        document.querySelectorAll('.MobileEditDisabled').forEach(function(el) {
          el.disabled = true;
        });

        // Check first input field for warning or error messages (SAP specific)
        const firstInput = document.querySelector('input:not([type="hidden"]), textarea, select');
        if (firstInput) {
          let value = firstInput.value || firstInput.getAttribute('value') || '';
          
          // Decode HTML entities
          const textarea = document.createElement('textarea');
          textarea.innerHTML = value;
          value = textarea.value;
                   
          if (value) {
            if (value === "Le UM scanné provient d'un autre transport" || value.includes("transport")) {
              firstInput.blur();
              playWarningSound.postMessage('Warning value detected');              
            } else if (value.includes("Erreur")) {
              firstInput.blur();
              playErrorSound.postMessage('Error value detected: ' + value);              
            }
          }
        }

        console.log('Custom keyboard JavaScript injected');
      })();
    ''');
  }

  void _extractWebsiteName(String url) {
    try {
      final uri = Uri.parse(url);
      String host = uri.host;
      
      // Remove www. prefix if present
      if (host.startsWith('www.')) {
        host = host.substring(4);
      }
      
      // Capitalize first letter
      if (host.isNotEmpty) {
        _websiteName = host[0].toUpperCase() + host.substring(1);
      } else {
        _websiteName = 'Website';
      }
    } catch (e) {
      _websiteName = 'Website';
    }
  }

  Future<void> _extractFavicon() async {
    try {
      // Use custom icon URL if available
      if (_customIconUrl.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _faviconUrl = _customIconUrl;
        });
        return;
      }
      
      final uri = Uri.parse(_currentUrl);
      // Use Google's favicon service as a fallback
      if (!mounted) return;
      setState(() {
        _faviconUrl = 'https://www.google.com/s2/favicons?domain=${uri.host}&sz=64';
      });
    } catch (e) {
      log('Error extracting favicon: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // WebView - unique key ensures fresh instance for each shortcut
          WebViewWidget(
            key: ValueKey('webview_${widget.initialUrl}'),
            controller: _controller,
          ),
          
          // Loading overlay with fade animation to prevent flickering
          AnimatedOpacity(
            opacity: _showLoadingIndicator ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_showLoadingIndicator,
              child: Container(
                color: Colors.white,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ),
          
          // Error overlay
          if (_hasError)
            Container(
              color: Colors.white,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 80,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Impossible de charger la page web',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Le site web n\'a pas pu être atteint. Veuillez vérifier votre connexion Internet et réessayer.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                     
                      const SizedBox(height: 24),
                      // WiFi Information Section
                      if (_wifiInfo != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left column: Current Connection and Saved Networks
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Current Network Status
                                    if (_wifiInfo!['currentNetwork'] != null) ...[
                                      Builder(
                                        builder: (context) {
                                          try {
                                            return _buildNetworkStatus(_wifiInfo!['currentNetwork']);
                                          } catch (e) {
                                            log('Error building network status: $e');
                                            return const SizedBox.shrink();
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    // Saved Networks
                                    if (_wifiInfo!['savedNetworks'] != null && (_wifiInfo!['savedNetworks'] as List).isNotEmpty) ...[
                                      Text(
                                        'Réseaux enregistrés :',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ...(_wifiInfo!['savedNetworks'] as List).map((network) {
                                        try {
                                          return _buildSavedNetworkItem(network);
                                        } catch (e) {
                                          log('Error building saved network item: $e');
                                          return const SizedBox.shrink();
                                        }
                                      }),
                                    ] else if (_wifiInfo!['error'] != null) ...[
                                      Text(
                                        'Erreur d\'accès WiFi :',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.red.shade200),
                                        ),
                                        child: Text(
                                          _wifiInfo!['error'],
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.red.shade800,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.amber.shade200),
                                        ),
                                        child: Text(
                                          'Aucun réseau enregistré trouvé ou la liste des réseaux est vide.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Right column: Internet Connection Status
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'État Internet',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Builder(
                                        builder: (context) {
                                          // Get live website status check
                                          final websiteCanConnect = _websiteStatus?['canConnect'] == true;
                                          final websiteIsSuccess = _websiteStatus?['isSuccess'] == true;
                                          final websiteError = _websiteStatus?['error'] as String?;
                                          
                                          // Check actual internet connectivity (8.8.8.8 test)
                                          final hasInternet = _wifiInfo?['hasInternet'] == true;
                                          
                                          // Determine internet status (3 states):
                                          // Priority: Check for website-specific errors FIRST (these prove internet works)
                                          final Color bgColor;
                                          final Color borderColor;
                                          final Color iconColor;
                                          final Color textColor;
                                          final IconData icon;
                                          final String title;
                                          final String subtitle;
                                          
                                          if (websiteIsSuccess && websiteCanConnect) {
                                            // State 3: Website is accessible - Internet OK
                                            bgColor = Colors.green.shade50;
                                            borderColor = Colors.green.shade200;
                                            iconColor = Colors.green;
                                            textColor = Colors.green.shade800;
                                            icon = Icons.cloud_done;
                                            title = 'Internet OK';
                                            subtitle = 'Connected';
                                          } else if (websiteError == 'connection_refused' || 
                                                     websiteError == 'connection_reset' ||
                                                     websiteError == 'timed_out' ||
                                                     (websiteCanConnect && !websiteIsSuccess)) {
                                            // State 2: Internet IS available but website has issues
                                          // - connection_refused: Server actively refused connection (internet works)
                                          // - connection_reset: Connection was reset by server (internet works)
                                          // - timed_out: Server not responding but DNS resolved (internet works)
                                          // - HTTP error codes 4xx/5xx (internet works)
                                          bgColor = Colors.orange.shade50;
                                          borderColor = Colors.orange.shade200;
                                          iconColor = Colors.orange;
                                          textColor = Colors.orange.shade800;
                                          icon = Icons.error_outline;
                                          title = 'Erreur du site web';
                                          subtitle = websiteError == 'connection_refused' ? 'Serveur refusé' : 
                                                     websiteError == 'timed_out' ? 'Délai d\'attente du serveur' : 'Problème serveur';
                                        } else if (websiteError == 'name_not_resolved' || !hasInternet) {
                                          // State 1: No internet at all
                                          // - name_not_resolved: DNS failed (no internet)
                                          // - !hasInternet: Cannot reach 8.8.8.8 (no internet)
                                          bgColor = Colors.red.shade50;
                                          borderColor = Colors.red.shade200;
                                          iconColor = Colors.red;
                                          textColor = Colors.red.shade800;
                                          icon = Icons.cloud_off;
                                          title = 'Pas d\'Internet';
                                          subtitle = 'Non disponible';
                                        } else {
                                          // State 1: Unknown/no connection
                                          bgColor = Colors.red.shade50;
                                          borderColor = Colors.red.shade200;
                                          iconColor = Colors.red;
                                          textColor = Colors.red.shade800;
                                          icon = Icons.cloud_off;
                                          title = 'Pas d\'Internet';
                                          subtitle = 'Non disponible';
                                        }
                                        
                                          return Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: bgColor,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: borderColor),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  icon,
                                                  size: 40,
                                                  color: iconColor,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  title,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: textColor,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  subtitle,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: textColor,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 12),
                                                // Dynamic status description
                                                Text(
                                                  _websiteStatus != null 
                                                    ? 'État: ${_websiteStatus!['errorMessage'] ?? _websiteStatus!['error'] ?? 'Vérification...'}'
                                                    : _errorDescription,
                                                  style: const TextStyle(
                                                    fontSize: 8,
                                                    color: Colors.black54,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                      Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context)!;
                          // Check if WiFi is connected
                          final hasWifiConnection = _wifiInfo?['currentNetwork'] != null;
                          // Check if Internet is OK
                          final websiteCanConnect = _websiteStatus?['canConnect'] == true;
                          final websiteIsSuccess = _websiteStatus?['isSuccess'] == true;
                          final internetIsOk = websiteIsSuccess && websiteCanConnect;
                          // Enable buttons only when both WiFi and Internet are OK
                          final buttonsEnabled = hasWifiConnection && internetIsOk;
                          // Capture the resetting state in the Builder
                          final isResetting = _isResettingInternet;
                          
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: buttonsEnabled ? _reloadPage : null,
                                icon: const Icon(Icons.refresh),
                                label: Text(l10n.retryButton),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  backgroundColor: Colors.lightGreen,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  disabledForegroundColor: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton.icon(
                                onPressed: buttonsEnabled ? _retryLoading : null,
                                icon: const Icon(Icons.restart_alt),
                                label: Text(l10n.reloadButton),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  side: BorderSide(
                                    color: buttonsEnabled ? Colors.blue.shade400 : Colors.grey.shade300, 
                                    width: 2
                                  ),
                                  disabledForegroundColor: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: isResetting ? null : _resetInternet,
                                icon: isResetting 
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.wifi_off),
                                label: Text(isResetting ? l10n.resettingInternet : l10n.resetInternet),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.orange.shade300,
                                  disabledForegroundColor: Colors.white,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Loading indicator with fade animation
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _showLoadingIndicator ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: LinearProgressIndicator(
                value: _loadingProgress,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          ),

          // Custom keyboard
          if (_showCustomKeyboard && _useCustomKeyboardRuntime) ...[
            Builder(
              builder: (context) {
                log('Rendering custom keyboard - _showCustomKeyboard: $_showCustomKeyboard, useCustomKeyboard: $_useCustomKeyboardRuntime');
                return _buildCustomKeyboard();
              },
            ),
          ],
        ],
      ),
      // Left swipe drawer menu
      drawer: _buildDrawer(),
    );
  }

Widget _buildNetworkStatus(dynamic currentNetwork) {
    if (currentNetwork == null || currentNetwork is! Map) {
      return const SizedBox.shrink();
    }

    final networkMap = Map<String, dynamic>.from(currentNetwork as Map);
    final isDisconnected = networkMap['status'] == 'disconnected';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WIFI Connection',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDisconnected ? Colors.red.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDisconnected ? Colors.red.shade200 : Colors.green.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isDisconnected ? Icons.wifi_off : Icons.wifi,
                size: 20,
                color: isDisconnected ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDisconnected ? 'Disconnected' : (networkMap['ssid'] ?? 'Unknown Network'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDisconnected ? Colors.red.shade800 : Colors.green.shade800,
                      ),
                    ),
                    if (!isDisconnected && networkMap['signalStrength'] != null)
                      Text(
                        'Signal: ${networkMap['signalStrength']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

Widget _buildSavedNetworkItem(dynamic network) {
    if (network == null || network is! Map) {
      return const SizedBox.shrink();
    }

    final networkMap = Map<String, dynamic>.from(network as Map);
    final isConnected = networkMap['status'] == 'connected';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isConnected ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isConnected ? Colors.blue.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.wifi : Icons.wifi_lock,
            size: 16,
            color: isConnected ? Colors.blue : Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              networkMap['ssid'] ?? 'Unknown',
              style: TextStyle(
                fontSize: 13,
                color: isConnected ? Colors.blue.shade800 : Colors.grey.shade700,
                fontWeight: isConnected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          if (isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Connected',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final l10n = AppLocalizations.of(context)!;
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade700,
              Colors.blue.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Website Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: _faviconUrl.isNotEmpty
                    ? ClipOval(
                        child: _faviconUrl.startsWith('assets/')
                            ? Image.asset(
                                _faviconUrl,
                                width: 64,
                                height: 64,
                                errorBuilder: (context, error, stackTrace) {
                                  // Clear the favicon URL to prevent repeated errors
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) {
                                      setState(() {
                                        _faviconUrl = '';
                                      });
                                    }
                                  });
                                  return const Icon(
                                    Icons.language,
                                    size: 50,
                                    color: Colors.blue,
                                  );
                                },
                              )
                            : Image.network(
                                _faviconUrl,
                                width: 64,
                                height: 64,
                                errorBuilder: (context, error, stackTrace) {
                                  // Clear the favicon URL to prevent repeated errors
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) {
                                      setState(() {
                                        _faviconUrl = '';
                                      });
                                    }
                                  });
                                  return const Icon(
                                    Icons.language,
                                    size: 50,
                                    color: Colors.blue,
                                  );
                                },
                              ),
                      )
                    : const Icon(
                        Icons.language,
                        size: 50,
                        color: Colors.blue,
                      ),
              ),
              const SizedBox(height: 24),
              
              // Website Name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  widget.shortcutName ?? (_customAppName.isNotEmpty ? _customAppName : _websiteName),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              
              // URL Display
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _currentUrl,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // App Version Display
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Version: $_appVersion',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Menu Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  children: [
                    _buildMenuTile(
                      icon: Icons.refresh,
                      title: l10n.reloadApp,
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        // Navigate back to shortcuts and immediately back to webview for complete reset
                        Navigator.of(context).pop(); // Go back to shortcut list
                        // Immediately navigate back to webview with same parameters for complete reset
                        Future.microtask(() {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => KioskWebViewScreen(
                                initialUrl: widget.initialUrl,
                                disableAutoFocus: widget.disableAutoFocus,
                                useCustomKeyboard: _useCustomKeyboardRuntime,
                                disableCopyPaste: _disableCopyPasteRuntime,
                                shortcutIconUrl: widget.shortcutIconUrl,
                                shortcutName: widget.shortcutName,
                              ),
                            ),
                          );
                        });
                      },
                    ),
                    _buildMenuTile(
                      icon: Icons.exit_to_app,
                      title: l10n.quit,
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        Navigator.of(context).pop(); // Return to home screen
                      },
                    ),
                    _buildMenuTile(
                      icon: Icons.settings,
                      title: l10n.settings,
                      onTap: () async {
                        Navigator.pop(context); // Close drawer
                        // Show password dialog first
                        final authenticated = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const PasswordDialog(),
                        );
                        
                        // Only show settings if authenticated
                        if (authenticated == true && mounted) {
                          _showWebViewSettings();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      hoverColor: Colors.white.withOpacity(0.1),
    );
  }

  /// Reset JavaScript keyboard setup flag and re-apply custom keyboard
  /// This is called when returning from settings to ensure keyboard works properly
  Future<void> _resetAndReapplyCustomKeyboard() async {
    log('Resetting and re-applying custom keyboard');
    try {
      // First, reset the JavaScript flag to allow re-initialization
      await _controller.runJavaScript('''
        console.log('Resetting custom keyboard setup flag');
        window.customKeyboardSetup = false;
        window.inputListenersSetup = false;
      ''');
      
      // Wait a brief moment for the flag reset to take effect
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Then, re-setup the custom keyboard
      _setupCustomKeyboard();
      
      log('Custom keyboard reset and re-applied successfully');
    } catch (e) {
      log('Error resetting custom keyboard: $e');
    }
  }

  void _showWebViewSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewSettingsScreen(
          useCustomKeyboard: _useCustomKeyboardRuntime,
          disableCopyPaste: _disableCopyPasteRuntime,
          enableWarningSound: _enableWarningSoundRuntime,
          onSettingsChanged: (useCustomKeyboard, disableCopyPaste, enableWarningSound) async {
            // Save old values before updating
            final oldDisableCopyPaste = _disableCopyPasteRuntime;
            final oldUseCustomKeyboard = _useCustomKeyboardRuntime;
            
            setState(() {
              _useCustomKeyboardRuntime = useCustomKeyboard;
              _disableCopyPasteRuntime = disableCopyPaste;
              _enableWarningSoundRuntime = enableWarningSound;
              if (!useCustomKeyboard) {
                _showCustomKeyboard = false;
              }
            });
            
            // Handle keyboard mode change
            if (useCustomKeyboard != oldUseCustomKeyboard) {
              if (useCustomKeyboard) {
                // Custom keyboard enabled - block system keyboard
                await _disableSystemKeyboards();
              } else {
                // Custom keyboard disabled - restore system keyboard
                await _enableSystemKeyboards();
              }
            }
            
            // Save all settings to shortcut
            await _saveCustomKeyboardSetting(useCustomKeyboard);
            await _saveCopyPasteSetting(disableCopyPaste);
            await _saveWarningSoundSetting(enableWarningSound);
            
            // Reload page to apply copy/paste changes if it changed
            if (disableCopyPaste != oldDisableCopyPaste) {
              _controller.reload();
            }
          },
        ),
      ),
    );
    
    // When returning from settings, re-apply keyboard configurations
    log('Returned from settings, re-applying keyboard configurations');
    if (_useCustomKeyboardRuntime && mounted) {
      // Re-disable system keyboards
      await _disableSystemKeyboards();
      
      // Reset the JavaScript keyboard setup to allow re-initialization
      await _resetAndReapplyCustomKeyboard();
    }
  }

  void _reloadPage() {
    if (mounted) {
      // Stop network check timer
      _stopNetworkCheckTimer();
      
      setState(() {
        _hasError = false;
        _errorDescription = '';
        _isLoading = true;
      });
      // Just reload the current URL
      _controller.loadRequest(
        Uri.parse(widget.initialUrl),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );
    }
  }

  void _retryLoading() {
    if (mounted) {
      // Navigate back and reopen - cleanest way to reset everything
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => KioskWebViewScreen(
            initialUrl: widget.initialUrl,
            disableAutoFocus: widget.disableAutoFocus,
            useCustomKeyboard: widget.useCustomKeyboard,
            disableCopyPaste: widget.disableCopyPaste,
            shortcutIconUrl: widget.shortcutIconUrl,
            shortcutName: widget.shortcutName,
          ),
        ),
      );
    }
  }

  Future<void> _resetInternet() async {
    setState(() {
      _isResettingInternet = true;
    });
    
    // Animate for 2 seconds before the blocking call
    for (int i = 0; i < 40; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    try {
      log('Attempting to reset internet connection');
      await platform.invokeMethod('resetInternet');
      
      // Animate for 2 seconds after the reset
      for (int i = 0; i < 40; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      log('Error resetting internet: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.internetResetFailed(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResettingInternet = false;
        });
      }
    }
  }

  void _startNetworkCheckTimer() {
    // Cancel any existing timer
    _networkCheckTimer?.cancel();
    
    // Start a periodic timer to check network status every 3 seconds (reduced from 1 for performance)
    _networkCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _hasError) {
        // Update WiFi info
        _fetchWifiInfo();
        // Check website status (non-blocking, fire-and-forget)
        if (!_isCheckingWebsite) {
          _checkWebsiteStatus();
        }
      } else {
        // Stop timer if error is cleared
        timer.cancel();
      }
    });
  }

  Future<void> _checkWebsiteStatus() async {
    // Prevent overlapping checks
    if (_isCheckingWebsite) {
      log('Skipping website check - already in progress');
      return;
    }
    
    _isCheckingWebsite = true;
    try {
      final status = await platform.invokeMethod('checkWebsiteStatus', {
        'url': widget.initialUrl,
      });
      
      if (mounted) {
        setState(() {
          if (status is Map) {
            _websiteStatus = Map<String, dynamic>.from(status);
            log('Website status: canConnect=${_websiteStatus?['canConnect']}, isSuccess=${_websiteStatus?['isSuccess']}, error=${_websiteStatus?['error']}');
          }
        });
      }
    } catch (e) {
      log('Error checking website status: $e');
    } finally {
      _isCheckingWebsite = false;
    }
  }

  void _stopNetworkCheckTimer() {
    _networkCheckTimer?.cancel();
    _networkCheckTimer = null;
  }

  Future<void> _checkAndAutoReload() async {
    // Check if WiFi is connected and has internet by attempting to reload
    if (_wifiInfo != null && _wifiInfo!['currentNetwork'] != null) {
      final currentNetwork = _wifiInfo!['currentNetwork'];
      if (currentNetwork is Map && currentNetwork['status'] != 'disconnected') {
        log('Network appears to be back, attempting auto-reload...');
        _reloadPage();
      }
    }
  }

  void _showCreateShortcutDialog() {
    final TextEditingController nameController = TextEditingController(
      text: _customAppName.isNotEmpty ? _customAppName : _websiteName,
    );
    final TextEditingController urlController = TextEditingController(
      text: widget.initialUrl,
    );
    final TextEditingController iconController = TextEditingController(
      text: _customIconUrl.isNotEmpty ? _customIconUrl : _faviconUrl,
    );
    
    bool disableAutoFocus = false;
    bool useCustomKeyboard = false;
    bool disableCopyPaste = false;
    
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.createShortcut),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.shortcutName,
                    hintText: l10n.shortcutNameHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: l10n.websiteUrl,
                    hintText: l10n.websiteUrlExample,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: iconController,
                  decoration: InputDecoration(
                    labelText: l10n.iconUrlPngJpg,
                    hintText: l10n.iconUrlHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.image),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.auto_fix_high),
                      tooltip: l10n.autoDetectFromUrl,
                      onPressed: () {
                        String url = urlController.text.trim();
                        if (url.isNotEmpty) {
                          try {
                            if (!url.startsWith('http')) url = 'https://$url';
                            final host = Uri.parse(url).host;
                            iconController.text = 'https://www.google.com/s2/favicons?domain=$host&sz=128';
                          } catch (e) {
                            // ignore
                          }
                        }
                      },
                    ),
                  ),
                  keyboardType: TextInputType.url,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                // Add the keyboard options
                Text(
                  l10n.keyboardOptions,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: Text(l10n.disableAutoFocus),
                  subtitle: Text(l10n.disableAutoFocusDesc),
                  value: disableAutoFocus,
                  onChanged: (value) {
                    setState(() {
                      disableAutoFocus = value ?? false;
                    });
                  },
                ),
                CheckboxListTile(
                  title: Text(l10n.useCustomKeyboard),
                  subtitle: Text(l10n.useCustomKeyboardDesc2),
                  value: useCustomKeyboard,
                  onChanged: (value) {
                    setState(() {
                      useCustomKeyboard = value ?? false;
                    });
                  },
                ),
                CheckboxListTile(
                  title: Text(l10n.disableCopyPaste),
                  subtitle: Text(l10n.disableCopyPasteDesc),
                  value: disableCopyPaste,
                  onChanged: (value) {
                    setState(() {
                      disableCopyPaste = value ?? false;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.tipTapMagicWand,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _createShortcutWithParams(
                  nameController.text.trim(),
                  urlController.text.trim(),
                  iconController.text.trim(),
                  disableAutoFocus: disableAutoFocus,
                  useCustomKeyboard: useCustomKeyboard,
                  disableCopyPaste: disableCopyPaste,
                );
              },
              child: Text(l10n.createShortcut),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeAppNameDialog() {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController nameController = TextEditingController(text: _customAppName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.changeAppName),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: l10n.appNameLabel,
            hintText: l10n.enterCustomAppName,
            border: const OutlineInputBorder(),
          ),
          maxLength: 30,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              _saveCustomAppName(nameController.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.appNameUpdated)),
              );
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _showChangeIconUrlDialog() {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController iconController = TextEditingController(text: _customIconUrl);
    
    // Generate suggested favicon URLs
    String host = '';
    try {
      host = Uri.parse(_currentUrl).host;
    } catch (e) {
      host = '';
    }
    
    final List<Map<String, String>> suggestedIcons = [
      {'name': l10n.googleFavicon128, 'url': 'https://www.google.com/s2/favicons?domain=$host&sz=128'},
      {'name': l10n.googleFavicon64, 'url': 'https://www.google.com/s2/favicons?domain=$host&sz=64'},
      {'name': l10n.appleTouchIcon, 'url': 'https://$host/apple-touch-icon.png'},
      {'name': l10n.directFavicon, 'url': 'https://$host/favicon.ico'},
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.changeIconUrl),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: iconController,
                decoration: InputDecoration(
                  labelText: l10n.iconUrl,
                  hintText: l10n.iconUrlHint,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.onlyPngJpgSupported,
                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.suggestedIcons,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...suggestedIcons.map((icon) => InkWell(
                onTap: () {
                  iconController.text = icon['url']!;
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Image.network(
                          icon['url']!,
                          width: 32,
                          height: 32,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          icon['name']!,
                          style: const TextStyle(fontSize: 13, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: 8),
              Text(
                l10n.tapSuggestionOrEnter,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final url = iconController.text.trim().toLowerCase();
              if (url.endsWith('.svg')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.svgNotSupported),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              _saveCustomIconUrl(iconController.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.iconUrlUpdated)),
              );
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _askToCreateShortcut() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.createShortcut),
        content: Text(
          l10n.createHomeShortcutQuestion(_customAppName.isNotEmpty ? _customAppName : _websiteName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.notNow),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createHomeScreenShortcut();
            },
            child: Text(l10n.createShortcut),
          ),
        ],
      ),
    );
  }

  static const platform = MethodChannel('devicegate.app/shortcut');

  Future<void> _createShortcutWithParams(
    String name, 
    String url, 
    String iconUrl, {
    bool disableAutoFocus = false,
    bool useCustomKeyboard = false,
    bool disableCopyPaste = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseEnterShortcutName), backgroundColor: Colors.orange),
      );
      return;
    }
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseEnterUrl), backgroundColor: Colors.orange),
      );
      return;
    }
    
    // Add https if no protocol
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    
    try {
      // Load asset icon if it's an asset path
      Uint8List? iconBytes;
      if (iconUrl.startsWith('assets/')) {
        try {
          final ByteData data = await rootBundle.load(iconUrl);
          iconBytes = data.buffer.asUint8List();
        } catch (e) {
          log('Failed to load asset icon: $e');
          // Continue without icon bytes - Android will use default icon
        }
      }
      
      await platform.invokeMethod('createShortcut', {
        'name': name,
        'url': url,
        'iconUrl': iconUrl,
        'iconBytes': iconBytes,
        'disableAutoFocus': disableAutoFocus,
        'useCustomKeyboard': useCustomKeyboard,
        'disableCopyPaste': disableCopyPaste,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.shortcutAdded(name)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToCreateShortcut(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createHomeScreenShortcut() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final String appName = _customAppName.isNotEmpty ? _customAppName : _websiteName;
      final String iconUrl = _customIconUrl.isNotEmpty ? _customIconUrl : _faviconUrl;
      
      await platform.invokeMethod('createShortcut', {
        'name': appName,
        'url': widget.initialUrl,
        'iconUrl': iconUrl,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.shortcutAdded(appName)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToCreateShortcut(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addViaChrome() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addToHomeViaChrome),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.chromeAddInstructions,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildStep('1', l10n.chromeStep1),
            _buildStep('2', l10n.chromeStep2),
            _buildStep('3', l10n.chromeStep3),
            _buildStep('4', l10n.chromeStep4),
            const SizedBox(height: 16),
            Text(
              l10n.chromeNoBadgeNote,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final Uri url = Uri.parse(widget.initialUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(l10n.openInChrome),
          ),
        ],
      ),
    );
  }

  void _applyAsAppIcon() async {
    final l10n = AppLocalizations.of(context)!;
    if (_customIconUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseSetIconUrlFirst),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(l10n.applyingIcon),
          ],
        ),
      ),
    );
    
    try {
      final String appName = _customAppName.isNotEmpty ? _customAppName : _websiteName;
      
      final success = await platform.invokeMethod('changeAppIcon', {
        'iconUrl': _customIconUrl,
        'appName': appName,
      });
      
      Navigator.pop(context); // Close loading dialog
      
      if (success == true) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.iconChanged),
            content: Text(
              l10n.iconChangedDescription,
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.ok),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToChangeAppIcon),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorWithMessage(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  /// Clamps the minimized icon position to ensure it stays within screen bounds
  Offset _clampMinimizedIconPosition(Offset position) {
    final screenSize = MediaQuery.of(context).size;
    final iconSize = 60.0 * _keyboardScale;
    
    final maxX = screenSize.width - iconSize - 10.0;
    final maxY = screenSize.height - iconSize - 10.0;
    
    final minX = 10.0;
    final minY = 10.0;
    final validMaxX = maxX > minX ? maxX : minX;
    final validMaxY = maxY > minY ? maxY : minY;
    
    return Offset(
      position.dx.clamp(minX, validMaxX),
      position.dy.clamp(minY, validMaxY),
    );
  }

  /// Custom numeric keyboard widget
  Widget _buildCustomKeyboard() {
    if (_keyboardMinimized) {
      final clampedPos = _clampMinimizedIconPosition(_minimizedIconPosition);
      return Positioned(
        left: clampedPos.dx,
        top: clampedPos.dy,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              // Constrain to screen bounds (ensure icon stays visible)
              final screenSize = MediaQuery.of(context).size;
              final iconSize = 60.0 * _keyboardScale;
              
              // Calculate new position with delta
              final newX = _minimizedIconPosition.dx + details.delta.dx;
              final newY = _minimizedIconPosition.dy + details.delta.dy;
              
              // Ensure icon doesn't go off screen
              final maxX = screenSize.width - iconSize - 10.0;
              final maxY = screenSize.height - iconSize - 10.0;
              
              // Ensure clamp range is valid (min <= max)
              final minIconX = 10.0;
              final minIconY = 10.0;
              final validMaxX = maxX > minIconX ? maxX : minIconX;
              final validMaxY = maxY > minIconY ? maxY : minIconY;
              
              // Clamp the new position
              _minimizedIconPosition = Offset(
                newX.clamp(minIconX, validMaxX),
                newY.clamp(minIconY, validMaxY),
              );
            });
            // Save minimized icon position to preferences
            _saveMinimizedIconPosition();
          },
          onTap: () {
            setState(() {
              _keyboardMinimized = false;
              _showCustomKeyboard = true;
            });
          },
          child: Container(
            width: 60 * _keyboardScale,
            height: 60 * _keyboardScale,
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(30 * _keyboardScale),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.keyboard,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: _keyboardPosition.dx,
      top: _keyboardPosition.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            // Move keyboard in same direction as finger drag
            _keyboardPosition = Offset(
              _keyboardPosition.dx + details.delta.dx, // Drag right -> move right
              _keyboardPosition.dy + details.delta.dy,  // Drag down -> move down
            );
            
            // Constrain to screen bounds (ensure keyboard stays visible)
            final screenSize = MediaQuery.of(context).size;
            final keyboardWidth = (_isExpandedMode ? 876.0 : 240.0) * _keyboardScale; // Wider when expanded to fit AZERTY + numeric
            final keyboardHeight = 352.0 * _keyboardScale; // Updated height with consistent button heights
            
            // Ensure keyboard doesn't go off screen
            final maxX = screenSize.width - keyboardWidth - 20.0;
            final bottomMargin = _isExpandedMode ? 55.0 : 50.0;
            final maxY = screenSize.height - keyboardHeight - bottomMargin;
            
            // Ensure clamp range is valid (min <= max)
            final minKeyboardX = 20.0;
            final minKeyboardY = 20.0;
            final validMaxX = maxX > minKeyboardX ? maxX : minKeyboardX;
            final validMaxY = maxY > minKeyboardY ? maxY : minKeyboardY;
            
            _keyboardPosition = Offset(
              _keyboardPosition.dx.clamp(minKeyboardX, validMaxX),
              _keyboardPosition.dy.clamp(minKeyboardY, validMaxY),
            );
          });
          // Save position to preferences
          _saveKeyboardPosition();
        },
        child: Container(
          width: (_isExpandedMode ? 876.0 : 240.0) * _keyboardScale,
          height: 352.0 * _keyboardScale,
          padding: EdgeInsets.all(12 * _keyboardScale),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Scale button + Drag bar (2 columns) + Hide button
              SizedBox(
                height: 50 * _keyboardScale,
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 50 * _keyboardScale,
                        child: ElevatedButton(
                          onPressed: _showScaleSettingsDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6 * _keyboardScale),
                            ),
                          ),
                          child: Icon(
                            Icons.settings,
                            size: 20 * _keyboardScale,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8 * _keyboardScale),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: double.infinity, // Fill full height
                        alignment: Alignment.center, // Center the icon
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(6 * _keyboardScale),
                        ),
                        child: Icon(
                          Icons.drag_handle,
                          color: Colors.blue,
                          size: 24 * _keyboardScale,
                        ),
                      ),
                    ),
                    SizedBox(width: 8 * _keyboardScale),
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 50 * _keyboardScale,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _keyboardMinimized = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6 * _keyboardScale),
                            ),
                          ),
                          child: Text('▼', style: TextStyle(fontSize: 18 * _keyboardScale, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8 * _keyboardScale),
              // Conditional keyboard content based on mode
              _isExpandedMode ? _buildExpandedKeyboardContent() : _buildNumericKeyboardContent(),
            ],
          ),
        ),
      ),
    );
  }

  /// Numeric keyboard content (rows 2-6)
  Widget _buildNumericKeyboardContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 2: ABC, ←, →, CLEAR
        SizedBox(
          height: 50 * _keyboardScale,
          child: Row(
            children: [
              Expanded(child: _buildKeyboardButton('ABC')),
              SizedBox(width: 6 * _keyboardScale),
              Expanded(child: _buildKeyboardButton('←', backgroundColor: Colors.grey.shade600)),
              SizedBox(width: 6 * _keyboardScale),
              Expanded(child: _buildKeyboardButton('→', backgroundColor: Colors.grey.shade600)),
              SizedBox(width: 6 * _keyboardScale),
              Expanded(child: _buildKeyboardButton('CE', backgroundColor: Colors.grey.shade600)),
            ],
          ),
        ),
        SizedBox(height: 6 * _keyboardScale),
        // Row 3 & 4: Numbers with DELETE button spanning both rows
        Row(
          children: [
            // Numbers section
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  // Row 3: 7, 8, 9
                  SizedBox(
                    height: 50 * _keyboardScale,
                    child: Row(
                      children: [
                        Expanded(child: _buildKeyboardButton('7')),
                        SizedBox(width: 4 * _keyboardScale),
                        Expanded(child: _buildKeyboardButton('8')),
                        SizedBox(width: 4 * _keyboardScale),
                        Expanded(child: _buildKeyboardButton('9')),
                      ],
                    ),
                  ),
                  SizedBox(height: 4 * _keyboardScale),
                  // Row 4: 4, 5, 6
                  SizedBox(
                    height: 50 * _keyboardScale,
                    child: Row(
                      children: [
                        Expanded(child: _buildKeyboardButton('4')),
                        SizedBox(width: 4 * _keyboardScale),
                        Expanded(child: _buildKeyboardButton('5')),
                        SizedBox(width: 4 * _keyboardScale),
                        Expanded(child: _buildKeyboardButton('6')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 6 * _keyboardScale),
            // DELETE button spanning rows 3 & 4
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 104 * _keyboardScale, // Spans 2 rows: 50 + 4 + 50
                child: ElevatedButton(
                  onPressed: () => _onKeyboardKeyPressed('', isBackspace: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.all(1 * _keyboardScale),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6 * _keyboardScale),
                    ),
                  ),
                  child: Text(
                    '⌫',
                    style: TextStyle(fontSize: 20 * _keyboardScale, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6 * _keyboardScale),
        // Row 5 & 6: Numbers with Enter button spanning both rows
        Row(
          children: [
            // Numbers section
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  // Row 5: 1, 2, 3
                  SizedBox(
                    height: 50 * _keyboardScale,
                    child: Row(
                      children: [
                        Expanded(child: _buildKeyboardButton('1')),
                        SizedBox(width: 4 * _keyboardScale),
                        Expanded(child: _buildKeyboardButton('2')),
                        SizedBox(width: 4 * _keyboardScale),
                        Expanded(child: _buildKeyboardButton('3')),
                      ],
                    ),
                  ),
                  SizedBox(height: 4 * _keyboardScale),
                  // Row 6: 0 (spans 2 columns), .
                  SizedBox(
                    height: 50 * _keyboardScale,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 50 * _keyboardScale,
                            child: ElevatedButton(
                              onPressed: () => _onKeyboardKeyPressed('0'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6 * _keyboardScale),
                                ),
                              ),
                              child: Text(
                                '0',
                                style: TextStyle(fontSize: 18 * _keyboardScale, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 4 * _keyboardScale),
                        Expanded(
                          flex: 1,
                          child: _buildKeyboardButton('.'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 6 * _keyboardScale),
            // Enter button spanning rows 5 & 6
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 104 * _keyboardScale, // Spans 2 rows: 50 + 4 + 50
                child: ElevatedButton(
                  onPressed: () => _onKeyboardKeyPressed('⏎'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.all(1 * _keyboardScale), // Reduced padding
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6 * _keyboardScale),
                    ),
                  ),
                  child: Text(
                    '⏎',
                    style: TextStyle(fontSize: 25 * _keyboardScale, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Alphanumeric keyboard content (rows 2-6)
  Widget _buildAlphanumericKeyboardContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 2: 123, ←, →, CLEAR
        SizedBox(
          height: 50,
          child: Row(
            children: [
              Expanded(child: _buildKeyboardButton('123')),
              const SizedBox(width: 6),
              Expanded(child: _buildKeyboardButton('←', backgroundColor: Colors.grey.shade600)),
              const SizedBox(width: 6),
              Expanded(child: _buildKeyboardButton('→', backgroundColor: Colors.grey.shade600)),
              const SizedBox(width: 6),
              Expanded(child: _buildKeyboardButton('CE', backgroundColor: Colors.grey.shade600)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // QWERTY keyboard rows
        // Row 3: Q W E R T Y U I O P
        SizedBox(
          height: 50,
          child: Row(
            children: [
              Expanded(child: _buildKeyboardButton('q')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('w')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('e')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('r')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('t')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('y')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('u')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('i')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('o')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('p')),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Row 4: A S D F G H J K L ⌫
        SizedBox(
          height: 50,
          child: Row(
            children: [
              Expanded(child: _buildKeyboardButton('a')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('s')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('d')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('f')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('g')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('h')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('j')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('k')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('l')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('', isBackspace: true)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Row 5: Z X C V B N M , . ⏎
        SizedBox(
          height: 50,
          child: Row(
            children: [
              Expanded(child: _buildKeyboardButton('z')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('x')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('c')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('v')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('b')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('n')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('m')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton(',')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('.')),
              const SizedBox(width: 4),
              Expanded(child: _buildKeyboardButton('⏎')), // Enter key
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Row 6: Space bar
        SizedBox(
          height: 50,
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildKeyboardButton(' '), // Space bar
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Expanded keyboard content (alphabetic left, numeric right)
  Widget _buildExpandedKeyboardContent() {
    return Row(
      children: [
        // Main AZERTY keyboard (600px wide for full layout)
        SizedBox(
          width: 600.0 * _keyboardScale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: & é " ' ( - è _ ç à ) = ⌫
              SizedBox(
                height: 50 * _keyboardScale,
                child: Row(
                  children: [
                    Expanded(child: _buildKeyboardButton('&')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('é')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('"')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton("'")),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('(')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('-')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('è')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('_')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('ç')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('à')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton(')')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('=')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(flex: 2, child: _buildKeyboardButton('⌫', backgroundColor: Colors.grey.shade600)),
                  ],
                ),
              ),
              SizedBox(height: 4 * _keyboardScale),
              // Rows 2 & 3: Combined layout with merged ENTER key
              SizedBox(
                height: 104 * _keyboardScale, // 50 + 4 + 50 = 104 for two rows with spacing
                child: Row(
                  children: [
                    // Column 1: 123 key to switch back to numeric keyboard
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 104 * _keyboardScale, // Full height for both rows
                        child: ElevatedButton(
                          onPressed: () => _onKeyboardKeyPressed('123'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6 * _keyboardScale),
                            ),
                          ),
                          child: Text(
                            '123',
                            style: TextStyle(fontSize: 20 * _keyboardScale, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 4 * _keyboardScale),
                    // Column 2: A (Row 2) / Q (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('a'),
                          ),
                          SizedBox(height: 4 * _keyboardScale),
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('q'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4 * _keyboardScale),
                    // Column 3: Z (Row 2) / S (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('z'),
                          ),
                          SizedBox(height: 4 * _keyboardScale),
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('s'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4 * _keyboardScale),
                    // Column 4: E (Row 2) / D (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('e'),
                          ),
                          SizedBox(height: 4 * _keyboardScale),
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('d'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4 * _keyboardScale),
                    // Column 5: R (Row 2) / F (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('r'),
                          ),
                          SizedBox(height: 4 * _keyboardScale),
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('f'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4 * _keyboardScale),
                    // Column 6: T (Row 2) / G (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('t'),
                          ),
                          SizedBox(height: 4 * _keyboardScale),
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('g'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4 * _keyboardScale),
                    // Column 7: Y (Row 2) / H (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('y'),
                          ),
                          SizedBox(height: 4 * _keyboardScale),
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('h'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4 * _keyboardScale),
                    // Column 8: U (Row 2) / J (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('u'),
                          ),
                          SizedBox(height: 4 * _keyboardScale),
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('j'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4 * _keyboardScale),
                    // Column 9: I (Row 2) / K (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('i'),
                          ),
                          SizedBox(height: 4 * _keyboardScale),
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('k'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4 * _keyboardScale),
                    // Column 10: O (Row 2) / L (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('o'),
                          ),
                          SizedBox(height: 4 * _keyboardScale),
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('l'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4 * _keyboardScale),
                    // Column 11: P (Row 2) / M (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('p'),
                          ),
                          SizedBox(height: 4 * _keyboardScale),
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('m'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4 * _keyboardScale),
                    // Column 12: ^ (Row 2) / ù (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('^'),
                          ),
                          SizedBox(height: 4 * _keyboardScale),
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('ù'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4 * _keyboardScale),
                    // Column 13: $ (Row 2) / * (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('\$'),
                          ),
                          SizedBox(height: 4 * _keyboardScale),
                          SizedBox(
                            height: 50 * _keyboardScale,
                            child: _buildKeyboardButton('*'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4 * _keyboardScale),
                    // Column 14: ENTER (spans both rows)
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 104 * _keyboardScale, // Full height for both rows
                        child: _buildKeyboardButton('⏎'), // Enter key
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4 * _keyboardScale),
              // Row 4: ⇪ < w x c v b n , ; : ! ⇪
              SizedBox(
                height: 50 * _keyboardScale,
                child: Row(
                  children: [
                    Expanded(flex: 2, child: _buildKeyboardButton(_isShift ? '⇪' : '⇪', backgroundColor: _isShift ? Colors.blue.shade600 : Colors.grey.shade600)),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('<')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('w')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('x')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('c')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('v')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('b')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('n')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton(',')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton(';')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton(':')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('!')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(flex: 2, child: _buildKeyboardButton(_isShift ? '⇪' : '⇪', backgroundColor: _isShift ? Colors.blue.shade600 : Colors.grey.shade600)),
                  ],
                ),
              ),
              SizedBox(height: 4 * _keyboardScale),
              // Row 5: ← → ESPACE
              SizedBox(
                height: 50 * _keyboardScale,
                child: Row(
                  children: [
                    Expanded(flex: 1, child: _buildKeyboardButton('←')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(flex: 1, child: _buildKeyboardButton('→')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(flex: 6, child: _buildKeyboardButton(' ')), // Space bar
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(flex: 1, child: _buildKeyboardButton('↑')),
                    SizedBox(width: 4 * _keyboardScale),
                    Expanded(flex: 1, child: _buildKeyboardButton('↓')),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 4 * _keyboardScale), // Gap between main keyboard and numeric sections
        // Right side: Numeric keyboard (240px wide, same as compact mode)
        SizedBox(
          width: 240.0 * _keyboardScale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 2: 123, ←, →, CLEAR
              SizedBox(
                height: 50 * _keyboardScale,
                child: Row(
                  children: [
                    Expanded(child: _buildKeyboardButton('123')),
                    SizedBox(width: 6 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('←', backgroundColor: Colors.grey.shade600)),
                    SizedBox(width: 6 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('→', backgroundColor: Colors.grey.shade600)),
                    SizedBox(width: 6 * _keyboardScale),
                    Expanded(child: _buildKeyboardButton('CE', backgroundColor: Colors.grey.shade600)),
                  ],
                ),
              ),
              SizedBox(height: 6 * _keyboardScale),
              // Row 3 & 4: Numbers with DELETE button spanning both rows
              Row(
                children: [
                  // Numbers section
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        // Row 3: 7, 8, 9
                        SizedBox(
                          height: 50 * _keyboardScale,
                          child: Row(
                            children: [
                              Expanded(child: _buildKeyboardButton('7')),
                              SizedBox(width: 4 * _keyboardScale),
                              Expanded(child: _buildKeyboardButton('8')),
                              SizedBox(width: 4 * _keyboardScale),
                              Expanded(child: _buildKeyboardButton('9')),
                            ],
                          ),
                        ),
                        SizedBox(height: 4 * _keyboardScale),
                        // Row 4: 4, 5, 6
                        SizedBox(
                          height: 50 * _keyboardScale,
                          child: Row(
                            children: [
                              Expanded(child: _buildKeyboardButton('4')),
                              SizedBox(width: 4 * _keyboardScale),
                              Expanded(child: _buildKeyboardButton('5')),
                              SizedBox(width: 4 * _keyboardScale),
                              Expanded(child: _buildKeyboardButton('6')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 6 * _keyboardScale),
                  // DELETE button spanning rows 3 & 4
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 104 * _keyboardScale, // Spans 2 rows: 50 + 4 + 50
                      child: ElevatedButton(
                        onPressed: () => _onKeyboardKeyPressed('', isBackspace: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.all(1 * _keyboardScale),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6 * _keyboardScale),
                          ),
                        ),
                        child: Text(
                          '⌫',
                          style: TextStyle(fontSize: 20 * _keyboardScale, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6 * _keyboardScale),
              // Row 5 & 6: Numbers with Enter button spanning both rows
              Row(
                children: [
                  // Numbers section
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        // Row 5: 1, 2, 3
                        SizedBox(
                          height: 50 * _keyboardScale,
                          child: Row(
                            children: [
                              Expanded(child: _buildKeyboardButton('1')),
                              SizedBox(width: 4 * _keyboardScale),
                              Expanded(child: _buildKeyboardButton('2')),
                              SizedBox(width: 4 * _keyboardScale),
                              Expanded(child: _buildKeyboardButton('3')),
                            ],
                          ),
                        ),
                        SizedBox(height: 4 * _keyboardScale),
                        // Row 6: 0 (spans 2 columns), .
                        SizedBox(
                          height: 50 * _keyboardScale,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 50 * _keyboardScale,
                                  child: ElevatedButton(
                                    onPressed: () => _onKeyboardKeyPressed('0'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade600,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6 * _keyboardScale),
                                      ),
                                    ),
                                    child: Text(
                                      '0',
                                      style: TextStyle(fontSize: 18 * _keyboardScale, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 4 * _keyboardScale),
                              Expanded(
                                flex: 1,
                                child: _buildKeyboardButton('.'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 6 * _keyboardScale),
                  // Enter button spanning rows 5 & 6
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 104 * _keyboardScale, // Spans 2 rows: 50 + 4 + 50
                      child: ElevatedButton(
                        onPressed: () => _onKeyboardKeyPressed('⏎'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.all(1 * _keyboardScale), // Reduced padding
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6 * _keyboardScale),
                          ),
                        ),
                        child: Text(
                          '⏎',
                          style: TextStyle(fontSize: 20 * _keyboardScale, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Helper method to build keyboard buttons
  /// Helper method to build keyboard buttons
  Widget _buildKeyboardButton(String text, {bool isBackspace = false, Color? backgroundColor, String? keyValue}) {
    // Determine display text based on Caps Lock/Shift state for letters
    String displayText;
    if (isBackspace) {
      displayText = '⌫';
    } else if (text == '⏎') {
      displayText = '⏎';
    } else if (RegExp(r'^[a-zA-Z]$').hasMatch(text)) {
      // For single letters, show uppercase if Caps Lock or Shift is active
      displayText = _isShift ? text.toUpperCase() : text.toLowerCase();
    } else {
      // For symbols, show shifted versions when Shift is pressed
      if (_isShift) {
        switch (text) {
          case '&': displayText = '+'; break;
          case 'é': displayText = '²'; break;
          case '"': displayText = '#'; break;
          case "'": displayText = '{'; break;
          case '(': displayText = '['; break;
          case '-': displayText = '|'; break;
          case 'è': displayText = '¤'; break;
          case '_': displayText = '\\'; break;
          case 'ç': displayText = '^'; break;
          case 'à': displayText = '@'; break;
          case ')': displayText = ']'; break;
          case '=': displayText = '}'; break;
          case '^': displayText = '¨'; break;
          case r'$': displayText = '£'; break;
          case 'ù': displayText = '%'; break;
          case '*': displayText = 'µ'; break;
          case ',': displayText = '?'; break;
          case ';': displayText = '.'; break;
          case ':': displayText = '/'; break;
          case '!': displayText = '§'; break;
          case '<': displayText = '>'; break;
          default: displayText = text; break;
        }
      } else {
        displayText = text;
      }
    }

    return SizedBox(
      height: 50 * _keyboardScale,
      child: ElevatedButton(
        onPressed: () => _onKeyboardKeyPressed(keyValue ?? text, isBackspace: isBackspace),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.grey.shade600,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6 * _keyboardScale),
          ),
        ),
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: ((displayText == '⇪' ) ? 28 : 20) * _keyboardScale,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _onKeyboardKeyPressed(String key, {bool isBackspace = false}) {
    log('Keyboard key pressed: $key, isBackspace: $isBackspace');
    
    if (isBackspace) {
      // Send backspace key
      _controller.runJavaScript('''
        console.log('Keyboard: backspace pressed');
        if (document.activeElement && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA')) {
          console.log('Keyboard: found active input for backspace');
          const input = document.activeElement;
          
          // Check if input supports selection
          if (input.selectionStart !== null && input.selectionEnd !== null) {
            console.log('Keyboard: input supports selection, using setRangeText');
            const start = input.selectionStart;
            const end = input.selectionEnd;
            if (start !== end) {
              // Delete selected text
              input.setRangeText('', start, end, 'end');
            } else if (start > 0) {
              // Delete character before cursor
              input.setRangeText('', start - 1, start, 'end');
            }
          } else {
            // For inputs that don't support selection, remove last character
            console.log('Keyboard: input does not support selection, removing last char');
            if (input.value.length > 0) {
              input.value = input.value.slice(0, -1);
            }
          }
          
          input.dispatchEvent(new Event('input', { bubbles: true }));
          console.log('Keyboard: backspace complete, value now:', input.value);
        } else {
          console.log('Keyboard: no active input found for backspace');
        }
      ''');
    } else if (key == '←') {
      // Move cursor left
      _controller.runJavaScript('''
        if (document.activeElement && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA')) {
          const input = document.activeElement;
          if (input.selectionStart !== null) {
            const pos = input.selectionStart;
            if (pos > 0) {
              input.setSelectionRange(pos - 1, pos - 1);
            }
          }
        }
      ''');
    } else if (key == '→') {
      // Move cursor right
      _controller.runJavaScript('''
        if (document.activeElement && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA')) {
          const input = document.activeElement;
          if (input.selectionStart !== null) {
            const pos = input.selectionStart;
            if (pos < input.value.length) {
              input.setSelectionRange(pos + 1, pos + 1);
            }
          }
        }
      ''');
    } else if (key == 'CE') {
      // Clear the entire input
      _controller.runJavaScript('''
        if (document.activeElement && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA')) {
          const input = document.activeElement;
          input.value = '';
          input.dispatchEvent(new Event('input', { bubbles: true }));
        }
      ''');
    } else if (key == '⌫') {
      // Delete key (backspace functionality)
      _controller.runJavaScript('''
        console.log('Keyboard: backspace pressed (⌫ key)');
        if (document.activeElement && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA')) {
          console.log('Keyboard: found active input for backspace');
          const input = document.activeElement;
          
          // Check if input supports selection
          if (input.selectionStart !== null && input.selectionEnd !== null) {
            console.log('Keyboard: input supports selection, using setRangeText');
            const start = input.selectionStart;
            const end = input.selectionEnd;
            if (start !== end) {
              // Delete selected text
              input.setRangeText('', start, end, 'end');
            } else if (start > 0) {
              // Delete character before cursor
              input.setRangeText('', start - 1, start, 'end');
            }
          } else {
            // For inputs that don't support selection, remove last character
            console.log('Keyboard: input does not support selection, removing last char');
            if (input.value.length > 0) {
              input.value = input.value.slice(0, -1);
            }
          }
          
          input.dispatchEvent(new Event('input', { bubbles: true }));
          console.log('Keyboard: backspace complete, value now:', input.value);
        } else {
          console.log('Keyboard: no active input found for backspace');
        }
      ''');
    } else if (key == 'Tab') {
      // Send tab key
      _controller.runJavaScript('''
        if (document.activeElement && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA')) {
          const input = document.activeElement;
          const start = input.selectionStart;
          const end = input.selectionEnd;
          input.setRangeText('\\t', start, end, 'end');
          input.dispatchEvent(new Event('input', { bubbles: true }));
        }
      ''');
    } else if (key == '←') {
      // Move cursor left
      _controller.runJavaScript('''
        if (document.activeElement && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA')) {
          const input = document.activeElement;
          if (input.selectionStart !== null) {
            const newPosition = Math.max(0, input.selectionStart - 1);
            input.setSelectionRange(newPosition, newPosition);
          }
        }
      ''');
    } else if (key == '→') {
      // Move cursor right
      _controller.runJavaScript('''
        if (document.activeElement && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA')) {
          const input = document.activeElement;
          if (input.selectionStart !== null) {
            const newPosition = Math.min(input.value.length, input.selectionStart + 1);
            input.setSelectionRange(newPosition, newPosition);
          }
        }
      ''');
    } else if (key == '↑') {
      // Move cursor up (to previous line in textarea)
      _controller.runJavaScript('''
        if (document.activeElement && document.activeElement.tagName === 'TEXTAREA') {
          const textarea = document.activeElement;
          const lines = textarea.value.split('\\n');
          const currentPos = textarea.selectionStart;
          
          // Find current line
          let currentLine = 0;
          let charCount = 0;
          for (let i = 0; i < lines.length; i++) {
            if (charCount + lines[i].length + 1 > currentPos) {
              currentLine = i;
              break;
            }
            charCount += lines[i].length + 1;
          }
          
          // Move to previous line if not at first line
          if (currentLine > 0) {
            const prevLine = lines[currentLine - 1];
            const prevLineStart = charCount - lines[currentLine - 1].length - 1;
            // Try to maintain column position
            const currentCol = currentPos - charCount + lines[currentLine].length;
            const newPosition = Math.min(prevLineStart + Math.min(currentCol, prevLine.length), prevLineStart + prevLine.length);
            textarea.setSelectionRange(newPosition, newPosition);
          }
        }
      ''');
    } else if (key == '↓') {
      // Move cursor down (to next line in textarea)
      _controller.runJavaScript('''
        if (document.activeElement && document.activeElement.tagName === 'TEXTAREA') {
          const textarea = document.activeElement;
          const lines = textarea.value.split('\\n');
          const currentPos = textarea.selectionStart;
          
          // Find current line
          let currentLine = 0;
          let charCount = 0;
          for (let i = 0; i < lines.length; i++) {
            if (charCount + lines[i].length + 1 > currentPos) {
              currentLine = i;
              break;
            }
            charCount += lines[i].length + 1;
          }
          
          // Move to next line if not at last line
          if (currentLine < lines.length - 1) {
            const nextLine = lines[currentLine + 1];
            const nextLineStart = charCount + lines[currentLine].length + 1;
            // Try to maintain column position
            const currentCol = currentPos - charCount + lines[currentLine].length;
            const newPosition = Math.min(nextLineStart + Math.min(currentCol, nextLine.length), nextLineStart + nextLine.length);
            textarea.setSelectionRange(newPosition, newPosition);
          }
        }
      ''');
    } else if (key == '⇪') {
      // Toggle Shift (temporary)
      setState(() {
        _isShift = !_isShift;
      });
    } else if (key == '123') {
      // Switch back to compact numeric keyboard
      setState(() {
        _isExpandedMode = false;
      });
      // Load saved numeric keyboard position or default to bottom-right
      if (_savedNumericKeyboardPosition != null) {
        final screenSize = MediaQuery.of(context).size;
        final keyboardWidth = 240.0 * _keyboardScale;
        final keyboardHeight = 352.0 * _keyboardScale;
        final maxX = screenSize.width - keyboardWidth - 20.0;
        final maxY = screenSize.height - keyboardHeight - 50.0;
        final clampedX = _savedNumericKeyboardPosition!.dx.clamp(20.0, maxX);
        final clampedY = _savedNumericKeyboardPosition!.dy.clamp(20.0, maxY);
        _keyboardPosition = Offset(clampedX, clampedY);
      } else {
        final screenSize = MediaQuery.of(context).size;
        _keyboardPosition = Offset(
          screenSize.width - 240.0 * _keyboardScale - 20,
          screenSize.height - 352.0 * _keyboardScale - 50,
        );
      }
    } else if (key == 'ABC') {
      // Expand to show full keyboard with alphabetic and numeric sections
      setState(() {
        _isExpandedMode = true;
      });
      // Try to use saved expanded keyboard position, otherwise center at bottom
      if (_savedExpandedKeyboardPosition != null) {
        // Load saved position and clamp to screen bounds
        final screenSize = MediaQuery.of(context).size;
        final keyboardWidth = 876.0 * _keyboardScale;
        final keyboardHeight = 352.0 * _keyboardScale;
        final clampedX = _savedExpandedKeyboardPosition!.dx.clamp(20.0, screenSize.width - keyboardWidth - 20.0);
        final clampedY = _savedExpandedKeyboardPosition!.dy.clamp(20.0, screenSize.height - keyboardHeight - 55.0);
        _keyboardPosition = Offset(clampedX, clampedY);
      } else {
        // No saved position, center at bottom
        final screenSize = MediaQuery.of(context).size;
        _keyboardPosition = Offset(
          (screenSize.width - 876.0 * _keyboardScale) / 2,
          screenSize.height - 352.0 * _keyboardScale,
        );
      }
    } else if (key == '⏎') {
      // Enter key - dispatch native enter key events to let the page handle it
      _controller.runJavaScript('''
        console.log('Keyboard: Enter key pressed, dispatching native events');
        if (document.activeElement) {
          // Dispatch keydown event
          const keydownEvent = new KeyboardEvent('keydown', {
            key: 'Enter',
            code: 'Enter',
            keyCode: 13,
            which: 13,
            charCode: 0,
            bubbles: true,
            cancelable: true
          });
          document.activeElement.dispatchEvent(keydownEvent);
          
          // Dispatch keypress event for compatibility
          const keypressEvent = new KeyboardEvent('keypress', {
            key: 'Enter',
            code: 'Enter',
            keyCode: 13,
            which: 13,
            charCode: 13,
            bubbles: true,
            cancelable: true
          });
          document.activeElement.dispatchEvent(keypressEvent);
          
          // Dispatch keyup event
          const keyupEvent = new KeyboardEvent('keyup', {
            key: 'Enter',
            code: 'Enter',
            keyCode: 13,
            which: 13,
            charCode: 0,
            bubbles: true,
            cancelable: true
          });
          document.activeElement.dispatchEvent(keyupEvent);
          
          console.log('Keyboard: Enter events dispatched');
        } else {
          console.log('Keyboard: no active element found');
        }
      ''');
    } else {
      // Handle letter case transformation and symbol shifting
      String keyToSend = key;
      if (RegExp(r'^[a-zA-Z]$').hasMatch(key)) {
        // Convert letters to uppercase if Caps Lock or Shift is active
        keyToSend = _isShift ? key.toUpperCase() : key.toLowerCase();
      } else if (_isShift) {
        // Shift symbols
        switch (key) {
          case '&': keyToSend = '+'; break;
          case 'é': keyToSend = '/'; break;
          case '"': keyToSend = '#'; break;
          case "'": keyToSend = '{'; break;
          case '(': keyToSend = '['; break;
          case '-': keyToSend = '|'; break;
          case 'è': keyToSend = '*'; break;
          case '_': keyToSend = '\\'; break;
          case 'ç': keyToSend = '^'; break;
          case 'à': keyToSend = '@'; break;
          case ')': keyToSend = ']'; break;
          case '=': keyToSend = '}'; break;
          case '^': keyToSend = '£'; break;
          case 'ù': keyToSend = '%'; break;
          case ',': keyToSend = '?'; break;
          case ';': keyToSend = '.'; break;
          case ':': keyToSend = '/'; break;
          case '!': keyToSend = '§'; break;
          case '<': keyToSend = '>'; break;
          default: keyToSend = key; break;
        }
      }
      
      log('keyToSend: $keyToSend for key: $key, _isShift: $_isShift');
      
      final escapedKey = jsonEncode(keyToSend);
      _controller.runJavaScript('''
        console.log('Keyboard: attempting to insert key');
        var keyToInsert = $escapedKey;
        if (document.activeElement && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA')) {
          console.log('Keyboard: found active input element');
          const input = document.activeElement;
          
          // Check if input supports selection
          if (input.selectionStart !== null && input.selectionEnd !== null) {
            const start = input.selectionStart;
            const end = input.selectionEnd;
            console.log('Keyboard: inserting key at position', start, end);
            input.setRangeText(keyToInsert, start, end, 'end');
          } else {
            // For inputs that don't support selection (like email, password), append to value
            console.log('Keyboard: input does not support selection, appending to value');
            input.value += keyToInsert;
          }
          
          input.dispatchEvent(new Event('input', { bubbles: true }));
          console.log('Keyboard: insertion complete, value now:', input.value);
        } else {
          console.log('Keyboard: no active input element found, activeElement:', document.activeElement);
        }
      ''');
    }
  }

  void _showScaleSettingsDialog() {
    final l10n = AppLocalizations.of(context)!;
    double originalScale = _keyboardScale; // Store original scale for cancel
    double tempScale = _keyboardScale; // Move outside StatefulBuilder
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.keyboardScaleSettings),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      '${(tempScale * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: tempScale,
                    min: 0.7,
                    max: 1.1,
                    divisions: 4,
                    label: '${(tempScale * 100).round()}%',
                    onChanged: (value) {
                      setState(() {
                        tempScale = value;
                      });
                      this.setState(() {
                        _keyboardScale = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Cancel: revert to original scale
                    this.setState(() {
                      _keyboardScale = originalScale;
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Apply: keep current scale (already applied in real-time)
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n.ok),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void deactivate() {
    // Stop any playing audio when navigating away from this screen
    _audioPlayer.stop();
    super.deactivate();
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Re-enable system keyboards when leaving the screen
    if (_useCustomKeyboardRuntime) {
      _enableSystemKeyboards();
    }
    
    // Cancel all timers
    _networkCheckTimer?.cancel();
    _keyboardPositionSaveTimer?.cancel();
    _minimizedIconPositionSaveTimer?.cancel();
    _loadingIndicatorDelayTimer?.cancel();
    
    // Clean up WebView controller
    _controller.clearCache();
    _controller.clearLocalStorage();
    _audioPlayer.dispose();
    super.dispose();
  }
}

 
