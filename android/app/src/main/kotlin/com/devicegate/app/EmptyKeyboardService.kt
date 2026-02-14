package com.devicegate.app

import android.inputmethodservice.InputMethodService
import android.view.View
import android.widget.FrameLayout
import android.util.Log

/**
 * Empty/Invisible IME keyboard service that:
 * 1. Shows no UI (zero height view)
 * 2. Allows physical input (laser scanner) to pass through
 * 3. Aggressively prevents IME navigation bar from showing
 * 
 * This replaces Gboard to prevent native keyboard from appearing
 * while still allowing input from physical devices like laser scanners.
 */
class EmptyKeyboardService : InputMethodService() {
    
    companion object {
        private const val TAG = "EmptyKeyboard"
    }
    
    override fun onCreateInputView(): View {
        Log.d(TAG, "Creating empty input view")
        
        // Return a completely empty view with zero height
        val emptyView = FrameLayout(this)
        emptyView.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            0 // Zero height = invisible
        )
        
        return emptyView
    }
    
    override fun onEvaluateFullscreenMode(): Boolean {
        // Never go fullscreen
        return false
    }
    
    override fun onEvaluateInputViewShown(): Boolean {
        // Always claim we're showing the keyboard (so system doesn't try to show another)
        // but our view has zero height, so nothing is actually visible
        return true
    }
    
    override fun onShowInputRequested(flags: Int, configChange: Boolean): Boolean {
        // Allow keyboard to be "shown" (but it's invisible)
        Log.d(TAG, "Keyboard show requested - showing empty view")
        return true
    }
    
    override fun onStartInput(attribute: android.view.inputmethod.EditorInfo?, restarting: Boolean) {
        super.onStartInput(attribute, restarting)
        Log.d(TAG, "Input started - empty keyboard active")
    }
    
    override fun onStartInputView(info: android.view.inputmethod.EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        Log.d(TAG, "Input view shown (invisible)")
    }
}
