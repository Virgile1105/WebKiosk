package com.devicegate.app

import android.app.Activity
import android.os.Bundle

class AdminPolicyComplianceActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setResult(RESULT_OK, intent)
        finish()
    }
}
