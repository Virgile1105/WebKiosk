import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class KioskWebViewScreen extends StatefulWidget {
  final String initialUrl;
  final bool disableAutoFocus;
  final bool useCustomKeyboard;
  final bool disableCopyPaste;

  const KioskWebViewScreen({
    super.key,
    required this.initialUrl,
    this.disableAutoFocus = false,
    this.useCustomKeyboard = false,
    this.disableCopyPaste = false,
  });

  @override
  State<KioskWebViewScreen> createState() => _KioskWebViewScreenState();
}

class _KioskWebViewScreenState extends State<KioskWebViewScreen> {
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
  Offset _keyboardPosition = const Offset(100, 200); // Temporary default, will be adjusted
  Offset _minimizedIconPosition = const Offset(100, 200); // Position for minimized icon

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenSize = MediaQuery.of(context).size;
    
    // Always clamp keyboard position to current screen bounds
    // Use maximum keyboard width to ensure it fits in both normal and expanded modes
    final keyboardWidth = 876.0; // Maximum width (expanded mode)
    final keyboardHeight = 352.0;
    final maxKeyboardX = screenSize.width - keyboardWidth - 20.0;
    final maxKeyboardY = screenSize.height - keyboardHeight - 20.0;
    
    // If position is still the temporary default, set to bottom-right
    // Use normal keyboard width for default positioning since keyboard starts in normal mode
    if (_keyboardPosition == const Offset(100, 200)) {
      final defaultKeyboardWidth = 240.0; // Normal mode width
      _keyboardPosition = Offset(
        screenSize.width - defaultKeyboardWidth - 20,  // Bottom-right x
        screenSize.height - keyboardHeight - 20, // Bottom-right y
      );
    } else {
      // Clamp existing position to new screen bounds
      // Ensure clamp range is valid (min <= max)
      final minX = 20.0;
      final minY = 20.0;
      final validMaxX = maxKeyboardX > minX ? maxKeyboardX : minX;
      final validMaxY = maxKeyboardY > minY ? maxKeyboardY : minY;
      
      _keyboardPosition = Offset(
        _keyboardPosition.dx.clamp(minX, validMaxX),
        _keyboardPosition.dy.clamp(minY, validMaxY),
      );
    }
    
    // Always clamp minimized icon position to current screen bounds
    final iconSize = 60.0;
    final maxIconX = screenSize.width - iconSize - 10.0;
    final maxIconY = screenSize.height - iconSize - 10.0;
    
    // If minimized icon position is still the temporary default, set to bottom-right
    if (_minimizedIconPosition == const Offset(100, 200)) {
      _minimizedIconPosition = Offset(
        screenSize.width - 80,  // 60px icon + 20px margin from right
        screenSize.height - 80, // 60px icon + 20px margin from bottom
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
    _initializeWebView();
    _loadCustomSettings(); // Fire-and-forget async loading
  }

  Future<void> _loadCustomSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customAppName = prefs.getString('custom_app_name') ?? '';
      _customIconUrl = prefs.getString('custom_icon_url') ?? '';
      // Load keyboard position - if none saved, will be set to default in didChangeDependencies
      final keyboardX = prefs.getDouble('keyboard_position_x');
      final keyboardY = prefs.getDouble('keyboard_position_y');
      if (keyboardX != null && keyboardY != null) {
        _keyboardPosition = Offset(keyboardX, keyboardY);
      }
      // Load minimized icon position
      final iconX = prefs.getDouble('minimized_icon_position_x');
      final iconY = prefs.getDouble('minimized_icon_position_y');
      if (iconX != null && iconY != null) {
        _minimizedIconPosition = Offset(iconX, iconY);
      }
      // If no saved position, _keyboardPosition remains as temporary default
      // and will be set to bottom-right in didChangeDependencies
    });
  }

  Future<void> _saveCustomAppName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_app_name', name);
    setState(() {
      _customAppName = name;
    });
    
    // Ask user if they want to create a home screen shortcut
    if (mounted && name.isNotEmpty) {
      _askToCreateShortcut();
    }
  }

  Future<void> _saveCustomIconUrl(String url) async {
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
  }

  Future<void> _saveKeyboardPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('keyboard_position_x', _keyboardPosition.dx);
    await prefs.setDouble('keyboard_position_y', _keyboardPosition.dy);
  }

  Future<void> _saveMinimizedIconPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('minimized_icon_position_x', _minimizedIconPosition.dx);
    await prefs.setDouble('minimized_icon_position_y', _minimizedIconPosition.dy);
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
          debugPrint('Custom keyboard: SHOW received - ${message.message}');
          setState(() {
            _showCustomKeyboard = true;
          });
        },
      )
      ..addJavaScriptChannel(
        'hideCustomKeyboard',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('Custom keyboard: HIDE received - ${message.message}');
          setState(() {
            _showCustomKeyboard = false;
          });
        },
      )
      ..addJavaScriptChannel(
        'debugLog',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('WebView Debug: ${message.message}');
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
              _controller.loadRequest(
                Uri.parse(widget.initialUrl).replace(queryParameters: {
                  ...Uri.parse(widget.initialUrl).queryParameters,
                  '_cache_bust': DateTime.now().millisecondsSinceEpoch.toString(),
                }),
                headers: {
                  'Cache-Control': 'no-cache, no-store, must-revalidate',
                  'Pragma': 'no-cache',
                  'Expires': '0',
                },
              );
            } else {
              // Actual page finished loading
              if (!mounted) return;
              setState(() {
                _isLoading = false;
              });
              _extractFavicon();
              // Prevent auto-focus on input fields to avoid keyboard popup (if option enabled)
              if (widget.disableAutoFocus) {
                _preventAutoFocus();
              }
              // Set up custom keyboard if enabled (independent of autofocus)
              if (widget.useCustomKeyboard) {
                _setupCustomKeyboard();
              }
              // Note: Copy/paste disabling is now handled in _setupCustomKeyboard()
            }
          },
          onPageStarted: (String url) {
            // Only set loading for actual URL, not blank page
            if (!url.contains('data:text/html') && url != 'about:blank') {
              if (!mounted) return;
              setState(() {
                _isLoading = true;
                _currentUrl = url;
                _extractWebsiteName(url);
              });
            }
          },
          onProgress: (int progress) {
            if (!mounted) return;
            setState(() {
              _loadingProgress = progress / 100;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      );
  }

  /// Injects JavaScript to prevent automatic focus on page load
  /// but still allows keyboard when user taps on input fields
  void _preventAutoFocus() {
    debugPrint('preventAutoFocus called');
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

  /// Disables copy, paste, and cut operations on input fields
  /// Sets up custom keyboard functionality
  void _setupCustomKeyboard() {
    debugPrint('Setting up custom keyboard for URL: ${widget.initialUrl}');
    _controller.runJavaScript('''
      (function() {
        // Check if custom keyboard is already set up
        if (window.customKeyboardSetup) {
          console.log('Custom keyboard already set up, skipping');
          return;
        }
        window.customKeyboardSetup = true;

        // Add CSS to ensure cursor is visible and prevent IME
        if (!document.querySelector('style[data-custom-keyboard]')) {
          const style = document.createElement('style');
          style.setAttribute('data-custom-keyboard', 'true');
          const cssText = 'input:focus, textarea:focus, select:focus, [contenteditable]:focus { caret-color: black !important; ime-mode: disabled !important; -webkit-ime-mode: disabled !important; -webkit-user-modify: read-write-plaintext-only !important; -webkit-touch-callout: none !important; -webkit-user-select: text !important; -webkit-tap-highlight-color: transparent !important; -webkit-appearance: none !important; pointer-events: auto !important; } input, textarea, select, [contenteditable] { ime-mode: disabled; -webkit-ime-mode: disabled; -webkit-user-modify: read-write-plaintext-only; -webkit-touch-callout: none; -webkit-user-select: text; -webkit-tap-highlight-color: transparent; -webkit-appearance: none; }';
          style.textContent = cssText;
          document.head.appendChild(style);
        }
        document.querySelectorAll('input, textarea, [contenteditable]').forEach(function(el) {
          if (!el.hasAttribute('data-inputmode-set')) {
            el.setAttribute('inputmode', 'none');
            el.setAttribute('data-inputmode-set', 'true');
          }
        });

        ${widget.disableCopyPaste ? '''
        // Disable copy/paste if option is enabled
        function disableCopyPaste(el) {
          if (!el.hasAttribute('data-copy-paste-disabled')) {
            el.setAttribute('data-copy-paste-disabled', 'true');
            el.addEventListener('copy', function(e) {
              e.preventDefault();
              e.stopPropagation();
              return false;
            });
            el.addEventListener('paste', function(e) {
              e.preventDefault();
              e.stopPropagation();
              return false;
            });
            el.addEventListener('cut', function(e) {
              e.preventDefault();
              e.stopPropagation();
              return false;
            });
            el.addEventListener('contextmenu', function(e) {
              e.preventDefault();
              e.stopPropagation();
              return false;
            });
          }
        }

        // Global copy/paste disabling
        if (!document.hasAttribute('data-global-copy-paste-disabled')) {
          document.setAttribute('data-global-copy-paste-disabled', 'true');
          document.addEventListener('copy', function(e) {
            e.preventDefault();
            e.stopPropagation();
            return false;
          });
          document.addEventListener('paste', function(e) {
            e.preventDefault();
            e.stopPropagation();
            return false;
          });
          document.addEventListener('cut', function(e) {
            e.preventDefault();
            e.stopPropagation();
            return false;
          });
          document.addEventListener('contextmenu', function(e) {
            e.preventDefault();
            e.stopPropagation();
            return false;
          });

          // Prevent keyboard shortcuts
          document.addEventListener('keydown', function(e) {
            if ((e.ctrlKey || e.metaKey) && (e.key === 'c' || e.key === 'v' || e.key === 'x')) {
              e.preventDefault();
              e.stopPropagation();
              return false;
            }
          });
        }

        // Apply to existing elements
        document.querySelectorAll('input, textarea, [contenteditable], [role="textbox"]').forEach(disableCopyPaste);
        ''' : ''}

        // Set up input listeners (only if not already set up)
        if (!window.inputListenersSetup) {
          window.inputListenersSetup = true;

          function setupInputListeners() {
            const inputs = document.querySelectorAll('input, textarea, [contenteditable], [role="textbox"], [contenteditable="true"], [role="combobox"], [role="searchbox"], [role="spinbutton"], [role="slider"], [role="listbox"], select');
            console.log('Found ' + inputs.length + ' input elements');
            debugLog.postMessage('Found ' + inputs.length + ' input elements');
            inputs.forEach(function(input) {
              console.log('Setting up input:', input.tagName, input.type, input.contentEditable, input.getAttribute('role'));
              debugLog.postMessage('Setting up input: ' + input.tagName + ' ' + input.type + ' ' + input.contentEditable + ' ' + input.getAttribute('role'));
              if (!input.hasAttribute('data-custom-keyboard')) {
                input.setAttribute('data-custom-keyboard', 'true');
                ${widget.disableCopyPaste ? 'disableCopyPaste(input);' : ''}
                input.addEventListener('focus', function(e) {
                  console.log('Custom keyboard: Input field focused');
                  debugLog.postMessage('Custom keyboard: Input field focused');
                  e.preventDefault();
                  e.stopPropagation();
                  
                  var target = e.target;
                  
                  // Set inputmode to none immediately
                  target.setAttribute('inputmode', 'none');
                  
                  if (target.type === 'password') {
                    // For password fields, ensure focus and show keyboard without readonly trick to avoid conflicts
                    target.focus();
                    showCustomKeyboard.postMessage('show');
                  } else {
                    // Aggressive IME prevention strategy for other fields
                    // Temporarily make readonly to prevent IME
                    target.setAttribute('readonly', 'true');
                    
                    // Force blur and refocus to reset IME state
                    setTimeout(function() {
                      target.removeAttribute('readonly');
                      target.focus();
                      
                      // Add one-time listeners to prevent IME reactivation
                      function preventIMEReactivation(te) {
                        te.preventDefault();
                        te.stopPropagation();
                        target.removeEventListener('touchstart', preventIMEReactivation);
                        target.removeEventListener('mousedown', preventIMEReactivation);
                      }
                      target.addEventListener('touchstart', preventIMEReactivation, { once: true });
                      target.addEventListener('mousedown', preventIMEReactivation, { once: true });
                    }, 10);
                    
                    showCustomKeyboard.postMessage('show');
                  }
                  return false;
                });
                input.addEventListener('blur', function(e) {
                  console.log('Custom keyboard: Input field blurred');
                  hideCustomKeyboard.postMessage('hide');
                });
                input.addEventListener('input', function(e) {
                  console.log('External input detected: ' + e.target.value);
                });
              }
            });
          }

          // Initial setup
          setupInputListeners();

          // Watch for new elements
          const observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
              mutation.addedNodes.forEach(function(node) {
                if (node.nodeType === 1) {
                  if (node.tagName === 'INPUT' || node.tagName === 'TEXTAREA' || node.contentEditable === 'true' || node.getAttribute('role') === 'textbox' || node.getAttribute('role') === 'combobox' || node.getAttribute('role') === 'searchbox' || node.getAttribute('role') === 'spinbutton' || node.getAttribute('role') === 'slider' || node.getAttribute('role') === 'listbox' || node.tagName === 'SELECT') {
                    if (!node.hasAttribute('data-custom-keyboard')) {
                      node.setAttribute('data-custom-keyboard', 'true');
                      node.setAttribute('inputmode', 'none');
                      ${widget.disableCopyPaste ? 'disableCopyPaste(node);' : ''}
                      node.addEventListener('focus', function(e) {
                        console.log('Custom keyboard: Input field focused');
                        e.preventDefault();
                        e.stopPropagation();
                        
                        var target = e.target;
                        
                        // Set inputmode to none immediately
                        target.setAttribute('inputmode', 'none');
                        
                        if (target.type === 'password') {
                          // For password fields, ensure focus and show keyboard without readonly trick to avoid conflicts
                          target.focus();
                          showCustomKeyboard.postMessage('show');
                        } else {
                          // Aggressive IME prevention strategy for other fields
                          // Temporarily make readonly to prevent IME
                          target.setAttribute('readonly', 'true');
                          
                          // Force blur and refocus to reset IME state
                          setTimeout(function() {
                            target.removeAttribute('readonly');
                            target.focus();
                            
                            // Add one-time listeners to prevent IME reactivation
                            function preventIMEReactivation(te) {
                              te.preventDefault();
                              te.stopPropagation();
                              target.removeEventListener('touchstart', preventIMEReactivation);
                              target.removeEventListener('mousedown', preventIMEReactivation);
                            }
                            target.addEventListener('touchstart', preventIMEReactivation, { once: true });
                            target.addEventListener('mousedown', preventIMEReactivation, { once: true });
                          }, 10);
                          
                          console.log('Sending show message to custom keyboard');
                          console.log('showCustomKeyboard object:', showCustomKeyboard);
                          console.log('window.showCustomKeyboard:', window.showCustomKeyboard);
                          showCustomKeyboard.postMessage('show');
                        }
                        return false;
                      });
                      node.addEventListener('blur', function(e) {
                        console.log('Custom keyboard: Input field blurred');
                        hideCustomKeyboard.postMessage('hide');
                      });
                      node.addEventListener('input', function(e) {
                        console.log('External input detected: ' + e.target.value || e.target.textContent);
                      });
                    }
                  } else {
                    const inputs = node.querySelectorAll('input, textarea, [contenteditable]');
                    inputs.forEach(function(input) {
                      if (!input.hasAttribute('data-custom-keyboard')) {
                        input.setAttribute('data-custom-keyboard', 'true');
                        input.setAttribute('inputmode', 'none');
                        ${widget.disableCopyPaste ? 'disableCopyPaste(input);' : ''}
                        input.addEventListener('focus', function(e) {
                          console.log('Custom keyboard: Input field focused');
                          e.preventDefault();
                          e.stopPropagation();
                          
                          var target = e.target;
                          
                          // Set inputmode to none immediately
                          target.setAttribute('inputmode', 'none');
                          
                          if (target.type === 'password') {
                            // For password fields, ensure focus and show keyboard without readonly trick to avoid conflicts
                            target.focus();
                            showCustomKeyboard.postMessage('show');
                          } else {
                            // Aggressive IME prevention strategy for other fields
                            // Temporarily make readonly to prevent IME
                            target.setAttribute('readonly', 'true');
                            
                            // Force blur and refocus to reset IME state
                            setTimeout(function() {
                              target.removeAttribute('readonly');
                              target.focus();
                              
                              // Add one-time listeners to prevent IME reactivation
                              function preventIMEReactivation(te) {
                                te.preventDefault();
                                te.stopPropagation();
                                target.removeEventListener('touchstart', preventIMEReactivation);
                                target.removeEventListener('mousedown', preventIMEReactivation);
                              }
                              target.addEventListener('touchstart', preventIMEReactivation, { once: true });
                              target.addEventListener('mousedown', preventIMEReactivation, { once: true });
                            }, 10);
                            
                            showCustomKeyboard.postMessage('show');
                          }
                          return false;
                        });
                        input.addEventListener('blur', function(e) {
                          console.log('Custom keyboard: Input field blurred');
                          hideCustomKeyboard.postMessage('hide');
                        });
                        input.addEventListener('input', function(e) {
                          console.log('External input detected: ' + e.target.value);
                        });
                        input.addEventListener('input', function(e) {
                          console.log('External input detected: ' + e.target.value);
                        });
                      }
                    });
                    if (inputs.length > 0) {
                      // No need to call setupInputListeners again since we handled them above
                    }
                  }
                }
              });
            });
          });

          observer.observe(document.body, {
            childList: true,
            subtree: true
          });

          // Global focus listener for debugging
          document.addEventListener('focus', function(e) {
            console.log('Global focus event on:', e.target.tagName, e.target.type, e.target.contentEditable, e.target.getAttribute('role'));
            debugLog.postMessage('Global focus event on: ' + e.target.tagName + ' ' + e.target.type + ' ' + e.target.contentEditable + ' ' + e.target.getAttribute('role'));
          }, true);

          // Handle iframes
          document.querySelectorAll('iframe').forEach(function(iframe) {
            try {
              var doc = iframe.contentDocument || iframe.contentWindow.document;
              if (doc) {
                var script = doc.createElement('script');
                script.textContent = \`
                  function setupInputListeners() {
                    const inputs = document.querySelectorAll('input, textarea, [contenteditable], [role="textbox"], [contenteditable="true"], [role="combobox"], [role="searchbox"], [role="spinbutton"], [role="slider"], [role="listbox"], select');
                    console.log('Found ' + inputs.length + ' input elements in iframe');
                    inputs.forEach(function(input) {
                      if (!input.hasAttribute('data-custom-keyboard')) {
                        input.setAttribute('data-custom-keyboard', 'true');
                        input.setAttribute('inputmode', 'none');
                        input.addEventListener('focus', function(e) {
                          console.log('Custom keyboard: Input field focused in iframe');
                          e.preventDefault();
                          e.stopPropagation();
                          var target = e.target;
                          target.setAttribute('inputmode', 'none');
                          target.setAttribute('readonly', 'true');
                          setTimeout(function() {
                            target.removeAttribute('readonly');
                            target.focus();
                            console.log('Sending show message from iframe');
                            window.parent.postMessage('showCustomKeyboard', '*');
                          }, 10);
                        });
                        input.addEventListener('blur', function(e) {
                          console.log('Custom keyboard: Input field blurred in iframe');
                          window.parent.postMessage('hideCustomKeyboard', '*');
                        });
                        input.addEventListener('input', function(e) {
                          console.log('External input detected in iframe: ' + (e.target.value || e.target.textContent));
                        });
                      }
                    });
                  }
                  setupInputListeners();
                  const observer = new MutationObserver(function(mutations) {
                    mutations.forEach(function(mutation) {
                      mutation.addedNodes.forEach(function(node) {
                        if (node.nodeType === 1) {
                          if (node.tagName === 'INPUT' || node.tagName === 'TEXTAREA' || node.contentEditable === 'true' || node.getAttribute('role') === 'textbox' || node.getAttribute('role') === 'combobox' || node.getAttribute('role') === 'searchbox' || node.getAttribute('role') === 'spinbutton' || node.getAttribute('role') === 'slider' || node.getAttribute('role') === 'listbox' || node.tagName === 'SELECT') {
                            if (!node.hasAttribute('data-custom-keyboard')) {
                              node.setAttribute('data-custom-keyboard', 'true');
                              node.setAttribute('inputmode', 'none');
                              node.addEventListener('focus', function(e) {
                                console.log('Custom keyboard: Input field focused in iframe');
                                e.preventDefault();
                                e.stopPropagation();
                                var target = e.target;
                                target.setAttribute('inputmode', 'none');
                                target.setAttribute('readonly', 'true');
                                setTimeout(function() {
                                  target.removeAttribute('readonly');
                                  target.focus();
                                  console.log('Sending show message from iframe');
                                  window.parent.postMessage('showCustomKeyboard', '*');
                                }, 10);
                              });
                              node.addEventListener('blur', function(e) {
                                console.log('Custom keyboard: Input field blurred in iframe');
                                window.parent.postMessage('hideCustomKeyboard', '*');
                              });
                              node.addEventListener('input', function(e) {
                                console.log('External input detected in iframe: ' + (e.target.value || e.target.textContent));
                              });
                            }
                          }
                          const inputs = node.querySelectorAll('input, textarea, [contenteditable]');
                          inputs.forEach(function(input) {
                            if (!input.hasAttribute('data-custom-keyboard')) {
                              input.setAttribute('data-custom-keyboard', 'true');
                              input.setAttribute('inputmode', 'none');
                              input.addEventListener('focus', function(e) {
                                console.log('Custom keyboard: Input field focused in iframe');
                                e.preventDefault();
                                e.stopPropagation();
                                var target = e.target;
                                target.setAttribute('inputmode', 'none');
                                target.setAttribute('readonly', 'true');
                                setTimeout(function() {
                                  target.removeAttribute('readonly');
                                  target.focus();
                                  console.log('Sending show message from iframe');
                                  window.parent.postMessage('showCustomKeyboard', '*');
                                }, 10);
                              });
                              input.addEventListener('blur', function(e) {
                                console.log('Custom keyboard: Input field blurred in iframe');
                                window.parent.postMessage('hideCustomKeyboard', '*');
                              });
                              input.addEventListener('input', function(e) {
                                console.log('External input detected in iframe: ' + (e.target.value || e.target.textContent));
                              });
                            }
                          });
                        }
                      });
                    });
                  });
                  observer.observe(doc.body, { childList: true, subtree: true });
                  doc.addEventListener('focus', function(e) {
                    console.log('Global focus event in iframe on:', e.target.tagName, e.target.type, e.target.contentEditable, e.target.getAttribute('role'));
                    window.parent.postMessage('debugLog:' + 'Global focus event in iframe on: ' + e.target.tagName + ' ' + e.target.type + ' ' + e.target.contentEditable + ' ' + e.target.getAttribute('role'), '*');
                  }, true);
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
              console.log('Received show from iframe');
              showCustomKeyboard.postMessage('show');
            } else if (e.data === 'hideCustomKeyboard') {
              console.log('Received hide from iframe');
              hideCustomKeyboard.postMessage('hide');
            } else if (typeof e.data === 'string' && e.data.startsWith('debugLog:')) {
              debugLog.postMessage(e.data.substring(9));
            }
          });

          // No need to blur or remove autofocus here, handled separately
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
      debugPrint('Error extracting favicon: $e');
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
          
          // Loading overlay to hide previous content
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          
          // Loading indicator
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _loadingProgress,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),

          // Custom keyboard
          if (_showCustomKeyboard && widget.useCustomKeyboard) ...[
            Builder(
              builder: (context) {
                debugPrint('Rendering custom keyboard - _showCustomKeyboard: $_showCustomKeyboard, useCustomKeyboard: ${widget.useCustomKeyboard}');
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

  Widget _buildDrawer() {
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
                        child: Image.network(
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
                  _customAppName.isNotEmpty ? _customAppName : _websiteName,
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
              const SizedBox(height: 32),
              
              // Menu Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  children: [
                    _buildMenuTile(
                      icon: Icons.refresh,
                      title: 'Reload Page',
                      onTap: () {
                        _controller.reload();
                        Navigator.pop(context);
                      },
                    ),
                    _buildMenuTile(
                      icon: Icons.home,
                      title: 'Home',
                      onTap: () {
                        _controller.loadRequest(Uri.parse(widget.initialUrl));
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(color: Colors.white24, height: 32),
                    _buildMenuTile(
                      icon: Icons.settings,
                      title: 'Website Settings',
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        _showWebsiteSettingsMenu();
                      },
                    ),
                    _buildMenuTile(
                      icon: Icons.apps,
                      title: 'Back to Shortcuts',
                      onTap: () {
                        Navigator.of(context).pop(); // Close drawer
                        Navigator.of(context).pop(); // Go back to shortcut list
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

  void _showWebsiteSettingsMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade800,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Website Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.white),
              title: const Text(
                'Change URL',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                _showChangeUrlDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.label, color: Colors.white),
              title: const Text(
                'Change App Name',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              subtitle: Text(
                _customAppName.isEmpty ? 'Not set' : _customAppName,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _showChangeAppNameDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.white),
              title: const Text(
                'Change Icon URL',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              subtitle: Text(
                _customIconUrl.isEmpty ? 'Not set' : _customIconUrl,
                style: TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.pop(context);
                _showChangeIconUrlDialog();
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.add_to_home_screen, color: Colors.white),
              title: const Text(
                'Add to Home Screen',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              subtitle: const Text(
                'Create shortcut with custom URL & icon',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _showCreateShortcutDialog();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
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
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Home Screen Shortcut'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Shortcut Name',
                    hintText: 'My Website',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Website URL',
                    hintText: 'https://example.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: iconController,
                  decoration: InputDecoration(
                    labelText: 'Icon URL (PNG/JPG only)',
                    hintText: 'https://example.com/icon.png',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.image),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.auto_fix_high),
                      tooltip: 'Auto-detect from URL',
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
                const Text(
                  'Keyboard Options:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Disable Auto Focus'),
                  subtitle: const Text('Prevent automatic keyboard popup on page load'),
                  value: disableAutoFocus,
                  onChanged: (value) {
                    setState(() {
                      disableAutoFocus = value ?? false;
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Use Custom Keyboard'),
                  subtitle: const Text('Replace system keyboard with custom numeric/alphanumeric keyboard'),
                  value: useCustomKeyboard,
                  onChanged: (value) {
                    setState(() {
                      useCustomKeyboard = value ?? false;
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Disable Copy/Paste'),
                  subtitle: const Text('Prevent copying and pasting in input fields'),
                  value: disableCopyPaste,
                  onChanged: (value) {
                    setState(() {
                      disableCopyPaste = value ?? false;
                    });
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tip: Tap the magic wand to auto-detect icon from URL',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
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
              child: const Text('Create Shortcut'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeUrlDialog() {
    final TextEditingController urlController = TextEditingController(text: _currentUrl);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change URL'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            labelText: 'URL',
            hintText: 'https://example.com',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              String url = urlController.text.trim();
              if (url.isNotEmpty) {
                if (!url.startsWith('http://') && !url.startsWith('https://')) {
                  url = 'https://$url';
                }
                _controller.loadRequest(Uri.parse(url));
                Navigator.pop(context);
              }
            },
            child: const Text('Load'),
          ),
        ],
      ),
    );
  }

  void _showChangeAppNameDialog() {
    final TextEditingController nameController = TextEditingController(text: _customAppName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change App Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'App Name',
            hintText: 'Enter custom app name',
            border: OutlineInputBorder(),
          ),
          maxLength: 30,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveCustomAppName(nameController.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('App name updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangeIconUrlDialog() {
    final TextEditingController iconController = TextEditingController(text: _customIconUrl);
    
    // Generate suggested favicon URLs
    String host = '';
    try {
      host = Uri.parse(_currentUrl).host;
    } catch (e) {
      host = '';
    }
    
    final List<Map<String, String>> suggestedIcons = [
      {'name': 'Google Favicon (128px) - Recommended', 'url': 'https://www.google.com/s2/favicons?domain=$host&sz=128'},
      {'name': 'Google Favicon (64px)', 'url': 'https://www.google.com/s2/favicons?domain=$host&sz=64'},
      {'name': 'Apple Touch Icon (PNG)', 'url': 'https://$host/apple-touch-icon.png'},
      {'name': 'Direct favicon.ico', 'url': 'https://$host/favicon.ico'},
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Icon URL'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: iconController,
                decoration: const InputDecoration(
                  labelText: 'Icon URL',
                  hintText: 'https://example.com/icon.png',
                  border: OutlineInputBorder(),
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
                    const Expanded(
                      child: Text(
                        'Only PNG, JPG, GIF, WebP supported.\nSVG files will NOT work!',
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Suggested icons:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
              const Text(
                'Tap a suggestion to use it, or enter your own PNG/JPG URL.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = iconController.text.trim().toLowerCase();
              if (url.endsWith('.svg')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('SVG files are not supported. Please use PNG or JPG.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              _saveCustomIconUrl(iconController.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Icon URL updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _askToCreateShortcut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Home Screen Shortcut'),
        content: Text(
          'Would you like to create a home screen shortcut with the name "${_customAppName}"?\n\nThis will add a new icon to your home screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createHomeScreenShortcut();
            },
            child: const Text('Create Shortcut'),
          ),
        ],
      ),
    );
  }

  static const platform = MethodChannel('webkiosk.builder/shortcut');

  Future<void> _createShortcutWithParams(
    String name, 
    String url, 
    String iconUrl, {
    bool disableAutoFocus = false,
    bool useCustomKeyboard = false,
    bool disableCopyPaste = false,
  }) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a shortcut name'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a URL'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    // Add https if no protocol
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    
    try {
      await platform.invokeMethod('createShortcut', {
        'name': name,
        'url': url,
        'iconUrl': iconUrl,
        'disableAutoFocus': disableAutoFocus,
        'useCustomKeyboard': useCustomKeyboard,
        'disableCopyPaste': disableCopyPaste,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shortcut "$name" added to home screen'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create shortcut: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createHomeScreenShortcut() async {
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
            content: Text('Shortcut "$appName" added to home screen'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create shortcut: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addViaChrome() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Home Screen via Chrome'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will open the website in Chrome. To add a clean shortcut without any badge:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildStep('1', 'Tap the menu icon (⋮) in Chrome'),
            _buildStep('2', 'Select "Add to Home screen"'),
            _buildStep('3', 'Enter your desired name'),
            _buildStep('4', 'Tap "Add"'),
            const SizedBox(height: 16),
            const Text(
              'The shortcut will use the website\'s icon without any app badge.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final Uri url = Uri.parse(widget.initialUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Open in Chrome'),
          ),
        ],
      ),
    );
  }

  void _applyAsAppIcon() async {
    if (_customIconUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set an icon URL first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Applying icon...'),
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
            title: const Text('Icon Changed!'),
            content: const Text(
              'The app icon has been updated.\n\n'
              'Note: The icon change will take effect after you:\n'
              '1. Close the app completely\n'
              '2. Wait a few seconds\n'
              '3. The launcher may need time to update\n\n'
              'Some launchers require a restart to show the new icon.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to change app icon'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
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

  /// Custom numeric keyboard widget
  Widget _buildCustomKeyboard() {
    if (_keyboardMinimized) {
      return Positioned(
        left: _minimizedIconPosition.dx,
        top: _minimizedIconPosition.dy,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              // Move minimized icon
              _minimizedIconPosition = Offset(
                _minimizedIconPosition.dx + details.delta.dx,
                _minimizedIconPosition.dy + details.delta.dy,
              );
              
              // Constrain to screen bounds (ensure icon stays visible)
              final screenSize = MediaQuery.of(context).size;
              final iconSize = 60.0;
              
              // Ensure icon doesn't go off screen
              final maxX = screenSize.width - iconSize - 10.0;
              final maxY = screenSize.height - iconSize - 10.0;
              
              // Ensure clamp range is valid (min <= max)
              final minIconX = 10.0;
              final minIconY = 10.0;
              final validMaxX = maxX > minIconX ? maxX : minIconX;
              final validMaxY = maxY > minIconY ? maxY : minIconY;
              
              _minimizedIconPosition = Offset(
                _minimizedIconPosition.dx.clamp(minIconX, validMaxX),
                _minimizedIconPosition.dy.clamp(minIconY, validMaxY),
              );
            });
            // Save minimized icon position to preferences
            _saveMinimizedIconPosition();
          },
          onTap: () {
            setState(() {
              _keyboardMinimized = false;
            });
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(30),
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
            final keyboardWidth = _isExpandedMode ? 876.0 : 240.0; // Wider when expanded to fit AZERTY + numeric
            final keyboardHeight = 352.0; // Updated height with consistent button heights
            
            // Ensure keyboard doesn't go off screen
            final maxX = screenSize.width - keyboardWidth - 20.0;
            final maxY = screenSize.height - keyboardHeight - 20.0;
            
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
          width: _isExpandedMode ? 876.0 : 240.0,
          padding: const EdgeInsets.all(12),
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
              // Row 1: Drag bar (3 columns) + Hide button
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: double.infinity, // Fill full height
                        alignment: Alignment.center, // Center the icon
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.drag_handle,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _keyboardMinimized = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text('▼', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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
          height: 50,
          child: Row(
            children: [
              Expanded(child: _buildKeyboardButton('ABC')),
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
                    height: 50,
                    child: Row(
                      children: [
                        Expanded(child: _buildKeyboardButton('7')),
                        const SizedBox(width: 4),
                        Expanded(child: _buildKeyboardButton('8')),
                        const SizedBox(width: 4),
                        Expanded(child: _buildKeyboardButton('9')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Row 4: 4, 5, 6
                  SizedBox(
                    height: 50,
                    child: Row(
                      children: [
                        Expanded(child: _buildKeyboardButton('4')),
                        const SizedBox(width: 4),
                        Expanded(child: _buildKeyboardButton('5')),
                        const SizedBox(width: 4),
                        Expanded(child: _buildKeyboardButton('6')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // DELETE button spanning rows 3 & 4
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 104, // Spans 2 rows: 50 + 4 + 50
                child: ElevatedButton(
                  onPressed: () => _onKeyboardKeyPressed('', isBackspace: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.all(1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    '⌫',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
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
                    height: 50,
                    child: Row(
                      children: [
                        Expanded(child: _buildKeyboardButton('1')),
                        const SizedBox(width: 4),
                        Expanded(child: _buildKeyboardButton('2')),
                        const SizedBox(width: 4),
                        Expanded(child: _buildKeyboardButton('3')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Row 6: 0 (spans 2 columns), .
                  SizedBox(
                    height: 50,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () => _onKeyboardKeyPressed('0'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: const Text(
                                '0',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
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
            const SizedBox(width: 6),
            // Enter button spanning rows 5 & 6
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 104, // Spans 2 rows: 50 + 4 + 50
                child: ElevatedButton(
                  onPressed: () => _onKeyboardKeyPressed('⏎'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.all(1), // Reduced padding
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    '⏎',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
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
          width: 600.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: & é " ' ( - è _ ç à ) = ⌫
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    Expanded(child: _buildKeyboardButton('&')),
                    const SizedBox(width: 4),
                    Expanded(child: _buildKeyboardButton('é')),
                    const SizedBox(width: 4),
                    Expanded(child: _buildKeyboardButton('"')),
                    const SizedBox(width: 4),
                    Expanded(child: _buildKeyboardButton("'")),
                    const SizedBox(width: 4),
                    Expanded(child: _buildKeyboardButton('(')),
                    const SizedBox(width: 4),
                    Expanded(child: _buildKeyboardButton('-')),
                    const SizedBox(width: 4),
                    Expanded(child: _buildKeyboardButton('è')),
                    const SizedBox(width: 4),
                    Expanded(child: _buildKeyboardButton('_')),
                    const SizedBox(width: 4),
                    Expanded(child: _buildKeyboardButton('ç')),
                    const SizedBox(width: 4),
                    Expanded(child: _buildKeyboardButton('à')),
                    const SizedBox(width: 4),
                    Expanded(child: _buildKeyboardButton(')')),
                    const SizedBox(width: 4),
                    Expanded(child: _buildKeyboardButton('=')),
                    const SizedBox(width: 4),
                    Expanded(flex: 2, child: _buildKeyboardButton('⌫', backgroundColor: Colors.grey.shade600)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Rows 2 & 3: Combined layout with merged ENTER key
              SizedBox(
                height: 104, // 50 + 4 + 50 = 104 for two rows with spacing
                child: Row(
                  children: [
                    // Column 1: 123 key to switch back to numeric keyboard
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 104, // Full height for both rows
                        child: ElevatedButton(
                          onPressed: () => _onKeyboardKeyPressed('123'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text(
                            '123',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Column 2: A (Row 2) / Q (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('a'),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('q'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Column 3: Z (Row 2) / S (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('z'),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('s'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Column 4: E (Row 2) / D (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('e'),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('d'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Column 5: R (Row 2) / F (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('r'),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('f'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Column 6: T (Row 2) / G (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('t'),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('g'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Column 7: Y (Row 2) / H (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('y'),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('h'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Column 8: U (Row 2) / J (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('u'),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('j'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Column 9: I (Row 2) / K (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('i'),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('k'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Column 10: O (Row 2) / L (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('o'),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('l'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Column 11: P (Row 2) / M (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('p'),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('m'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Column 12: ^ (Row 2) / ù (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('^'),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('ù'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Column 13: $ (Row 2) / * (Row 3)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('\$'),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 50,
                            child: _buildKeyboardButton('*'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Column 14: ENTER (spans both rows)
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 104, // Full height for both rows
                        child: _buildKeyboardButton('⏎'), // Enter key
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Row 4: ⇪ < w x c v b n , ; : ! ⇪
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    Expanded(flex: 2, child: _buildKeyboardButton(_isShift ? '⇪' : '⇪', backgroundColor: _isShift ? Colors.blue.shade600 : Colors.grey.shade600)),
                    const SizedBox(width: 4),
                    Expanded(child: _buildKeyboardButton('<')),
                    const SizedBox(width: 4),
                    Expanded(child: _buildKeyboardButton('w')),
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
                    Expanded(child: _buildKeyboardButton(',')),
                    const SizedBox(width: 4),
                    Expanded(child: _buildKeyboardButton(';')),
                    const SizedBox(width: 4),
                    Expanded(child: _buildKeyboardButton(':')),
                    const SizedBox(width: 4),
                    Expanded(child: _buildKeyboardButton('!')),
                    const SizedBox(width: 4),
                    Expanded(flex: 2, child: _buildKeyboardButton(_isShift ? '⇪' : '⇪', backgroundColor: _isShift ? Colors.blue.shade600 : Colors.grey.shade600)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Row 5: ← → ESPACE
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    Expanded(flex: 1, child: _buildKeyboardButton('←')),
                    const SizedBox(width: 4),
                    Expanded(flex: 1, child: _buildKeyboardButton('→')),
                    const SizedBox(width: 4),
                    Expanded(flex: 6, child: _buildKeyboardButton(' ')), // Space bar
                    const SizedBox(width: 4),
                    Expanded(flex: 1, child: _buildKeyboardButton('↑')),
                    const SizedBox(width: 4),
                    Expanded(flex: 1, child: _buildKeyboardButton('↓')),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4), // Gap between main keyboard and numeric sections
        // Right side: Numeric keyboard (240px wide, same as compact mode)
        SizedBox(
          width: 240.0,
          child: Column(
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
                          height: 50,
                          child: Row(
                            children: [
                              Expanded(child: _buildKeyboardButton('7')),
                              const SizedBox(width: 4),
                              Expanded(child: _buildKeyboardButton('8')),
                              const SizedBox(width: 4),
                              Expanded(child: _buildKeyboardButton('9')),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Row 4: 4, 5, 6
                        SizedBox(
                          height: 50,
                          child: Row(
                            children: [
                              Expanded(child: _buildKeyboardButton('4')),
                              const SizedBox(width: 4),
                              Expanded(child: _buildKeyboardButton('5')),
                              const SizedBox(width: 4),
                              Expanded(child: _buildKeyboardButton('6')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // DELETE button spanning rows 3 & 4
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 104, // Spans 2 rows: 50 + 4 + 50
                      child: ElevatedButton(
                        onPressed: () => _onKeyboardKeyPressed('', isBackspace: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.all(1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          '⌫',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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
                          height: 50,
                          child: Row(
                            children: [
                              Expanded(child: _buildKeyboardButton('1')),
                              const SizedBox(width: 4),
                              Expanded(child: _buildKeyboardButton('2')),
                              const SizedBox(width: 4),
                              Expanded(child: _buildKeyboardButton('3')),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Row 6: 0 (spans 2 columns), .
                        SizedBox(
                          height: 50,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: () => _onKeyboardKeyPressed('0'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade600,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    child: const Text(
                                      '0',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
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
                  const SizedBox(width: 6),
                  // Enter button spanning rows 5 & 6
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 104, // Spans 2 rows: 50 + 4 + 50
                      child: ElevatedButton(
                        onPressed: () => _onKeyboardKeyPressed('⏎'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.all(1), // Reduced padding
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          '⏎',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
      height: 50,
      child: ElevatedButton(
        onPressed: () => _onKeyboardKeyPressed(keyValue ?? text, isBackspace: isBackspace),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.grey.shade600,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: (displayText == '⇪' ) ? 28 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _onKeyboardKeyPressed(String key, {bool isBackspace = false}) {
    debugPrint('Keyboard key pressed: $key, isBackspace: $isBackspace');
    
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
      // Position numeric keyboard at bottom right of the screen
      final screenSize = MediaQuery.of(context).size;
      _keyboardPosition = Offset(
        screenSize.width - 240.0,
        screenSize.height - 352.0,
      );
      _saveKeyboardPosition();
    } else if (key == 'ABC') {
      // Expand to show full keyboard with alphabetic and numeric sections
      setState(() {
        _isExpandedMode = true;
      });
      // Position keyboard centered horizontally at the bottom of the screen
      final screenSize = MediaQuery.of(context).size;
      _keyboardPosition = Offset(
        (screenSize.width - 876.0) / 2,
        screenSize.height - 352.0,
      );
      _saveKeyboardPosition();
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
      
      debugPrint('keyToSend: $keyToSend for key: $key, _isShift: $_isShift');
      
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

  @override
  void dispose() {
    // Clean up WebView controller
    _controller.clearCache();
    _controller.clearLocalStorage();
    super.dispose();
  }
}
