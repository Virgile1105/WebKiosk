# Device Owner Setup Guide

This guide explains how to set up your DeviceGate app as a Device Owner for kiosk mode functionality.

## Prerequisites

- ADB (Android Debug Bridge) installed on your computer
- USB debugging enabled on your Android device
- Device must be factory reset (for Device Owner setup)
- **Important**: Remove all Google accounts and factory reset the device before proceeding

## Step 1: Prepare Your Device

1. **Factory Reset** your device (Settings > System > Reset > Factory data reset)
2. **Skip** Google account setup during initial configuration
3. Enable **Developer Options**:
   - Go to Settings > About phone
   - Tap "Build number" 7 times
4. Enable **USB Debugging**:
   - Go to Settings > Developer options
   - Enable "USB debugging"

## Step 2: Build and Install Your App

1. Connect your device via USB
2. Build and install the app:
   ```bash
   flutter build apk
   flutter install
   ```

3. Note your app's package name: `com.devicegate.app`

## Step 3: Set App as Device Owner

1. **Important**: Do this BEFORE adding any Google accounts

2. Open a terminal/command prompt and run:
   ```bash
   adb shell dpm set-device-owner com.devicegate.app/.MyDeviceAdminReceiver
   ```

3. You should see a success message:
   ```
   Success: Device owner set to package com.devicegate.app
   Active admin set to component {com.devicegate.app/com.devicegate.app.MyDeviceAdminReceiver}
   ```

4. Grant required permissions (optional - app will auto-grant on first launch):
   ```bash
   # For device info access on Android 12+
   adb shell pm grant com.devicegate.app android.permission.BLUETOOTH_CONNECT
   
   # For screen timeout control
   adb shell pm grant com.devicegate.app android.permission.WRITE_SECURE_SETTINGS
   ```
   
   **Note:** DeviceGate automatically grants these permissions on first launch, so this step is optional.

## Step 4: Verify Device Owner Status

1. Launch the DeviceGate app
2. Use the following code in your Flutter app to check device owner status:
   ```dart
   bool isOwner = await isDeviceOwner();
   print('Is Device Owner: $isOwner');
   ```

## Step 5: Enable Kiosk Mode

Once your app is a Device Owner, you can enable kiosk mode programmatically:

```dart
// Enable kiosk mode
bool success = await enableKioskMode();
if (success) {
  print('Kiosk mode enabled!');
} else {
  print('Failed to enable kiosk mode');
}

// Check if currently in kiosk mode
bool inKiosk = await isInKioskMode();
print('In kiosk mode: $inKiosk');

// Disable kiosk mode (for testing)
await disableKioskMode();
```

## Auto-Start on Boot

Your app is now configured to automatically start when the device boots up. The `BootReceiver` will launch your app automatically.

## Troubleshooting

### "Not allowed to set device owner because..."

**Causes**:
- Device has a Google account already added
- Device was not factory reset
- There are other user profiles on the device

**Solution**: Factory reset and try again without adding any accounts first.

### Command not found: adb

**Solution**: Install Android SDK Platform Tools:
- Download from: https://developer.android.com/studio/releases/platform-tools
- Add the folder to your system PATH

### Device unauthorized in adb

**Solution**: 
1. Unplug the device
2. Run `adb kill-server`
3. Plug device back in
4. Accept the "Allow USB debugging" prompt on device
5. Run `adb devices` to verify

### App crashes in kiosk mode

**Solution**: Make sure you have all required permissions in AndroidManifest.xml (already added).

## Removing Device Owner (For Testing)

If you need to remove device owner status:

```bash
adb shell dpm remove-active-admin com.devicegate.app/.MyDeviceAdminReceiver
```

Or factory reset the device.

## Production Deployment

For production kiosk devices:
1. Use Android Enterprise (formerly Android for Work)
2. Use MDM (Mobile Device Management) solutions like:
   - Google Workspace
   - Microsoft Intune
   - VMware Workspace ONE
   - etc.

These tools make it easier to deploy device owner apps at scale without manual ADB commands.
