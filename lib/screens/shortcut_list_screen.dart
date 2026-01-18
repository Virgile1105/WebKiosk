import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shortcut_item.dart';
import 'kiosk_webview_screen.dart';

class ShortcutListScreen extends StatefulWidget {
  const ShortcutListScreen({super.key});

  @override
  State<ShortcutListScreen> createState() => _ShortcutListScreenState();
}

class _ShortcutListScreenState extends State<ShortcutListScreen> {
  static const platform = MethodChannel('webkiosk.builder/shortcut');
  List<ShortcutItem> _shortcuts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShortcuts();
  }

  Future<void> _loadShortcuts() async {
    final prefs = await SharedPreferences.getInstance();
    final shortcutsJson = prefs.getString('shortcuts') ?? '';
    setState(() {
      _shortcuts = ShortcutItem.decodeList(shortcutsJson);
      _isLoading = false;
    });
  }

  Future<void> _saveShortcuts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shortcuts', ShortcutItem.encodeList(_shortcuts));
  }

  Future<void> _addShortcut() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController(text: 'https://');
    final iconUrlController = TextEditingController();
    bool disableAutoFocus = false;
    bool useCustomKeyboard = false;
    bool disableCopyPaste = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Shortcut'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g., Google',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Website URL',
                    hintText: 'https://www.google.com',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: iconUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Icon URL (optional)',
                    hintText: 'Leave empty for auto-detect',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tip: Leave icon URL empty to use the site\'s favicon automatically.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Disable Keyboard'),
                  subtitle: const Text(
                    'Prevent keyboard from appearing on input fields',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: disableAutoFocus,
                  onChanged: (value) {
                    setDialogState(() {
                      disableAutoFocus = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Use Custom Keyboard'),
                  subtitle: const Text(
                    'Show numeric keyboard in bottom-left corner',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: useCustomKeyboard,
                  onChanged: (value) {
                    setDialogState(() {
                      useCustomKeyboard = value;
                      if (value) {
                        disableAutoFocus = true; // Custom keyboard implies disabling system keyboard
                      }
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Disable Copy/Paste'),
                  subtitle: const Text(
                    'Prevent copying and pasting in input fields',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: disableCopyPaste,
                  onChanged: (value) {
                    setDialogState(() {
                      disableCopyPaste = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      var url = urlController.text.trim();
      var iconUrl = iconUrlController.text.trim();

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

      // Auto-generate icon URL if not provided
      if (iconUrl.isEmpty) {
        try {
          final uri = Uri.parse(url);
          iconUrl = 'https://www.google.com/s2/favicons?domain=${uri.host}&sz=128';
        } catch (e) {
          iconUrl = 'https://www.google.com/s2/favicons?domain=$url&sz=128';
        }
      }

      // Create the shortcut item
      final shortcut = ShortcutItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        url: url,
        iconUrl: iconUrl,
        disableAutoFocus: disableAutoFocus,
        useCustomKeyboard: useCustomKeyboard,
        disableCopyPaste: disableCopyPaste,
      );

      // Add to list and save
      setState(() {
        _shortcuts.add(shortcut);
      });
      await _saveShortcuts();

      // Create home screen shortcut
      await _createHomeScreenShortcut(shortcut);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shortcut "$name" added!')),
        );
      }
    }
  }

  Future<void> _createHomeScreenShortcut(ShortcutItem shortcut) async {
    try {
      await platform.invokeMethod('createShortcut', {
        'shortcutId': 'webkiosk_${shortcut.id}',
        'name': shortcut.name,
        'url': shortcut.url,
        'iconUrl': shortcut.iconUrl,
        'disableAutoFocus': shortcut.disableAutoFocus,
        'useCustomKeyboard': shortcut.useCustomKeyboard,
        'disableCopyPaste': shortcut.disableCopyPaste,
      });
    } catch (e) {
      debugPrint('Error creating home screen shortcut: $e');
    }
  }

  Future<void> _deleteHomeScreenShortcut(ShortcutItem shortcut) async {
    try {
      await platform.invokeMethod('deleteShortcut', {
        'shortcutId': 'webkiosk_${shortcut.id}',
      });
    } catch (e) {
      debugPrint('Error deleting home screen shortcut: $e');
    }
  }

  Future<void> _deleteShortcut(ShortcutItem shortcut) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shortcut'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${shortcut.name}"?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Important: You must manually remove the shortcut from your home screen. Android does not allow apps to delete home screen shortcuts.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Delete from home screen first
      await _deleteHomeScreenShortcut(shortcut);
      
      setState(() {
        _shortcuts.removeWhere((s) => s.id == shortcut.id);
      });
      await _saveShortcuts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${shortcut.name}" deleted. Remember to remove the shortcut from your home screen.')),
        );
      }
    }
  }

  void _showShortcutOptions(ShortcutItem shortcut) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(context);
                _openShortcut(shortcut);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_to_home_screen),
              title: const Text('Add to Home Screen'),
              subtitle: const Text('Create another home screen shortcut'),
              onTap: () async {
                Navigator.pop(context);
                await _createHomeScreenShortcut(shortcut);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Home screen shortcut created!')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteShortcut(shortcut);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openShortcut(ShortcutItem shortcut) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KioskWebViewScreen(
          initialUrl: shortcut.url,
          disableAutoFocus: shortcut.disableAutoFocus,
          useCustomKeyboard: shortcut.useCustomKeyboard,
          disableCopyPaste: shortcut.disableCopyPaste,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebKiosk Builder'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shortcuts.isEmpty
              ? _buildEmptyState()
              : _buildShortcutGrid(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addShortcut,
        icon: const Icon(Icons.add),
        label: const Text('Add Shortcut'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.web_rounded,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No shortcuts yet',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first shortcut',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: _shortcuts.length,
        itemBuilder: (context, index) {
          final shortcut = _shortcuts[index];
          return _buildShortcutTile(shortcut);
        },
      ),
    );
  }

  Widget _buildShortcutTile(ShortcutItem shortcut) {
    return GestureDetector(
      onTap: () => _openShortcut(shortcut),
      onLongPress: () => _showShortcutOptions(shortcut),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  shortcut.iconUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.language,
                      size: 40,
                      color: Colors.grey[600],
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                shortcut.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
