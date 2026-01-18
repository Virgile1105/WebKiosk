package com.webkiosk.builder

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import com.webkiosk.builder.R
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {
    private val CHANNEL = "webkiosk.builder/shortcut"
    private val TAG = "WebKioskBuilder"
    private var methodChannel: MethodChannel? = null
    private var pendingUrl: String? = null
    private var urlAlreadyRetrieved = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "createShortcut" -> {
                    val shortcutId = call.argument<String>("shortcutId") ?: "webkiosk_${System.currentTimeMillis()}"
                    val name = call.argument<String>("name") ?: "WebKiosk"
                    val url = call.argument<String>("url") ?: ""
                    val iconUrl = call.argument<String>("iconUrl") ?: ""
                    val disableAutoFocus = call.argument<Boolean>("disableAutoFocus") ?: false
                    val useCustomKeyboard = call.argument<Boolean>("useCustomKeyboard") ?: false
                    val disableCopyPaste = call.argument<Boolean>("disableCopyPaste") ?: false
                    val noIcon = call.argument<Boolean>("noIcon") ?: false
                    
                    Log.d(TAG, "Creating shortcut: id=$shortcutId, name=$name, url=$url, iconUrl=$iconUrl, disableAutoFocus=$disableAutoFocus, useCustomKeyboard=$useCustomKeyboard, disableCopyPaste=$disableCopyPaste, noIcon=$noIcon")
                    
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            createShortcut(shortcutId, name, url, iconUrl, disableAutoFocus, useCustomKeyboard, disableCopyPaste, noIcon)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error creating shortcut", e)
                            result.error("SHORTCUT_ERROR", e.message, null)
                        }
                    }
                }
                "changeAppIcon" -> {
                    val iconUrl = call.argument<String>("iconUrl") ?: ""
                    val appName = call.argument<String>("appName") ?: "WebKiosk Builder"
                    
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
                "deleteShortcut" -> {
                    val shortcutId = call.argument<String>("shortcutId") ?: ""
                    try {
                        if (shortcutId.isNotEmpty()) {
                            ShortcutManagerCompat.removeDynamicShortcuts(context, listOf(shortcutId))
                            ShortcutManagerCompat.disableShortcuts(
                                context,
                                listOf(shortcutId),
                                "Shortcut has been removed"
                            )
                            Log.d(TAG, "Deleted shortcut: $shortcutId")
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error deleting shortcut", e)
                        result.error("DELETE_ERROR", e.message, null)
                    }
                }
                "updateShortcut" -> {
                    val shortcutId = call.argument<String>("shortcutId") ?: ""
                    val name = call.argument<String>("name") ?: "WebKiosk"
                    val url = call.argument<String>("url") ?: ""
                    val iconUrl = call.argument<String>("iconUrl") ?: ""
                    val disableAutoFocus = call.argument<Boolean>("disableAutoFocus") ?: false
                    val useCustomKeyboard = call.argument<Boolean>("useCustomKeyboard") ?: false
                    val disableCopyPaste = call.argument<Boolean>("disableCopyPaste") ?: false
                    val noIcon = call.argument<Boolean>("noIcon") ?: false
                    
                    Log.d(TAG, "Updating shortcut: id=$shortcutId, name=$name, url=$url")
                    
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val updated = updateShortcut(shortcutId, name, url, iconUrl, disableAutoFocus, useCustomKeyboard, disableCopyPaste, noIcon)
                            result.success(updated)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error updating shortcut", e)
                            result.error("UPDATE_ERROR", e.message, null)
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
        
        if (!url.isNullOrEmpty()) {
            // Send the new URL to Flutter
            methodChannel?.invokeMethod("onNewUrl", url)
            // Reset flag for next intent
            urlAlreadyRetrieved = false
        }
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
            ComponentName(this, "com.webkiosk.builder.MainActivity"),
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )
        
        // Enable alias with custom icon
        pm.setComponentEnabledSetting(
            ComponentName(this, "com.webkiosk.builder.MainActivityAlias"),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
        
        Log.d(TAG, "Switched to custom icon alias")
    }
    
    private fun resetToDefaultIcon() {
        val pm = packageManager
        
        // Enable main activity
        pm.setComponentEnabledSetting(
            ComponentName(this, "com.webkiosk.builder.MainActivity"),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
        
        // Disable alias
        pm.setComponentEnabledSetting(
            ComponentName(this, "com.webkiosk.builder.MainActivityAlias"),
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )
        
        Log.d(TAG, "Reset to default icon")
    }

    private suspend fun createShortcut(shortcutId: String, name: String, url: String, iconUrlString: String, disableAutoFocus: Boolean, useCustomKeyboard: Boolean, disableCopyPaste: Boolean, noIcon: Boolean) = withContext(Dispatchers.IO) {
        // Create a proper app-like intent with URI data for shortcuts
        val launchIntent = Intent(Intent.ACTION_VIEW, Uri.parse("webkiosk://open?url=${Uri.encode(url)}&disableAutoFocus=$disableAutoFocus&useCustomKeyboard=$useCustomKeyboard&disableCopyPaste=$disableCopyPaste")).apply {
            setPackage(context.packageName)
            setClassName(context, "com.webkiosk.builder.MainActivity")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        var icon: IconCompat? = null
        
        // Try to download icon from URL (unless noIcon is true)
        if (iconUrlString.isNotEmpty() && !noIcon) {
            try {
                Log.d(TAG, "Attempting to download icon from: $iconUrlString")
                val iconBitmap = downloadIcon(iconUrlString)
                if (iconBitmap != null) {
                    Log.d(TAG, "Icon downloaded successfully: ${iconBitmap.width}x${iconBitmap.height}")
                    // Scale the bitmap to a proper icon size
                    val scaledBitmap = scaleBitmap(iconBitmap, 192, 192)
                    // Use bitmap directly for better compatibility
                    icon = IconCompat.createWithBitmap(scaledBitmap)
                    Log.d(TAG, "Bitmap icon created successfully")
                } else {
                    Log.e(TAG, "Downloaded bitmap is null")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error downloading icon", e)
            }
        }
        
        // Use default app icon if no icon was downloaded or noIcon is true
        if (icon == null) {
            Log.d(TAG, "Using default app icon")
            icon = IconCompat.createWithResource(context, R.mipmap.ic_launcher)
        }

        val shortcutInfo = ShortcutInfoCompat.Builder(context, shortcutId)
            .setShortLabel(name)
            .setLongLabel(name)
            .setIcon(icon)
            .setIntent(launchIntent)
            .setLongLived(true)
            .build()

        withContext(Dispatchers.Main) {
            try {
                // Add as a dynamic shortcut
                ShortcutManagerCompat.pushDynamicShortcut(context, shortcutInfo)
                Log.d(TAG, "Added dynamic shortcut: $shortcutId")
                
                // Request to pin it to home screen
                val success = ShortcutManagerCompat.requestPinShortcut(context, shortcutInfo, null)
                Log.d(TAG, "Pin shortcut request sent: $success")
                
            } catch (e: Exception) {
                Log.e(TAG, "Error creating shortcut", e)
            }
        }
    }

    private suspend fun updateShortcut(shortcutId: String, name: String, url: String, iconUrlString: String, disableAutoFocus: Boolean, useCustomKeyboard: Boolean, disableCopyPaste: Boolean, noIcon: Boolean): Boolean = withContext(Dispatchers.IO) {
        // Create updated intent
        val launchIntent = Intent().apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            setPackage(context.packageName)
            setClassName(context, "com.webkiosk.builder.MainActivity")
            putExtra("url", url)
            putExtra("disableAutoFocus", disableAutoFocus)
            putExtra("useCustomKeyboard", useCustomKeyboard)
            putExtra("disableCopyPaste", disableCopyPaste)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        var icon: IconCompat? = null
        
        // Try to download icon
        if (iconUrlString.isNotEmpty() && !noIcon) {
            try {
                val iconBitmap = downloadIcon(iconUrlString)
                if (iconBitmap != null) {
                    val scaledBitmap = scaleBitmap(iconBitmap, 192, 192)
                    icon = IconCompat.createWithBitmap(scaledBitmap)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error downloading icon for update", e)
            }
        }
        
        if (icon == null) {
            icon = IconCompat.createWithResource(context, R.mipmap.ic_launcher)
        }

        val shortcutInfo = ShortcutInfoCompat.Builder(context, shortcutId)
            .setShortLabel(name)
            .setLongLabel(name)
            .setIcon(icon)
            .setIntent(launchIntent)
            .setLongLived(true)
            .build()

        // Update the dynamic shortcut
        val updateResult = withContext(Dispatchers.Main) {
            try {
                ShortcutManagerCompat.pushDynamicShortcut(context, shortcutInfo)
                Log.d(TAG, "Updated dynamic shortcut: $shortcutId")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update shortcut", e)
                false
            }
        }
        
        return@withContext updateResult
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
    
    private fun scaleBitmap(bitmap: Bitmap, width: Int, height: Int): Bitmap {
        return Bitmap.createScaledBitmap(bitmap, width, height, true)
    }
}
