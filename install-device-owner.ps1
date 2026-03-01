# DeviceGate - Device Owner Installation Script
# This script installs the app and sets it as Device Owner via ADB

Write-Host "DeviceGate Device Owner Installation" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check if device is connected
Write-Host "Checking for connected devices..." -ForegroundColor Yellow
flutter devices

Write-Host ""
Write-Host "Make sure your device/emulator is:" -ForegroundColor Yellow
Write-Host "  1. Connected via ADB" -ForegroundColor White
Write-Host "  2. Freshly reset (no accounts added)" -ForegroundColor White
Write-Host "  3. Not encrypted (or PROVISIONING_SKIP_ENCRYPTION won't work)" -ForegroundColor White
Write-Host ""

$continue = Read-Host "Continue? (y/n)"
if ($continue -ne "y") {
    Write-Host "Installation cancelled." -ForegroundColor Red
    exit
}

# Install the APK
Write-Host ""
Write-Host "Installing DeviceGate APK..." -ForegroundColor Yellow
flutter install

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to install APK!" -ForegroundColor Red
    exit 1
}

Write-Host "APK installed successfully!" -ForegroundColor Green

# Set as Device Owner
Write-Host ""
Write-Host "Setting DeviceGate as Device Owner..." -ForegroundColor Yellow
adb shell dpm set-device-owner com.devicegate.app/.MyDeviceAdminReceiver

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Failed to set Device Owner!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common reasons:" -ForegroundColor Yellow
    Write-Host "  - Device has accounts added (must be factory reset)" -ForegroundColor White
    Write-Host "  - Device is already managed" -ForegroundColor White
    Write-Host "  - Component name is incorrect" -ForegroundColor White
    Write-Host ""
    Write-Host "To fix: Factory reset device and try again" -ForegroundColor Yellow
    exit 1
}

Write-Host "Device Owner set successfully!" -ForegroundColor Green

# Grant required permissions
Write-Host ""
Write-Host "Granting required permissions..." -ForegroundColor Yellow

# Grant BLUETOOTH_CONNECT for device info (Android 12+)
Write-Host "  - BLUETOOTH_CONNECT..." -ForegroundColor White
adb shell pm grant com.devicegate.app android.permission.BLUETOOTH_CONNECT 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "    Granted!" -ForegroundColor Green
} else {
    Write-Host "    Skipped (not needed or app will auto-grant)" -ForegroundColor Gray
}

# Launch the app
Write-Host ""
Write-Host "Launching DeviceGate..." -ForegroundColor Yellow
adb shell am start -n com.devicegate.app/.MainActivity

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "DeviceGate is now running in Device Owner mode." -ForegroundColor Cyan
Write-Host "The app should be in kiosk mode on your device." -ForegroundColor Cyan
Write-Host ""
Write-Host "To remove Device Owner later, use the 'Remove Device Owner' option in Settings." -ForegroundColor Yellow
