# DeviceGate Localization Guide

## Overview

DeviceGate now supports **automatic language detection** based on the device's system language:
- **French** (`fr`) - Full French translation
- **English** (`en`) - Default language (fallback)

The app automatically uses French if the device is set to French, otherwise it defaults to English.

## How it Works

The localization system uses Flutter's official `flutter_localizations` package with ARB (Application Resource Bundle) files.

### Translation Files Location
- **English**: `lib/l10n/app_en.arb`
- **French**: `lib/l10n/app_fr.arb`

### Configuration Files
- `l10n.yaml` - Localization configuration
- `pubspec.yaml` - Includes `flutter_localizations` and `intl` packages  
- `lib/main.dart` - Configured with `AppLocalizations.delegate` and supported locales

## How to Use Translations in Your Code

### 1. Import the localization class

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

### 2. Get the localization instance in your widget

```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  
  return Text(l10n.settings); // Will show "Settings" or "Paramètres"
}
```

### 3. Use localized strings

```dart
// Simple text
Text(l10n.cancel)        // "Cancel" or "Annuler"
Text(l10n.save)          // "Save" or "Enregistrer"
Text(l10n.settings)      // "Settings" or "Paramètres"

// In dialogs
AlertDialog(
  title: Text(l10n.removeDeviceOwner),
  content: Text(l10n.removeDeviceOwnerWarning),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(l10n.cancel),
    ),
  ],
)

// In SnackBars
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(l10n.deviceOwnerRemoved)),
)
```

## Adding New Translations

### Step 1: Add to English file (`lib/l10n/app_en.arb`)

```json
{
  "@@locale": "en",
  ...,
  "myNewText": "My new text",
  "textWith Placeholder": "Hello {name}!",
  "@textWithPlaceholder": {
    "placeholders": {
      "name": {
        "type": "String"
      }
    }
  }
}
```

### Step 2: Add to French file (`lib/l10n/app_fr.arb`)

```json
{
  "@@locale": "fr",
  ...,
  "myNewText": "Mon nouveau texte",
  "textWithPlaceholder": "Bonjour {name} !"
}
```

### Step 3: Regenerate localization files

Run this command in the terminal:
```bash
flutter pub get
```

This automatically generates the `app_localizations.dart` file with your new keys.

### Step 4: Use in your code

```dart
Text(l10n.myNewText)
// Or with placeholders:
Text(l10n.textWithPlaceholder('Alice'))
```

## Current Translation Coverage

The `Advanced Settings` screen has been fully translated as an example. Other screens still contain hardcoded French text that needs to be migrated.

### Screens to Update
- [ ] `shortcut_list_screen.dart`
- [ ] `settings_screen.dart`
- [x] `advanced_settings_screen.dart` ✓ (Done as example)
- [ ] `advanced_settings_info_screen.dart`
- [ ] `configuration_screen.dart`
- [ ] `add_shortcut_screen.dart`
- [ ] `add_apps_screen.dart`
- [ ] `network_status_screen.dart`
- [ ] `info_screen.dart`
- [ ] `webview_settings_screen.dart`
- [ ] `kiosk_webview_screen.dart`
- [ ] `error_page.dart`
- [ ] `password_dialog.dart`

## Available Translation Keys

### Common
- `cancel`, `save`, `ok`, `delete`, `add`, `open`, `clear`
- `retry`, `reload`, `quit`

### Settings Screen
- `settings`, `deviceName`, `info`, `infoDesc`
- `configuration`, `configurationDesc`
- `addShortcut`, `addShortcutDesc`
- `addApps`, `addAppsDesc`
- `network`, `networkDesc`
- `advancedSettings`, `advancedSettingsDesc`
- `exitToHome`, `exitToHomeDesc`

### Advanced Settings
- `deviceOwnerMode`, `enabled`, `disabled`
- `deviceOwnerEnabledDesc`, `deviceOwnerDisabledDesc`
- `removeDeviceOwner`, `removeDeviceOwnerWarning`
- `deviceOwnerRemoved`, `failedToRemoveDeviceOwner`
- `uninstallDeviceGate`, `uninstallDeviceGateDesc`
- `removeDeviceOwnerFirst`
- `couldNotOpenAppSettings`
- `factoryDataReset`, `factoryDataResetDesc`
- `couldNotOpenSettings`
- `advancedSettingsInfo`, `advancedSettingsInfoDesc`

### Advanced Settings Info
- `systemDeveloperSettings`
- `developerMode`, `usbDebugging`, `usbFileTransfer`
- `locationPermissions`, `locationAccess`
- `allowAllTheTime`, `usePreciseLocation`
- `grantLocationPermissions`
- `locationPermissionsGranted`

### Add Shortcut/Apps
- `pleaseEnterNameAndUrl`
- `disableKeyboard`, `disableKeyboardDesc`
- `useCustomKeyboard`, `useCustomKeyboardDesc`
- `disableCopyPaste`, `disableCopyPasteDesc`
- `shortcutName`, `iconSource`
- `loadingApps`, `noAppsFound`

## Testing Languages

### On Device
The app automatically detects the device language. To test:
1. Open Android Settings
2. Go to System → Languages & input → Languages
3. Change to French or English
4. Reopen DeviceGate

### In Development
You can force a specific locale in `main.dart`:
```dart
MaterialApp(
  locale: const Locale('fr', ''), // Force French
  // or
  locale: const Locale('en', ''), // Force English
  ...
)
```

## Best Practices

1. **Always add to both files**: Every key in `app_en.arb` must exist in `app_fr.arb`
2. **Use descriptive keys**: `uninstallDeviceGate` not `text1`
3. **Group related keys**: Keep screen-specific translations together
4. **Run `flutter pub get`** after modifying ARB files
5. **Test both languages** before releasing
6. **Keep logs in English**: Localization is only for UI text, not debug logs

## Example: Updating a Screen

Here's how to update `settings_screen.dart`:

**Before:**
```dart
Text('Advanced Settings')
Text('Developer options and USB settings')
```

**After:**
```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  
  return Column(
    children: [
      Text(l10n.advancedSettings),
      Text(l10n.advancedSettingsDesc),
    ],
  );
}
```

## Notes

- The system automatically falls back to English if a French string is missing
- ARB files support special characters and newlines (`\\n`)
- Placeholders use format: `{variableName}`
- All generated code is in `.dart_tool/flutter_gen/gen_l10n/`
- Never edit generated files manually - they're recreated on `flutter pub get`
