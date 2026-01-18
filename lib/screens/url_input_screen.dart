import 'package:flutter/material.dart';
import 'kiosk_webview_screen.dart';

class UrlInputScreen extends StatefulWidget {
  const UrlInputScreen({super.key});

  @override
  State<UrlInputScreen> createState() => _UrlInputScreenState();
}

class _UrlInputScreenState extends State<UrlInputScreen> {
  final TextEditingController _urlController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _navigateToWebView() {
    String url = _urlController.text.trim();
    
    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a URL';
      });
      return;
    }

    // Add http:// if no protocol is specified
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    // Basic URL validation
    Uri? uri;
    try {
      uri = Uri.parse(url);
      if (uri.host.isEmpty) {
        throw FormatException('Invalid URL');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Please enter a valid URL';
      });
      return;
    }

    // Navigate to webview screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => KioskWebViewScreen(
          initialUrl: url,
          disableAutoFocus: true,
          useCustomKeyboard: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade700,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.web,
                      size: 80,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'WebKiosk Builder',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter a website URL to begin',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: 'Website URL',
                        hintText: 'example.com or https://example.com',
                        prefixIcon: const Icon(Icons.link),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorText: _errorMessage,
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _navigateToWebView(),
                      onChanged: (_) {
                        if (_errorMessage != null) {
                          setState(() {
                            _errorMessage = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _navigateToWebView,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Open Website',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
