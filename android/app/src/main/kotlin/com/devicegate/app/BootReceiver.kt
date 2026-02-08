package com.devicegate.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    private val TAG = "BootReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "BootReceiver triggered with action: ${intent.action}")
        
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || 
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == Intent.ACTION_LOCKED_BOOT_COMPLETED) {
            Log.d(TAG, "Boot completed, launching DeviceGate app and service")
            
            // Start the service for persistence
            try {
                val serviceIntent = Intent(context, KioskService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                Log.d(TAG, "Service started successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Error starting service", e)
            }
            
            // Small delay to ensure system is ready
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                try {
                    // Launch the main activity with HOME intent to make it default launcher
                    val launchIntent = Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_MAIN
                        addCategory(Intent.CATEGORY_HOME)
                        addCategory(Intent.CATEGORY_DEFAULT)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    }
                    context.startActivity(launchIntent)
                    Log.d(TAG, "Activity launched successfully with HOME intent")
                } catch (e: Exception) {
                    Log.e(TAG, "Error launching activity", e)
                }
            }, 2000) // 2 second delay
        }
    }
}
