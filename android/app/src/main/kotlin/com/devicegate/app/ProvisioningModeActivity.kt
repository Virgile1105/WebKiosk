package com.devicegate.app

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.Intent
import android.os.Bundle
import android.os.PersistableBundle

class ProvisioningModeActivity : Activity() {

    private val EXTRA_PROVISIONING_ALLOWED_PROVISIONING_MODES = "android.app.extra.PROVISIONING_ALLOWED_PROVISIONING_MODES"
    private val EXTRA_PROVISIONING_MODE = "android.app.extra.PROVISIONING_MODE"
    private val PROVISIONING_MODE_FULLY_MANAGED_DEVICE = 1

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val provisioningMode = PROVISIONING_MODE_FULLY_MANAGED_DEVICE

        // Grab the extras and pass to AdminPolicyComplianceActivity
        val extras = intent.getParcelableExtra<PersistableBundle>(DevicePolicyManager.EXTRA_PROVISIONING_ADMIN_EXTRAS_BUNDLE)
        val resultIntent = Intent()

        if (extras != null) {
            resultIntent.putExtra(DevicePolicyManager.EXTRA_PROVISIONING_ADMIN_EXTRAS_BUNDLE, extras)
        }

        resultIntent.putExtra(EXTRA_PROVISIONING_MODE, provisioningMode)

        setResult(RESULT_OK, resultIntent)
        finish()
    }
}
