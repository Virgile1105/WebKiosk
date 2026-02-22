// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Delete';

  @override
  String get add => 'Add';

  @override
  String get open => 'Open';

  @override
  String get clear => 'Clear';

  @override
  String get retry => 'Retry';

  @override
  String get reload => 'Reload';

  @override
  String get quit => 'Quit';

  @override
  String get settings => 'Settings';

  @override
  String get deviceName => 'Device Name';

  @override
  String get info => 'Info';

  @override
  String get information => 'Information';

  @override
  String get infoDesc => 'App and device information';

  @override
  String get configuration => 'Configuration';

  @override
  String get configurationDesc => 'Custom display and behavior settings';

  @override
  String get addShortcut => 'Add Shortcut';

  @override
  String get addShortcutDesc => 'Add a new web shortcut';

  @override
  String get addApps => 'Add Apps';

  @override
  String get addAppsDesc => 'Add installed Android apps';

  @override
  String get network => 'Network';

  @override
  String get networkDesc => 'View network status and settings';

  @override
  String get advancedSettings => 'Advanced Settings';

  @override
  String get advancedSettingsDesc => 'Developer options and USB settings';

  @override
  String get exitToHome => 'Exit to Home';

  @override
  String get exitToHomeDesc => 'Return to native Android home';

  @override
  String get deviceOwnerMode => 'Device Owner Mode';

  @override
  String get enabled => 'ENABLED';

  @override
  String get disabled => 'DISABLED';

  @override
  String get deviceOwnerEnabledDesc => 'Click to remove Device Owner mode';

  @override
  String get deviceOwnerDisabledDesc => 'Device Owner mode is disabled';

  @override
  String get removeDeviceOwner => 'Remove Device Owner?';

  @override
  String get removeDeviceOwnerWarning =>
      'This will remove Device Owner privileges. You will no longer be able to:\\n\\n• Control system settings\\n• Prevent uninstallation\\n• Use kiosk mode features\\n\\nContinue?';

  @override
  String get deviceOwnerRemoved =>
      'Device Owner removed. You can now factory reset.';

  @override
  String get failedToRemoveDeviceOwner => 'Failed to remove Device Owner';

  @override
  String get uninstallDeviceGate => 'Uninstall DeviceGate';

  @override
  String get uninstallDeviceGateDesc => 'Uninstall DeviceGate from this device';

  @override
  String get removeDeviceOwnerFirst =>
      'Remove Device Owner mode first to enable';

  @override
  String get couldNotOpenAppSettings =>
      'Could not open app settings. Please uninstall manually from Settings.';

  @override
  String get factoryDataReset => 'Factory Data Reset';

  @override
  String get factoryDataResetDesc => 'Factory reset this device';

  @override
  String get couldNotOpenSettings =>
      'Could not open settings. Please factory reset manually from Settings.';

  @override
  String get advancedSettingsInfo => 'Advanced Settings Information';

  @override
  String get advancedSettingsInfoDesc =>
      'View system developer and USB settings';

  @override
  String get systemDeveloperSettings => 'System & Developer Settings';

  @override
  String get developerMode => 'Developer Mode';

  @override
  String get usbDebugging => 'USB Debugging';

  @override
  String get usbFileTransfer => 'USB File Transfer';

  @override
  String get locationPermissions => 'Location Permissions';

  @override
  String get locationAccess => 'Location Access';

  @override
  String get allowAllTheTime => 'Allow all the time';

  @override
  String get usePreciseLocation => 'Use precise location';

  @override
  String get grantLocationPermissions => 'Grant Location Permissions';

  @override
  String get locationPermissionsGranted =>
      'All location permissions have been granted successfully.';

  @override
  String get pleaseEnterNameAndUrl => 'Please enter a name and URL';

  @override
  String get advancedOptions => 'Advanced Options';

  @override
  String get disableKeyboard => 'Disable Keyboard';

  @override
  String get disableKeyboardDesc =>
      'Prevent keyboard from appearing on input fields';

  @override
  String get useCustomKeyboard => 'Use Custom Keyboard';

  @override
  String get useCustomKeyboardDesc =>
      'Show numeric keyboard in bottom-left corner (autofocus can be controlled separately)';

  @override
  String get disableCopyPaste => 'Disable Copy/Paste';

  @override
  String get disableCopyPasteDesc =>
      'Prevent copying and pasting in input fields';

  @override
  String get shortcutName => 'Shortcut Name';

  @override
  String get iconSource => 'Icon Source:';

  @override
  String get loadingApps => 'Loading apps...';

  @override
  String get noAppsFound => 'No apps found';

  @override
  String get addNewShortcut => 'Add New Shortcut';

  @override
  String get name => 'Name';

  @override
  String get websiteUrl => 'Website URL';

  @override
  String get icon => 'Icon';

  @override
  String get iconUrl => 'Icon URL';

  @override
  String get iconUrlOptional => 'Icon URL (optional)';

  @override
  String get useUrlBelow => 'Use URL (below)';

  @override
  String get usingAssetIcon => 'Using asset icon';

  @override
  String get leaveIconUrlEmpty =>
      'Leave icon URL empty to use the site\'s favicon (or default icon if unavailable).';

  @override
  String get usingSelectedAssetIcon => 'Using selected asset icon.';

  @override
  String get nameHint => 'e.g., Google';

  @override
  String get websiteUrlHint => 'https://www.google.com';

  @override
  String get leaveEmptyForAutoDetect => 'Leave empty for auto-detect';

  @override
  String get checkAppsToAdd => 'Check apps to add to DeviceGate home';

  @override
  String get errorSavingShortcut => 'Error saving shortcut';

  @override
  String get errorLoadingDeviceInfo => 'Error loading device info';

  @override
  String get couldNotLoadDeviceInfo => 'Could not load device information';

  @override
  String get errorLoadingApps => 'Error loading apps';

  @override
  String get couldNotLoadApps => 'Could not load installed applications';

  @override
  String get addedToHome => 'added to home';

  @override
  String get bluetoothDevices => 'Bluetooth Devices';

  @override
  String get appVersion => 'App Version';

  @override
  String get buildNumber => 'Build Number';

  @override
  String get deviceInfo => 'Device Information';

  @override
  String get ipAddress => 'IP Address';

  @override
  String get productName => 'Product Name';

  @override
  String get androidModel => 'Android Model';

  @override
  String get serialNumber => 'Serial Number';

  @override
  String get androidVersion => 'Android Version';

  @override
  String get securityPatch => 'Last Security Update';

  @override
  String get notAvailable => 'Not available';

  @override
  String get errorLoading => 'Error loading';

  @override
  String get noBluetooth => 'No Bluetooth Devices';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get unexpectedError => 'An unexpected error occurred';

  @override
  String get technicalDetails => 'Technical details';

  @override
  String get errorLabel => 'Error:';

  @override
  String get stackTrace => 'Stack Trace:';

  @override
  String get version => 'Version';

  @override
  String get configurationError => 'Configuration Error';

  @override
  String get couldNotSaveTopBarSetting => 'Could not save top bar setting';

  @override
  String get couldNotSaveAutoRotationSetting =>
      'Could not save auto-rotation setting';

  @override
  String get couldNotSaveScreenTimeout =>
      'Could not save screen timeout setting';

  @override
  String get screenTimeout => 'Screen Timeout';

  @override
  String get never => 'Never';

  @override
  String get seconds => 'seconds';

  @override
  String get second => 'second';

  @override
  String get minutes => 'minutes';

  @override
  String get minute => 'minute';

  @override
  String get hours => 'hours';

  @override
  String get hour => 'hour';

  @override
  String get current => 'current';

  @override
  String get currentSystemValue => 'Current system value';

  @override
  String get alwaysShowTopBar => 'Always Show Top Bar';

  @override
  String get alwaysShowTopBarDesc => 'Keep navigation bar visible at all times';

  @override
  String get autoRotation => 'Auto Rotation';

  @override
  String get autoRotationDesc => 'Allow screen rotation';

  @override
  String get lockOrientation => 'Lock Orientation';

  @override
  String get portrait => 'Portrait';

  @override
  String get landscape => 'Landscape';

  @override
  String get customDisplaySettings => 'Custom display settings';

  @override
  String get topBarAlwaysVisible => 'Top bar always visible';

  @override
  String get topBarShownDesc => 'Android status bar stays always displayed';

  @override
  String get topBarHiddenDesc => 'Status bar is hidden (swipe down to show)';

  @override
  String get screenRotatesAutomatically =>
      'Screen rotates automatically based on orientation';

  @override
  String lockedIn(Object orientation) {
    return 'Locked in $orientation';
  }

  @override
  String currently(Object value) {
    return 'Currently: $value';
  }

  @override
  String get cancelButton => 'Cancel';

  @override
  String get fifteenSeconds => '15 seconds';

  @override
  String get thirtySeconds => '30 seconds';

  @override
  String get oneMinute => '1 minute';

  @override
  String get twoMinutes => '2 minutes';

  @override
  String get fiveMinutes => '5 minutes';

  @override
  String get tenMinutes => '10 minutes';

  @override
  String get thirtyMinutes => '30 minutes';

  @override
  String get passwordProtection => 'Password Protection';

  @override
  String get passwordProtectionDesc => 'Require password to access settings';

  @override
  String get changePassword => 'Change Password';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get newPassword => 'New Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get enterPassword => 'Enter password';

  @override
  String get incorrectPassword => 'Incorrect password';

  @override
  String tooManyAttempts(Object minutes, Object seconds) {
    return 'Too many failed attempts.\nTry again in ${minutes}min ${seconds}s';
  }

  @override
  String get passwordMismatch => 'Passwords do not match';

  @override
  String get passwordChanged => 'Password changed successfully';

  @override
  String get networkStatus => 'Network Status';

  @override
  String get wifiStatus => 'WiFi Status';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get noWifiConnection => 'No WiFi connection';

  @override
  String get active => 'Active';

  @override
  String get signalStrength => 'Signal Strength';

  @override
  String get speedTest => 'Speed Test';

  @override
  String get runSpeedTest => 'Run Speed Test';

  @override
  String get download => 'Download';

  @override
  String get upload => 'Upload';

  @override
  String get resetInternet => 'Reset Internet';

  @override
  String get resettingInternet => 'Resetting...';

  @override
  String internetResetFailed(Object error) {
    return 'Failed to reset Internet: $error';
  }

  @override
  String get savedNetworks => 'Saved Networks';

  @override
  String get forget => 'Forget';

  @override
  String get connect => 'Connect';

  @override
  String get initializationError => 'Initialization Error';

  @override
  String errorSavingName(Object error) {
    return 'Error saving name: $error';
  }

  @override
  String errorSavingIcon(Object error) {
    return 'Error saving icon: $error';
  }

  @override
  String get createHomeShortcut => 'Create Home Screen Shortcut';

  @override
  String get changeAppName => 'Change App Name';

  @override
  String get changeAppIcon => 'Change App Icon';

  @override
  String get keyboardSettings => 'Keyboard Settings';

  @override
  String get resetSettings => 'Reset Settings';

  @override
  String get systemStatus => 'System Status';

  @override
  String get on => 'ON';

  @override
  String get off => 'OFF';

  @override
  String get granted => 'GRANTED';

  @override
  String get denied => 'DENIED';

  @override
  String get locationPermissionGranted => 'Location permission granted';

  @override
  String get locationPermissionDenied => 'Location permission denied';

  @override
  String get backgroundLocationGranted => 'Background location access granted';

  @override
  String get onlyWhileUsingApp => 'Only while using the app';

  @override
  String get always => 'ALWAYS';

  @override
  String get limited => 'LIMITED';

  @override
  String get preciseGpsEnabled => 'Precise GPS location enabled';

  @override
  String get approximateLocationOnly => 'Approximate location only';

  @override
  String get precise => 'PRECISE';

  @override
  String get approx => 'APPROX';

  @override
  String get grantLocationPermissionsManually =>
      'Please grant location permissions manually in Settings';

  @override
  String get httpError400Title => 'Bad Request';

  @override
  String get httpError401Title => 'Unauthorized';

  @override
  String get httpError403Title => 'Access Denied';

  @override
  String get httpError404Title => 'Page Not Found';

  @override
  String get httpError500Title => 'Internal Server Error';

  @override
  String get httpError502Title => 'Bad Gateway';

  @override
  String get httpError503Title => 'Service Unavailable';

  @override
  String get httpError504Title => 'Gateway Timeout';

  @override
  String httpErrorDefaultTitle(Object statusCode) {
    return 'HTTP Error $statusCode';
  }

  @override
  String get httpError400Desc =>
      'The server cannot process the request due to a client error.';

  @override
  String get httpError401Desc =>
      'Authentication is required to access this resource.';

  @override
  String get httpError403Desc =>
      'You do not have permission to access this resource.';

  @override
  String get httpError404Desc =>
      'The requested page does not exist on the server.';

  @override
  String get httpError500Desc =>
      'The server encountered an internal error and could not process the request.';

  @override
  String get httpError502Desc =>
      'The server received an invalid response from the upstream server.';

  @override
  String get httpError503Desc =>
      'The server is temporarily unavailable, probably under maintenance.';

  @override
  String get httpError504Desc =>
      'The server did not receive a response in time from the upstream server.';

  @override
  String httpErrorDefaultDesc(Object statusCode) {
    return 'The server returned an HTTP error code $statusCode.';
  }

  @override
  String get urlLabel => 'URL:';

  @override
  String get serverMessage => 'Server message:';

  @override
  String get retryButton => 'Retry';

  @override
  String get reloadButton => 'Reload';

  @override
  String get unknown => 'Unknown';

  @override
  String get deviceTypeKeyboard => 'Keyboard';

  @override
  String get deviceTypeScanner => 'Scanner';

  @override
  String get deviceTypeMouse => 'Mouse';

  @override
  String get deviceTypeAudio => 'Audio';

  @override
  String get disableAutoFocus => 'Disable Auto Focus';

  @override
  String get disableAutoFocusDesc =>
      'Prevent automatic keyboard popup on page load';

  @override
  String get useCustomKeyboardDesc2 =>
      'Replace system keyboard with custom numeric/alphanumeric keyboard';

  @override
  String get createShortcut => 'Create Shortcut';

  @override
  String get appNameUpdated => 'App name updated';

  @override
  String get changeIconUrl => 'Change Icon URL';

  @override
  String get svgNotSupported =>
      'SVG files are not supported. Please use PNG or JPG.';

  @override
  String get iconUrlUpdated => 'Icon URL updated';

  @override
  String get notNow => 'Not Now';

  @override
  String get pleaseEnterShortcutName => 'Please enter a shortcut name';

  @override
  String get pleaseEnterUrl => 'Please enter a URL';

  @override
  String shortcutAdded(Object name) {
    return 'Shortcut \"$name\" added!';
  }

  @override
  String failedToCreateShortcut(Object error) {
    return 'Failed to create shortcut: $error';
  }

  @override
  String get addToHomeViaChrome => 'Add to Home Screen via Chrome';

  @override
  String get pleaseSetIconUrlFirst => 'Please set an icon URL first';

  @override
  String get applyingIcon => 'Applying icon...';

  @override
  String get iconChanged => 'Icon Changed!';

  @override
  String get failedToChangeAppIcon => 'Failed to change app icon';

  @override
  String get keyboardScaleSettings => 'Keyboard Scale Settings';

  @override
  String get openInChrome => 'Open in Chrome';

  @override
  String get shortcutNameHint => 'My Website';

  @override
  String get websiteUrlExample => 'https://example.com';

  @override
  String get iconUrlPngJpg => 'Icon URL (PNG/JPG only)';

  @override
  String get iconUrlHint => 'https://example.com/icon.png';

  @override
  String get autoDetectFromUrl => 'Auto-detect from URL';

  @override
  String get keyboardOptions => 'Keyboard Options:';

  @override
  String get tipTapMagicWand =>
      'Tip: Tap the magic wand to auto-detect icon from URL';

  @override
  String get appNameLabel => 'App Name';

  @override
  String get enterCustomAppName => 'Enter custom app name';

  @override
  String get onlyPngJpgSupported =>
      'Only PNG, JPG, GIF, WebP supported.\\nSVG files will NOT work!';

  @override
  String get suggestedIcons => 'Suggested icons:';

  @override
  String get googleFavicon128 => 'Google Favicon (128px) - Recommended';

  @override
  String get googleFavicon64 => 'Google Favicon (64px)';

  @override
  String get appleTouchIcon => 'Apple Touch Icon (PNG)';

  @override
  String get directFavicon => 'Direct favicon.ico';

  @override
  String get tapSuggestionOrEnter =>
      'Tap a suggestion to use it, or enter your own PNG/JPG URL.';

  @override
  String createHomeShortcutQuestion(Object name) {
    return 'Would you like to create a home screen shortcut with the name \"$name\"?\\n\\nThis will add a new icon to your home screen.';
  }

  @override
  String get chromeAddInstructions =>
      'This will open the website in Chrome. To add a clean shortcut without any badge:';

  @override
  String get chromeStep1 => 'Tap the menu icon (⋮) in Chrome';

  @override
  String get chromeStep2 => 'Select \\\"Add to Home screen\\\"';

  @override
  String get chromeStep3 => 'Enter your desired name';

  @override
  String get chromeStep4 => 'Tap \\\"Add\\\"';

  @override
  String get chromeNoBadgeNote =>
      'The shortcut will use the website\'s icon without any app badge.';

  @override
  String get iconChangedDescription =>
      'The app icon has been updated.\\n\\nNote: The icon change will take effect after you:\\n1. Close the app completely\\n2. Wait a few seconds\\n3. The launcher may need time to update\\n\\nSome launchers require a restart to show the new icon.';

  @override
  String errorWithMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get reloadApp => 'Reload Application';

  @override
  String get cannotInitializeWebBrowser => 'Cannot initialize web browser';

  @override
  String get networkError => 'Network Error';

  @override
  String get cannotRetrieveWifiInfo => 'Cannot retrieve WiFi information';

  @override
  String speedTestError(Object error) {
    return 'Speed test error: $error';
  }

  @override
  String internetResetError(Object error) {
    return 'Failed to reset Internet: $error';
  }

  @override
  String get wifiConnection => 'WiFi Connection';

  @override
  String get internetStatus => 'Internet Status';

  @override
  String get internetOk => 'Internet OK';

  @override
  String get websiteError => 'Website Error';

  @override
  String get siteUnavailable => 'The site is unavailable';

  @override
  String get noInternet => 'No Internet';

  @override
  String get connectionImpossible => 'Connection impossible';

  @override
  String get internetSpeed => 'Internet\nSpeed';

  @override
  String get testInProgress => 'Test in progress...';

  @override
  String get restartTest => 'Restart test';

  @override
  String get antennaIdentification => 'Antenna/Access Point Identification';

  @override
  String get bssidMacAntenna => 'BSSID (Antenna MAC)';

  @override
  String get manufacturer => 'Manufacturer';

  @override
  String get gatewayRouterIp => 'Gateway (Router IP)';

  @override
  String get wifiChannel => 'WiFi Channel';

  @override
  String channel(Object number) {
    return 'Channel $number';
  }

  @override
  String get channelWidth => 'Channel Width';

  @override
  String get band => 'Band';

  @override
  String get frequency => 'Frequency';

  @override
  String frequencyMhz(Object frequency) {
    return '$frequency MHz';
  }

  @override
  String get security => 'Security';

  @override
  String get connectionInfo => 'Connection Information';

  @override
  String get wifiStandard => 'WiFi Standard';

  @override
  String get currentSpeed => 'Current Speed';

  @override
  String speedMbps(Object speed) {
    return '$speed Mbps';
  }

  @override
  String get txSpeedUpload => 'TX Speed (Upload)';

  @override
  String get rxSpeedDownload => 'RX Speed (Download)';

  @override
  String get maxSpeed => 'Max Speed';

  @override
  String get ipAddressTablet => 'IP Address (Tablet)';

  @override
  String get dns => 'DNS';

  @override
  String get displayError => 'Display Error';

  @override
  String get excellent => 'Excellent';

  @override
  String get good => 'Good';

  @override
  String get medium => 'Medium';

  @override
  String get slow => 'Slow';

  @override
  String get verySlow => 'Very Slow';

  @override
  String get testing => 'Test...';

  @override
  String get veryGood => 'Very good';

  @override
  String get fair => 'Fair';

  @override
  String get poor => 'Poor';

  @override
  String get veryPoor => 'Very poor';

  @override
  String get mbps => 'Mbps';

  @override
  String get signal => 'Signal';

  @override
  String get loadingError => 'Loading Error';

  @override
  String get cannotLoadAppData => 'Cannot load app data';

  @override
  String saveError(Object error) {
    return 'Save error: $error';
  }

  @override
  String get selectAppToAdd => 'Select App to Add';

  @override
  String get deleteShortcut => 'Delete Shortcut';

  @override
  String confirmDeleteShortcut(Object name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String shortcutDeleted(Object name) {
    return '\"$name\" deleted';
  }

  @override
  String failedToLaunch(Object name) {
    return 'Failed to launch $name';
  }

  @override
  String errorLaunching(Object error, Object name) {
    return 'Error launching $name: $error';
  }

  @override
  String appsAdded(Object count) {
    return '$count app(s) added';
  }

  @override
  String appsRemoved(Object count) {
    return '$count app(s) removed';
  }

  @override
  String get pleaseEnterValidUrl => 'Please enter a valid URL';

  @override
  String get enterWebsiteUrlToBegin => 'Enter a website URL to begin';

  @override
  String get urlExampleHint => 'example.com or https://example.com';

  @override
  String get openWebsite => 'Open Website';

  @override
  String get webviewSettings => 'Webview Settings';

  @override
  String get customKeyboard => 'Custom Keyboard';

  @override
  String get customKeyboardDesc =>
      'Show numeric custom keyboard in bottom-left corner';

  @override
  String get sapWarningSounds => 'SAP Warning Sounds';

  @override
  String get sapWarningSoundsDesc =>
      'Enable sounds for SAP warning and error messages';

  @override
  String get startupError => 'Startup Error';

  @override
  String get startupErrorDesc => 'The application could not start correctly';

  @override
  String get unhandledError => 'Unhandled Error';

  @override
  String get serverRefused => 'Server refused';

  @override
  String get serverTimeout => 'Server timeout';

  @override
  String get serverProblem => 'Server problem';

  @override
  String get unknownNetwork => 'Unknown Network';

  @override
  String signalFormat(Object strength) {
    return 'Signal: $strength';
  }

  @override
  String get unknownError => 'Unknown error';

  @override
  String get unknownUrl => 'Unknown URL';

  @override
  String statusFormat(Object status) {
    return 'Status: $status';
  }

  @override
  String get checking => 'Checking...';
}
