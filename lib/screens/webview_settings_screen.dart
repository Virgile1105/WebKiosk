import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Paramètres de la vue web',
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
                title: const Text(
                  'Clavier personnalisé',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: const Text(
                  'Afficher le clavier numérique personnalisé dans le coin inférieur gauche',
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
                title: const Text(
                  'Désactiver Copier/Coller',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: const Text(
                  'Empêcher le copier-coller dans les champs de saisie',
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
                title: const Text(
                  'Sons d\'alerte SAP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: const Text(
                  'Activer les sons pour les messages d\'avertissement et d\'erreur SAP',
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
