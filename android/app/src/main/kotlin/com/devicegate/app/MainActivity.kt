package com.devicegate.app

import android.Manifest
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import io.flutter.Log
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.os.BatteryManager
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

class MainActivity : FlutterActivity() {
    private val CHANNEL = "devicegate.app/shortcut"
    private val BATTERY_CHANNEL = "devicegate.app/battery"
    private val TAG = "DeviceGate"
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var batteryReceiver: BroadcastReceiver? = null
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
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // Setup EventChannel for battery updates
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                Log.i(TAG, "Battery stream listener attached")
                batteryReceiver = createBatteryReceiver(events)
                val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
                registerReceiver(batteryReceiver, filter)
                Log.i(TAG, "Battery receiver registered")
            }
            
            override fun onCancel(arguments: Any?) {
                Log.i(TAG, "Battery stream listener cancelled")
                batteryReceiver?.let { unregisterReceiver(it) }
                batteryReceiver = null
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
                    val isOwner = isDeviceOwner()
                    result.success(isOwner)
                }
                "isInKioskMode" -> {
                    val inKiosk = isInKioskMode()
                    result.success(inKiosk)
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
                "removeDeviceOwner" -> {
                    try {
                        val success = removeDeviceOwner()
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error removing device owner", e)
                        result.error("REMOVE_OWNER_ERROR", e.message, null)
                    }
                }
                "disableSystemKeyboards" -> {
                    try {
                        val success = disableSystemKeyboards()
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error disabling system keyboards", e)
                        result.error("KEYBOARD_ERROR", e.message, null)
                    }
                }
                "enableSystemKeyboards" -> {
                    try {
                        val success = enableSystemKeyboards()
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error enabling system keyboards", e)
                        result.error("KEYBOARD_ERROR", e.message, null)
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
                "forceHideKeyboard" -> {
                    try {
                        forceHideKeyboard()
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error force hiding keyboard", e)
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
                "getBatteryLevel" -> {
                    try {
                        val level = getBatteryLevel()
                        result.success(level)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting battery level", e)
                        result.error("BATTERY_ERROR", e.message, null)
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
    
    private fun enableKioskMode(): Boolean {
        initDevicePolicyManager()
        
        if (!isDeviceOwner()) {
            Log.w(TAG, "App is not a device owner. Cannot enable kiosk mode.")
            return false
        }
        
        try {
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
    
    /**
     * Sets the empty IME as the only permitted keyboard.
     * This replaces all system keyboards (including Gboard) with our invisible IME.
     * Only works when app is device owner.
     */
    private fun disableSystemKeyboards(): Boolean {
        initDevicePolicyManager()
        
        if (!isDeviceOwner()) {
            Log.w(TAG, "Not a device owner, cannot set empty keyboard")
            return false
        }
        
        try {
            // Get input method service to find all IMEs
            val inputMethodManager = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
            val enabledImes = inputMethodManager.enabledInputMethodList
            
            // Save current IMEs before changing
            val imeIds = enabledImes.map { it.id }
            val prefs = getSharedPreferences("DeviceGatePrefs", Context.MODE_PRIVATE)
            prefs.edit().putStringSet("savedSystemKeyboards", imeIds.toSet()).apply()
            
            Log.d(TAG, "Found ${imeIds.size} system keyboards: $imeIds")
            
            // Set permitted input methods to ONLY our empty keyboard
            val emptyImeId = "${packageName}/.EmptyKeyboardService"
            devicePolicyManager?.setPermittedInputMethods(adminComponent!!, listOf(emptyImeId))
            
            Log.d(TAG, "Empty keyboard set as only permitted IME: $emptyImeId")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error setting empty keyboard", e)
            return false
        }
    }
    
    /**
     * Re-enables system keyboards.
     * Called when custom keyboard is disabled or app exits.
     */
    private fun enableSystemKeyboards(): Boolean {
        initDevicePolicyManager()
        
        if (!isDeviceOwner()) {
            Log.w(TAG, "Not a device owner, cannot enable system keyboards")
            return false
        }
        
        try {
            // Set permitted input methods to null (allows all keyboards)
            devicePolicyManager?.setPermittedInputMethods(adminComponent!!, null)
            
            Log.d(TAG, "System keyboards enabled successfully")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error enabling system keyboards", e)
            return false
        }
    }

    /**
     * Aggressively switches to empty IME and hides IME navigation bar.
     * Uses multiple techniques to ensure the IME bar doesn't show:
     * 1. Force enables our empty keyboard if not enabled
     * 2. Force switches to our empty keyboard
     * 3. Sets aggressive window flags to prevent IME bar
     */
    private fun hideImeAggressively() {
        try {
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
            val emptyImeId = "${packageName}/.EmptyKeyboardService"
            
            // Check if our empty IME is enabled
            val enabledImes = imm.enabledInputMethodList
            val isEmptyImeEnabled = enabledImes.any { it.id == emptyImeId }
            
            if (!isEmptyImeEnabled) {
                Log.d(TAG, "Empty IME not enabled yet - user needs to enable it in settings")
                // Try to open IME settings to let user enable it
                try {
                    val intent = android.content.Intent(android.provider.Settings.ACTION_INPUT_METHOD_SETTINGS)
                    intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                } catch (e: Exception) {
                    Log.w(TAG, "Could not open IME settings", e)
                }
            } else {
                Log.d(TAG, "Empty IME is enabled")
            }
            
            // Force switch to our empty keyboard using reflection (requires system permissions or device owner)
            try {
                // Method 1: Try using hidden setInputMethod API
                val setInputMethodMethod = imm.javaClass.getMethod(
                    "setInputMethod",
                    android.os.IBinder::class.java,
                    String::class.java
                )
                window?.decorView?.windowToken?.let { token ->
                    setInputMethodMethod.invoke(imm, token, emptyImeId)
                    Log.d(TAG, "Switched to empty IME using setInputMethod")
                }
            } catch (e: Exception) {
                Log.d(TAG, "setInputMethod not available: ${e.message}")
                
                // Method 2: Try using setInputMethodAndSubtype
                try {
                    val inputMethodInfo = enabledImes.find { it.id == emptyImeId }
                    if (inputMethodInfo != null) {
                        val setInputMethodAndSubtypeMethod = imm.javaClass.getMethod(
                            "setInputMethodAndSubtype",
                            android.os.IBinder::class.java,
                            String::class.java,
                            android.view.inputmethod.InputMethodSubtype::class.java
                        )
                        window?.decorView?.windowToken?.let { token ->
                            setInputMethodAndSubtypeMethod.invoke(imm, token, emptyImeId, null)
                            Log.d(TAG, "Switched to empty IME using setInputMethodAndSubtype")
                        }
                    }
                } catch (e2: Exception) {
                    Log.d(TAG, "setInputMethodAndSubtype not available: ${e2.message}")
                }
            }
            
            // VERY AGGRESSIVE: Set multiple window flags to prevent IME bar
            window?.setSoftInputMode(
                android.view.WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN or
                android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
            )
            
            // Additional aggressive flag: Add FLAG_ALT_FOCUSABLE_IM to prevent IME bar
            // This was the "very aggressive" flag that worked before
            window?.setFlags(
                android.view.WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM,
                android.view.WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM
            )
            
            Log.d(TAG, "Empty IME activated with very aggressive IME bar hiding (FLAG_ALT_FOCUSABLE_IM)")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting empty IME", e)
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
     * Force hides any active keyboard and resets IME connection state.
     * This works even without device owner by directly manipulating the InputMethodManager.
     */
    private fun forceHideKeyboard() {
        try {
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
            
            // Hide soft input from window token
            window?.decorView?.windowToken?.let { token ->
                imm.hideSoftInputFromWindow(token, android.view.inputmethod.InputMethodManager.HIDE_NOT_ALWAYS)
                Log.d(TAG, "Force hid keyboard via hideSoftInputFromWindow")
            }
            
            // Also try hiding from current focus
            currentFocus?.windowToken?.let { token ->
                imm.hideSoftInputFromWindow(token, 0)
                Log.d(TAG, "Force hid keyboard from current focus")
            }
            
            // Restart input to clear any stale IME connections
            try {
                val restartInputMethod = imm.javaClass.getMethod("restartInput", android.view.View::class.java)
                currentFocus?.let { view ->
                    restartInputMethod.invoke(imm, view)
                    Log.d(TAG, "Restarted input connection")
                }
            } catch (e: Exception) {
                Log.d(TAG, "Could not restart input: ${e.message}")
            }
            
            // Clear any active input connection
            try {
                val isActiveMethod = imm.javaClass.getMethod("isActive")
                val isActive = isActiveMethod.invoke(imm) as Boolean
                if (isActive) {
                    val finishMethod = imm.javaClass.getMethod("finishInput")
                    finishMethod.invoke(imm)
                    Log.d(TAG, "Finished active input connection")
                }
            } catch (e: Exception) {
                Log.d(TAG, "Could not finish input: ${e.message}")
            }
            
            Log.d(TAG, "Force keyboard hide completed")
        } catch (e: Exception) {
            Log.e(TAG, "Error force hiding keyboard", e)
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

                    devicePolicyManager.setPermissionGrantState(
                        adminComponent,
                        packageName,
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED
                    )
                    Log.i(TAG, "Granted ACCESS_FINE_LOCATION permission via Device Owner")
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

    private fun createBatteryReceiver(events: EventChannel.EventSink?): BroadcastReceiver {
        return object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
                val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
                
                val batteryPct = if (level >= 0 && scale > 0) {
                    (level * 100 / scale.toFloat()).toInt()
                } else {
                    -1
                }
                
                val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                               status == BatteryManager.BATTERY_STATUS_FULL
                
                Log.i(TAG, "Battery update: level=$batteryPct%, status=$status, isCharging=$isCharging")
                
                val batteryData = mapOf(
                    "level" to batteryPct,
                    "isCharging" to isCharging
                )
                
                events?.success(batteryData)
            }
        }
    }

    private fun getBatteryLevel(): Map<String, Any> {
        return try {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            val status = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_STATUS)
            val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || 
                           status == BatteryManager.BATTERY_STATUS_FULL
            
            mapOf(
                "level" to level,
                "isCharging" to isCharging
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error getting battery level", e)
            mapOf(
                "level" to -1,
                "isCharging" to false
            )
        }
    }
}
