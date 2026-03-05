package com.devicegate.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.Timestamp
import com.google.firebase.firestore.FirebaseFirestore
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Foreground service that monitors for device shutdown events.
 * 
 * On Android 9+, ACTION_SHUTDOWN can only be received by dynamically registered receivers.
 * This service stays running and registers a receiver to catch shutdown events,
 * allowing us to update Firestore before the device turns off.
 */
class ShutdownMonitorService : Service() {
    
    companion object {
        private const val TAG = "DeviceGate"
        private const val CHANNEL_ID = "shutdown_monitor_channel"
        private const val NOTIFICATION_ID = 1001
        private const val PREFS_NAME = "DeviceGatePrefs"
        private const val KEY_SERIAL_NUMBER = "serialNumber"
        private const val KEY_SAP_STATUS = "sapStatus"
        private const val KEY_SAP_USER = "sapUser"
        private const val KEY_SAP_RESSOURCE = "sapRessource"
        private const val KEY_APP_DEVICE_NAME = "appDeviceName"
        private const val KEY_APP_VERSION = "appVersion"
        private const val KEY_MANUFACTURER = "manufacturer"
        private const val KEY_MODEL = "model"
        private const val KEY_DEVICE_NAME = "deviceName"
        private const val KEY_ANDROID_VERSION = "androidVersion"
        private const val KEY_SECURITY_PATCH = "securityPatch"
        private const val KEY_BLUETOOTH_DEVICES = "bluetoothDevices"
        private const val KEY_PRODUCT_NAME = "productName"
        
        /**
         * Save the serial number to SharedPreferences.
         */
        fun saveSerialNumber(context: Context, serialNumber: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(KEY_SERIAL_NUMBER, serialNumber).apply()
            Log.d(TAG, "ShutdownMonitorService: Saved serial number: $serialNumber")
        }
        
        /**
         * Save all device info to SharedPreferences for shutdown access.
         */
        fun saveDeviceInfo(
            context: Context,
            sapStatus: String,
            sapUser: String,
            sapRessource: String,
            appDeviceName: String,
            appVersion: String,
            manufacturer: String,
            model: String,
            deviceName: String,
            androidVersion: String,
            securityPatch: String,
            serialNumber: String,
            productName: String,
            bluetoothDevices: String
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(KEY_SAP_STATUS, sapStatus)
                .putString(KEY_SAP_USER, sapUser)
                .putString(KEY_SAP_RESSOURCE, sapRessource)
                .putString(KEY_APP_DEVICE_NAME, appDeviceName)
                .putString(KEY_APP_VERSION, appVersion)
                .putString(KEY_MANUFACTURER, manufacturer)
                .putString(KEY_MODEL, model)
                .putString(KEY_DEVICE_NAME, deviceName)
                .putString(KEY_ANDROID_VERSION, androidVersion)
                .putString(KEY_SECURITY_PATCH, securityPatch)
                .putString(KEY_SERIAL_NUMBER, serialNumber)
                .putString(KEY_PRODUCT_NAME, productName)
                .putString(KEY_BLUETOOTH_DEVICES, bluetoothDevices)
                .apply()
            Log.d(TAG, "ShutdownMonitorService: Saved device info - sapStatus=$sapStatus, sapUser=$sapUser, serial=$serialNumber")
        }
    }
    
    private var shutdownReceiver: BroadcastReceiver? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "ShutdownMonitorService: onCreate")
        
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        registerShutdownReceiver()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "ShutdownMonitorService: onStartCommand")
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        Log.d(TAG, "ShutdownMonitorService: onDestroy")
        unregisterShutdownReceiver()
        super.onDestroy()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Device Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors device status"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DeviceGate")
            .setContentText("Monitoring device status")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    private fun registerShutdownReceiver() {
        if (shutdownReceiver != null) return
        
        shutdownReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                Log.d(TAG, "ShutdownMonitorService: Received broadcast: ${intent?.action}")
                
                when (intent?.action) {
                    Intent.ACTION_SHUTDOWN,
                    "android.intent.action.QUICKBOOT_POWEROFF",
                    "com.htc.intent.action.QUICKBOOT_POWEROFF",
                    "com.samsung.intent.action.ACTION_SHUTDOWN" -> {
                        Log.d(TAG, "ShutdownMonitorService: Device shutdown detected!")
                        handleShutdown()
                    }
                }
            }
        }
        
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SHUTDOWN)
            addAction("android.intent.action.QUICKBOOT_POWEROFF")
            addAction("com.htc.intent.action.QUICKBOOT_POWEROFF")
            addAction("com.samsung.intent.action.ACTION_SHUTDOWN")
        }
        
        // On Android 13+, we need to specify receiver export behavior
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(shutdownReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(shutdownReceiver, filter)
        }
        
        Log.d(TAG, "ShutdownMonitorService: Shutdown receiver registered dynamically")
    }
    
    private fun unregisterShutdownReceiver() {
        shutdownReceiver?.let {
            try {
                unregisterReceiver(it)
                Log.d(TAG, "ShutdownMonitorService: Shutdown receiver unregistered")
            } catch (e: Exception) {
                Log.e(TAG, "ShutdownMonitorService: Error unregistering receiver", e)
            }
        }
        shutdownReceiver = null
    }
    
    private fun handleShutdown() {
        // Get data from SharedPreferences
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val serialNumber = prefs.getString(KEY_SERIAL_NUMBER, null)
        val sapStatus = prefs.getString(KEY_SAP_STATUS, "off")
        val sapUser = prefs.getString(KEY_SAP_USER, "") ?: ""
        val sapRessource = prefs.getString(KEY_SAP_RESSOURCE, "") ?: ""
        val appDeviceName = prefs.getString(KEY_APP_DEVICE_NAME, "") ?: ""
        val appVersion = prefs.getString(KEY_APP_VERSION, "") ?: ""
        val manufacturer = prefs.getString(KEY_MANUFACTURER, "") ?: ""
        val model = prefs.getString(KEY_MODEL, "") ?: ""
        val deviceName = prefs.getString(KEY_DEVICE_NAME, "") ?: ""
        val androidVersion = prefs.getString(KEY_ANDROID_VERSION, "") ?: ""
        val securityPatch = prefs.getString(KEY_SECURITY_PATCH, "") ?: ""
        val productName = prefs.getString(KEY_PRODUCT_NAME, "") ?: ""
        val bluetoothDevices = prefs.getString(KEY_BLUETOOTH_DEVICES, "") ?: ""
        
        Log.d(TAG, "ShutdownMonitorService: serial=$serialNumber, sapStatus=$sapStatus, sapUser=$sapUser")
        
        if (serialNumber.isNullOrEmpty()) {
            Log.e(TAG, "ShutdownMonitorService: No serial number, cannot update Firestore")
            return
        }
        
        // Only update if SAP was active (not already off)
        if (sapStatus == "off") {
            Log.d(TAG, "ShutdownMonitorService: SAP status already off, skipping Firestore update")
            return
        }
        
        // Update Firestore synchronously with full device info
        updateFirestoreSync(
            serialNumber,
            sapUser,
            sapRessource,
            appDeviceName,
            appVersion,
            manufacturer,
            model,
            deviceName,
            androidVersion,
            securityPatch,
            productName,
            bluetoothDevices
        )
        
        // Update SharedPreferences
        prefs.edit().putString(KEY_SAP_STATUS, "off").apply()
    }
    
    private fun updateFirestoreSync(
        serialNumber: String,
        sapUser: String,
        sapRessource: String,
        appDeviceName: String,
        appVersion: String,
        manufacturer: String,
        model: String,
        deviceName: String,
        androidVersion: String,
        securityPatch: String,
        productName: String,
        bluetoothDevices: String
    ) {
        try {
            // Initialize Firebase if needed
            if (FirebaseApp.getApps(this).isEmpty()) {
                FirebaseApp.initializeApp(this)
                Log.d(TAG, "ShutdownMonitorService: Firebase initialized")
            }
            
            val db = FirebaseFirestore.getInstance()
            val logsRef = db.collection("Devices").document(serialNumber).collection("Logs")
            
            // Use a latch to wait synchronously
            val latch = CountDownLatch(1)
            
            // Parse bluetooth devices from "name|status;name|status" format to list of maps
            val bluetoothList = if (bluetoothDevices.isNotEmpty()) {
                bluetoothDevices.split(";").mapNotNull { device ->
                    val parts = device.split("|")
                    if (parts.size >= 2) {
                        hashMapOf(
                            "name" to parts[0],
                            "status" to parts[1]
                        )
                    } else null
                }
            } else {
                emptyList()
            }
            
            val logEntry = hashMapOf(
                "sapStatus" to "off",
                "sapUser" to sapUser,
                "sapRessource" to sapRessource,
                "appDeviceName" to appDeviceName,
                "appVersion" to appVersion,
                "manufacturer" to manufacturer,
                "model" to model,
                "deviceName" to deviceName,
                "androidVersion" to androidVersion,
                "securityPatch" to securityPatch,
                "serialNumber" to serialNumber,
                "productName" to productName,
                "bluetoothDevices" to bluetoothList,
                "lastInputTime" to Timestamp.now(),
                "trigger" to "shutdown"
            )
            
            Log.d(TAG, "ShutdownMonitorService: Writing to Firestore with trigger=shutdown...")
            
            logsRef.add(logEntry)
                .addOnSuccessListener {
                    Log.d(TAG, "ShutdownMonitorService: Firestore update SUCCESS")
                    latch.countDown()
                }
                .addOnFailureListener { e ->
                    Log.e(TAG, "ShutdownMonitorService: Firestore update FAILED: ${e.message}")
                    latch.countDown()
                }
            
            // Wait up to 5 seconds for completion
            val completed = latch.await(5, TimeUnit.SECONDS)
            
            if (!completed) {
                Log.w(TAG, "ShutdownMonitorService: Firestore update timed out")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "ShutdownMonitorService: Error updating Firestore", e)
        }
    }
}
