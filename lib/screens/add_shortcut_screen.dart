import 'package:flutter/material.dart';
import '../models/shortcut_item.dart';
import '../generated/l10n/app_localizations.dart';

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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseEnterNameAndUrl)),
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addNewShortcut),
        backgroundColor: const Color.fromRGBO(51, 61, 71, 1),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveShortcut,
            child: Text(
              l10n.save.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Name field
          Text(
            l10n.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: l10n.nameHint,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 24),

          // Website URL field
          Text(
            l10n.websiteUrl,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: l10n.websiteUrlHint,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 24),

          // Icon selection
          Text(
            l10n.icon,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                child: Text(icon.isEmpty ? l10n.useUrlBelow : icon.replaceFirst('assets/icon/', '')),
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
          Text(
            l10n.iconUrlOptional,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _iconUrlController,
            enabled: _selectedAssetIcon.isEmpty,
            decoration: InputDecoration(
              hintText: _selectedAssetIcon.isNotEmpty ? l10n.usingAssetIcon : l10n.leaveEmptyForAutoDetect,
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
                ? l10n.usingSelectedAssetIcon
                : l10n.leaveIconUrlEmpty,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Advanced options header
          const Divider(),
          const SizedBox(height: 8),
          Text(
            l10n.advancedOptions,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Use Custom Keyboard switch
          SwitchListTile(
            title: Text(l10n.useCustomKeyboard),
            subtitle: Text(
              l10n.useCustomKeyboardDesc,
              style: const TextStyle(fontSize: 12),
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
            title: Text(l10n.disableCopyPaste),
            subtitle: Text(
              l10n.disableCopyPasteDesc,
              style: const TextStyle(fontSize: 12),
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
