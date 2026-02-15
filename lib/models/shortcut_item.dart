import 'dart:convert';

class ShortcutItem {
  final String id;
  final String name;
  final String url;
  final String iconUrl;
  final bool disableAutoFocus;
  final bool useCustomKeyboard;
  final bool disableCopyPaste;
  final bool enableWarningSound;

  ShortcutItem({
    required this.id,
    required this.name,
    required this.url,
    required this.iconUrl,
    this.disableAutoFocus = false,
    this.useCustomKeyboard = false,
    this.disableCopyPaste = false,
    this.enableWarningSound = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'iconUrl': iconUrl,
    'disableAutoFocus': disableAutoFocus,
    'useCustomKeyboard': useCustomKeyboard,
    'disableCopyPaste': disableCopyPaste,
    'enableWarningSound': enableWarningSound,
  };

  factory ShortcutItem.fromJson(Map<String, dynamic> json) => ShortcutItem(
    id: json['id'] as String,
    name: json['name'] as String,
    url: json['url'] as String,
    iconUrl: json['iconUrl'] as String,
    disableAutoFocus: json['disableAutoFocus'] as bool? ?? false,
    useCustomKeyboard: json['useCustomKeyboard'] as bool? ?? false,
    disableCopyPaste: json['disableCopyPaste'] as bool? ?? false,
    enableWarningSound: json['enableWarningSound'] as bool? ?? false,
  );

  static String encodeList(List<ShortcutItem> items) {
    return jsonEncode(items.map((item) => item.toJson()).toList());
  }

  static List<ShortcutItem> decodeList(String jsonString) {
    if (jsonString.isEmpty) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => ShortcutItem.fromJson(json)).toList();
  }
}
