import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/shortcut_item.dart';
import 'error_page.dart';

class AddAppsScreen extends StatefulWidget {
  final List<ShortcutItem> currentShortcuts;
  
  const AddAppsScreen({super.key, required this.currentShortcuts});

  @override
  State<AddAppsScreen> createState() => _AddAppsScreenState();
}

class _AddAppsScreenState extends State<AddAppsScreen> {
  static const platform = MethodChannel('devicegate.app/shortcut');
  List<Map<String, dynamic>> _installedApps = [];
  final Set<String> _selectedPackages = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize selected packages from current shortcuts
    _selectedPackages.addAll(
      widget.currentShortcuts
          .where((s) => s.url.startsWith('app://'))
          .map((s) => s.url.substring(6)) // Remove 'app://' prefix
    );
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getInstalledApps');
      setState(() {
        _installedApps = result.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ErrorPage(
              errorTitle: 'Erreur de chargement',
              errorMessage: 'Impossible de charger les applications installées',
              error: error,
              stackTrace: stackTrace,
              onRetry: () {
                Navigator.of(context).pop();
                setState(() {
                  _isLoading = true;
                });
                _loadInstalledApps();
              },
            ),
          ),
        );
      }
    }
  }

  void _toggleApp(String packageName) {
    setState(() {
      if (_selectedPackages.contains(packageName)) {
        _selectedPackages.remove(packageName);
      } else {
        _selectedPackages.add(packageName);
      }
    });
  }

  void _saveChanges() {
    // Create a map of changes: add or remove
    final changes = <String, Map<String, dynamic>>{};
    
    // Find apps to add
    for (var app in _installedApps) {
      final packageName = app['packageName'] as String;
      final isCurrentlyOnHome = widget.currentShortcuts.any((s) => s.url == 'app://$packageName');
      final shouldBeOnHome = _selectedPackages.contains(packageName);
      
      if (shouldBeOnHome && !isCurrentlyOnHome) {
        changes[packageName] = {
          'action': 'add',
          'name': app['name'],
          'icon': app['icon'],
        };
      } else if (!shouldBeOnHome && isCurrentlyOnHome) {
        changes[packageName] = {
          'action': 'remove',
        };
      }
    }
    
    Navigator.pop(context, changes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Apps'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: const Text(
              'SAVE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _installedApps.isEmpty
              ? const Center(
                  child: Text(
                    'No apps found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : Column(
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      color: Colors.grey.shade100,
                      child: Text(
                        'Check apps to add to DeviceGate home',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    // Apps list
                    Expanded(
                      child: ListView.builder(
                        itemCount: _installedApps.length,
                        itemBuilder: (context, index) {
                          final app = _installedApps[index];
                          final appName = app['name'] as String;
                          final packageName = app['packageName'] as String;
                          final iconBase64 = app['icon'] as String?;
                          final isSelected = _selectedPackages.contains(packageName);

                          Widget leading;
                          if (iconBase64 != null && iconBase64.isNotEmpty) {
                            try {
                              final bytes = base64Decode(iconBase64);
                              leading = Image.memory(
                                bytes,
                                width: 48,
                                height: 48,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.android, size: 48);
                                },
                              );
                            } catch (e) {
                              leading = const Icon(Icons.android, size: 48);
                            }
                          } else {
                            leading = const Icon(Icons.android, size: 48);
                          }

                          return CheckboxListTile(
                            secondary: SizedBox(
                              width: 48,
                              height: 48,
                              child: leading,
                            ),
                            title: Text(
                              appName,
                              style: const TextStyle(fontSize: 16),
                            ),
                            subtitle: Text(
                              packageName,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            value: isSelected,
                            onChanged: (bool? value) {
                              _toggleApp(packageName);
                            },
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 4.0,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
