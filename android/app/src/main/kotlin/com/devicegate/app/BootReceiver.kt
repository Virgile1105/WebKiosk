package com.devicegate.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    private val TAG = "BootReceiver"
    
    companion object {
        @Volatile
        private var lastBootTime: Long = 0
        private const val BOOT_COOLDOWN_MS = 60000L // 60 seconds
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "BootReceiver triggered with action: ${intent.action}")
        
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || 
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == Intent.ACTION_LOCKED_BOOT_COMPLETED) {
            
            // Check if we already handled a boot event recently using static variable
            // (SharedPreferences not available during LOCKED_BOOT_COMPLETED)
            val currentTime = System.currentTimeMillis()
            
            if (currentTime - lastBootTime < BOOT_COOLDOWN_MS) {
                Log.d(TAG, "Ignoring duplicate boot broadcast (${intent.action}) - already handled ${(currentTime - lastBootTime)}ms ago")
                return
            }
            
            // Save this boot time
            lastBootTime = currentTime
            
            Log.d(TAG, "Boot completed (${intent.action}), launching DeviceGate app")
            
            // Small delay to ensure system is ready
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                try {
                    // Launch the main activity as normal app (home preference already set by MainActivity)
                    val launchIntent = Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_MAIN
                        addCategory(Intent.CATEGORY_LAUNCHER)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    }
                    context.startActivity(launchIntent)
                    Log.d(TAG, "Activity launched successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Error launching activity", e)
                }
            }, 2000) // 2 second delay
        }
    }
}
