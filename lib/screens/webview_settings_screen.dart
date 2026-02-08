import 'package:flutter/material.dart';

class WebViewSettingsScreen extends StatefulWidget {
  final bool useCustomKeyboard;
  final bool disableCopyPaste;
  final Function(bool useCustomKeyboard, bool disableCopyPaste) onSettingsChanged;

  const WebViewSettingsScreen({
    super.key,
    required this.useCustomKeyboard,
    required this.disableCopyPaste,
    required this.onSettingsChanged,
  });

  @override
  State<WebViewSettingsScreen> createState() => _WebViewSettingsScreenState();
}

class _WebViewSettingsScreenState extends State<WebViewSettingsScreen> {
  late bool _useCustomKeyboard;
  late bool _disableCopyPaste;

  @override
  void initState() {
    super.initState();
    _useCustomKeyboard = widget.useCustomKeyboard;
    _disableCopyPaste = widget.disableCopyPaste;
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
                onChanged: (value) {
                  setState(() {
                    _useCustomKeyboard = value;
                  });
                  widget.onSettingsChanged(_useCustomKeyboard, _disableCopyPaste);
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
                onChanged: (value) {
                  setState(() {
                    _disableCopyPaste = value;
                  });
                  widget.onSettingsChanged(_useCustomKeyboard, _disableCopyPaste);
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
