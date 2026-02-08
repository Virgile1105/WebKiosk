package com.devicegate.app

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log

class KioskService : Service() {
    private val TAG = "KioskService"

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "KioskService started")
        
        // Launch MainActivity
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        
        startActivity(launchIntent)
        
        return START_STICKY
    }
}
