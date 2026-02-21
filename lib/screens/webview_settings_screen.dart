import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';

class WebViewSettingsScreen extends StatefulWidget {
  final bool useCustomKeyboard;
  final bool disableCopyPaste;
  final bool enableWarningSound;
  final Future<void> Function(bool useCustomKeyboard, bool disableCopyPaste, bool enableWarningSound) onSettingsChanged;

  const WebViewSettingsScreen({
    super.key,
    required this.useCustomKeyboard,
    required this.disableCopyPaste,
    required this.enableWarningSound,
    required this.onSettingsChanged,
  });

  @override
  State<WebViewSettingsScreen> createState() => _WebViewSettingsScreenState();
}

class _WebViewSettingsScreenState extends State<WebViewSettingsScreen> {
  late bool _useCustomKeyboard;
  late bool _disableCopyPaste;
  late bool _enableWarningSound;

  @override
  void initState() {
    super.initState();
    _useCustomKeyboard = widget.useCustomKeyboard;
    _disableCopyPaste = widget.disableCopyPaste;
    _enableWarningSound = widget.enableWarningSound;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.webviewSettings,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color.fromRGBO(51, 61, 71, 1),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: SwitchListTile(
                title: Text(
                  l10n.customKeyboard,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  l10n.customKeyboardDesc,
                  style: TextStyle(fontSize: 14),
                ),
                value: _useCustomKeyboard,
                onChanged: (value) async {
                  setState(() {
                    _useCustomKeyboard = value;
                  });
                  await widget.onSettingsChanged(_useCustomKeyboard, _disableCopyPaste, _enableWarningSound);
                },
                contentPadding: EdgeInsets.zero,
                activeColor: const Color.fromRGBO(51, 61, 71, 1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: SwitchListTile(
                title: Text(
                  l10n.disableCopyPaste,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  l10n.disableCopyPasteDesc,
                  style: TextStyle(fontSize: 14),
                ),
                value: _disableCopyPaste,
                onChanged: (value) async {
                  setState(() {
                    _disableCopyPaste = value;
                  });
                  await widget.onSettingsChanged(_useCustomKeyboard, _disableCopyPaste, _enableWarningSound);
                },
                contentPadding: EdgeInsets.zero,
                activeColor: const Color.fromRGBO(51, 61, 71, 1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: SwitchListTile(
                title: Text(
                  l10n.sapWarningSounds,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  l10n.sapWarningSoundsDesc,
                  style: TextStyle(fontSize: 14),
                ),
                value: _enableWarningSound,
                onChanged: (value) async {
                  setState(() {
                    _enableWarningSound = value;
                  });
                  await widget.onSettingsChanged(_useCustomKeyboard, _disableCopyPaste, _enableWarningSound);
                },
                contentPadding: EdgeInsets.zero,
                activeColor: const Color.fromRGBO(51, 61, 71, 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
