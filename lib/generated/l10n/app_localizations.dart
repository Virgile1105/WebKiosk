import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @quit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get quit;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @deviceName.
  ///
  /// In en, this message translates to:
  /// **'Device Name'**
  String get deviceName;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @information.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// No description provided for @infoDesc.
  ///
  /// In en, this message translates to:
  /// **'App and device information'**
  String get infoDesc;

  /// No description provided for @configuration.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get configuration;

  /// No description provided for @configurationDesc.
  ///
  /// In en, this message translates to:
  /// **'Custom display and behavior settings'**
  String get configurationDesc;

  /// No description provided for @addShortcut.
  ///
  /// In en, this message translates to:
  /// **'Add Shortcut'**
  String get addShortcut;

  /// No description provided for @addShortcutDesc.
  ///
  /// In en, this message translates to:
  /// **'Add a new web shortcut'**
  String get addShortcutDesc;

  /// No description provided for @addApps.
  ///
  /// In en, this message translates to:
  /// **'Add Apps'**
  String get addApps;

  /// No description provided for @addAppsDesc.
  ///
  /// In en, this message translates to:
  /// **'Add installed Android apps'**
  String get addAppsDesc;

  /// No description provided for @network.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get network;

  /// No description provided for @networkDesc.
  ///
  /// In en, this message translates to:
  /// **'View network status and settings'**
  String get networkDesc;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get advancedSettings;

  /// No description provided for @advancedSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Developer options and USB settings'**
  String get advancedSettingsDesc;

  /// No description provided for @exitToHome.
  ///
  /// In en, this message translates to:
  /// **'Exit to Home'**
  String get exitToHome;

  /// No description provided for @exitToHomeDesc.
  ///
  /// In en, this message translates to:
  /// **'Return to native Android home'**
  String get exitToHomeDesc;

  /// No description provided for @deviceOwnerMode.
  ///
  /// In en, this message translates to:
  /// **'Device Owner Mode'**
  String get deviceOwnerMode;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'ENABLED'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'DISABLED'**
  String get disabled;

  /// No description provided for @deviceOwnerEnabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Click to remove Device Owner mode'**
  String get deviceOwnerEnabledDesc;

  /// No description provided for @deviceOwnerDisabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Device Owner mode is disabled'**
  String get deviceOwnerDisabledDesc;

  /// No description provided for @removeDeviceOwner.
  ///
  /// In en, this message translates to:
  /// **'Remove Device Owner?'**
  String get removeDeviceOwner;

  /// No description provided for @removeDeviceOwnerWarning.
  ///
  /// In en, this message translates to:
  /// **'This will remove Device Owner privileges. You will no longer be able to:\\n\\n• Control system settings\\n• Prevent uninstallation\\n• Use kiosk mode features\\n\\nContinue?'**
  String get removeDeviceOwnerWarning;

  /// No description provided for @deviceOwnerRemoved.
  ///
  /// In en, this message translates to:
  /// **'Device Owner removed. You can now factory reset.'**
  String get deviceOwnerRemoved;

  /// No description provided for @failedToRemoveDeviceOwner.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove Device Owner'**
  String get failedToRemoveDeviceOwner;

  /// No description provided for @uninstallDeviceGate.
  ///
  /// In en, this message translates to:
  /// **'Uninstall DeviceGate'**
  String get uninstallDeviceGate;

  /// No description provided for @uninstallDeviceGateDesc.
  ///
  /// In en, this message translates to:
  /// **'Uninstall DeviceGate from this device'**
  String get uninstallDeviceGateDesc;

  /// No description provided for @removeDeviceOwnerFirst.
  ///
  /// In en, this message translates to:
  /// **'Remove Device Owner mode first to enable'**
  String get removeDeviceOwnerFirst;

  /// No description provided for @couldNotOpenAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Could not open app settings. Please uninstall manually from Settings.'**
  String get couldNotOpenAppSettings;

  /// No description provided for @factoryDataReset.
  ///
  /// In en, this message translates to:
  /// **'Factory Data Reset'**
  String get factoryDataReset;

  /// No description provided for @factoryDataResetDesc.
  ///
  /// In en, this message translates to:
  /// **'Factory reset this device'**
  String get factoryDataResetDesc;

  /// No description provided for @couldNotOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Could not open settings. Please factory reset manually from Settings.'**
  String get couldNotOpenSettings;

  /// No description provided for @advancedSettingsInfo.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings Information'**
  String get advancedSettingsInfo;

  /// No description provided for @advancedSettingsInfoDesc.
  ///
  /// In en, this message translates to:
  /// **'View system developer and USB settings'**
  String get advancedSettingsInfoDesc;

  /// No description provided for @systemDeveloperSettings.
  ///
  /// In en, this message translates to:
  /// **'System & Developer Settings'**
  String get systemDeveloperSettings;

  /// No description provided for @developerMode.
  ///
  /// In en, this message translates to:
  /// **'Developer Mode'**
  String get developerMode;

  /// No description provided for @usbDebugging.
  ///
  /// In en, this message translates to:
  /// **'USB Debugging'**
  String get usbDebugging;

  /// No description provided for @usbFileTransfer.
  ///
  /// In en, this message translates to:
  /// **'USB File Transfer'**
  String get usbFileTransfer;

  /// No description provided for @locationPermissions.
  ///
  /// In en, this message translates to:
  /// **'Location Permissions'**
  String get locationPermissions;

  /// No description provided for @locationAccess.
  ///
  /// In en, this message translates to:
  /// **'Location Access'**
  String get locationAccess;

  /// No description provided for @allowAllTheTime.
  ///
  /// In en, this message translates to:
  /// **'Allow all the time'**
  String get allowAllTheTime;

  /// No description provided for @usePreciseLocation.
  ///
  /// In en, this message translates to:
  /// **'Use precise location'**
  String get usePreciseLocation;

  /// No description provided for @grantLocationPermissions.
  ///
  /// In en, this message translates to:
  /// **'Grant Location Permissions'**
  String get grantLocationPermissions;

  /// No description provided for @locationPermissionsGranted.
  ///
  /// In en, this message translates to:
  /// **'All location permissions have been granted successfully.'**
  String get locationPermissionsGranted;

  /// No description provided for @pleaseEnterNameAndUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name and URL'**
  String get pleaseEnterNameAndUrl;

  /// No description provided for @advancedOptions.
  ///
  /// In en, this message translates to:
  /// **'Advanced Options'**
  String get advancedOptions;

  /// No description provided for @disableKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Disable Keyboard'**
  String get disableKeyboard;

  /// No description provided for @disableKeyboardDesc.
  ///
  /// In en, this message translates to:
  /// **'Prevent keyboard from appearing on input fields'**
  String get disableKeyboardDesc;

  /// No description provided for @useCustomKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Use Custom Keyboard'**
  String get useCustomKeyboard;

  /// No description provided for @useCustomKeyboardDesc.
  ///
  /// In en, this message translates to:
  /// **'Show numeric keyboard in bottom-left corner (autofocus can be controlled separately)'**
  String get useCustomKeyboardDesc;

  /// No description provided for @disableCopyPaste.
  ///
  /// In en, this message translates to:
  /// **'Disable Copy/Paste'**
  String get disableCopyPaste;

  /// No description provided for @disableCopyPasteDesc.
  ///
  /// In en, this message translates to:
  /// **'Prevent copying and pasting in input fields'**
  String get disableCopyPasteDesc;

  /// No description provided for @shortcutName.
  ///
  /// In en, this message translates to:
  /// **'Shortcut Name'**
  String get shortcutName;

  /// No description provided for @iconSource.
  ///
  /// In en, this message translates to:
  /// **'Icon Source:'**
  String get iconSource;

  /// No description provided for @loadingApps.
  ///
  /// In en, this message translates to:
  /// **'Loading apps...'**
  String get loadingApps;

  /// No description provided for @noAppsFound.
  ///
  /// In en, this message translates to:
  /// **'No apps found'**
  String get noAppsFound;

  /// No description provided for @addNewShortcut.
  ///
  /// In en, this message translates to:
  /// **'Add New Shortcut'**
  String get addNewShortcut;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @websiteUrl.
  ///
  /// In en, this message translates to:
  /// **'Website URL'**
  String get websiteUrl;

  /// No description provided for @icon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get icon;

  /// No description provided for @iconUrl.
  ///
  /// In en, this message translates to:
  /// **'Icon URL'**
  String get iconUrl;

  /// No description provided for @iconUrlOptional.
  ///
  /// In en, this message translates to:
  /// **'Icon URL (optional)'**
  String get iconUrlOptional;

  /// No description provided for @useUrlBelow.
  ///
  /// In en, this message translates to:
  /// **'Use URL (below)'**
  String get useUrlBelow;

  /// No description provided for @usingAssetIcon.
  ///
  /// In en, this message translates to:
  /// **'Using asset icon'**
  String get usingAssetIcon;

  /// No description provided for @leaveIconUrlEmpty.
  ///
  /// In en, this message translates to:
  /// **'Leave icon URL empty to use the site\'s favicon (or default icon if unavailable).'**
  String get leaveIconUrlEmpty;

  /// No description provided for @usingSelectedAssetIcon.
  ///
  /// In en, this message translates to:
  /// **'Using selected asset icon.'**
  String get usingSelectedAssetIcon;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Google'**
  String get nameHint;

  /// No description provided for @websiteUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://www.google.com'**
  String get websiteUrlHint;

  /// No description provided for @leaveEmptyForAutoDetect.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for auto-detect'**
  String get leaveEmptyForAutoDetect;

  /// No description provided for @checkAppsToAdd.
  ///
  /// In en, this message translates to:
  /// **'Check apps to add to DeviceGate home'**
  String get checkAppsToAdd;

  /// No description provided for @errorSavingShortcut.
  ///
  /// In en, this message translates to:
  /// **'Error saving shortcut'**
  String get errorSavingShortcut;

  /// No description provided for @errorLoadingDeviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Error loading device info'**
  String get errorLoadingDeviceInfo;

  /// No description provided for @couldNotLoadDeviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Could not load device information'**
  String get couldNotLoadDeviceInfo;

  /// No description provided for @errorLoadingApps.
  ///
  /// In en, this message translates to:
  /// **'Error loading apps'**
  String get errorLoadingApps;

  /// No description provided for @couldNotLoadApps.
  ///
  /// In en, this message translates to:
  /// **'Could not load installed applications'**
  String get couldNotLoadApps;

  /// No description provided for @addedToHome.
  ///
  /// In en, this message translates to:
  /// **'added to home'**
  String get addedToHome;

  /// No description provided for @bluetoothDevices.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Devices'**
  String get bluetoothDevices;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// No description provided for @buildNumber.
  ///
  /// In en, this message translates to:
  /// **'Build Number'**
  String get buildNumber;

  /// No description provided for @deviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Device Information'**
  String get deviceInfo;

  /// No description provided for @ipAddress.
  ///
  /// In en, this message translates to:
  /// **'IP Address'**
  String get ipAddress;

  /// No description provided for @productName.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get productName;

  /// No description provided for @androidModel.
  ///
  /// In en, this message translates to:
  /// **'Android Model'**
  String get androidModel;

  /// No description provided for @serialNumber.
  ///
  /// In en, this message translates to:
  /// **'Serial Number'**
  String get serialNumber;

  /// No description provided for @androidVersion.
  ///
  /// In en, this message translates to:
  /// **'Android Version'**
  String get androidVersion;

  /// No description provided for @securityPatch.
  ///
  /// In en, this message translates to:
  /// **'Last Security Update'**
  String get securityPatch;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading'**
  String get errorLoading;

  /// No description provided for @noBluetooth.
  ///
  /// In en, this message translates to:
  /// **'No Bluetooth Devices'**
  String get noBluetooth;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get unexpectedError;

  /// No description provided for @technicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get technicalDetails;

  /// No description provided for @errorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error:'**
  String get errorLabel;

  /// No description provided for @stackTrace.
  ///
  /// In en, this message translates to:
  /// **'Stack Trace:'**
  String get stackTrace;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @configurationError.
  ///
  /// In en, this message translates to:
  /// **'Configuration Error'**
  String get configurationError;

  /// No description provided for @couldNotSaveTopBarSetting.
  ///
  /// In en, this message translates to:
  /// **'Could not save top bar setting'**
  String get couldNotSaveTopBarSetting;

  /// No description provided for @couldNotSaveAutoRotationSetting.
  ///
  /// In en, this message translates to:
  /// **'Could not save auto-rotation setting'**
  String get couldNotSaveAutoRotationSetting;

  /// No description provided for @couldNotSaveScreenTimeout.
  ///
  /// In en, this message translates to:
  /// **'Could not save screen timeout setting'**
  String get couldNotSaveScreenTimeout;

  /// No description provided for @screenTimeout.
  ///
  /// In en, this message translates to:
  /// **'Screen Timeout'**
  String get screenTimeout;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get seconds;

  /// No description provided for @second.
  ///
  /// In en, this message translates to:
  /// **'second'**
  String get second;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutes;

  /// No description provided for @minute.
  ///
  /// In en, this message translates to:
  /// **'minute'**
  String get minute;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get hours;

  /// No description provided for @hour.
  ///
  /// In en, this message translates to:
  /// **'hour'**
  String get hour;

  /// No description provided for @current.
  ///
  /// In en, this message translates to:
  /// **'current'**
  String get current;

  /// No description provided for @currentSystemValue.
  ///
  /// In en, this message translates to:
  /// **'Current system value'**
  String get currentSystemValue;

  /// No description provided for @alwaysShowTopBar.
  ///
  /// In en, this message translates to:
  /// **'Always Show Top Bar'**
  String get alwaysShowTopBar;

  /// No description provided for @alwaysShowTopBarDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep navigation bar visible at all times'**
  String get alwaysShowTopBarDesc;

  /// No description provided for @autoRotation.
  ///
  /// In en, this message translates to:
  /// **'Auto Rotation'**
  String get autoRotation;

  /// No description provided for @autoRotationDesc.
  ///
  /// In en, this message translates to:
  /// **'Allow screen rotation'**
  String get autoRotationDesc;

  /// No description provided for @lockOrientation.
  ///
  /// In en, this message translates to:
  /// **'Lock Orientation'**
  String get lockOrientation;

  /// No description provided for @portrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get portrait;

  /// No description provided for @landscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get landscape;

  /// No description provided for @customDisplaySettings.
  ///
  /// In en, this message translates to:
  /// **'Custom display settings'**
  String get customDisplaySettings;

  /// No description provided for @topBarAlwaysVisible.
  ///
  /// In en, this message translates to:
  /// **'Top bar always visible'**
  String get topBarAlwaysVisible;

  /// No description provided for @topBarShownDesc.
  ///
  /// In en, this message translates to:
  /// **'Android status bar stays always displayed'**
  String get topBarShownDesc;

  /// No description provided for @topBarHiddenDesc.
  ///
  /// In en, this message translates to:
  /// **'Status bar is hidden (swipe down to show)'**
  String get topBarHiddenDesc;

  /// No description provided for @screenRotatesAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Screen rotates automatically based on orientation'**
  String get screenRotatesAutomatically;

  /// No description provided for @lockedIn.
  ///
  /// In en, this message translates to:
  /// **'Locked in {orientation}'**
  String lockedIn(Object orientation);

  /// No description provided for @currently.
  ///
  /// In en, this message translates to:
  /// **'Currently: {value}'**
  String currently(Object value);

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @fifteenSeconds.
  ///
  /// In en, this message translates to:
  /// **'15 seconds'**
  String get fifteenSeconds;

  /// No description provided for @thirtySeconds.
  ///
  /// In en, this message translates to:
  /// **'30 seconds'**
  String get thirtySeconds;

  /// No description provided for @oneMinute.
  ///
  /// In en, this message translates to:
  /// **'1 minute'**
  String get oneMinute;

  /// No description provided for @twoMinutes.
  ///
  /// In en, this message translates to:
  /// **'2 minutes'**
  String get twoMinutes;

  /// No description provided for @fiveMinutes.
  ///
  /// In en, this message translates to:
  /// **'5 minutes'**
  String get fiveMinutes;

  /// No description provided for @tenMinutes.
  ///
  /// In en, this message translates to:
  /// **'10 minutes'**
  String get tenMinutes;

  /// No description provided for @thirtyMinutes.
  ///
  /// In en, this message translates to:
  /// **'30 minutes'**
  String get thirtyMinutes;

  /// No description provided for @passwordProtection.
  ///
  /// In en, this message translates to:
  /// **'Password Protection'**
  String get passwordProtection;

  /// No description provided for @passwordProtectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Require password to access settings'**
  String get passwordProtectionDesc;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get enterPassword;

  /// No description provided for @incorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get incorrectPassword;

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts.\nTry again in {minutes}min {seconds}s'**
  String tooManyAttempts(Object minutes, Object seconds);

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordMismatch;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get passwordChanged;

  /// No description provided for @networkStatus.
  ///
  /// In en, this message translates to:
  /// **'Network Status'**
  String get networkStatus;

  /// No description provided for @wifiStatus.
  ///
  /// In en, this message translates to:
  /// **'WiFi Status'**
  String get wifiStatus;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @noWifiConnection.
  ///
  /// In en, this message translates to:
  /// **'No WiFi connection'**
  String get noWifiConnection;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @signalStrength.
  ///
  /// In en, this message translates to:
  /// **'Signal Strength'**
  String get signalStrength;

  /// No description provided for @speedTest.
  ///
  /// In en, this message translates to:
  /// **'Speed Test'**
  String get speedTest;

  /// No description provided for @runSpeedTest.
  ///
  /// In en, this message translates to:
  /// **'Run Speed Test'**
  String get runSpeedTest;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @resetInternet.
  ///
  /// In en, this message translates to:
  /// **'Reset Internet'**
  String get resetInternet;

  /// No description provided for @resettingInternet.
  ///
  /// In en, this message translates to:
  /// **'Resetting...'**
  String get resettingInternet;

  /// No description provided for @internetResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to reset Internet: {error}'**
  String internetResetFailed(Object error);

  /// No description provided for @savedNetworks.
  ///
  /// In en, this message translates to:
  /// **'Saved Networks'**
  String get savedNetworks;

  /// No description provided for @forget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get forget;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @initializationError.
  ///
  /// In en, this message translates to:
  /// **'Initialization Error'**
  String get initializationError;

  /// No description provided for @errorSavingName.
  ///
  /// In en, this message translates to:
  /// **'Error saving name: {error}'**
  String errorSavingName(Object error);

  /// No description provided for @errorSavingIcon.
  ///
  /// In en, this message translates to:
  /// **'Error saving icon: {error}'**
  String errorSavingIcon(Object error);

  /// No description provided for @createHomeShortcut.
  ///
  /// In en, this message translates to:
  /// **'Create Home Screen Shortcut'**
  String get createHomeShortcut;

  /// No description provided for @changeAppName.
  ///
  /// In en, this message translates to:
  /// **'Change App Name'**
  String get changeAppName;

  /// No description provided for @changeAppIcon.
  ///
  /// In en, this message translates to:
  /// **'Change App Icon'**
  String get changeAppIcon;

  /// No description provided for @keyboardSettings.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Settings'**
  String get keyboardSettings;

  /// No description provided for @resetSettings.
  ///
  /// In en, this message translates to:
  /// **'Reset Settings'**
  String get resetSettings;

  /// No description provided for @systemStatus.
  ///
  /// In en, this message translates to:
  /// **'System Status'**
  String get systemStatus;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get off;

  /// No description provided for @granted.
  ///
  /// In en, this message translates to:
  /// **'GRANTED'**
  String get granted;

  /// No description provided for @denied.
  ///
  /// In en, this message translates to:
  /// **'DENIED'**
  String get denied;

  /// No description provided for @locationPermissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Location permission granted'**
  String get locationPermissionGranted;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get locationPermissionDenied;

  /// No description provided for @backgroundLocationGranted.
  ///
  /// In en, this message translates to:
  /// **'Background location access granted'**
  String get backgroundLocationGranted;

  /// No description provided for @onlyWhileUsingApp.
  ///
  /// In en, this message translates to:
  /// **'Only while using the app'**
  String get onlyWhileUsingApp;

  /// No description provided for @always.
  ///
  /// In en, this message translates to:
  /// **'ALWAYS'**
  String get always;

  /// No description provided for @limited.
  ///
  /// In en, this message translates to:
  /// **'LIMITED'**
  String get limited;

  /// No description provided for @preciseGpsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Precise GPS location enabled'**
  String get preciseGpsEnabled;

  /// No description provided for @approximateLocationOnly.
  ///
  /// In en, this message translates to:
  /// **'Approximate location only'**
  String get approximateLocationOnly;

  /// No description provided for @precise.
  ///
  /// In en, this message translates to:
  /// **'PRECISE'**
  String get precise;

  /// No description provided for @approx.
  ///
  /// In en, this message translates to:
  /// **'APPROX'**
  String get approx;

  /// No description provided for @grantLocationPermissionsManually.
  ///
  /// In en, this message translates to:
  /// **'Please grant location permissions manually in Settings'**
  String get grantLocationPermissionsManually;

  /// No description provided for @httpError400Title.
  ///
  /// In en, this message translates to:
  /// **'Bad Request'**
  String get httpError400Title;

  /// No description provided for @httpError401Title.
  ///
  /// In en, this message translates to:
  /// **'Unauthorized'**
  String get httpError401Title;

  /// No description provided for @httpError403Title.
  ///
  /// In en, this message translates to:
  /// **'Access Denied'**
  String get httpError403Title;

  /// No description provided for @httpError404Title.
  ///
  /// In en, this message translates to:
  /// **'Page Not Found'**
  String get httpError404Title;

  /// No description provided for @httpError500Title.
  ///
  /// In en, this message translates to:
  /// **'Internal Server Error'**
  String get httpError500Title;

  /// No description provided for @httpError502Title.
  ///
  /// In en, this message translates to:
  /// **'Bad Gateway'**
  String get httpError502Title;

  /// No description provided for @httpError503Title.
  ///
  /// In en, this message translates to:
  /// **'Service Unavailable'**
  String get httpError503Title;

  /// No description provided for @httpError504Title.
  ///
  /// In en, this message translates to:
  /// **'Gateway Timeout'**
  String get httpError504Title;

  /// No description provided for @httpErrorDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'HTTP Error {statusCode}'**
  String httpErrorDefaultTitle(Object statusCode);

  /// No description provided for @httpError400Desc.
  ///
  /// In en, this message translates to:
  /// **'The server cannot process the request due to a client error.'**
  String get httpError400Desc;

  /// No description provided for @httpError401Desc.
  ///
  /// In en, this message translates to:
  /// **'Authentication is required to access this resource.'**
  String get httpError401Desc;

  /// No description provided for @httpError403Desc.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to access this resource.'**
  String get httpError403Desc;

  /// No description provided for @httpError404Desc.
  ///
  /// In en, this message translates to:
  /// **'The requested page does not exist on the server.'**
  String get httpError404Desc;

  /// No description provided for @httpError500Desc.
  ///
  /// In en, this message translates to:
  /// **'The server encountered an internal error and could not process the request.'**
  String get httpError500Desc;

  /// No description provided for @httpError502Desc.
  ///
  /// In en, this message translates to:
  /// **'The server received an invalid response from the upstream server.'**
  String get httpError502Desc;

  /// No description provided for @httpError503Desc.
  ///
  /// In en, this message translates to:
  /// **'The server is temporarily unavailable, probably under maintenance.'**
  String get httpError503Desc;

  /// No description provided for @httpError504Desc.
  ///
  /// In en, this message translates to:
  /// **'The server did not receive a response in time from the upstream server.'**
  String get httpError504Desc;

  /// No description provided for @httpErrorDefaultDesc.
  ///
  /// In en, this message translates to:
  /// **'The server returned an HTTP error code {statusCode}.'**
  String httpErrorDefaultDesc(Object statusCode);

  /// No description provided for @urlLabel.
  ///
  /// In en, this message translates to:
  /// **'URL:'**
  String get urlLabel;

  /// No description provided for @serverMessage.
  ///
  /// In en, this message translates to:
  /// **'Server message:'**
  String get serverMessage;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @reloadButton.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reloadButton;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @deviceTypeKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get deviceTypeKeyboard;

  /// No description provided for @deviceTypeScanner.
  ///
  /// In en, this message translates to:
  /// **'Scanner'**
  String get deviceTypeScanner;

  /// No description provided for @deviceTypeMouse.
  ///
  /// In en, this message translates to:
  /// **'Mouse'**
  String get deviceTypeMouse;

  /// No description provided for @deviceTypeAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get deviceTypeAudio;

  /// No description provided for @disableAutoFocus.
  ///
  /// In en, this message translates to:
  /// **'Disable Auto Focus'**
  String get disableAutoFocus;

  /// No description provided for @disableAutoFocusDesc.
  ///
  /// In en, this message translates to:
  /// **'Prevent automatic keyboard popup on page load'**
  String get disableAutoFocusDesc;

  /// No description provided for @useCustomKeyboardDesc2.
  ///
  /// In en, this message translates to:
  /// **'Replace system keyboard with custom numeric/alphanumeric keyboard'**
  String get useCustomKeyboardDesc2;

  /// No description provided for @createShortcut.
  ///
  /// In en, this message translates to:
  /// **'Create Shortcut'**
  String get createShortcut;

  /// No description provided for @appNameUpdated.
  ///
  /// In en, this message translates to:
  /// **'App name updated'**
  String get appNameUpdated;

  /// No description provided for @changeIconUrl.
  ///
  /// In en, this message translates to:
  /// **'Change Icon URL'**
  String get changeIconUrl;

  /// No description provided for @svgNotSupported.
  ///
  /// In en, this message translates to:
  /// **'SVG files are not supported. Please use PNG or JPG.'**
  String get svgNotSupported;

  /// No description provided for @iconUrlUpdated.
  ///
  /// In en, this message translates to:
  /// **'Icon URL updated'**
  String get iconUrlUpdated;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get notNow;

  /// No description provided for @pleaseEnterShortcutName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a shortcut name'**
  String get pleaseEnterShortcutName;

  /// No description provided for @pleaseEnterUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a URL'**
  String get pleaseEnterUrl;

  /// No description provided for @shortcutAdded.
  ///
  /// In en, this message translates to:
  /// **'Shortcut \"{name}\" added!'**
  String shortcutAdded(Object name);

  /// No description provided for @failedToCreateShortcut.
  ///
  /// In en, this message translates to:
  /// **'Failed to create shortcut: {error}'**
  String failedToCreateShortcut(Object error);

  /// No description provided for @addToHomeViaChrome.
  ///
  /// In en, this message translates to:
  /// **'Add to Home Screen via Chrome'**
  String get addToHomeViaChrome;

  /// No description provided for @pleaseSetIconUrlFirst.
  ///
  /// In en, this message translates to:
  /// **'Please set an icon URL first'**
  String get pleaseSetIconUrlFirst;

  /// No description provided for @applyingIcon.
  ///
  /// In en, this message translates to:
  /// **'Applying icon...'**
  String get applyingIcon;

  /// No description provided for @iconChanged.
  ///
  /// In en, this message translates to:
  /// **'Icon Changed!'**
  String get iconChanged;

  /// No description provided for @failedToChangeAppIcon.
  ///
  /// In en, this message translates to:
  /// **'Failed to change app icon'**
  String get failedToChangeAppIcon;

  /// No description provided for @keyboardScaleSettings.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Scale Settings'**
  String get keyboardScaleSettings;

  /// No description provided for @openInChrome.
  ///
  /// In en, this message translates to:
  /// **'Open in Chrome'**
  String get openInChrome;

  /// No description provided for @shortcutNameHint.
  ///
  /// In en, this message translates to:
  /// **'My Website'**
  String get shortcutNameHint;

  /// No description provided for @websiteUrlExample.
  ///
  /// In en, this message translates to:
  /// **'https://example.com'**
  String get websiteUrlExample;

  /// No description provided for @iconUrlPngJpg.
  ///
  /// In en, this message translates to:
  /// **'Icon URL (PNG/JPG only)'**
  String get iconUrlPngJpg;

  /// No description provided for @iconUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/icon.png'**
  String get iconUrlHint;

  /// No description provided for @autoDetectFromUrl.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect from URL'**
  String get autoDetectFromUrl;

  /// No description provided for @keyboardOptions.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Options:'**
  String get keyboardOptions;

  /// No description provided for @tipTapMagicWand.
  ///
  /// In en, this message translates to:
  /// **'Tip: Tap the magic wand to auto-detect icon from URL'**
  String get tipTapMagicWand;

  /// No description provided for @appNameLabel.
  ///
  /// In en, this message translates to:
  /// **'App Name'**
  String get appNameLabel;

  /// No description provided for @enterCustomAppName.
  ///
  /// In en, this message translates to:
  /// **'Enter custom app name'**
  String get enterCustomAppName;

  /// No description provided for @onlyPngJpgSupported.
  ///
  /// In en, this message translates to:
  /// **'Only PNG, JPG, GIF, WebP supported.\\nSVG files will NOT work!'**
  String get onlyPngJpgSupported;

  /// No description provided for @suggestedIcons.
  ///
  /// In en, this message translates to:
  /// **'Suggested icons:'**
  String get suggestedIcons;

  /// No description provided for @googleFavicon128.
  ///
  /// In en, this message translates to:
  /// **'Google Favicon (128px) - Recommended'**
  String get googleFavicon128;

  /// No description provided for @googleFavicon64.
  ///
  /// In en, this message translates to:
  /// **'Google Favicon (64px)'**
  String get googleFavicon64;

  /// No description provided for @appleTouchIcon.
  ///
  /// In en, this message translates to:
  /// **'Apple Touch Icon (PNG)'**
  String get appleTouchIcon;

  /// No description provided for @directFavicon.
  ///
  /// In en, this message translates to:
  /// **'Direct favicon.ico'**
  String get directFavicon;

  /// No description provided for @tapSuggestionOrEnter.
  ///
  /// In en, this message translates to:
  /// **'Tap a suggestion to use it, or enter your own PNG/JPG URL.'**
  String get tapSuggestionOrEnter;

  /// No description provided for @createHomeShortcutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Would you like to create a home screen shortcut with the name \"{name}\"?\\n\\nThis will add a new icon to your home screen.'**
  String createHomeShortcutQuestion(Object name);

  /// No description provided for @chromeAddInstructions.
  ///
  /// In en, this message translates to:
  /// **'This will open the website in Chrome. To add a clean shortcut without any badge:'**
  String get chromeAddInstructions;

  /// No description provided for @chromeStep1.
  ///
  /// In en, this message translates to:
  /// **'Tap the menu icon (⋮) in Chrome'**
  String get chromeStep1;

  /// No description provided for @chromeStep2.
  ///
  /// In en, this message translates to:
  /// **'Select \\\"Add to Home screen\\\"'**
  String get chromeStep2;

  /// No description provided for @chromeStep3.
  ///
  /// In en, this message translates to:
  /// **'Enter your desired name'**
  String get chromeStep3;

  /// No description provided for @chromeStep4.
  ///
  /// In en, this message translates to:
  /// **'Tap \\\"Add\\\"'**
  String get chromeStep4;

  /// No description provided for @chromeNoBadgeNote.
  ///
  /// In en, this message translates to:
  /// **'The shortcut will use the website\'s icon without any app badge.'**
  String get chromeNoBadgeNote;

  /// No description provided for @iconChangedDescription.
  ///
  /// In en, this message translates to:
  /// **'The app icon has been updated.\\n\\nNote: The icon change will take effect after you:\\n1. Close the app completely\\n2. Wait a few seconds\\n3. The launcher may need time to update\\n\\nSome launchers require a restart to show the new icon.'**
  String get iconChangedDescription;

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithMessage(Object error);

  /// No description provided for @reloadApp.
  ///
  /// In en, this message translates to:
  /// **'Reload Application'**
  String get reloadApp;

  /// No description provided for @cannotInitializeWebBrowser.
  ///
  /// In en, this message translates to:
  /// **'Cannot initialize web browser'**
  String get cannotInitializeWebBrowser;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network Error'**
  String get networkError;

  /// No description provided for @cannotRetrieveWifiInfo.
  ///
  /// In en, this message translates to:
  /// **'Cannot retrieve WiFi information'**
  String get cannotRetrieveWifiInfo;

  /// No description provided for @speedTestError.
  ///
  /// In en, this message translates to:
  /// **'Speed test error: {error}'**
  String speedTestError(Object error);

  /// No description provided for @internetResetError.
  ///
  /// In en, this message translates to:
  /// **'Failed to reset Internet: {error}'**
  String internetResetError(Object error);

  /// No description provided for @wifiConnection.
  ///
  /// In en, this message translates to:
  /// **'WiFi Connection'**
  String get wifiConnection;

  /// No description provided for @internetStatus.
  ///
  /// In en, this message translates to:
  /// **'Internet Status'**
  String get internetStatus;

  /// No description provided for @internetOk.
  ///
  /// In en, this message translates to:
  /// **'Internet OK'**
  String get internetOk;

  /// No description provided for @websiteError.
  ///
  /// In en, this message translates to:
  /// **'Website Error'**
  String get websiteError;

  /// No description provided for @siteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The site is unavailable'**
  String get siteUnavailable;

  /// No description provided for @noInternet.
  ///
  /// In en, this message translates to:
  /// **'No Internet'**
  String get noInternet;

  /// No description provided for @connectionImpossible.
  ///
  /// In en, this message translates to:
  /// **'Connection impossible'**
  String get connectionImpossible;

  /// No description provided for @internetSpeed.
  ///
  /// In en, this message translates to:
  /// **'Internet\nSpeed'**
  String get internetSpeed;

  /// No description provided for @testInProgress.
  ///
  /// In en, this message translates to:
  /// **'Test in progress...'**
  String get testInProgress;

  /// No description provided for @restartTest.
  ///
  /// In en, this message translates to:
  /// **'Restart test'**
  String get restartTest;

  /// No description provided for @antennaIdentification.
  ///
  /// In en, this message translates to:
  /// **'Antenna/Access Point Identification'**
  String get antennaIdentification;

  /// No description provided for @bssidMacAntenna.
  ///
  /// In en, this message translates to:
  /// **'BSSID (Antenna MAC)'**
  String get bssidMacAntenna;

  /// No description provided for @manufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get manufacturer;

  /// No description provided for @gatewayRouterIp.
  ///
  /// In en, this message translates to:
  /// **'Gateway (Router IP)'**
  String get gatewayRouterIp;

  /// No description provided for @wifiChannel.
  ///
  /// In en, this message translates to:
  /// **'WiFi Channel'**
  String get wifiChannel;

  /// No description provided for @channel.
  ///
  /// In en, this message translates to:
  /// **'Channel {number}'**
  String channel(Object number);

  /// No description provided for @channelWidth.
  ///
  /// In en, this message translates to:
  /// **'Channel Width'**
  String get channelWidth;

  /// No description provided for @band.
  ///
  /// In en, this message translates to:
  /// **'Band'**
  String get band;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @frequencyMhz.
  ///
  /// In en, this message translates to:
  /// **'{frequency} MHz'**
  String frequencyMhz(Object frequency);

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @connectionInfo.
  ///
  /// In en, this message translates to:
  /// **'Connection Information'**
  String get connectionInfo;

  /// No description provided for @wifiStandard.
  ///
  /// In en, this message translates to:
  /// **'WiFi Standard'**
  String get wifiStandard;

  /// No description provided for @currentSpeed.
  ///
  /// In en, this message translates to:
  /// **'Current Speed'**
  String get currentSpeed;

  /// No description provided for @speedMbps.
  ///
  /// In en, this message translates to:
  /// **'{speed} Mbps'**
  String speedMbps(Object speed);

  /// No description provided for @txSpeedUpload.
  ///
  /// In en, this message translates to:
  /// **'TX Speed (Upload)'**
  String get txSpeedUpload;

  /// No description provided for @rxSpeedDownload.
  ///
  /// In en, this message translates to:
  /// **'RX Speed (Download)'**
  String get rxSpeedDownload;

  /// No description provided for @maxSpeed.
  ///
  /// In en, this message translates to:
  /// **'Max Speed'**
  String get maxSpeed;

  /// No description provided for @ipAddressTablet.
  ///
  /// In en, this message translates to:
  /// **'IP Address (Tablet)'**
  String get ipAddressTablet;

  /// No description provided for @dns.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get dns;

  /// No description provided for @displayError.
  ///
  /// In en, this message translates to:
  /// **'Display Error'**
  String get displayError;

  /// No description provided for @excellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get excellent;

  /// No description provided for @good.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get good;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @slow.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get slow;

  /// No description provided for @verySlow.
  ///
  /// In en, this message translates to:
  /// **'Very Slow'**
  String get verySlow;

  /// No description provided for @testing.
  ///
  /// In en, this message translates to:
  /// **'Test...'**
  String get testing;

  /// No description provided for @veryGood.
  ///
  /// In en, this message translates to:
  /// **'Very good'**
  String get veryGood;

  /// No description provided for @fair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get fair;

  /// No description provided for @poor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get poor;

  /// No description provided for @veryPoor.
  ///
  /// In en, this message translates to:
  /// **'Very poor'**
  String get veryPoor;

  /// No description provided for @mbps.
  ///
  /// In en, this message translates to:
  /// **'Mbps'**
  String get mbps;

  /// No description provided for @signal.
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get signal;

  /// No description provided for @loadingError.
  ///
  /// In en, this message translates to:
  /// **'Loading Error'**
  String get loadingError;

  /// No description provided for @cannotLoadAppData.
  ///
  /// In en, this message translates to:
  /// **'Cannot load app data'**
  String get cannotLoadAppData;

  /// No description provided for @saveError.
  ///
  /// In en, this message translates to:
  /// **'Save error: {error}'**
  String saveError(Object error);

  /// No description provided for @selectAppToAdd.
  ///
  /// In en, this message translates to:
  /// **'Select App to Add'**
  String get selectAppToAdd;

  /// No description provided for @deleteShortcut.
  ///
  /// In en, this message translates to:
  /// **'Delete Shortcut'**
  String get deleteShortcut;

  /// No description provided for @confirmDeleteShortcut.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String confirmDeleteShortcut(Object name);

  /// No description provided for @shortcutDeleted.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" deleted'**
  String shortcutDeleted(Object name);

  /// No description provided for @failedToLaunch.
  ///
  /// In en, this message translates to:
  /// **'Failed to launch {name}'**
  String failedToLaunch(Object name);

  /// No description provided for @errorLaunching.
  ///
  /// In en, this message translates to:
  /// **'Error launching {name}: {error}'**
  String errorLaunching(Object error, Object name);

  /// No description provided for @appsAdded.
  ///
  /// In en, this message translates to:
  /// **'{count} app(s) added'**
  String appsAdded(Object count);

  /// No description provided for @appsRemoved.
  ///
  /// In en, this message translates to:
  /// **'{count} app(s) removed'**
  String appsRemoved(Object count);

  /// No description provided for @pleaseEnterValidUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid URL'**
  String get pleaseEnterValidUrl;

  /// No description provided for @enterWebsiteUrlToBegin.
  ///
  /// In en, this message translates to:
  /// **'Enter a website URL to begin'**
  String get enterWebsiteUrlToBegin;

  /// No description provided for @urlExampleHint.
  ///
  /// In en, this message translates to:
  /// **'example.com or https://example.com'**
  String get urlExampleHint;

  /// No description provided for @openWebsite.
  ///
  /// In en, this message translates to:
  /// **'Open Website'**
  String get openWebsite;

  /// No description provided for @webviewSettings.
  ///
  /// In en, this message translates to:
  /// **'Webview Settings'**
  String get webviewSettings;

  /// No description provided for @customKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Custom Keyboard'**
  String get customKeyboard;

  /// No description provided for @customKeyboardDesc.
  ///
  /// In en, this message translates to:
  /// **'Show numeric custom keyboard in bottom-left corner'**
  String get customKeyboardDesc;

  /// No description provided for @sapWarningSounds.
  ///
  /// In en, this message translates to:
  /// **'SAP Warning Sounds'**
  String get sapWarningSounds;

  /// No description provided for @sapWarningSoundsDesc.
  ///
  /// In en, this message translates to:
  /// **'Enable sounds for SAP warning and error messages'**
  String get sapWarningSoundsDesc;

  /// No description provided for @startupError.
  ///
  /// In en, this message translates to:
  /// **'Startup Error'**
  String get startupError;

  /// No description provided for @startupErrorDesc.
  ///
  /// In en, this message translates to:
  /// **'The application could not start correctly'**
  String get startupErrorDesc;

  /// No description provided for @unhandledError.
  ///
  /// In en, this message translates to:
  /// **'Unhandled Error'**
  String get unhandledError;

  /// No description provided for @serverRefused.
  ///
  /// In en, this message translates to:
  /// **'Server refused'**
  String get serverRefused;

  /// No description provided for @serverTimeout.
  ///
  /// In en, this message translates to:
  /// **'Server timeout'**
  String get serverTimeout;

  /// No description provided for @serverProblem.
  ///
  /// In en, this message translates to:
  /// **'Server problem'**
  String get serverProblem;

  /// No description provided for @unknownNetwork.
  ///
  /// In en, this message translates to:
  /// **'Unknown Network'**
  String get unknownNetwork;

  /// No description provided for @signalFormat.
  ///
  /// In en, this message translates to:
  /// **'Signal: {strength}'**
  String signalFormat(Object strength);

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @unknownUrl.
  ///
  /// In en, this message translates to:
  /// **'Unknown URL'**
  String get unknownUrl;

  /// No description provided for @statusFormat.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String statusFormat(Object status);

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get checking;

  /// No description provided for @defaultHomeScreen.
  ///
  /// In en, this message translates to:
  /// **'Default Home Screen'**
  String get defaultHomeScreen;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'NOT SET'**
  String get notSet;

  /// No description provided for @defaultHomeEnabledDesc.
  ///
  /// In en, this message translates to:
  /// **'DeviceGate is set as the default home launcher'**
  String get defaultHomeEnabledDesc;

  /// No description provided for @defaultHomeDisabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap to set DeviceGate as default home'**
  String get defaultHomeDisabledDesc;

  /// No description provided for @tapToChangeDefaultHome.
  ///
  /// In en, this message translates to:
  /// **'Tap to change default home app'**
  String get tapToChangeDefaultHome;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
