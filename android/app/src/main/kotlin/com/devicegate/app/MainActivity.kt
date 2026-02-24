package com.devicegate.app

import android.Manifest
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.util.Log
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.BroadcastReceiver
import android.content.IntentFilter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import android.content.Intent
import android.content.Context
import android.app.ActivityManager
import android.os.Build
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import android.net.wifi.WifiManager
import kotlin.math.min
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.hardware.usb.UsbManager
import android.os.UserManager
import android.provider.Settings
import android.accounts.AccountManager
import android.net.Uri
import androidx.core.content.FileProvider
import org.json.JSONObject
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    private val CHANNEL = "devicegate.app/shortcut"
    private val BLUETOOTH_EVENT_CHANNEL = "devicegate.app/bluetooth_events"
    private val TAG = "DeviceGate"
    private var methodChannel: MethodChannel? = null
    private var bluetoothEventChannel: EventChannel? = null
    private val bluetoothEventSinks = mutableListOf<EventChannel.EventSink>()
    private var bluetoothReceiver: BroadcastReceiver? = null
    private var pendingUrl: String? = null
    private var urlAlreadyRetrieved = false
    private var devicePolicyManager: DevicePolicyManager? = null
    private var adminComponent: ComponentName? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check for clear device owner flag
        val clearFlag = File("/sdcard/clear_device_owner")
        if (clearFlag.exists()) {
            try {
                val devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                devicePolicyManager.clearDeviceOwnerApp(packageName)
                Log.i(TAG, "Device owner cleared via flag")
                clearFlag.delete()
            } catch (e: Exception) {
                Log.e(TAG, "Error clearing device owner via flag", e)
            }
        }
        
        // Auto-grant necessary permissions if device owner
        grantRequiredPermissions()
        
        // Ensure we're set as default home launcher on every app start
        setAsDefaultHome()
    }
    
    private fun grantRequiredPermissions() {
        try {
            initDevicePolicyManager()
            
            if (!isDeviceOwner()) {
                return
            }
            
            // Auto-grant Bluetooth permissions for device info (Android 12+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    val admin = adminComponent
                    if (admin != null) {
                        val bluetoothConnectState = devicePolicyManager?.getPermissionGrantState(
                            admin,
                            packageName,
                            Manifest.permission.BLUETOOTH_CONNECT
                        )
                        if (bluetoothConnectState != android.app.admin.DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED) {
                            devicePolicyManager?.setPermissionGrantState(
                                admin,
                                packageName,
                                Manifest.permission.BLUETOOTH_CONNECT,
                                android.app.admin.DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED
                            )
                            Log.i(TAG, "BLUETOOTH_CONNECT permission auto-granted on startup")
                        } else {
                            Log.d(TAG, "BLUETOOTH_CONNECT permission already granted")
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error auto-granting BLUETOOTH_CONNECT permission", e)
                }
            }
            
            // Auto-grant READ_PHONE_STATE for serial number access
            try {
                val admin = adminComponent
                if (admin != null) {
                    val phoneStateState = devicePolicyManager?.getPermissionGrantState(
                        admin,
                        packageName,
                        Manifest.permission.READ_PHONE_STATE
                    )
                    if (phoneStateState != android.app.admin.DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED) {
                        devicePolicyManager?.setPermissionGrantState(
                            admin,
                            packageName,
                            Manifest.permission.READ_PHONE_STATE,
                            android.app.admin.DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED
                        )
                        Log.i(TAG, "READ_PHONE_STATE permission auto-granted on startup")
                    } else {
                        Log.d(TAG, "READ_PHONE_STATE permission already granted")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error auto-granting READ_PHONE_STATE permission", e)
            }
            
            // Auto-grant WRITE_SECURE_SETTINGS for screen timeout control
            try {
                if (!hasPermission(Manifest.permission.WRITE_SECURE_SETTINGS)) {
                    val granted = grantPermissionViaShell(Manifest.permission.WRITE_SECURE_SETTINGS)
                    Log.i(TAG, "WRITE_SECURE_SETTINGS permission auto-granted on startup: $granted")
                } else {
                    Log.d(TAG, "WRITE_SECURE_SETTINGS permission already granted")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error auto-granting WRITE_SECURE_SETTINGS permission", e)
            }
            
            // Auto-grant location permissions (Allow all the time + Use precise location)
            try {
                val admin = adminComponent
                if (admin != null) {
                    // Grant fine location (precise location)
                    val fineLocationState = devicePolicyManager?.getPermissionGrantState(
                        admin,
                        packageName,
                        android.Manifest.permission.ACCESS_FINE_LOCATION
                    )
                    if (fineLocationState != android.app.admin.DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED) {
                        devicePolicyManager?.setPermissionGrantState(
                            admin,
                            packageName,
                            android.Manifest.permission.ACCESS_FINE_LOCATION,
                            android.app.admin.DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED
                        )
                        Log.i(TAG, "ACCESS_FINE_LOCATION permission auto-granted on startup")
                    } else {
                        Log.d(TAG, "ACCESS_FINE_LOCATION permission already granted")
                    }
                    
                    // Grant coarse location
                    val coarseLocationState = devicePolicyManager?.getPermissionGrantState(
                        admin,
                        packageName,
                        android.Manifest.permission.ACCESS_COARSE_LOCATION
                    )
                    if (coarseLocationState != android.app.admin.DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED) {
                        devicePolicyManager?.setPermissionGrantState(
                            admin,
                            packageName,
                            android.Manifest.permission.ACCESS_COARSE_LOCATION,
                            android.app.admin.DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED
                        )
                        Log.i(TAG, "ACCESS_COARSE_LOCATION permission auto-granted on startup")
                    } else {
                        Log.d(TAG, "ACCESS_COARSE_LOCATION permission already granted")
                    }
                    
                    // Grant background location (Allow all the time) on Android 10+
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val backgroundLocationState = devicePolicyManager?.getPermissionGrantState(
                            admin,
                            packageName,
                            android.Manifest.permission.ACCESS_BACKGROUND_LOCATION
                        )
                        if (backgroundLocationState != android.app.admin.DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED) {
                            devicePolicyManager?.setPermissionGrantState(
                                admin,
                                packageName,
                                android.Manifest.permission.ACCESS_BACKGROUND_LOCATION,
                                android.app.admin.DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED
                            )
                            Log.i(TAG, "ACCESS_BACKGROUND_LOCATION permission auto-granted on startup (Allow all the time)")
                        } else {
                            Log.d(TAG, "ACCESS_BACKGROUND_LOCATION permission already granted (Allow all the time)")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error auto-granting location permissions", e)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in grantRequiredPermissions", e)
        }
    }
    
    private fun hasPermission(permission: String): Boolean {
        return checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }
    
    private fun grantPermissionViaShell(permission: String): Boolean {
        return try {
            val process = Runtime.getRuntime().exec("pm grant $packageName $permission")
            process.waitFor()
            val exitCode = process.exitValue()
            Log.d(TAG, "Permission grant shell command exit code: $exitCode")
            exitCode == 0
        } catch (e: Exception) {
            Log.e(TAG, "Error executing shell command to grant permission", e)
            false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // Set up Bluetooth EventChannel for status updates
        bluetoothEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, BLUETOOTH_EVENT_CHANNEL)
        bluetoothEventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                events?.let { sink ->
                    bluetoothEventSinks.add(sink)
                    Log.d(TAG, "Bluetooth EventSink added, total: ${bluetoothEventSinks.size}")
                    // Register receiver only once (when first listener connects)
                    if (bluetoothEventSinks.size == 1) {
                        registerBluetoothReceiver()
                    }
                    // Send initial state to this new listener
                    sendBluetoothUpdate()
                }
            }
            
            override fun onCancel(arguments: Any?) {
                // We can't identify which sink cancelled, so we keep using the list
                // The EventChannel framework handles cleanup
                Log.d(TAG, "Bluetooth EventSink onCancel called")
            }
        })
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "changeAppIcon" -> {
                    val iconUrl = call.argument<String>("iconUrl") ?: ""
                    val appName = call.argument<String>("appName") ?: "DeviceGate"
                    
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val success = changeAppIcon(iconUrl, appName)
                            result.success(success)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error changing app icon", e)
                            result.error("ICON_ERROR", e.message, null)
                        }
                    }
                }
                "resetAppIcon" -> {
                    try {
                        resetToDefaultIcon()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("RESET_ERROR", e.message, null)
                    }
                }
                "getUrl" -> {
                    try {
                        // Only return URL once to prevent double processing
                        if (!urlAlreadyRetrieved) {
                            // Check if this is a main app launch (not from shortcut)
                            if (intent.action == Intent.ACTION_MAIN) {
                                Log.d(TAG, "Main app launch detected, returning null")
                                result.success(null)
                                return@setMethodCallHandler
                            }
                            
                            // First try to get URL from intent extra
                            var url = intent.getStringExtra("url")
                            
                            // If not found, try to get from intent data (for shortcuts)
                            if (url.isNullOrEmpty() && intent.data != null) {
                                val data = intent.data
                                url = data?.getQueryParameter("url")
                                Log.d(TAG, "Got URL from intent data: $url")
                            }
                            
                            Log.d(TAG, "Returning URL: $url")
                            if (!url.isNullOrEmpty()) {
                                urlAlreadyRetrieved = true
                            }
                            result.success(url)
                        } else {
                            Log.d(TAG, "URL already retrieved, returning null")
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting URL from intent", e)
                        result.error("URL_ERROR", e.message, null)
                    }
                }
                "enableKioskMode" -> {
                    try {
                        val enabled = enableKioskMode()
                        result.success(enabled)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error enabling kiosk mode", e)
                        result.error("KIOSK_ERROR", e.message, null)
                    }
                }
                "disableKioskMode" -> {
                    try {
                        disableKioskMode()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error disabling kiosk mode", e)
                        result.error("KIOSK_ERROR", e.message, null)
                    }
                }
                "isDeviceOwner" -> {
                    try {
                        val isOwner = isDeviceOwner()
                        result.success(isOwner)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error checking device owner status", e)
                        result.error("DEVICE_OWNER_ERROR", e.message, null)
                    }
                }
                "isInKioskMode" -> {
                    try {
                        val inKiosk = isInKioskMode()
                        result.success(inKiosk)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error checking kiosk mode status", e)
                        result.error("KIOSK_STATUS_ERROR", e.message, null)
                    }
                }
                "exitToHome" -> {
                    try {
                        exitToHome()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error exiting to home", e)
                        result.error("EXIT_ERROR", e.message, null)
                    }
                }
                "getInstalledApps" -> {
                    try {
                        val apps = getInstalledApps()
                        result.success(apps)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting installed apps", e)
                        result.error("APPS_ERROR", e.message, null)
                    }
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    try {
                        val success = launchApp(packageName)
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error launching app", e)
                        result.error("LAUNCH_ERROR", e.message, null)
                    }
                }
                "updateLockTaskPackages" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    try {
                        val success = updateLockTaskPackages(packages)
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error updating lock task packages", e)
                        result.error("LOCK_TASK_ERROR", e.message, null)
                    }
                }
                "removeDeviceOwner" -> {
                    try {
                        val success = removeDeviceOwner()
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error removing device owner", e)
                        result.error("REMOVE_OWNER_ERROR", e.message, null)
                    }
                }
                "checkAccountsExist" -> {
                    try {
                        val accountsExist = checkAccountsExist()
                        result.success(accountsExist)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error checking accounts", e)
                        result.error("CHECK_ACCOUNTS_ERROR", e.message, null)
                    }
                }
                "enableDeviceOwner" -> {
                    try {
                        val resultMap = enableDeviceOwner()
                        result.success(resultMap)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error enabling device owner", e)
                        result.error("ENABLE_OWNER_ERROR", e.message, null)
                    }
                }
                "hideImeAggressively" -> {
                    try {
                        hideImeAggressively()
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error hiding IME aggressively", e)
                        result.error("IME_ERROR", e.message, null)
                    }
                }
                "restoreImeDefault" -> {
                    try {
                        restoreImeDefault()
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error restoring IME default", e)
                        result.error("IME_ERROR", e.message, null)
                    }
                }
                "resetInputConnection" -> {
                    try {
                        resetInputConnection()
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error resetting input connection", e)
                        result.error("INPUT_ERROR", e.message, null)
                    }
                }
                "clearDeviceOwner" -> {
                    try {
                        val devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val adminComponent = ComponentName(this, MyDeviceAdminReceiver::class.java)
                        devicePolicyManager.clearDeviceOwnerApp(packageName)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error clearing device owner", e)
                        result.error("CLEAR_ERROR", e.message, null)
                    }
                }
                "getWifiInfo" -> {
                    try {
                        val wifiInfo = getWifiInfo()
                        result.success(wifiInfo)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting WiFi info", e)
                        result.error("WIFI_ERROR", e.message, null)
                    }
                }
                "checkWebsiteStatus" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        val url = args?.get("url") as? String ?: ""
                        val status = checkWebsiteStatus(url)
                        result.success(status)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error checking website status", e)
                        result.error("WEBSITE_ERROR", e.message, null)
                    }
                }
                "testInternetSpeed" -> {
                    try {
                        val speedResult = testInternetSpeed()
                        result.success(speedResult)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error testing internet speed", e)
                        result.error("SPEED_TEST_ERROR", e.message, null)
                    }
                }
                "resetInternet" -> {
                    try {
                        resetInternet()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error resetting internet", e)
                        result.error("RESET_ERROR", e.message, null)
                    }
                }
                "hasPhysicalKeyboard" -> {
                    try {
                        val hasKeyboard = hasPhysicalKeyboard()
                        result.success(hasKeyboard)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error checking keyboard", e)
                        result.error("KEYBOARD_ERROR", e.message, null)
                    }
                }
                "applySystemUiMode" -> {
                    try {
                        val alwaysShowTopBar = call.argument<Boolean>("alwaysShowTopBar") ?: false
                        applySystemUiMode(alwaysShowTopBar)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error applying system UI mode", e)
                        result.error("SYSTEM_UI_ERROR", e.message, null)
                    }
                }
                "setScreenTimeout" -> {
                    try {
                        val timeout = call.argument<Int>("timeout") ?: 60000
                        val success = setScreenTimeout(timeout)
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error setting screen timeout", e)
                        result.error("SCREEN_TIMEOUT_ERROR", e.message, null)
                    }
                }
                "getScreenTimeout" -> {
                    try {
                        val timeout = getScreenTimeout()
                        result.success(timeout)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting screen timeout", e)
                        result.error("SCREEN_TIMEOUT_ERROR", e.message, null)
                    }
                }
                "setScreenOrientation" -> {
                    try {
                        val autoRotation = call.argument<Boolean>("autoRotation") ?: true
                        setScreenOrientation(autoRotation)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error setting screen orientation", e)
                        result.error("SCREEN_ORIENTATION_ERROR", e.message, null)
                    }
                }
                "getLockedOrientation" -> {
                    try {
                        val orientation = getLockedOrientation()
                        result.success(orientation)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting locked orientation", e)
                        result.error("SCREEN_ORIENTATION_ERROR", e.message, null)
                    }
                }
                "getAutoRotation" -> {
                    try {
                        val autoRotation = getAutoRotation()
                        result.success(autoRotation)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting auto-rotation setting", e)
                        result.error("SCREEN_ORIENTATION_ERROR", e.message, null)
                    }
                }
                "getDeviceModel" -> {
                    try {
                        val deviceModel = getDeviceModel()
                        result.success(deviceModel)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting device model", e)
                        result.error("DEVICE_MODEL_ERROR", e.message, null)
                    }
                }
                "getBluetoothDevices" -> {
                    try {
                        val devices = getBluetoothDevices()
                        result.success(devices)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting Bluetooth devices", e)
                        result.error("BLUETOOTH_ERROR", e.message, null)
                    }
                }
                "isDeveloperModeEnabled" -> {
                    try {
                        val enabled = isDeveloperModeEnabled()
                        result.success(enabled)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error checking developer mode", e)
                        result.error("DEVELOPER_MODE_ERROR", e.message, null)
                    }
                }
                "setDeveloperMode" -> {
                    try {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val success = setDeveloperMode(enabled)
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error setting developer mode", e)
                        result.error("DEVELOPER_MODE_ERROR", e.message, null)
                    }
                }
                "isUsbDebuggingEnabled" -> {
                    try {
                        val enabled = isUsbDebuggingEnabled()
                        result.success(enabled)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error checking USB debugging", e)
                        result.error("USB_DEBUGGING_ERROR", e.message, null)
                    }
                }
                "setUsbDebugging" -> {
                    try {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val success = setUsbDebugging(enabled)
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error setting USB debugging", e)
                        result.error("USB_DEBUGGING_ERROR", e.message, null)
                    }
                }
                "isUsbFileTransferEnabled" -> {
                    try {
                        val enabled = isUsbFileTransferEnabled()
                        result.success(enabled)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error checking USB file transfer", e)
                        result.error("USB_FILE_TRANSFER_ERROR", e.message, null)
                    }
                }
                "setUsbFileTransfer" -> {
                    try {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val success = setUsbFileTransfer(enabled)
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error setting USB file transfer", e)
                        result.error("USB_FILE_TRANSFER_ERROR", e.message, null)
                    }
                }
                "uninstallApp" -> {
                    try {
                        val success = uninstallApp()
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error uninstalling app", e)
                        result.error("UNINSTALL_ERROR", e.message, null)
                    }
                }
                "factoryReset" -> {
                    try {
                        val success = factoryReset()
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error performing factory reset", e)
                        result.error("FACTORY_RESET_ERROR", e.message, null)
                    }
                }
                "isLocationPermissionGranted" -> {
                    try {
                        val granted = isLocationPermissionGranted()
                        result.success(granted)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error checking location permission", e)
                        result.error("LOCATION_PERMISSION_ERROR", e.message, null)
                    }
                }
                "isBackgroundLocationGranted" -> {
                    try {
                        val granted = isBackgroundLocationGranted()
                        result.success(granted)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error checking background location permission", e)
                        result.error("LOCATION_PERMISSION_ERROR", e.message, null)
                    }
                }
                "isPreciseLocationEnabled" -> {
                    try {
                        val enabled = isPreciseLocationEnabled()
                        result.success(enabled)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error checking precise location", e)
                        result.error("LOCATION_PERMISSION_ERROR", e.message, null)
                    }
                }
                "requestLocationPermission" -> {
                    try {
                        requestLocationPermission()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error requesting location permission", e)
                        result.error("LOCATION_PERMISSION_ERROR", e.message, null)
                    }
                }
                "checkForUpdate" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val updateInfo = checkForUpdate()
                            result.success(updateInfo)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error checking for update", e)
                            result.error("UPDATE_CHECK_ERROR", e.message, null)
                        }
                    }
                }
                "downloadAndInstallUpdate" -> {
                    val downloadUrl = call.argument<String>("downloadUrl")
                    if (downloadUrl == null) {
                        result.error("INVALID_ARGS", "downloadUrl is required", null)
                        return@setMethodCallHandler
                    }
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val success = downloadAndInstallUpdate(downloadUrl)
                            result.success(success)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error downloading/installing update", e)
                            result.error("UPDATE_INSTALL_ERROR", e.message, null)
                        }
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Check if there's a pending URL from a shortcut that launched before Flutter was ready
        pendingUrl?.let { url ->
            pendingUrl = null
            methodChannel?.invokeMethod("onNewUrl", url)
        }
        
        // Set up device owner restrictions
        setupDeviceOwnerRestrictions()
    }
    
    private fun setupDeviceOwnerRestrictions() {
        initDevicePolicyManager()
        
        if (!isDeviceOwner()) {
            Log.w(TAG, "Not a device owner, cannot set restrictions")
            return
        }
        
        try {
            // Disable user ability to add other users
            devicePolicyManager?.addUserRestriction(adminComponent!!, android.os.UserManager.DISALLOW_ADD_USER)
            
            // Disable factory reset
            devicePolicyManager?.addUserRestriction(adminComponent!!, android.os.UserManager.DISALLOW_FACTORY_RESET)
            
            // Disable safe boot
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                devicePolicyManager?.addUserRestriction(adminComponent!!, android.os.UserManager.DISALLOW_SAFE_BOOT)
            }
            
            // WiFi management settings
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                // Force WiFi to stay always on (never sleep)
                devicePolicyManager?.setGlobalSetting(
                    adminComponent!!,
                    android.provider.Settings.Global.WIFI_SLEEP_POLICY,
                    android.provider.Settings.Global.WIFI_SLEEP_POLICY_NEVER.toString()
                )
                Log.d(TAG, "WiFi sleep policy set to NEVER")
            }
            
            // Set as default home once during initial setup
            setAsDefaultHome()
            
            // Configure lock task features to show status bar in kiosk mode
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                devicePolicyManager?.setLockTaskFeatures(
                    adminComponent!!,
                    android.app.admin.DevicePolicyManager.LOCK_TASK_FEATURE_GLOBAL_ACTIONS or
                    android.app.admin.DevicePolicyManager.LOCK_TASK_FEATURE_HOME or
                    android.app.admin.DevicePolicyManager.LOCK_TASK_FEATURE_NOTIFICATIONS or
                    android.app.admin.DevicePolicyManager.LOCK_TASK_FEATURE_SYSTEM_INFO
                )
                Log.d(TAG, "Lock task features configured: GLOBAL_ACTIONS, HOME, NOTIFICATIONS, SYSTEM_INFO")
            }
            
            // Auto-grant Bluetooth permissions for device info
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    val permGranted = devicePolicyManager?.setPermissionGrantState(
                        adminComponent!!,
                        packageName,
                        Manifest.permission.BLUETOOTH_CONNECT,
                        android.app.admin.DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED
                    )
                    Log.d(TAG, "BLUETOOTH_CONNECT permission grant state set: $permGranted")
                } catch (e: Exception) {
                    Log.e(TAG, "Error granting BLUETOOTH_CONNECT permission", e)
                }
            }
            
            Log.d(TAG, "Device owner restrictions applied successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up device owner restrictions", e)
        }
    }

    override fun onResume() {
        super.onResume()
        
        // Re-enable kiosk mode if needed (but don't constantly reset home preference)
        if (isDeviceOwner()) {
            try {
                // Only re-enable kiosk mode if not already active
                // Note: Don't call setAsDefaultHome() here - it's too expensive to run on every resume
                // Home preference is already set in setupDeviceOwnerRestrictions()
                if (!isInKioskMode()) {
                    enableKioskMode()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in onResume", e)
            }
        }
        
        // Reapply system UI mode to maintain status bar transparency
        reapplySystemUiMode()
        
        // Reapply screen orientation setting
        reapplyScreenOrientation()
    }
    
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            // Reapply system UI mode when window gains focus
            reapplySystemUiMode()
            
            // Reapply screen orientation setting
            reapplyScreenOrientation()
        }
    }
    
    private fun reapplySystemUiMode() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val alwaysShowTopBar = prefs.getBoolean("flutter.always_show_top_bar", false)
            Log.i(TAG, "Reapplying system UI mode: alwaysShowTopBar=$alwaysShowTopBar")
            applySystemUiMode(alwaysShowTopBar)
        } catch (e: Exception) {
            Log.e(TAG, "Error reapplying system UI mode", e)
        }
    }

    private fun reapplyScreenOrientation() {
        try {
            // Read from Android system settings instead of SharedPreferences
            val autoRotation = getAutoRotation()
            Log.i(TAG, "Reapplying screen orientation from system setting: autoRotation=$autoRotation")
            
            // Apply orientation to activity
            if (autoRotation) {
                requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR
            } else {
                // Read locked orientation from USER_ROTATION
                val userRotation = Settings.System.getInt(
                    contentResolver,
                    Settings.System.USER_ROTATION,
                    android.view.Surface.ROTATION_90 // Default: landscape
                )
                
                requestedOrientation = if (userRotation == android.view.Surface.ROTATION_90 || userRotation == android.view.Surface.ROTATION_270) {
                    android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                } else {
                    android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reapplying screen orientation", e)
        }
    }
    
    private fun setAsDefaultHome() {
        try {
            initDevicePolicyManager()
            
            if (!isDeviceOwner()) {
                Log.w(TAG, "Not a device owner, cannot set as default home")
                return
            }
            
            // Clear previous preferred home activity
            devicePolicyManager?.clearPackagePersistentPreferredActivities(adminComponent!!, packageName)
            
            // Set this app as the persistent preferred home activity
            val filter = android.content.IntentFilter().apply {
                addAction(Intent.ACTION_MAIN)
                addCategory(Intent.CATEGORY_HOME)
                addCategory(Intent.CATEGORY_DEFAULT)
            }
            
            val activity = ComponentName(this, MainActivity::class.java)
            devicePolicyManager?.addPersistentPreferredActivity(adminComponent!!, filter, activity)
            
            Log.d(TAG, "Set as default home successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting as default home", e)
        }
    }
    


    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        
        // Get URL from the new intent
        var url = intent.getStringExtra("url")
        
        // If not found, try to get from intent data (for shortcuts with custom URI)
        if (url.isNullOrEmpty() && intent.data != null) {
            url = intent.data?.getQueryParameter("url")
        }
        
        Log.d(TAG, "onNewIntent - URL: $url")
        
        // Always send to Flutter, even if null (for main app launches)
        methodChannel?.invokeMethod("onNewUrl", url)
        
        // Reset flag for next intent
        urlAlreadyRetrieved = false
    }

    private suspend fun changeAppIcon(iconUrlString: String, appName: String): Boolean = withContext(Dispatchers.IO) {
        if (iconUrlString.isEmpty()) {
            return@withContext false
        }
        
        try {
            // Download the icon
            Log.d(TAG, "Downloading icon for app: $iconUrlString")
            val bitmap = downloadIcon(iconUrlString)
            if (bitmap == null) {
                Log.e(TAG, "Failed to download icon")
                return@withContext false
            }
            
            // Save icon to internal storage
            val iconFile = File(context.filesDir, "custom_app_icon.png")
            FileOutputStream(iconFile).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
            Log.d(TAG, "Icon saved to: ${iconFile.absolutePath}")
            
            // Switch to the alias activity (which uses custom icon)
            withContext(Dispatchers.Main) {
                switchToCustomIcon()
            }
            
            return@withContext true
        } catch (e: Exception) {
            Log.e(TAG, "Error in changeAppIcon", e)
            return@withContext false
        }
    }
    
    private fun switchToCustomIcon() {
        val pm = packageManager
        
        // Disable main activity launcher
        pm.setComponentEnabledSetting(
            ComponentName(this, "com.devicegate.app.MainActivity"),
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )
        
        // Enable alias with custom icon
        pm.setComponentEnabledSetting(
            ComponentName(this, "com.devicegate.app.MainActivityAlias"),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
        
        Log.d(TAG, "Switched to custom icon alias")
    }
    
    private fun resetToDefaultIcon() {
        val pm = packageManager
        
        // Enable main activity
        pm.setComponentEnabledSetting(
            ComponentName(this, "com.devicegate.app.MainActivity"),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
        
        // Disable alias
        pm.setComponentEnabledSetting(
            ComponentName(this, "com.devicegate.app.MainActivityAlias"),
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )
        
        Log.d(TAG, "Reset to default icon")
    }

    private fun downloadIcon(iconUrl: String): Bitmap? {
        if (iconUrl.isEmpty()) {
            Log.d(TAG, "Icon URL is empty, returning null")
            return null
        }
        
        // Validate that it's a proper HTTP/HTTPS URL
        if (!iconUrl.startsWith("http://") && !iconUrl.startsWith("https://")) {
            Log.d(TAG, "Icon URL is not a valid HTTP/HTTPS URL: $iconUrl")
            return null
        }
        
        // Check for invalid characters that would make it malformed
        if (iconUrl.contains(" ") || iconUrl.contains("file://")) {
            Log.d(TAG, "Icon URL contains invalid characters: $iconUrl")
            return null
        }
        
        return try {
            Log.d(TAG, "Attempting to download icon from: $iconUrl")
            val url = URL(iconUrl)
            val connection = url.openConnection() as HttpURLConnection
            connection.doInput = true
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            connection.setRequestProperty("User-Agent", "Mozilla/5.0")
            connection.connect()
            
            val responseCode = connection.responseCode
            Log.d(TAG, "Icon download response code: $responseCode")
            
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val input = connection.inputStream
                val bitmap = BitmapFactory.decodeStream(input)
                input.close()
                bitmap
            } else {
                Log.e(TAG, "Failed to download icon: HTTP $responseCode")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception downloading icon", e)
            null
        }
    }
    
    private fun scaleBitmap(bitmap: Bitmap, targetWidth: Int, targetHeight: Int): Bitmap {
        val originalWidth = bitmap.width
        val originalHeight = bitmap.height

        // Calculate scale factor to fit within target dimensions while maintaining aspect ratio
        val scaleFactor = min(targetWidth.toFloat() / originalWidth, targetHeight.toFloat() / originalHeight)

        val scaledWidth = (originalWidth * scaleFactor).toInt()
        val scaledHeight = (originalHeight * scaleFactor).toInt()

        // Create scaled bitmap
        val scaledBitmap = Bitmap.createScaledBitmap(bitmap, scaledWidth, scaledHeight, true)

        // If we need a square icon, create a square canvas and center the scaled image
        if (targetWidth == targetHeight) {
            val squareBitmap = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
            val canvas = android.graphics.Canvas(squareBitmap)
            val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)

            // Center the scaled image on the square canvas
            val xOffset = (targetWidth - scaledWidth) / 2f
            val yOffset = (targetHeight - scaledHeight) / 2f

            canvas.drawBitmap(scaledBitmap, xOffset, yOffset, paint)
            return squareBitmap
        }

        return scaledBitmap
    }
    
    // ========== KIOSK MODE & DEVICE OWNER METHODS ==========
    
    private fun initDevicePolicyManager() {
        if (devicePolicyManager == null) {
            devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            adminComponent = ComponentName(this, MyDeviceAdminReceiver::class.java)
        }
    }
    
    private fun isDeviceOwner(): Boolean {
        initDevicePolicyManager()
        return devicePolicyManager?.isDeviceOwnerApp(packageName) ?: false
    }
    
    private fun removeDeviceOwner(): Boolean {
        initDevicePolicyManager()
        
        if (!isDeviceOwner()) {
            Log.w(TAG, "App is not a device owner")
            return false
        }
        
        try {
            // Disable kiosk mode first
            disableKioskMode()
            
            // Remove user restrictions
            devicePolicyManager?.clearUserRestriction(adminComponent!!, android.os.UserManager.DISALLOW_ADD_USER)
            devicePolicyManager?.clearUserRestriction(adminComponent!!, android.os.UserManager.DISALLOW_FACTORY_RESET)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                devicePolicyManager?.clearUserRestriction(adminComponent!!, android.os.UserManager.DISALLOW_SAFE_BOOT)
            }
            
            // Clear lock task packages
            devicePolicyManager?.setLockTaskPackages(adminComponent!!, arrayOf())
            
            // Remove device admin
            devicePolicyManager?.clearDeviceOwnerApp(packageName)
            
            Log.d(TAG, "Device owner removed successfully")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error removing device owner", e)
            return false
        }
    }
    
    private fun checkAccountsExist(): Boolean {
        return try {
            val accountManager = getSystemService(Context.ACCOUNT_SERVICE) as AccountManager
            val accounts = accountManager.accounts
            val hasAccounts = accounts.isNotEmpty()
            
            if (hasAccounts) {
                Log.i(TAG, "Found ${accounts.size} account(s) on device:")
                accounts.forEach { account ->
                    Log.i(TAG, "  - ${account.type}: ${account.name}")
                }
            } else {
                Log.i(TAG, "No accounts found on device")
            }
            
            hasAccounts
        } catch (e: Exception) {
            Log.e(TAG, "Error checking accounts", e)
            false // Assume no accounts if we can't check
        }
    }
    
    private fun isDeviceRooted(): Boolean {
        return try {
            // Check for common root binaries
            val paths = arrayOf(
                "/system/app/Superuser.apk",
                "/sbin/su",
                "/system/bin/su",
                "/system/xbin/su",
                "/data/local/xbin/su",
                "/data/local/bin/su",
                "/system/sd/xbin/su",
                "/system/bin/failsafe/su",
                "/data/local/su",
                "/su/bin/su"
            )
            
            paths.any { path ->
                try {
                    java.io.File(path).exists()
                } catch (e: Exception) {
                    false
                }
            } || try {
                // Try executing 'su' command
                val process = Runtime.getRuntime().exec(arrayOf("which", "su"))
                val reader = java.io.BufferedReader(java.io.InputStreamReader(process.inputStream))
                val output = reader.readText().trim()
                reader.close()
                process.waitFor()
                output.isNotEmpty()
            } catch (e: Exception) {
                false
            }
        } catch (e: Exception) {
            false
        }
    }
    
    private fun enableDeviceOwner(): Map<String, Any> {
        return try {
            // Check if already device owner
            if (isDeviceOwner()) {
                Log.i(TAG, "Already a device owner")
                return mapOf(
                    "success" to true,
                    "message" to "Already in Device Owner mode"
                )
            }
            
            // Check if accounts exist
            if (checkAccountsExist()) {
                Log.w(TAG, "Cannot set device owner: accounts exist on device")
                return mapOf(
                    "success" to false,
                    "error" to "ACCOUNTS_EXIST",
                    "message" to "Cannot enable Device Owner mode while accounts are logged in. Please remove all accounts from Settings and try again."
                )
            }
            
            val adminComponent = ComponentName(this, MyDeviceAdminReceiver::class.java)
            val componentString = adminComponent.flattenToString()
            
            // Try root method first if device is rooted
            val isRooted = isDeviceRooted()
            Log.i(TAG, "Device rooted: $isRooted")
            
            if (isRooted) {
                Log.i(TAG, "Attempting to set device owner via root...")
                try {
                    val rootCommand = "su -c 'dpm set-device-owner $componentString'"
                    val process = Runtime.getRuntime().exec(rootCommand)
                    val exitCode = process.waitFor()
                    
                    if (exitCode == 0) {
                        Log.i(TAG, "Device owner set successfully via root")
                        
                        // Initialize and enable kiosk mode
                        initDevicePolicyManager()
                        enableKioskMode()
                        setAsDefaultHome()
                        grantRequiredPermissions()
                        
                        return mapOf(
                            "success" to true,
                            "message" to "Device Owner mode enabled successfully via root access"
                        )
                    } else {
                        val errorReader = java.io.BufferedReader(java.io.InputStreamReader(process.errorStream))
                        val errorOutput = errorReader.readText()
                        errorReader.close()
                        Log.e(TAG, "Root command failed. Exit code: $exitCode, Error: $errorOutput")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Root command exception", e)
                }
            }
            
            // Try to set device owner via shell command (likely to fail on non-rooted devices)
            Log.i(TAG, "Attempting to set device owner via shell command")
            
            val command = "dpm set-device-owner $componentString"
            
            val process = Runtime.getRuntime().exec(command)
            val exitCode = process.waitFor()
            
            if (exitCode == 0) {
                Log.i(TAG, "Device owner set successfully")
                
                // Initialize and enable kiosk mode
                initDevicePolicyManager()
                enableKioskMode()
                setAsDefaultHome()
                grantRequiredPermissions()
                
                return mapOf(
                    "success" to true,
                    "message" to "Device Owner mode enabled successfully"
                )
            } else {
                // Read error output
                val errorReader = java.io.BufferedReader(java.io.InputStreamReader(process.errorStream))
                val errorOutput = errorReader.readText()
                errorReader.close()
                
                Log.e(TAG, "Failed to set device owner. Exit code: $exitCode, Error: $errorOutput")
                
                // Determine why it failed and provide specific guidance
                val rootStatus = if (isRooted) "Device is rooted, but root command failed." else "Device is not rooted."
                
                // Return instructions for manual ADB setup
                return mapOf(
                    "success" to false,
                    "error" to "REQUIRES_ADB",
                    "message" to "⚠️ Android Security Restriction\n\n" +
                                 "Apps cannot promote themselves to Device Owner mode due to Android security policies. $rootStatus\n\n" +
                                 "✅ Manual Setup Required:\n\n" +
                                 "1. Enable USB Debugging:\n   Settings → Developer Options → USB Debugging\n\n" +
                                 "2. Connect device to computer via USB\n\n" +
                                 "3. Open terminal/command prompt and run:\n   adb shell dpm set-device-owner com.devicegate.app/.MyDeviceAdminReceiver\n\n" +
                                 "4. Restart DeviceGate app\n\n" +
                                 "Note: Make sure no accounts are logged in and no work profiles exist before running the command."
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error enabling device owner", e)
            return mapOf(
                "success" to false,
                "error" to "EXCEPTION",
                "message" to "Error: ${e.message ?: "Unknown error"}"
            )
        }
    }
    
    private fun enableKioskMode(): Boolean {
        initDevicePolicyManager()
        
        if (!isDeviceOwner()) {
            Log.w(TAG, "App is not a device owner. Cannot enable kiosk mode.")
            return false
        }
        
        try {
            // Configure lock task features to show status bar (battery, network, time)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                // Android 9+ (API 28+): Enable system info bar and power button access
                devicePolicyManager?.setLockTaskFeatures(
                    adminComponent!!,
                    android.app.admin.DevicePolicyManager.LOCK_TASK_FEATURE_GLOBAL_ACTIONS or
                    android.app.admin.DevicePolicyManager.LOCK_TASK_FEATURE_HOME or
                    android.app.admin.DevicePolicyManager.LOCK_TASK_FEATURE_NOTIFICATIONS or
                    android.app.admin.DevicePolicyManager.LOCK_TASK_FEATURE_SYSTEM_INFO
                )
                Log.d(TAG, "Lock task features enabled: GLOBAL_ACTIONS (power button), HOME, NOTIFICATIONS, SYSTEM_INFO")
            }
            
            // Set this app as the lock task package
            devicePolicyManager?.setLockTaskPackages(adminComponent!!, arrayOf(packageName))
            
            // Start lock task mode
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                startLockTask()
            }
            
            Log.d(TAG, "Kiosk mode enabled successfully")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error enabling kiosk mode", e)
            return false
        }
    }
    
    private fun disableKioskMode() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                stopLockTask()
            }
            Log.d(TAG, "Kiosk mode disabled")
        } catch (e: Exception) {
            Log.e(TAG, "Error disabling kiosk mode", e)
        }
    }
    
    private fun isInKioskMode(): Boolean {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            activityManager.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            @Suppress("DEPRECATION")
            activityManager.isInLockTaskMode
        } else {
            false
        }
    }
    
    private fun exitToHome() {
        try {
            initDevicePolicyManager()
            
            // Exit kiosk mode if active
            disableKioskMode()
            
            // Find the default system launcher (not DeviceGate)
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
            }
            
            val resolveInfoList = packageManager.queryIntentActivities(homeIntent, 0)
            
            // Find a launcher that is not this app
            val otherLauncher = resolveInfoList.firstOrNull { resolveInfo ->
                resolveInfo.activityInfo.packageName != packageName
            }
            
            if (otherLauncher != null && isDeviceOwner()) {
                // Clear DeviceGate as persistent preferred home
                devicePolicyManager?.clearPackagePersistentPreferredActivities(adminComponent!!, packageName)
                
                // Set the system launcher as persistent preferred home
                val filter = android.content.IntentFilter().apply {
                    addAction(Intent.ACTION_MAIN)
                    addCategory(Intent.CATEGORY_HOME)
                    addCategory(Intent.CATEGORY_DEFAULT)
                }
                
                val activity = ComponentName(
                    otherLauncher.activityInfo.packageName,
                    otherLauncher.activityInfo.name
                )
                devicePolicyManager?.addPersistentPreferredActivity(adminComponent!!, filter, activity)
                
                Log.d(TAG, "Set system launcher as default: ${otherLauncher.activityInfo.packageName}")
                
                // Launch the other launcher
                val launchIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    setPackage(otherLauncher.activityInfo.packageName)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(launchIntent)
                Log.d(TAG, "Launched system launcher")
            } else {
                // Fallback: just launch home intent
                val fallbackIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(fallbackIntent)
                Log.w(TAG, "No other launcher found or not device owner")
            }
            
            Log.d(TAG, "Exited to home screen")
        } catch (e: Exception) {
            Log.e(TAG, "Error exiting to home", e)
            throw e
        }
    }
    
    private fun getInstalledApps(): List<Map<String, Any>> {
        val apps = mutableListOf<Map<String, Any>>()
        val addedPackages = mutableSetOf<String>()

        // Use LauncherApps API - this is what real launchers use
        val launcherApps = getSystemService(Context.LAUNCHER_APPS_SERVICE) as? android.content.pm.LauncherApps
        
        if (launcherApps != null) {
            val profiles = launcherApps.profiles
            Log.d(TAG, "LauncherApps: Found ${profiles.size} user profiles")
            
            for (profile in profiles) {
                val activityList = launcherApps.getActivityList(null, profile)
                Log.d(TAG, "LauncherApps: Found ${activityList.size} activities for profile")
                
                for (launcherActivityInfo in activityList) {
                    val packageName = launcherActivityInfo.applicationInfo.packageName
                    
                    // Skip DeviceGate itself and duplicates
                    if (packageName == this.packageName || addedPackages.contains(packageName)) {
                        continue
                    }
                    
                    try {
                        val appName = launcherActivityInfo.label.toString()
                        
                        // Get app icon as base64
                        val icon = launcherActivityInfo.getIcon(0) ?: launcherActivityInfo.applicationInfo.loadIcon(packageManager)
                        val bitmap = icon.toBitmap()
                        val iconBase64 = bitmapToBase64(bitmap)
                        
                        apps.add(mapOf(
                            "name" to appName,
                            "packageName" to packageName,
                            "icon" to iconBase64
                        ))
                        addedPackages.add(packageName)
                        
                        Log.d(TAG, "LauncherApps: Added $appName ($packageName)")
                    } catch (e: Exception) {
                        Log.e(TAG, "LauncherApps: Error getting info for $packageName", e)
                    }
                }
            }
        }
        
        Log.d(TAG, "LauncherApps method found ${apps.size} apps")
        
        // Fallback: also try queryIntentActivities to catch any missed apps
        val intent = Intent(Intent.ACTION_MAIN, null)
        intent.addCategory(Intent.CATEGORY_LAUNCHER)
        
        val resolveInfos = packageManager.queryIntentActivities(intent, 0)
        Log.d(TAG, "queryIntentActivities found ${resolveInfos.size} activities")
        
        for (resolveInfo in resolveInfos) {
            val packageName = resolveInfo.activityInfo.packageName
            
            // Skip DeviceGate itself and already added apps
            if (packageName == this.packageName || addedPackages.contains(packageName)) {
                continue
            }
            
            try {
                val appInfo = resolveInfo.activityInfo.applicationInfo
                val appName = packageManager.getApplicationLabel(appInfo).toString()
                
                // Get app icon as base64
                val icon = appInfo.loadIcon(packageManager)
                val bitmap = icon.toBitmap()
                val iconBase64 = bitmapToBase64(bitmap)
                
                apps.add(mapOf(
                    "name" to appName,
                    "packageName" to packageName,
                    "icon" to iconBase64
                ))
                addedPackages.add(packageName)
                
                Log.d(TAG, "Fallback: Added $appName ($packageName)")
            } catch (e: Exception) {
                Log.e(TAG, "Fallback: Error for $packageName", e)
            }
        }
        
        // Sort by app name
        val sortedApps = apps.sortedBy { it["name"] as String }
        Log.d(TAG, "Total apps: ${sortedApps.size}")
        return sortedApps
    }
    
    private fun android.graphics.drawable.Drawable.toBitmap(): Bitmap {
        if (this is android.graphics.drawable.BitmapDrawable) {
            return bitmap
        }
        
        val width = if (intrinsicWidth > 0) intrinsicWidth else 96
        val height = if (intrinsicHeight > 0) intrinsicHeight else 96
        
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bitmap)
        setBounds(0, 0, canvas.width, canvas.height)
        draw(canvas)
        return bitmap
    }
    
    private fun bitmapToBase64(bitmap: Bitmap): String {
        val outputStream = java.io.ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
        val byteArray = outputStream.toByteArray()
        return android.util.Base64.encodeToString(byteArray, android.util.Base64.NO_WRAP)
    }
    
    private fun launchApp(packageName: String): Boolean {
        return try {
            Log.d(TAG, "Attempting to launch app: $packageName")
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent != null) {
                // Note: Lock task packages are already set during device owner setup
                // No need to modify them here - this was causing performance issues
                
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                startActivity(launchIntent)
                Log.d(TAG, "Successfully launched app: $packageName")
                true
            } else {
                Log.e(TAG, "No launch intent found for: $packageName")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error launching app: $packageName", e)
            false
        }
    }
    
    private fun updateLockTaskPackages(packages: List<String>): Boolean {
        initDevicePolicyManager()
        
        if (!isDeviceOwner()) {
            Log.w(TAG, "App is not a device owner, cannot update lock task packages")
            return false
        }
        
        return try {
            // Always include DeviceGate app itself
            val allPackages = mutableListOf(packageName)
            allPackages.addAll(packages)
            
            Log.d(TAG, "Updating lock task packages: $allPackages")
            devicePolicyManager?.setLockTaskPackages(adminComponent!!, allPackages.toTypedArray())
            Log.d(TAG, "Lock task packages updated successfully")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error updating lock task packages", e)
            false
        }
    }
    
    /**
     * Aggressively hides the system keyboard IME bar from appearing (even on focus)
     * BUT allows hardware input devices like barcode scanners to work
     * Strategy: If a physical keyboard/scanner is connected via Bluetooth,
     * block ALL soft keyboards. Otherwise allow soft keyboards.
     */
    private fun hideImeAggressively() {
        try {
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
            
            // TIER 1: Check if a physical keyboard/scanner is connected (Android's Configuration.keyboard)
            val hasPhysicalInputDevice = isPhysicalKeyboardConnected()
            
            if (hasPhysicalInputDevice) {
                // Physical keyboard/scanner connected - block ALL soft keyboards
                Log.d(TAG, "TIER 1: Physical keyboard detected (KEYBOARD_QWERTY) - blocking all soft keyboards")
                blockAllSoftKeyboards(imm)
                return
            }
            
            // TIER 2: No physical keyboard - check if any Bluetooth device is ACTIVELY connected
            val bluetoothDevices = getBluetoothDevices()
            val connectedBluetoothDevices = bluetoothDevices.filter { it["connected"] == "Connected" }
            val hasConnectedBluetoothDevice = connectedBluetoothDevices.isNotEmpty()
            
            Log.d(TAG, "Bluetooth check: ${bluetoothDevices.size} paired, ${connectedBluetoothDevices.size} connected")
            
            if (!hasConnectedBluetoothDevice) {
                // No physical keyboard AND no connected Bluetooth devices - block ALL soft keyboards
                Log.d(TAG, "TIER 2: No physical keyboard, no connected Bluetooth devices - blocking all soft keyboards")
                blockAllSoftKeyboards(imm)
                return
            }
            
            // TIER 3: No physical keyboard BUT Bluetooth device actively connected - use IME name-based filtering
            val deviceNames = connectedBluetoothDevices.mapNotNull { it["name"] }.joinToString(", ")
            Log.d(TAG, "TIER 3: No physical keyboard, but ${connectedBluetoothDevices.size} Bluetooth device(s) connected ($deviceNames) - using IME filtering")
            
            // Get current active input method
            val currentIme = android.provider.Settings.Secure.getString(
                contentResolver,
                android.provider.Settings.Secure.DEFAULT_INPUT_METHOD
            )
            
            // List of known scanner/hardware keyboard IME packages that should NOT be blocked
            val hardwareInputDevices = listOf(
                "honeywell",      // Honeywell scanners (e.g., XLR)
                "datalogic",      // Datalogic scanners (e.g., Powerscan)
                "zebra",          // Zebra scanners
                "scanner",        // Generic scanner keyword
                "barcode",        // Barcode scanner keyword
                "hardware",       // Hardware keyboard keyword
                "physical"        // Physical keyboard keyword
            )
            
            // Check if current IME is a hardware input device
            val isHardwareDevice = hardwareInputDevices.any { 
                currentIme?.contains(it, ignoreCase = true) == true 
            }
            
            if (isHardwareDevice) {
                // Don't block hardware input devices - allow them to work
                Log.d(TAG, "Detected hardware input device IME: $currentIme - allowing input")
                // Clear any previous aggressive flags to ensure scanner works
                window?.clearFlags(android.view.WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)
                window?.setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_STATE_UNSPECIFIED)
            } else {
                // It's a soft keyboard - hide it aggressively
                Log.d(TAG, "Detected soft keyboard IME: $currentIme - blocking")
                blockAllSoftKeyboards(imm)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in hideImeAggressively", e)
        }
    }
    
    /**
     * Helper to block all soft keyboards with aggressive window flags
     */
    private fun blockAllSoftKeyboards(imm: android.view.inputmethod.InputMethodManager) {
        // VERY AGGRESSIVE: Set multiple window flags to prevent IME bar
        window?.setSoftInputMode(
            android.view.WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN or
            android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
        )
        
        // Additional aggressive flag: Add FLAG_ALT_FOCUSABLE_IM to prevent IME bar
        window?.setFlags(
            android.view.WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM,
            android.view.WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM
        )
        
        // Also hide any currently shown soft keyboard
        currentFocus?.let { focus ->
            imm.hideSoftInputFromWindow(focus.windowToken, android.view.inputmethod.InputMethodManager.HIDE_NOT_ALWAYS)
        }
        
        Log.d(TAG, "All soft keyboards blocked with aggressive IME hiding")
    }
    
    /**
     * Checks if Android reports a physical keyboard is connected.
     * This uses Android's system-level keyboard detection, which is set when
     * devices like barcode scanners register themselves as HID keyboards.
     */
    private fun isPhysicalKeyboardConnected(): Boolean {
        try {
            // Check Android's built-in physical keyboard detection
            val config = resources.configuration
            val keyboardType = config.keyboard
            
            // Log keyboard configuration for debugging
            val keyboardTypeName = when (keyboardType) {
                android.content.res.Configuration.KEYBOARD_NOKEYS -> "KEYBOARD_NOKEYS"
                android.content.res.Configuration.KEYBOARD_QWERTY -> "KEYBOARD_QWERTY"
                android.content.res.Configuration.KEYBOARD_12KEY -> "KEYBOARD_12KEY"
                else -> "UNKNOWN ($keyboardType)"
            }
            
            // Also log which input devices Android recognizes as keyboards
            val inputDevices = android.view.InputDevice.getDeviceIds()
            val keyboardDevices = mutableListOf<String>()
            
            for (deviceId in inputDevices) {
                val device = android.view.InputDevice.getDevice(deviceId)
                if (device != null) {
                    // Check if device has keyboard capability
                    val sources = device.sources
                    val isKeyboard = (sources and android.view.InputDevice.SOURCE_KEYBOARD) != 0
                    val isExternal = !device.isVirtual
                    
                    if (isKeyboard && isExternal) {
                        keyboardDevices.add("${device.name} (id=$deviceId)")
                    }
                }
            }
            
            if (keyboardDevices.isNotEmpty()) {
                Log.d(TAG, "Physical keyboard check: $keyboardTypeName, external keyboards: $keyboardDevices")
            } else {
                Log.d(TAG, "Physical keyboard check: $keyboardTypeName, no external keyboards detected")
            }
            
            // Return true only if Android reports a physical keyboard is present
            return keyboardType != android.content.res.Configuration.KEYBOARD_NOKEYS
        } catch (e: Exception) {
            Log.e(TAG, "Error checking for physical keyboard", e)
            return false
        }
    }

    /**
     * Restores default IME behavior and removes aggressive flags
     */
    private fun restoreImeDefault() {
        try {
            // Remove FLAG_ALT_FOCUSABLE_IM
            window?.clearFlags(android.view.WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)
            
            // Restore default soft input mode
            window?.setSoftInputMode(
                android.view.WindowManager.LayoutParams.SOFT_INPUT_STATE_UNSPECIFIED or
                android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
            )
            
            Log.d(TAG, "IME restored to default behavior, aggressive flags removed")
        } catch (e: Exception) {
            Log.e(TAG, "Error restoring IME default", e)
        }
    }

    /**
     * Resets the InputMethod connection to ensure hardware keyboard/scanner input works
     * after soft keyboard usage. This should be called when navigating to a WebView.
     */
    private fun resetInputConnection() {
        try {
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
            
            // Step 1: Clear any aggressive IME flags
            window?.clearFlags(android.view.WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)
            window?.setSoftInputMode(
                android.view.WindowManager.LayoutParams.SOFT_INPUT_STATE_UNSPECIFIED or
                android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
            )
            
            // Step 2: Restart input on the current view
            currentFocus?.let { view ->
                imm.restartInput(view)
                Log.d(TAG, "InputMethod restarted on focused view: ${view.javaClass.simpleName}")
            }
            
            // Step 3: If no focus, try to restart on the decor view
            if (currentFocus == null) {
                window?.decorView?.let { decorView ->
                    imm.restartInput(decorView)
                    Log.d(TAG, "InputMethod restarted on decor view")
                }
            }
            
            Log.d(TAG, "Input connection reset completed - scanner should now receive input")
        } catch (e: Exception) {
            Log.e(TAG, "Error resetting input connection", e)
        }
    }

    /**
     * Gets WiFi information including saved networks and current connection status.
     */
    private fun getWifiInfo(): Map<String, Any> {
        Log.i(TAG, "getWifiInfo called")
        val wifiManager = getSystemService(Context.WIFI_SERVICE) as WifiManager
        
        val wifiInfo = mutableMapOf<String, Any>()
        
        try {
            // Check if we're device owner and grant location permission if needed
            val devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = ComponentName(this, MyDeviceAdminReceiver::class.java)

            val isDeviceOwner = devicePolicyManager.isDeviceOwnerApp(packageName)
            Log.i(TAG, "Is device owner: $isDeviceOwner")

            if (isDeviceOwner) {
                // As device owner, we can grant runtime permissions
                try {
                    val currentGrantState = devicePolicyManager.getPermissionGrantState(
                        adminComponent,
                        packageName,
                        Manifest.permission.ACCESS_FINE_LOCATION
                    )
                    Log.i(TAG, "Current location permission grant state: $currentGrantState")

                    // Only grant permission if not already granted (to avoid repeated notifications)
                    if (currentGrantState != DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED) {
                        devicePolicyManager.setPermissionGrantState(
                            adminComponent,
                            packageName,
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED
                        )
                        Log.i(TAG, "Granted ACCESS_FINE_LOCATION permission via Device Owner")
                    } else {
                        Log.i(TAG, "ACCESS_FINE_LOCATION already granted, skipping")
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to grant location permission via Device Owner", e)
                }
            }
            
            // Check location permission
            val hasLocationPermission = ContextCompat.checkSelfPermission(
                this, 
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
            
            // Check if location services are enabled
            val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val isLocationEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) || 
                                   locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
            
            Log.i(TAG, "Location permission granted: $hasLocationPermission, Location enabled: $isLocationEnabled")
            
            // Get current connection info
            val connectionInfo = wifiManager.connectionInfo
            val currentNetwork = if (connectionInfo != null && connectionInfo.networkId != -1) {
                val networkMap = mutableMapOf<String, Any>(
                    "ssid" to (connectionInfo.ssid ?: "Unknown").removeSurrounding("\""),
                    "bssid" to (connectionInfo.bssid ?: "Unknown"),
                    "rssi" to connectionInfo.rssi,
                    "signalDbm" to "${connectionInfo.rssi} dBm",
                    "linkSpeed" to connectionInfo.linkSpeed,
                    "frequency" to connectionInfo.frequency,
                    "ipAddress" to connectionInfo.ipAddress,
                    "signalStrength" to calculateSignalStrength(connectionInfo.rssi)
                )
                
                // Extract router manufacturer from BSSID MAC address
                try {
                    val macPrefix = connectionInfo.bssid?.substring(0, 8)?.uppercase() ?: ""
                    val manufacturer = when {
                        // Cisco
                        macPrefix.startsWith("00:1A:11") || macPrefix.startsWith("00:18:0A") || 
                        macPrefix.startsWith("00:40:96") || macPrefix.startsWith("00:1C:0E") ||
                        macPrefix.startsWith("C0:25:E9") || macPrefix.startsWith("00:07:0D") -> "Cisco"
                        
                        // Ubiquiti
                        macPrefix.startsWith("00:24:A5") || macPrefix.startsWith("F0:9F:C2") ||
                        macPrefix.startsWith("68:D7:9A") || macPrefix.startsWith("78:8A:20") ||
                        macPrefix.startsWith("04:18:D6") || macPrefix.startsWith("24:A4:3C") -> "Ubiquiti"
                        
                        // Netgear
                        macPrefix.startsWith("00:03:7F") || macPrefix.startsWith("00:0F:66") ||
                        macPrefix.startsWith("00:1B:2F") || macPrefix.startsWith("00:14:6C") ||
                        macPrefix.startsWith("00:1E:2A") || macPrefix.startsWith("A0:04:60") -> "Netgear"
                        
                        // TP-Link
                        macPrefix.startsWith("00:1D:7E") || macPrefix.startsWith("00:22:6B") ||
                        macPrefix.startsWith("F4:EC:38") || macPrefix.startsWith("98:DE:D0") ||
                        macPrefix.startsWith("50:C7:BF") || macPrefix.startsWith("B0:4E:26") -> "TP-Link"
                        
                        // Aruba
                        macPrefix.startsWith("B4:75:0E") || macPrefix.startsWith("CC:40:D0") ||
                        macPrefix.startsWith("00:0B:86") || macPrefix.startsWith("D8:C7:C8") -> "Aruba"
                        
                        // Ruckus
                        macPrefix.startsWith("00:0C:42") || macPrefix.startsWith("18:64:72") ||
                        macPrefix.startsWith("88:DC:96") || macPrefix.startsWith("54:3D:37") -> "Ruckus"
                        
                        // Asus
                        macPrefix.startsWith("00:1F:C6") || macPrefix.startsWith("00:22:15") ||
                        macPrefix.startsWith("04:42:1A") || macPrefix.startsWith("30:85:A9") ||
                        macPrefix.startsWith("1C:87:2C") || macPrefix.startsWith("2C:FD:A1") -> "Asus"
                        
                        // D-Link
                        macPrefix.startsWith("00:05:5D") || macPrefix.startsWith("00:0D:88") ||
                        macPrefix.startsWith("00:15:E9") || macPrefix.startsWith("00:17:9A") ||
                        macPrefix.startsWith("00:1B:11") || macPrefix.startsWith("28:10:7B") -> "D-Link"
                        
                        // Linksys
                        macPrefix.startsWith("00:04:5A") || macPrefix.startsWith("00:06:25") ||
                        macPrefix.startsWith("00:0C:41") || macPrefix.startsWith("00:12:17") ||
                        macPrefix.startsWith("00:13:10") || macPrefix.startsWith("00:14:BF") -> "Linksys"
                        
                        // Huawei
                        macPrefix.startsWith("00:1E:10") || macPrefix.startsWith("00:25:9E") ||
                        macPrefix.startsWith("D4:6E:0E") || macPrefix.startsWith("F8:E7:1E") ||
                        macPrefix.startsWith("C8:94:02") || macPrefix.startsWith("34:6B:D3") -> "Huawei"
                        
                        // ZTE
                        macPrefix.startsWith("8C:34:FD") || macPrefix.startsWith("E8:48:B8") ||
                        macPrefix.startsWith("68:DB:F5") || macPrefix.startsWith("C8:3A:6B") -> "ZTE"
                        
                        // Belkin
                        macPrefix.startsWith("00:11:50") || macPrefix.startsWith("08:86:3B") ||
                        macPrefix.startsWith("94:44:52") || macPrefix.startsWith("EC:1A:59") -> "Belkin"
                        
                        // Mikrotik
                        macPrefix.startsWith("00:0C:42") || macPrefix.startsWith("D4:CA:6D") ||
                        macPrefix.startsWith("4C:5E:0C") || macPrefix.startsWith("E4:8D:8C") -> "MikroTik"
                        
                        // Apple (Airport)
                        macPrefix.startsWith("00:03:93") || macPrefix.startsWith("00:0A:95") ||
                        macPrefix.startsWith("00:0D:93") || macPrefix.startsWith("00:17:F2") ||
                        macPrefix.startsWith("28:CF:E9") || macPrefix.startsWith("A4:D1:8C") -> "Apple"
                        
                        // Google (Nest WiFi, Google WiFi)
                        macPrefix.startsWith("00:1A:11") || macPrefix.startsWith("F4:F5:D8") ||
                        macPrefix.startsWith("6C:AD:F8") || macPrefix.startsWith("CC:32:E5") -> "Google"
                        
                        // Amazon (eero)
                        macPrefix.startsWith("F8:BB:BF") || macPrefix.startsWith("08:62:66") -> "Amazon (eero)"
                        
                        // Xiaomi
                        macPrefix.startsWith("34:CE:00") || macPrefix.startsWith("78:11:DC") ||
                        macPrefix.startsWith("64:09:80") || macPrefix.startsWith("50:8F:4C") -> "Xiaomi"
                        
                        // Sagemcom
                        macPrefix.startsWith("00:13:C8") || macPrefix.startsWith("F4:06:8D") ||
                        macPrefix.startsWith("E4:AB:89") || macPrefix.startsWith("84:26:15") -> "Sagemcom"
                        
                        // Technicolor
                        macPrefix.startsWith("00:1F:9F") || macPrefix.startsWith("00:14:7C") ||
                        macPrefix.startsWith("88:F7:C7") || macPrefix.startsWith("A4:91:B1") -> "Technicolor"
                        
                        // AVM (Fritz!Box)
                        macPrefix.startsWith("00:04:0E") || macPrefix.startsWith("3C:A6:2F") ||
                        macPrefix.startsWith("C8:0E:14") || macPrefix.startsWith("7C:FF:4D") -> "AVM (Fritz!Box)"
                        
                        else -> "Autre/Inconnu"
                    }
                    networkMap["routerManufacturer"] = manufacturer
                } catch (e: Exception) {
                    Log.w(TAG, "Could not determine router manufacturer", e)
                }
                
                // Add WiFi generation/standard (WiFi 4/5/6)
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                    try {
                        val wifiGeneration = when (connectionInfo.wifiStandard) {
                            android.net.wifi.ScanResult.WIFI_STANDARD_11N -> "WiFi 4 (802.11n)"
                            android.net.wifi.ScanResult.WIFI_STANDARD_11AC -> "WiFi 5 (802.11ac)"
                            android.net.wifi.ScanResult.WIFI_STANDARD_11AX -> "WiFi 6 (802.11ax)"
                            android.net.wifi.ScanResult.WIFI_STANDARD_LEGACY -> "Legacy (802.11a/b/g)"
                            else -> "Unknown"
                        }
                        networkMap["wifiStandard"] = wifiGeneration
                    } catch (e: Exception) {
                        Log.w(TAG, "Could not get WiFi standard", e)
                    }
                }
                
                // Add max supported link speed and TX/RX speeds (Android 12+)
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                    try {
                        networkMap["maxLinkSpeed"] = connectionInfo.maxSupportedTxLinkSpeedMbps
                        networkMap["txLinkSpeed"] = connectionInfo.txLinkSpeedMbps
                        networkMap["rxLinkSpeed"] = connectionInfo.rxLinkSpeedMbps
                    } catch (e: Exception) {
                        Log.w(TAG, "Could not get link speeds", e)
                    }
                }
                
                // Determine frequency band
                val frequencyBand = when {
                    connectionInfo.frequency in 2400..2500 -> "2.4 GHz"
                    connectionInfo.frequency in 5000..5900 -> "5 GHz"
                    connectionInfo.frequency >= 6000 -> "6 GHz"
                    else -> "Unknown"
                }
                networkMap["frequencyBand"] = frequencyBand
                
                // Calculate WiFi channel from frequency
                val channel = when {
                    connectionInfo.frequency in 2400..2500 -> {
                        // 2.4 GHz channels
                        (connectionInfo.frequency - 2407) / 5
                    }
                    connectionInfo.frequency in 5000..5900 -> {
                        // 5 GHz channels
                        (connectionInfo.frequency - 5000) / 5
                    }
                    connectionInfo.frequency >= 6000 -> {
                        // 6 GHz channels (WiFi 6E)
                        (connectionInfo.frequency - 5950) / 5
                    }
                    else -> -1
                }
                if (channel > 0) {
                    networkMap["channel"] = channel
                }
                
                // Try to determine channel width from network capabilities
                try {
                    val configuredNetworks = wifiManager.configuredNetworks
                    val currentConfig = configuredNetworks?.find { it.networkId == connectionInfo.networkId }
                    // Note: Direct channel width is not easily available, but we can infer from WiFi standard
                    val channelWidth = when {
                        networkMap["wifiStandard"] == "WiFi 6 (802.11ax)" -> "20/40/80/160 MHz"
                        networkMap["wifiStandard"] == "WiFi 5 (802.11ac)" -> "20/40/80 MHz"
                        networkMap["wifiStandard"] == "WiFi 4 (802.11n)" -> "20/40 MHz"
                        else -> "20 MHz"
                    }
                    networkMap["channelWidth"] = channelWidth
                } catch (e: Exception) {
                    Log.w(TAG, "Could not determine channel width", e)
                }
                
                // Get security type from configured networks
                try {
                    val configuredNetworks = wifiManager.configuredNetworks
                    val currentConfig = configuredNetworks?.find { it.networkId == connectionInfo.networkId }
                    currentConfig?.let { config ->
                        val securityType = when {
                            config.allowedKeyManagement.get(android.net.wifi.WifiConfiguration.KeyMgmt.WPA2_PSK) -> "WPA2"
                            config.allowedKeyManagement.get(android.net.wifi.WifiConfiguration.KeyMgmt.WPA_PSK) -> "WPA"
                            config.allowedKeyManagement.get(android.net.wifi.WifiConfiguration.KeyMgmt.NONE) -> "Open"
                            else -> "WPA/WPA2"
                        }
                        networkMap["securityType"] = securityType
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Could not determine security type", e)
                }
                
                networkMap
            } else {
                // Try to get the last connected network info even when disconnected
                val lastNetwork = if (connectionInfo != null && connectionInfo.ssid != null) {
                    mapOf(
                        "ssid" to connectionInfo.ssid.removeSurrounding("\""),
                        "status" to "disconnected",
                        "lastConnected" to true
                    )
                } else {
                    mapOf(
                        "status" to "disconnected"
                    )
                }
                lastNetwork
            }
            wifiInfo["currentNetwork"] = currentNetwork
            
            // Get configured (saved) networks
            val configuredNetworks = mutableListOf<Map<String, Any>>()

            // Try to get networks - device owner apps may have access even without location permission
            var networkAccessGranted = hasLocationPermission && isLocationEnabled

            if (!networkAccessGranted && isDeviceOwner) {
                Log.i(TAG, "Device owner app - attempting to access networks despite location restrictions")
                networkAccessGranted = true // Give device owner a chance
            }

            if (!networkAccessGranted) {
                wifiInfo["error"] = "Location permission not granted or location services disabled. Required for WiFi network access."
                Log.w(TAG, "Network access not granted - permission: $hasLocationPermission, location: $isLocationEnabled, deviceOwner: $isDeviceOwner")
            } else {
                try {
                    val networks = wifiManager.configuredNetworks
                    Log.i(TAG, "Configured networks count: ${networks?.size ?: 0}")

                    if (networks != null && networks.isNotEmpty()) {
                        // Use a map to deduplicate by SSID, keeping the connected one if present
                        val networkMap = mutableMapOf<String, Map<String, Any>>()
                        
                        for (network in networks) {
                            val isConnected = connectionInfo != null && connectionInfo.networkId == network.networkId
                            val ssid = network.SSID?.removeSurrounding("\"") ?: "Unknown"
                            Log.i(TAG, "Processing network: $ssid (ID: ${network.networkId})")
                            
                            val networkData = mapOf(
                                "ssid" to ssid,
                                "networkId" to network.networkId,
                                "status" to if (isConnected) "connected" else "saved"
                            )
                            
                            // If this SSID already exists, prefer the connected one
                            if (!networkMap.containsKey(ssid) || isConnected) {
                                networkMap[ssid] = networkData
                            }
                        }
                        
                        configuredNetworks.addAll(networkMap.values)
                        Log.i(TAG, "Total unique configured networks added: ${configuredNetworks.size}")
                    } else {
                        Log.w(TAG, "No configured networks found or list is empty")
                        if (isDeviceOwner) {
                            wifiInfo["error"] = "No saved WiFi networks found. As device owner, this may indicate no networks have been configured."
                        } else {
                            wifiInfo["error"] = "No saved WiFi networks found. Location access may be required."
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error getting configured networks", e)
                    wifiInfo["error"] = "Error accessing WiFi networks: ${e.message}"
                }
            }
            
            wifiInfo["savedNetworks"] = configuredNetworks
            
            // Check actual internet connectivity (independent of WiFi status)
            wifiInfo["hasInternet"] = checkInternetConnectivity()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error getting WiFi info", e)
            wifiInfo["error"] = e.message ?: "Unknown error"
        }
        
        return wifiInfo
    }
    
    /**
     * Checks actual internet connectivity by attempting to reach Google DNS.
     * This is independent of WiFi connection status.
     */
    private fun checkInternetConnectivity(): Boolean {
        return try {
            val socket = java.net.Socket()
            val socketAddress = java.net.InetSocketAddress("8.8.8.8", 53)
            socket.connect(socketAddress, 1000) // 1 second timeout
            socket.close()
            true
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Checks website connectivity status by attempting HTTP connection.
     * Returns a map with status information.
     * Runs on a background thread to avoid NetworkOnMainThreadException.
     */
    private fun checkWebsiteStatus(url: String): Map<String, Any> {
        val status = mutableMapOf<String, Any>()
        
        try {
            // Use thread to avoid NetworkOnMainThreadException
            val thread = Thread {
                try {
                    val urlObj = java.net.URL(url)
                    val connection = urlObj.openConnection() as java.net.HttpURLConnection
                    connection.connectTimeout = 3000 // 3 seconds
                    connection.readTimeout = 3000
                    connection.requestMethod = "HEAD"
                    
                    val responseCode = connection.responseCode
                    connection.disconnect()
                    
                    status["canConnect"] = true
                    status["responseCode"] = responseCode
                    status["isSuccess"] = responseCode in 200..399
                    
                } catch (e: java.net.UnknownHostException) {
                    status["canConnect"] = false
                    status["error"] = "name_not_resolved"
                    status["errorMessage"] = "DNS resolution failed"
                } catch (e: java.net.ConnectException) {
                    // Connection refused means we CAN connect to network (internet works)
                    // but the server refused the connection
                    status["canConnect"] = true
                    status["isSuccess"] = false
                    status["error"] = "connection_refused"
                    status["errorMessage"] = "Connection refused"
                } catch (e: java.net.SocketTimeoutException) {
                    // Timeout means we CAN connect to network (DNS resolved)
                    // but server didn't respond in time
                    status["canConnect"] = true
                    status["isSuccess"] = false
                    status["error"] = "timed_out"
                    status["errorMessage"] = "Connection timed out"
                } catch (e: Exception) {
                    // Check exception message to identify connection refused errors
                    val errorMsg = e.message?.lowercase() ?: ""
                    val exceptionType = e.javaClass.simpleName
                    android.util.Log.d("MainActivity", "checkWebsiteStatus inner exception: $exceptionType, message: ${e.message}")
                    
                    if (errorMsg.contains("refused") || errorMsg.contains("econnrefused")) {
                        status["canConnect"] = true
                        status["isSuccess"] = false
                        status["error"] = "connection_refused"
                        status["errorMessage"] = "Connection refused"
                    } else if (errorMsg.contains("timeout") || errorMsg.contains("timed out")) {
                        status["canConnect"] = true
                        status["isSuccess"] = false
                        status["error"] = "timed_out"
                        status["errorMessage"] = "Connection timed out"
                    } else if (errorMsg.contains("unknown host") || errorMsg.contains("unable to resolve")) {
                        status["canConnect"] = false
                        status["error"] = "name_not_resolved"
                        status["errorMessage"] = "DNS resolution failed"
                    } else {
                        status["canConnect"] = false
                        status["error"] = "unknown"
                        status["errorMessage"] = e.message ?: "Unknown error"
                        status["exceptionType"] = exceptionType
                        status["exceptionMessage"] = e.message ?: "null"
                    }
                }
            }
            
            thread.start()
            thread.join(3500) // Wait max 3.5 seconds for thread to complete (3s timeout + 0.5s buffer)
            
            if (thread.isAlive) {
                // Thread didn't finish in time
                thread.interrupt()
                status["canConnect"] = false
                status["error"] = "timed_out"
                status["errorMessage"] = "Connection check timed out"
            }
            
        } catch (e: Exception) {
            // Outer exception handling for thread issues
            status["canConnect"] = false
            status["error"] = "unknown"
            status["errorMessage"] = e.message ?: "Unknown error"
            status["exceptionType"] = e.javaClass.simpleName
            status["exceptionMessage"] = e.message ?: "null"
        }
        
        return status
    }
    
    /**
     * Calculates signal strength from RSSI value.
     * Returns a string like "Excellent", "Good", "Fair", "Weak", "Poor"
     */
    private fun calculateSignalStrength(rssi: Int): String {
        return when {
            rssi >= -50 -> "Excellent"
            rssi >= -60 -> "Good"
            rssi >= -70 -> "Fair"
            rssi >= -80 -> "Weak"
            else -> "Poor"
        }
    }
    
    /**
     * Resets the internet connection by toggling WiFi off and on.
     * Requires device owner permissions.
     */
    private fun resetInternet() {
        Log.i(TAG, "Resetting internet connection")
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        
        try {
            // Disable WiFi
            Log.i(TAG, "Disabling WiFi")
            wifiManager.isWifiEnabled = false
            
            // Wait a moment
            Thread.sleep(2000)
            
            // Re-enable WiFi
            Log.i(TAG, "Re-enabling WiFi")
            wifiManager.isWifiEnabled = true
            
            Log.i(TAG, "Internet reset completed")
        } catch (e: Exception) {
            Log.e(TAG, "Error resetting internet", e)
            throw e
        }
    }

    /**
     * Test internet speed by downloading a test file.
     * Returns immediately and sends progress updates via method channel.
     */
    private fun testInternetSpeed(): Map<String, Any> {
        // Start test in background thread
        Thread {
            try {
                // Try multiple test URLs until one succeeds
                val testUrls = listOf(
                    "http://ipv4.download.thinkbroadband.com/100MB.zip",
                    "http://212.183.159.230/100MB.zip",
                    "http://speedtest.ftp.otenet.gr/files/test100Mb.db"
                )
                
                var success = false
                for (testUrl in testUrls) {
                    try {
                        Log.i(TAG, "Trying speed test with URL: $testUrl")
                        
                        val url = java.net.URL(testUrl)
                        val connection = url.openConnection() as java.net.HttpURLConnection
                        connection.connectTimeout = 10000
                        connection.readTimeout = 20000
                        connection.requestMethod = "GET"
                        
                        val inputStream = connection.inputStream
                        val buffer = ByteArray(131072) // 128KB buffer
                        
                        val startTime = System.currentTimeMillis()
                        val warmupDuration = 2000L // 2 seconds warmup
                        val testDuration = 12000L // 10 seconds test after warmup
                        var totalBytes = 0L
                        var measurementBytes = 0L
                        var measurementStartTime = 0L
                        var measurementStarted = false
                        var lastUpdateTime = startTime
                        var bytesRead: Int
                        
                        while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                            totalBytes += bytesRead
                            if (measurementStarted) {
                                measurementBytes += bytesRead
                            }
                            
                            val elapsed = System.currentTimeMillis() - startTime
                            
                            // Start measurement after warmup
                            if (elapsed >= warmupDuration && !measurementStarted) {
                                measurementStartTime = System.currentTimeMillis()
                                measurementBytes = 0L
                                measurementStarted = true
                                Log.i(TAG, "Warmup complete, starting measurement")
                            }
                            
                            // Send progress update every 200ms during measurement
                            if (measurementStarted && elapsed - (lastUpdateTime - startTime) >= 200) {
                                val measurementDuration = (System.currentTimeMillis() - measurementStartTime) / 1000.0
                                if (measurementDuration > 0) {
                                    val megabits = (measurementBytes * 8) / 1_000_000.0
                                    val currentSpeed = megabits / measurementDuration
                                    
                                    runOnUiThread {
                                        val progressData = mapOf(
                                            "downloadSpeed" to currentSpeed,
                                            "bytesDownloaded" to measurementBytes,
                                            "durationMs" to (System.currentTimeMillis() - measurementStartTime),
                                            "isComplete" to false
                                        )
                                        methodChannel?.invokeMethod("speedTestProgress", progressData)
                                    }
                                }
                                lastUpdateTime = System.currentTimeMillis()
                            }
                            
                            // Stop after total duration
                            if (elapsed >= testDuration) {
                                break
                            }
                        }
                        
                        inputStream.close()
                        connection.disconnect()
                        
                        // Calculate final speed
                        val measurementDuration = if (measurementStarted && measurementStartTime > 0) {
                            (System.currentTimeMillis() - measurementStartTime) / 1000.0
                        } else {
                            (System.currentTimeMillis() - startTime) / 1000.0
                        }
                        val finalBytes = if (measurementStarted) measurementBytes else totalBytes
                        val megabits = (finalBytes * 8) / 1_000_000.0
                        val speedMbps = megabits / measurementDuration
                        
                        // Send final result
                        runOnUiThread {
                            val result = mapOf(
                                "downloadSpeed" to speedMbps,
                                "bytesDownloaded" to finalBytes,
                                "durationMs" to (measurementDuration * 1000).toLong(),
                                "secondsAgo" to 0,
                                "isComplete" to true
                            )
                            methodChannel?.invokeMethod("speedTestProgress", result)
                        }
                        
                        Log.i(TAG, "Speed test completed: $speedMbps Mbps ($finalBytes bytes in ${measurementDuration}s)")
                        success = true
                        break
                    } catch (e: Exception) {
                        Log.e(TAG, "Error with URL $testUrl: ${e.message}", e)
                        // Continue to next URL
                    }
                }
                
                if (!success) {
                    runOnUiThread {
                        val result = mapOf(
                            "downloadSpeed" to 0.0,
                            "bytesDownloaded" to 0L,
                            "durationMs" to 0L,
                            "isComplete" to true,
                            "error" to "All test URLs failed"
                        )
                        methodChannel?.invokeMethod("speedTestProgress", result)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in speed test", e)
                runOnUiThread {
                    val result = mapOf(
                        "downloadSpeed" to 0.0,
                        "bytesDownloaded" to 0L,
                        "durationMs" to 0L,
                        "isComplete" to true,
                        "error" to (e.message ?: "Unknown error")
                    )
                    methodChannel?.invokeMethod("speedTestProgress", result)
                }
            }
        }.start()
        
        // Return immediately
        return mapOf("status" to "started")
    }

    private fun hasPhysicalKeyboard(): Boolean {
        return try {
            val config = resources.configuration
            config.keyboard != android.content.res.Configuration.KEYBOARD_NOKEYS
        } catch (e: Exception) {
            Log.e(TAG, "Error checking keyboard", e)
            false
        }
    }

    private fun getDeviceModel(): Map<String, String> {
        // Get device name from Settings.Global.DEVICE_NAME (marketing name like "Galaxy A12")
        val deviceName = try {
            Settings.Global.getString(contentResolver, Settings.Global.DEVICE_NAME) ?: ""
        } catch (e: Exception) {
            ""
        }
        
        // Get serial number - try multiple methods
        val serialNumber = getDeviceSerialNumber()
        
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "product" to Build.PRODUCT,
            "deviceName" to deviceName,
            "serialNumber" to serialNumber,
            "androidVersion" to Build.VERSION.RELEASE,
            "securityPatch" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Build.VERSION.SECURITY_PATCH else ""
        )
    }
    
    private fun getDeviceSerialNumber(): String {
        // Method 1: Try Build.getSerial() with READ_PHONE_STATE permission
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val serial = Build.getSerial()
                if (serial.isNotEmpty() && serial != "unknown") {
                    Log.i(TAG, "Serial from Build.getSerial(): $serial")
                    return serial
                }
            } else {
                @Suppress("DEPRECATION")
                val serial = Build.SERIAL
                if (serial.isNotEmpty() && serial != "unknown") {
                    Log.i(TAG, "Serial from Build.SERIAL: $serial")
                    return serial
                }
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Build.getSerial() security exception: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Build.getSerial() error: ${e.message}")
        }
        
        // Method 2: Try system property via reflection
        try {
            val c = Class.forName("android.os.SystemProperties")
            val get = c.getMethod("get", String::class.java)
            val serial = get.invoke(c, "ro.serialno") as? String
            if (!serial.isNullOrEmpty() && serial != "unknown") {
                Log.i(TAG, "Serial from ro.serialno: $serial")
                return serial
            }
            // Try alternative property names
            val serial2 = get.invoke(c, "ril.serialnumber") as? String
            if (!serial2.isNullOrEmpty() && serial2 != "unknown") {
                Log.i(TAG, "Serial from ril.serialnumber: $serial2")
                return serial2
            }
            val serial3 = get.invoke(c, "ro.boot.serialno") as? String
            if (!serial3.isNullOrEmpty() && serial3 != "unknown") {
                Log.i(TAG, "Serial from ro.boot.serialno: $serial3")
                return serial3
            }
        } catch (e: Exception) {
            Log.w(TAG, "SystemProperties method failed: ${e.message}")
        }
        
        // Method 3: Try reading from /sys/class/android_usb/android0/iSerial
        try {
            val file = java.io.File("/sys/class/android_usb/android0/iSerial")
            if (file.exists() && file.canRead()) {
                val serial = file.readText().trim()
                if (serial.isNotEmpty() && serial != "unknown") {
                    Log.i(TAG, "Serial from iSerial file: $serial")
                    return serial
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "iSerial file read failed: ${e.message}")
        }
        
        // Method 4: Fallback to Android ID (unique but not the hardware serial)
        try {
            val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
            if (!androidId.isNullOrEmpty()) {
                Log.i(TAG, "Using Android ID as fallback: $androidId")
                return androidId
            }
        } catch (e: Exception) {
            Log.e(TAG, "Android ID fallback failed: ${e.message}")
        }
        
        return ""
    }

    private fun getBluetoothDevices(): List<Map<String, Any>> {
        val devicesList = mutableListOf<Map<String, Any>>()
        
        try {
            Log.i(TAG, "Getting Bluetooth devices - API Level: ${Build.VERSION.SDK_INT}")
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+ - Check for BLUETOOTH_CONNECT permission
                val hasBluetoothConnect = ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
                Log.i(TAG, "BLUETOOTH_CONNECT permission: ${if (hasBluetoothConnect) "GRANTED" else "DENIED"}")
                
                if (!hasBluetoothConnect) {
                    Log.w(TAG, "BLUETOOTH_CONNECT permission not granted")
                    return devicesList
                }
            } else {
                // Pre-Android 12 - Check for basic Bluetooth permission
                val hasBluetooth = ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH) == PackageManager.PERMISSION_GRANTED
                Log.i(TAG, "BLUETOOTH permission: ${if (hasBluetooth) "GRANTED" else "DENIED"}")
            }
            
            val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            if (bluetoothManager == null) {
                Log.e(TAG, "BluetoothManager is null")
                return devicesList
            }
            
            val bluetoothAdapter: BluetoothAdapter? = bluetoothManager.adapter
            if (bluetoothAdapter == null) {
                Log.e(TAG, "Bluetooth adapter not available")
                return devicesList
            }
            
            Log.i(TAG, "Bluetooth adapter state: ${bluetoothAdapter.state}, enabled: ${bluetoothAdapter.isEnabled}")
            
            if (!bluetoothAdapter.isEnabled) {
                Log.w(TAG, "Bluetooth is not enabled")
                return devicesList
            }
            
            // Get list of connected devices across all profiles
            val connectedDevices = mutableSetOf<String>()
            
            // Helper function to safely get connected devices for a profile
            fun tryGetConnectedDevices(profile: Int, profileName: String) {
                try {
                    val devices = bluetoothManager.getConnectedDevices(profile)
                    devices.forEach { device ->
                        try {
                            connectedDevices.add(device.address)
                            Log.d(TAG, "Found connected device on $profileName: ${device.address}")
                        } catch (e: SecurityException) {
                            Log.w(TAG, "Security exception accessing device on $profileName")
                        }
                    }
                } catch (e: IllegalArgumentException) {
                    Log.d(TAG, "Profile $profileName not supported on this device")
                } catch (e: SecurityException) {
                    Log.w(TAG, "Security exception for $profileName profile")
                } catch (e: Exception) {
                    Log.w(TAG, "Error getting connected devices for $profileName: ${e.message}")
                }
            }
            
            // Try to get connected devices from various profiles
            tryGetConnectedDevices(android.bluetooth.BluetoothProfile.GATT, "GATT")
            tryGetConnectedDevices(android.bluetooth.BluetoothProfile.A2DP, "A2DP")
            tryGetConnectedDevices(android.bluetooth.BluetoothProfile.HEADSET, "HEADSET")
            tryGetConnectedDevices(android.bluetooth.BluetoothProfile.GATT_SERVER, "GATT_SERVER")
            
            // HID_HOST profile for keyboards and mice (API 30+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                tryGetConnectedDevices(4, "HID_HOST") // BluetoothProfile.HID_HOST
            }
            
            // HEARING_AID profile (API 28+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                tryGetConnectedDevices(android.bluetooth.BluetoothProfile.HEARING_AID, "HEARING_AID")
            }
            
            // LE_AUDIO profile (API 33+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                tryGetConnectedDevices(22, "LE_AUDIO") // BluetoothProfile.LE_AUDIO
            }
            
            Log.i(TAG, "Found ${connectedDevices.size} actively connected device addresses")
            
            // Get bonded (paired) devices
            val bondedDevices: Set<BluetoothDevice>? = try {
                bluetoothAdapter.bondedDevices
            } catch (e: SecurityException) {
                Log.e(TAG, "Security exception getting bonded devices: ${e.message}")
                null
            }
            
            if (bondedDevices == null) {
                Log.w(TAG, "bondedDevices is null")
                return devicesList
            }
            
            Log.i(TAG, "Found ${bondedDevices.size} bonded devices")
            
            bondedDevices.forEach { device ->
                try {
                    val deviceInfo = mutableMapOf<String, Any>()
                    val name = try { device.name } catch (e: SecurityException) { null }
                    val address = try { device.address } catch (e: SecurityException) { null }
                    
                    deviceInfo["name"] = name ?: "Unknown Device"
                    deviceInfo["address"] = address ?: "Unknown"
                    
                    Log.d(TAG, "Device: ${deviceInfo["name"]} (${deviceInfo["address"]})")
                    
                    // Check if device is actively connected using reflection
                    val isConnected = try {
                        val method = device.javaClass.getMethod("isConnected")
                        method.invoke(device) as? Boolean ?: false
                    } catch (e: Exception) {
                        // Fallback: check if device is in the connectedDevices set from profiles
                        address?.let { connectedDevices.contains(it) } ?: false
                    }
                    
                    // Use boolean for connection status (more reliable than string comparison)
                    deviceInfo["isConnected"] = isConnected
                    Log.d(TAG, "  Connection status: isConnected=$isConnected")
                    
                    // Check bond state
                    val bondState = when (device.bondState) {
                        BluetoothDevice.BOND_BONDED -> "Paired"
                        BluetoothDevice.BOND_BONDING -> "Pairing"
                        BluetoothDevice.BOND_NONE -> "Not Paired"
                        else -> "Unknown"
                    }
                    deviceInfo["bondState"] = bondState
                    Log.d(TAG, "  Bond state: $bondState")
                    
                    // Try to determine device type
                    val deviceName = (name ?: "").lowercase()
                    
                    // First check device name for scanner/barcode reader keywords
                    val deviceType = when {
                        // Check for scanner/barcode reader keywords in name
                        deviceName.contains("scan") || 
                        deviceName.contains("barcode") || 
                        deviceName.contains("granit") || 
                        deviceName.contains("honeywell") || 
                        deviceName.contains("zebra") || 
                        deviceName.contains("datalogic") || 
                        deviceName.contains("symbol") || 
                        deviceName.contains("voyager") || 
                        deviceName.contains("reader") -> {
                            Log.d(TAG, "  Device detected as Scanner by name: $name")
                            "Scanner"
                        }
                        else -> {
                            // Fall back to Bluetooth class detection
                            val deviceClass = device.bluetoothClass
                            when {
                                deviceClass == null -> {
                                    Log.d(TAG, "  Device class is null")
                                    "Unknown"
                                }
                                deviceClass.majorDeviceClass == 0x0500 -> {
                                    // Peripheral devices - check minor class for specific type
                                    val deviceMinorClass = deviceClass.deviceClass and 0xFF
                                    when {
                                        deviceMinorClass and 0x40 != 0 -> {
                                            Log.d(TAG, "  Device class: 0x0500 minor 0x40 (Keyboard)")
                                            "Keyboard"
                                        }
                                        deviceMinorClass and 0x80 != 0 -> {
                                            Log.d(TAG, "  Device class: 0x0500 minor 0x80 (Pointing Device)")
                                            "Mouse"
                                        }
                                        deviceMinorClass and 0x10 != 0 -> {
                                            Log.d(TAG, "  Device class: 0x0500 minor 0x10 (Scanner/Remote)")
                                            "Scanner"
                                        }
                                        else -> {
                                            Log.d(TAG, "  Device class: 0x0500 minor 0x${deviceMinorClass.toString(16)} (Peripheral)")
                                            "Peripheral"
                                        }
                                    }
                                }
                                deviceClass.majorDeviceClass == 0x0400 -> {
                                    Log.d(TAG, "  Device class: 0x0400 (Audio)")
                                    "Audio"
                                }
                                deviceClass.majorDeviceClass == 0x0200 -> {
                                    Log.d(TAG, "  Device class: 0x0200 (Phone)")
                                    "Phone"
                                }
                                deviceClass.majorDeviceClass == 0x0100 -> {
                                    Log.d(TAG, "  Device class: 0x0100 (Computer)")
                                    "Computer"
                                }
                                else -> {
                                    Log.d(TAG, "  Device class: 0x${deviceClass.majorDeviceClass.toString(16)} (Other)")
                                    "Other"
                                }
                            }
                        }
                    }
                    deviceInfo["type"] = deviceType
                    
                    devicesList.add(deviceInfo)
                    Log.i(TAG, "Added device: ${deviceInfo["name"]} - ${deviceInfo["type"]} - ${deviceInfo["connected"]}")
                } catch (e: SecurityException) {
                    Log.e(TAG, "Security exception accessing device: ${e.message}")
                } catch (e: Exception) {
                    Log.e(TAG, "Exception accessing device: ${e.message}", e)
                }
            }
            
            Log.i(TAG, "Returning ${devicesList.size} Bluetooth devices")
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception in getBluetoothDevices", e)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting Bluetooth devices", e)
        }
        
        return devicesList
    }

    private fun registerBluetoothReceiver() {
        if (bluetoothReceiver != null) return
        
        bluetoothReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    BluetoothDevice.ACTION_ACL_CONNECTED,
                    BluetoothDevice.ACTION_ACL_DISCONNECTED,
                    BluetoothAdapter.ACTION_STATE_CHANGED,
                    BluetoothDevice.ACTION_BOND_STATE_CHANGED -> {
                        Log.d(TAG, "Bluetooth event received: ${intent.action}")
                        sendBluetoothUpdate()
                    }
                }
            }
        }
        
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        }
        
        // Bluetooth broadcasts come from the system, so we need RECEIVER_EXPORTED
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(bluetoothReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(bluetoothReceiver, filter)
        }
        Log.d(TAG, "Bluetooth receiver registered")
        
        // Send initial state
        sendBluetoothUpdate()
    }
    
    private fun unregisterBluetoothReceiver() {
        bluetoothReceiver?.let {
            try {
                unregisterReceiver(it)
                Log.d(TAG, "Bluetooth receiver unregistered")
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering Bluetooth receiver", e)
            }
        }
        bluetoothReceiver = null
    }
    
    private fun sendBluetoothUpdate() {
        try {
            val devices = getBluetoothDevices()
            runOnUiThread {
                // Send to all registered sinks, removing any that fail
                val iterator = bluetoothEventSinks.iterator()
                while (iterator.hasNext()) {
                    try {
                        iterator.next().success(devices)
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to send to EventSink, removing: ${e.message}")
                        iterator.remove()
                    }
                }
                Log.d(TAG, "Sent Bluetooth update to ${bluetoothEventSinks.size} listeners")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending Bluetooth update", e)
        }
    }

    // Developer mode and USB settings functions
    
    private fun isDeveloperModeEnabled(): Boolean {
        return try {
            val enabled = Settings.Global.getInt(
                contentResolver,
                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                0
            )
            Log.i(TAG, "Developer mode enabled: ${enabled == 1}")
            enabled == 1
        } catch (e: Exception) {
            Log.e(TAG, "Error checking developer mode", e)
            false
        }
    }
    
    private fun setDeveloperMode(enabled: Boolean): Boolean {
        return try {
            val admin = adminComponent
            if (devicePolicyManager?.isDeviceOwnerApp(packageName) == true && admin != null) {
                // Use DevicePolicyManager to set system setting
                devicePolicyManager?.setSystemSetting(
                    admin,
                    Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                    if (enabled) "1" else "0"
                )
                Log.i(TAG, "Developer mode ${if (enabled) "enabled" else "disabled"} via DevicePolicyManager")
                
                // If disabling developer mode, also disable USB debugging
                if (!enabled) {
                    setUsbDebugging(false)
                }
                
                true
            } else {
                Log.w(TAG, "Not device owner, cannot set developer mode")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting developer mode", e)
            false
        }
    }
    
    private fun isUsbDebuggingEnabled(): Boolean {
        return try {
            val enabled = Settings.Global.getInt(
                contentResolver,
                Settings.Global.ADB_ENABLED,
                0
            )
            Log.i(TAG, "USB debugging enabled: ${enabled == 1}")
            enabled == 1
        } catch (e: Exception) {
            Log.e(TAG, "Error checking USB debugging", e)
            false
        }
    }
    
    private fun setUsbDebugging(enabled: Boolean): Boolean {
        return try {
            val admin = adminComponent
            if (devicePolicyManager?.isDeviceOwnerApp(packageName) == true && admin != null) {
                // Use DevicePolicyManager to set system setting
                devicePolicyManager?.setSystemSetting(
                    admin,
                    Settings.Global.ADB_ENABLED,
                    if (enabled) "1" else "0"
                )
                Log.i(TAG, "USB debugging ${if (enabled) "enabled" else "disabled"} via DevicePolicyManager")
                true
            } else {
                Log.w(TAG, "Not device owner, cannot set USB debugging")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting USB debugging", e)
            false
        }
    }
    
    private fun isUsbFileTransferEnabled(): Boolean {
        return try {
            // Check if USB is configured for file transfer (MTP mode)
            // This is typically controlled by the USB connection mode
            val usbManager = getSystemService(Context.USB_SERVICE) as? UsbManager
            
            if (usbManager == null) {
                Log.w(TAG, "UsbManager not available")
                return false
            }
            
            // Try to check if MTP is enabled via system property
            try {
                val getProp = Runtime.getRuntime().exec("getprop sys.usb.config")
                val reader = java.io.BufferedReader(java.io.InputStreamReader(getProp.inputStream))
                val config = reader.readLine() ?: ""
                reader.close()
                
                val isMtpEnabled = config.contains("mtp") || config.contains("file_transfer")
                Log.i(TAG, "USB config: $config, MTP enabled: $isMtpEnabled")
                isMtpEnabled
            } catch (e: Exception) {
                Log.w(TAG, "Could not read USB config property: ${e.message}")
                // Fallback: assume enabled if developer mode is on
                isDeveloperModeEnabled()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking USB file transfer", e)
            false
        }
    }
    
    private fun setUsbFileTransfer(enabled: Boolean): Boolean {
        return try {
            // Setting USB file transfer mode requires changing USB configuration
            // This can be done via system properties but requires shell access
            
            val command = if (enabled) {
                "svc usb setFunctions mtp"
            } else {
                "svc usb setFunctions"
            }
            
            Log.i(TAG, "Attempting to set USB mode with command: $command")
            
            val process = Runtime.getRuntime().exec(command)
            val exitCode = process.waitFor()
            
            if (exitCode == 0) {
                Log.i(TAG, "USB file transfer ${if (enabled) "enabled" else "disabled"} successfully")
                true
            } else {
                val errorReader = java.io.BufferedReader(java.io.InputStreamReader(process.errorStream))
                val errorOutput = errorReader.readText()
                errorReader.close()
                Log.w(TAG, "Failed to set USB mode, exit code: $exitCode, error: $errorOutput")
                
                // Alternative approach: try using setprop
                try {
                    val propertyCommand = if (enabled) {
                        "setprop persist.sys.usb.config mtp,adb"
                    } else {
                        "setprop persist.sys.usb.config none"
                    }
                    
                    val propProcess = Runtime.getRuntime().exec(propertyCommand)
                    val propExitCode = propProcess.waitFor()
                    
                    if (propExitCode == 0) {
                        Log.i(TAG, "USB file transfer ${if (enabled) "enabled" else "disabled"} via setprop")
                        true
                    } else {
                        Log.w(TAG, "setprop also failed with exit code: $propExitCode")
                        false
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "setprop approach failed: ${e.message}")
                    false
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting USB file transfer", e)
            false
        }
    }

    private fun uninstallApp(): Boolean {
        return try {
            Log.i(TAG, "Requesting app uninstall")
            
            // Create intent to open app info settings where user can uninstall
            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            val uri = android.net.Uri.fromParts("package", packageName, null)
            intent.data = uri
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            
            // Start the app info activity
            startActivity(intent)
            
            Log.i(TAG, "App info screen opened successfully")
            
            // Close the app to allow the user to uninstall
            android.os.Handler(mainLooper).postDelayed({
                Log.i(TAG, "Closing app to allow uninstall")
                finishAndRemoveTask()
            }, 500)
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error opening app info", e)
            false
        }
    }

    private fun factoryReset(): Boolean {
        return try {
            Log.i(TAG, "Opening factory reset settings")
            
            var opened = false
            
            // Method 1: Try direct component name (works on most Samsung/stock Android)
            if (!opened) {
                try {
                    val intent = Intent()
                    intent.setClassName("com.android.settings", "com.android.settings.Settings\$ResetDashboardFragmentActivity")
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    Log.i(TAG, "Opened via ResetDashboardFragmentActivity")
                    opened = true
                } catch (e: Exception) {
                    Log.w(TAG, "ResetDashboardFragmentActivity not available: ${e.message}")
                }
            }
            
            // Method 2: Try MasterClear activity (older Android versions)
            if (!opened) {
                try {
                    val intent = Intent()
                    intent.setClassName("com.android.settings", "com.android.settings.MasterClear")
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    Log.i(TAG, "Opened via MasterClear activity")
                    opened = true
                } catch (e: Exception) {
                    Log.w(TAG, "MasterClear activity not available: ${e.message}")
                }
            }
            
            // Method 3: Try Settings with fragment parameter
            if (!opened) {
                try {
                    val intent = Intent(android.provider.Settings.ACTION_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    intent.putExtra(":settings:show_fragment", "com.android.settings.MasterClear")
                    startActivity(intent)
                    Log.i(TAG, "Opened Settings with MasterClear fragment")
                    opened = true
                } catch (e: Exception) {
                    Log.w(TAG, "Fragment navigation failed: ${e.message}")
                }
            }
            
            // Method 4: Try Privacy Settings (some Android versions)
            if (!opened) {
                try {
                    val intent = Intent(android.provider.Settings.ACTION_PRIVACY_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    Log.i(TAG, "Opened Privacy Settings")
                    opened = true
                } catch (e: Exception) {
                    Log.w(TAG, "Privacy Settings failed: ${e.message}")
                }
            }
            
            // Method 5: Final fallback - open main Settings
            if (!opened) {
                val intent = Intent(android.provider.Settings.ACTION_SETTINGS)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
                Log.i(TAG, "Opened main Settings as final fallback")
            }
            
            // Close the app to allow the user to perform factory reset
            android.os.Handler(mainLooper).postDelayed({
                Log.i(TAG, "Closing app to allow factory reset")
                finishAndRemoveTask()
            }, 500)
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error opening factory reset settings", e)
            false
        }
    }

    private fun isLocationPermissionGranted(): Boolean {
        return try {
            val fineLocation = checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION)
            val coarseLocation = checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION)
            
            val granted = fineLocation == android.content.pm.PackageManager.PERMISSION_GRANTED &&
                         coarseLocation == android.content.pm.PackageManager.PERMISSION_GRANTED
            
            Log.i(TAG, "Location permission granted: $granted")
            granted
        } catch (e: Exception) {
            Log.e(TAG, "Error checking location permission", e)
            false
        }
    }

    private fun isBackgroundLocationGranted(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val backgroundLocation = checkSelfPermission(android.Manifest.permission.ACCESS_BACKGROUND_LOCATION)
                val granted = backgroundLocation == android.content.pm.PackageManager.PERMISSION_GRANTED
                Log.i(TAG, "Background location permission granted: $granted")
                granted
            } else {
                // Before Android 10, background location is granted with foreground location
                val fineGranted = isLocationPermissionGranted()
                Log.i(TAG, "Background location (pre-Q): $fineGranted")
                fineGranted
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking background location permission", e)
            false
        }
    }

    private fun isPreciseLocationEnabled(): Boolean {
        return try {
            val fineLocation = checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION)
            val enabled = fineLocation == android.content.pm.PackageManager.PERMISSION_GRANTED
            Log.i(TAG, "Precise location enabled: $enabled")
            enabled
        } catch (e: Exception) {
            Log.e(TAG, "Error checking precise location", e)
            false
        }
    }

    private fun requestLocationPermission() {
        try {
            Log.i(TAG, "Requesting location permissions")
            
            // Use Device Owner API to grant permissions without user interaction
            val admin = adminComponent
            if (devicePolicyManager?.isDeviceOwnerApp(packageName) == true && admin != null) {
                try {
                    // Grant location permissions as Device Owner
                    devicePolicyManager?.setPermissionGrantState(
                        admin,
                        packageName,
                        android.Manifest.permission.ACCESS_FINE_LOCATION,
                        android.app.admin.DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED
                    )
                    devicePolicyManager?.setPermissionGrantState(
                        admin,
                        packageName,
                        android.Manifest.permission.ACCESS_COARSE_LOCATION,
                        android.app.admin.DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED
                    )
                    
                    // Grant background location on Android 10+
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        devicePolicyManager?.setPermissionGrantState(
                            admin,
                            packageName,
                            android.Manifest.permission.ACCESS_BACKGROUND_LOCATION,
                            android.app.admin.DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED
                        )
                    }
                    
                    Log.i(TAG, "Location permissions granted via Device Owner")
                } catch (e: Exception) {
                    Log.e(TAG, "Error granting permissions via Device Owner: $e")
                    // Fallback to requesting normally
                    requestLocationPermissionsNormally()
                }
            } else {
                // Not Device Owner, request normally
                requestLocationPermissionsNormally()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting location permission", e)
        }
    }
    
    private fun requestLocationPermissionsNormally() {
        try {
            val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                arrayOf(
                    android.Manifest.permission.ACCESS_FINE_LOCATION,
                    android.Manifest.permission.ACCESS_COARSE_LOCATION,
                    android.Manifest.permission.ACCESS_BACKGROUND_LOCATION
                )
            } else {
                arrayOf(
                    android.Manifest.permission.ACCESS_FINE_LOCATION,
                    android.Manifest.permission.ACCESS_COARSE_LOCATION
                )
            }
            
            requestPermissions(permissions, 1001)
            Log.i(TAG, "Requested location permissions via normal flow")
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting permissions normally", e)
        }
    }

    private fun applySystemUiMode(alwaysShowTopBar: Boolean) {
        try {
            window?.decorView?.let { decorView ->
                // Set status bar color based on mode
                if (alwaysShowTopBar) {
                    // Semi-transparent dark background for status bar
                    window?.statusBarColor = 0x88000000.toInt() // 53% opacity black
                } else {
                    // Fully transparent when hidden
                    window?.statusBarColor = 0x00000000.toInt()
                }
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    // Android 11+ (API 30+) - Use WindowInsetsController
                    window?.setDecorFitsSystemWindows(false)
                    window?.insetsController?.let { controller ->
                        if (alwaysShowTopBar) {
                            // Show status bar, hide navigation bar with sticky immersive
                            controller.show(android.view.WindowInsets.Type.statusBars())
                            controller.hide(android.view.WindowInsets.Type.navigationBars())
                            controller.systemBarsBehavior = android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                            // Set light icons on dark background
                            controller.setSystemBarsAppearance(
                                0,
                                android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                            )
                        } else {
                            // Hide both bars with sticky immersive
                            controller.hide(android.view.WindowInsets.Type.systemBars())
                            controller.systemBarsBehavior = android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                        }
                    }
                } else {
                    // Android 10 and below - Use system UI flags
                    var flags = (View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION)
                    
                    if (alwaysShowTopBar) {
                        // Hide navigation bar with immersive sticky, keep status bar visible
                        // Remove light status bar flag to show light icons on dark background
                        flags = flags or 
                                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    } else {
                        // Hide both bars with immersive sticky
                        flags = flags or
                                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                                View.SYSTEM_UI_FLAG_FULLSCREEN or
                                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    }
                    
                    decorView.systemUiVisibility = flags
                }
                
                Log.i(TAG, "Applied system UI mode: alwaysShowTopBar=$alwaysShowTopBar")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error applying system UI mode", e)
        }
    }

    private fun setScreenTimeout(timeout: Int): Boolean {
        try {
            // Use timeout value as-is (no longer converting -1 to Integer.MAX_VALUE)
            val timeoutValue = timeout
            
            // Set screen timeout directly using Settings.System
            // This works because we have WRITE_SECURE_SETTINGS permission as Device Owner
            val result = Settings.System.putInt(
                contentResolver,
                Settings.System.SCREEN_OFF_TIMEOUT,
                timeoutValue
            )
            
            if (result) {
                Log.i(TAG, "Screen timeout successfully set to: $timeout ms")
            } else {
                Log.e(TAG, "Failed to set screen timeout - putInt returned false")
            }
            
            return result
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException setting screen timeout - missing WRITE_SECURE_SETTINGS permission?", e)
            return false
        } catch (e: Exception) {
            Log.e(TAG, "Error setting screen timeout", e)
            return false
        }
    }

    private fun getScreenTimeout(): Int {
        try {
            // Get current screen timeout from system settings
            val timeoutValue = Settings.System.getInt(
                contentResolver,
                Settings.System.SCREEN_OFF_TIMEOUT,
                60000 // Default: 1 minute
            )
            
            // Return timeout value as-is (no conversion needed)
            Log.i(TAG, "Current screen timeout: $timeoutValue ms")
            return timeoutValue
        } catch (e: Exception) {
            Log.e(TAG, "Error getting screen timeout", e)
            return 60000 // Default: 1 minute
        }
    }

    private fun setScreenOrientation(autoRotation: Boolean) {
        try {
            // Set Android system auto-rotation setting
            val result = Settings.System.putInt(
                contentResolver,
                Settings.System.ACCELEROMETER_ROTATION,
                if (autoRotation) 1 else 0
            )
            
            if (result) {
                if (autoRotation) {
                    // Enable auto-rotation - let activity follow sensor
                    requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR
                    Log.i(TAG, "Auto-rotation ENABLED in system settings and activity")
                } else {
                    // Disable auto-rotation - lock to current orientation
                    val currentOrientation = resources.configuration.orientation
                    
                    if (currentOrientation == android.content.res.Configuration.ORIENTATION_LANDSCAPE) {
                        // Lock to landscape
                        Settings.System.putInt(
                            contentResolver,
                            Settings.System.USER_ROTATION,
                            android.view.Surface.ROTATION_90 // Landscape
                        )
                        requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                        Log.i(TAG, "Auto-rotation DISABLED in system settings, locked to LANDSCAPE")
                    } else {
                        // Lock to portrait
                        Settings.System.putInt(
                            contentResolver,
                            Settings.System.USER_ROTATION,
                            android.view.Surface.ROTATION_0 // Portrait
                        )
                        requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                        Log.i(TAG, "Auto-rotation DISABLED in system settings, locked to PORTRAIT")
                    }
                }
            } else {
                Log.e(TAG, "Failed to set auto-rotation setting - putInt returned false")
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException setting auto-rotation - missing WRITE_SETTINGS permission?", e)
        } catch (e: Exception) {
            Log.e(TAG, "Error setting screen orientation", e)
        }
    }

    private fun getAutoRotation(): Boolean {
        try {
            // Read Android system auto-rotation setting
            val autoRotationValue = Settings.System.getInt(
                contentResolver,
                Settings.System.ACCELEROMETER_ROTATION,
                1 // Default: enabled
            )
            
            val autoRotation = autoRotationValue == 1
            Log.i(TAG, "Current auto-rotation setting: ${if (autoRotation) "ENABLED" else "DISABLED"}")
            return autoRotation
        } catch (e: Exception) {
            Log.e(TAG, "Error getting auto-rotation setting", e)
            return true // Default: enabled
        }
    }

    private fun getLockedOrientation(): String {
        try {
            val autoRotation = getAutoRotation()
            
            if (autoRotation) {
                // Auto-rotation enabled, return current orientation
                val currentOrientation = resources.configuration.orientation
                return if (currentOrientation == android.content.res.Configuration.ORIENTATION_LANDSCAPE) {
                    "landscape"
                } else {
                    "portrait"
                }
            } else {
                // Auto-rotation disabled, read USER_ROTATION setting
                val userRotation = Settings.System.getInt(
                    contentResolver,
                    Settings.System.USER_ROTATION,
                    android.view.Surface.ROTATION_90 // Default: landscape
                )
                
                // ROTATION_0 or ROTATION_180 = portrait, ROTATION_90 or ROTATION_270 = landscape
                return if (userRotation == android.view.Surface.ROTATION_90 || userRotation == android.view.Surface.ROTATION_270) {
                    "landscape"
                } else {
                    "portrait"
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting locked orientation", e)
            return "landscape"
        }
    }
    
    // ========== App Update Functions ==========
    
    private suspend fun checkForUpdate(): Map<String, Any?> = withContext(Dispatchers.IO) {
        try {
            val apiUrl = "https://api.github.com/repos/Virgile1105/DeviceGate/releases/latest"
            val connection = URL(apiUrl).openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.setRequestProperty("Accept", "application/vnd.github.v3+json")
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            
            val responseCode = connection.responseCode
            if (responseCode != HttpURLConnection.HTTP_OK) {
                Log.w(TAG, "GitHub API returned $responseCode")
                return@withContext mapOf(
                    "hasUpdate" to false,
                    "error" to "GitHub API error: $responseCode"
                )
            }
            
            val response = connection.inputStream.bufferedReader().readText()
            val json = JSONObject(response)
            
            val tagName = json.optString("tag_name", "")
            val releaseName = json.optString("name", tagName)
            val releaseBody = json.optString("body", "")
            
            // Parse version from tag (e.g., "v1.0.2-15" -> version="1.0.2", build=15)
            val tagWithoutPrefix = tagName.removePrefix("v").removePrefix("V")
            val (latestVersion, latestBuild) = parseVersionAndBuild(tagWithoutPrefix)
            
            // Get current app version and build code
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            val currentVersion = packageInfo.versionName ?: "0.0.0"
            val currentBuild = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.longVersionCode.toInt()
            } else {
                @Suppress("DEPRECATION")
                packageInfo.versionCode
            }
            
            // Full version strings for display (e.g., "1.0.1+10")
            val currentFullVersion = "$currentVersion+$currentBuild"
            val latestFullVersion = if (latestBuild > 0) "$latestVersion+$latestBuild" else latestVersion
            
            // Find APK download URL from assets
            var downloadUrl: String? = null
            val assets = json.optJSONArray("assets") ?: JSONArray()
            for (i in 0 until assets.length()) {
                val asset = assets.getJSONObject(i)
                val name = asset.optString("name", "")
                if (name.endsWith(".apk")) {
                    downloadUrl = asset.optString("browser_download_url", null)
                    break
                }
            }
            
            // Compare versions (including build number)
            val hasUpdate = compareVersionsWithBuild(latestVersion, latestBuild, currentVersion, currentBuild) > 0
            
            Log.d(TAG, "Update check: current=$currentFullVersion, latest=$latestFullVersion, hasUpdate=$hasUpdate")
            
            return@withContext mapOf(
                "hasUpdate" to hasUpdate,
                "currentVersion" to currentFullVersion,
                "latestVersion" to latestFullVersion,
                "releaseName" to releaseName,
                "releaseNotes" to releaseBody,
                "downloadUrl" to downloadUrl
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error checking for update", e)
            return@withContext mapOf(
                "hasUpdate" to false,
                "error" to e.message
            )
        }
    }
    
    private fun parseVersionAndBuild(versionString: String): Pair<String, Int> {
        // Parse versions like "1.0.2-15", "1.0.2+15", or "1.0.2"
        val regex = Regex("""^([\d.]+)[-+]?(\d+)?$""")
        val match = regex.find(versionString)
        
        return if (match != null) {
            val version = match.groupValues[1]
            val build = match.groupValues.getOrNull(2)?.toIntOrNull() ?: 0
            Pair(version, build)
        } else {
            // Fallback: treat whole string as version, no build
            Pair(versionString.replace(Regex("[^\\d.]"), ""), 0)
        }
    }
    
    private fun compareVersionsWithBuild(v1: String, build1: Int, v2: String, build2: Int): Int {
        // First compare version numbers
        val versionCompare = compareVersions(v1, v2)
        if (versionCompare != 0) return versionCompare
        
        // If versions are equal, compare build numbers
        return build1.compareTo(build2)
    }
    
    private fun compareVersions(v1: String, v2: String): Int {
        val parts1 = v1.split(".").map { it.toIntOrNull() ?: 0 }
        val parts2 = v2.split(".").map { it.toIntOrNull() ?: 0 }
        val maxLen = maxOf(parts1.size, parts2.size)
        
        for (i in 0 until maxLen) {
            val p1 = parts1.getOrElse(i) { 0 }
            val p2 = parts2.getOrElse(i) { 0 }
            if (p1 != p2) return p1.compareTo(p2)
        }
        return 0
    }
    
    private suspend fun downloadAndInstallUpdate(downloadUrl: String): Boolean = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "Downloading update from: $downloadUrl")
            
            // Download APK to cache directory
            val connection = URL(downloadUrl).openConnection() as HttpURLConnection
            connection.connectTimeout = 30000
            connection.readTimeout = 60000
            
            // Follow redirects (GitHub uses them)
            connection.instanceFollowRedirects = true
            
            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                Log.e(TAG, "Download failed with code: ${connection.responseCode}")
                return@withContext false
            }
            
            val apkFile = File(cacheDir, "update.apk")
            connection.inputStream.use { input ->
                FileOutputStream(apkFile).use { output ->
                    input.copyTo(output)
                }
            }
            
            Log.d(TAG, "APK downloaded to: ${apkFile.absolutePath}, size: ${apkFile.length()}")
            
            // Install the APK
            withContext(Dispatchers.Main) {
                installApk(apkFile)
            }
            
            return@withContext true
        } catch (e: Exception) {
            Log.e(TAG, "Error downloading/installing update", e)
            return@withContext false
        }
    }
    
    private fun installApk(apkFile: File) {
        try {
            val apkUri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                apkFile
            )
            
            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
            }
            
            // Temporarily disable kiosk mode if active
            if (isInKioskMode()) {
                disableKioskMode()
            }
            
            startActivity(installIntent)
            Log.d(TAG, "Install intent started")
        } catch (e: Exception) {
            Log.e(TAG, "Error installing APK", e)
            throw e
        }
    }
}
