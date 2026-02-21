import 'package:flutter/material.dart';
import '../models/shortcut_item.dart';

class AddShortcutScreen extends StatefulWidget {
  const AddShortcutScreen({super.key});

  @override
  State<AddShortcutScreen> createState() => _AddShortcutScreenState();
}

class _AddShortcutScreenState extends State<AddShortcutScreen> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController(text: 'https://');
  final _iconUrlController = TextEditingController();
  bool _disableAutoFocus = false;
  bool _useCustomKeyboard = false;
  bool _disableCopyPaste = false;
  String _selectedAssetIcon = '';

  // Available asset icons
  final List<String> _availableAssetIcons = [
    '', // Empty option for URL input
    'assets/icon/SAP_EWM.png',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _iconUrlController.dispose();
    super.dispose();
  }

  void _saveShortcut() {
    final name = _nameController.text.trim();
    var url = _urlController.text.trim();
    var iconUrl = _iconUrlController.text.trim();

    if (name.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name and URL')),
      );
      return;
    }

    // Ensure URL has protocol
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    // Determine final icon URL
    var finalIconUrl = _selectedAssetIcon;
    if (finalIconUrl.isEmpty) {
      finalIconUrl = iconUrl;
    }

    final shortcut = ShortcutItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      url: url,
      iconUrl: finalIconUrl,
      disableAutoFocus: _disableAutoFocus,
      useCustomKeyboard: _useCustomKeyboard,
      disableCopyPaste: _disableCopyPaste,
    );

    Navigator.pop(context, shortcut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Shortcut'),
        backgroundColor: const Color.fromRGBO(51, 61, 71, 1),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveShortcut,
            child: const Text(
              'SAVE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Name field
          const Text(
            'Name',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'e.g., Google',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 24),

          // Website URL field
          const Text(
            'Website URL',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: 'https://www.google.com',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 24),

          // Icon selection
          const Text(
            'Icon',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedAssetIcon,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: _availableAssetIcons.map((icon) {
              return DropdownMenuItem<String>(
                value: icon,
                child: Text(icon.isEmpty ? 'Use URL (below)' : icon.replaceFirst('assets/icon/', '')),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedAssetIcon = value ?? '';
                if (_selectedAssetIcon.isNotEmpty) {
                  _iconUrlController.clear();
                }
              });
            },
          ),
          const SizedBox(height: 16),

          // Icon URL field
          const Text(
            'Icon URL (optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _iconUrlController,
            enabled: _selectedAssetIcon.isEmpty,
            decoration: InputDecoration(
              hintText: _selectedAssetIcon.isNotEmpty ? 'Using asset icon' : 'Leave empty for auto-detect',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: _selectedAssetIcon.isNotEmpty,
              fillColor: _selectedAssetIcon.isNotEmpty ? Colors.grey.shade100 : null,
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
          Text(
            _selectedAssetIcon.isNotEmpty
                ? 'Using selected asset icon.'
                : 'Leave icon URL empty to use the site\'s favicon (or default icon if unavailable).',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Advanced options header
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Advanced Options',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Disable Keyboard switch
          SwitchListTile(
            title: const Text('Disable Keyboard'),
            subtitle: const Text(
              'Prevent keyboard from appearing on input fields',
              style: TextStyle(fontSize: 12),
            ),
            value: _disableAutoFocus,
            onChanged: (value) {
              setState(() {
                _disableAutoFocus = value;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),

          // Use Custom Keyboard switch
          SwitchListTile(
            title: const Text('Use Custom Keyboard'),
            subtitle: const Text(
              'Show numeric keyboard in bottom-left corner (autofocus can be controlled separately)',
              style: TextStyle(fontSize: 12),
            ),
            value: _useCustomKeyboard,
            onChanged: (value) {
              setState(() {
                _useCustomKeyboard = value;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),

          // Disable Copy/Paste switch
          SwitchListTile(
            title: const Text('Disable Copy/Paste'),
            subtitle: const Text(
              'Prevent copying and pasting in input fields',
              style: TextStyle(fontSize: 12),
            ),
            value: _disableCopyPaste,
            onChanged: (value) {
              setState(() {
                _disableCopyPaste = value;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
