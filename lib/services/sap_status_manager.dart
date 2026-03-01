import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_info.dart';
import '../utils/logger.dart';
import 'firebaseDataManagement.dart';

/// Manages SAP EWM status tracking and Firestore updates
/// Status progression: active → slow (5min) → idle (10min) → paused (15min) → dormant (20min) → inactive (30min)
class SapStatusManager {
  static final SapStatusManager _instance = SapStatusManager._internal();
  factory SapStatusManager() => _instance;
  SapStatusManager._internal();

  Timer? _statusCheckTimer;
  
  // Status thresholds in minutes
  static const int _slowThreshold = 5;
  static const int _idleThreshold = 10;
  static const int _pausedThreshold = 15;
  static const int _dormantThreshold = 20;
  static const int _inactiveThreshold = 30;
  static const int _timerInterval = 5; // Each timer fires after 5 minutes

  /// Called when user enters SAP EWM webview
  /// Runs asynchronously to avoid blocking screen initialization
  void onEnterSapEwm() {
    Future.microtask(() {
      final deviceInfo = DeviceInfo();
      final previousStatus = deviceInfo.sapStatus;
      
      deviceInfo.sapStatus = SapStatus.active;
      deviceInfo.lastPageChangeTime = DateTime.now();
      
      log('SapStatusManager: Entered SAP EWM (previous: ${previousStatus.name}, new: active)');
      
      // Write to Firestore if status changed
      if (previousStatus != SapStatus.active) {
        _writeStatusToFirestore();
      }
      
      // Start timer for first status change (5 minutes → slow)
      _startNextTimer(SapStatus.active);
    });
  }

  /// Called when user leaves SAP EWM webview
  /// Runs asynchronously to avoid blocking screen disposal
  void onLeaveSapEwm() {
    Future.microtask(() {
      final deviceInfo = DeviceInfo();
      final previousStatus = deviceInfo.sapStatus;
      
      deviceInfo.sapStatus = SapStatus.off;
      
      log('SapStatusManager: Left SAP EWM (previous: ${previousStatus.name}, new: off)');
      
      // Write to Firestore if status changed
      if (previousStatus != SapStatus.off) {
        _writeStatusToFirestore();
      }
      
      // Stop timer
      _stopTimer();
    });
  }

  /// Called when user navigates to a new page within SAP EWM
  /// Runs asynchronously to avoid blocking page load
  void onPageChange() {
    // Use scheduleMicrotask to avoid blocking the page load
    Future.microtask(() {
      final deviceInfo = DeviceInfo();
      final previousStatus = deviceInfo.sapStatus;
      
      // Update last page change time
      deviceInfo.lastPageChangeTime = DateTime.now();
      
      log('SapStatusManager: Page changed (current status: ${previousStatus.name})');
      
      // If status was not active, change to active and write to Firestore
      if (previousStatus != SapStatus.active && previousStatus != SapStatus.off) {
        deviceInfo.sapStatus = SapStatus.active;
        log('SapStatusManager: Status changed from ${previousStatus.name} to active');
        _writeStatusToFirestore();
      }
      
      // Reset timer - user is active, restart 5-minute countdown
      _startNextTimer(SapStatus.active);
    });
  }

  /// Get the next status in the progression
  SapStatus? _getNextStatus(SapStatus current) {
    switch (current) {
      case SapStatus.active:
        return SapStatus.slow;
      case SapStatus.slow:
        return SapStatus.idle;
      case SapStatus.idle:
        return SapStatus.paused;
      case SapStatus.paused:
        return SapStatus.dormant;
      case SapStatus.dormant:
        return SapStatus.inactive;
      case SapStatus.inactive:
        return null; // No more progression after inactive
      case SapStatus.off:
        return null;
    }
  }

  /// Start timer for the next status change
  void _startNextTimer(SapStatus currentStatus) {
    _stopTimer();
    
    final nextStatus = _getNextStatus(currentStatus);
    if (nextStatus == null) {
      log('SapStatusManager: No more timers needed (at ${currentStatus.name})');
      return;
    }
    
    _statusCheckTimer = Timer(
      const Duration(minutes: _timerInterval),
      () => _onTimerFired(nextStatus),
    );
    
    log('SapStatusManager: Started timer for ${nextStatus.name} (${_timerInterval} min)');
  }

  /// Called when a timer fires - transition to next status
  void _onTimerFired(SapStatus targetStatus) {
    final deviceInfo = DeviceInfo();
    final currentStatus = deviceInfo.sapStatus;
    
    // Verify we're in the expected state
    final expectedPrevious = _getPreviousStatus(targetStatus);
    if (currentStatus != expectedPrevious) {
      log('SapStatusManager: Timer fired but status is ${currentStatus.name}, expected ${expectedPrevious?.name}');
      return;
    }
    
    // Verify time elapsed
    final lastChange = deviceInfo.lastPageChangeTime;
    if (lastChange == null) return;
    
    final minutesElapsed = DateTime.now().difference(lastChange).inMinutes;
    final requiredMinutes = _getThresholdForStatus(targetStatus);
    
    if (minutesElapsed < requiredMinutes) {
      // Not enough time passed, restart timer for remaining time
      final remaining = requiredMinutes - minutesElapsed;
      _statusCheckTimer = Timer(
        Duration(minutes: remaining),
        () => _onTimerFired(targetStatus),
      );
      log('SapStatusManager: Not enough time ($minutesElapsed min), restarting for $remaining min');
      return;
    }
    
    // Transition to target status
    deviceInfo.sapStatus = targetStatus;
    log('SapStatusManager: Status changed to ${targetStatus.name} ($minutesElapsed min since last activity)');
    _writeStatusToFirestore();
    
    // Start timer for next status (if not at inactive)
    _startNextTimer(targetStatus);
  }

  /// Get the previous status in the progression
  SapStatus? _getPreviousStatus(SapStatus status) {
    switch (status) {
      case SapStatus.slow:
        return SapStatus.active;
      case SapStatus.idle:
        return SapStatus.slow;
      case SapStatus.paused:
        return SapStatus.idle;
      case SapStatus.dormant:
        return SapStatus.paused;
      case SapStatus.inactive:
        return SapStatus.dormant;
      default:
        return null;
    }
  }

  /// Get the threshold in minutes for a status
  int _getThresholdForStatus(SapStatus status) {
    switch (status) {
      case SapStatus.slow:
        return _slowThreshold;
      case SapStatus.idle:
        return _idleThreshold;
      case SapStatus.paused:
        return _pausedThreshold;
      case SapStatus.dormant:
        return _dormantThreshold;
      case SapStatus.inactive:
        return _inactiveThreshold;
      default:
        return 0;
    }
  }

  /// Stop the timer
  void _stopTimer() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
  }

  /// Write current status to Firestore
  void _writeStatusToFirestore() {
    final deviceInfo = DeviceInfo();
    deviceInfo.lastInputTime = Timestamp.now();
    
    log('SapStatusManager: Writing to Firestore - status: ${deviceInfo.sapStatus.name}');
    FirebaseDataManagement.writeDeviceInfo();
  }

  /// Dispose resources
  void dispose() {
    _stopTimer();
  }
}
