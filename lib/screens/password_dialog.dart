import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import '../generated/l10n/app_localizations.dart';

class PasswordDialog extends StatefulWidget {
  const PasswordDialog({super.key});

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final List<int> _enteredCode = [];
  final int _codeLength = 6;
  List<int> _shuffledKeys = [];
  String? _errorMessage;
  String _storedPassword = '119181'; // Default password
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  @override
  void initState() {
    super.initState();
    _loadPassword();
    _loadLockoutStatus();
    _shuffleKeys();
  }

  Future<void> _loadPassword() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _storedPassword = prefs.getString('settings_password') ?? '119181';
      });
    } catch (e) {
      log('Error loading password: $e');
    }
  }

  Future<void> _loadLockoutStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final failedAttempts = prefs.getInt('failed_password_attempts') ?? 0;
      final lockoutTimestamp = prefs.getInt('lockout_until_timestamp');
      
      if (lockoutTimestamp != null) {
        final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutTimestamp);
        if (DateTime.now().isBefore(lockoutTime)) {
          setState(() {
            _failedAttempts = failedAttempts;
            _lockoutUntil = lockoutTime;
            // Error message will be set in build method
          });
          // Start the countdown timer
          _startLockoutTimer();
        } else {
          // Lockout expired, reset
          await prefs.remove('failed_password_attempts');
          await prefs.remove('lockout_until_timestamp');
          setState(() {
            _failedAttempts = 0;
          });
        }
      } else {
        // No lockout timestamp - reset any stale failed attempts
        if (failedAttempts > 0) {
          await prefs.remove('failed_password_attempts');
        }
        // _failedAttempts stays at 0 (default)
      }
    } catch (e) {
      log('Error loading lockout status: $e');
    }
  }

  String _getLockoutMessage(BuildContext context) {
    if (_lockoutUntil == null) return '';
    final remaining = _lockoutUntil!.difference(DateTime.now());
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final l10n = AppLocalizations.of(context)!;
    return l10n.tooManyAttempts(minutes, seconds);
  }

  Future<void> _saveLockoutStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('failed_password_attempts', _failedAttempts);
      if (_lockoutUntil != null) {
        await prefs.setInt('lockout_until_timestamp', _lockoutUntil!.millisecondsSinceEpoch);
      }
    } catch (e) {
      log('Error saving lockout status: $e');
    }
  }

  Future<void> _clearLockout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('failed_password_attempts');
      await prefs.remove('lockout_until_timestamp');
      setState(() {
        _failedAttempts = 0;
        _lockoutUntil = null;
      });
    } catch (e) {
      log('Error clearing lockout: $e');
    }
  }

  void _shuffleKeys() {
    _shuffledKeys = List.generate(10, (index) => index);
    _shuffledKeys.shuffle(Random());
  }

  void _onNumberPressed(int number) {
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      return; // Still locked out
    }
    
    if (_enteredCode.length < _codeLength) {
      setState(() {
        _enteredCode.add(number);
        _errorMessage = null;
      });
    }
  }

  void _onClearPressed() {
    setState(() {
      _enteredCode.clear();
      if (_lockoutUntil == null || DateTime.now().isAfter(_lockoutUntil!)) {
        _errorMessage = null;
      }
      _shuffleKeys();
    });
  }

  void _onValidatePressed() async {
    // Check if still locked out
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      setState(() {
        // Error message will be updated by timer
      });
      return;
    }
    
    final enteredPassword = _enteredCode.join();
    if (enteredPassword == _storedPassword) {
      // Success - clear failed attempts
      await _clearLockout();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      // Failed attempt
      _failedAttempts++;
      
      if (_failedAttempts >= 3) {
        // Lock out for 15 minutes
        _lockoutUntil = DateTime.now().add(const Duration(minutes: 15));
        await _saveLockoutStatus();
        setState(() {
          // Error message will be set in build method
          _enteredCode.clear();
          _shuffleKeys();
        });
        
        // Start timer to update countdown
        _startLockoutTimer();
      } else {
        await _saveLockoutStatus();
        setState(() {
          // Set error message to trigger display in build method
          _errorMessage = 'incorrect'; // Will be replaced with localized text in build()
          _enteredCode.clear();
          _shuffleKeys();
        });
      }
    }
  }

  void _startLockoutTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
        setState(() {
          // Trigger rebuild to update countdown
        });
        _startLockoutTimer();
      } else if (mounted) {
        _clearLockout();
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool isLockedOut = _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
    
    // Update error message based on current state
    if (isLockedOut) {
      _errorMessage = _getLockoutMessage(context);
    } else if (_failedAttempts > 0 && _failedAttempts < 3 && _errorMessage != null && !_errorMessage!.contains('min')) {
      _errorMessage = '${l10n.incorrectPassword}\n${l10n.retry} ${_failedAttempts}/3';
    }
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate responsive sizes
          final screenHeight = MediaQuery.of(context).size.height;
          final screenWidth = MediaQuery.of(context).size.width;
          final isPortrait = screenHeight > screenWidth;
          
          // Adaptive sizing
          final dialogPadding = isPortrait ? 16.0 : 20.0;
          final titleFontSize = isPortrait ? 20.0 : 24.0;
          final buttonSize = isPortrait ? 48.0 : 55.0;
          final buttonMargin = isPortrait ? 4.0 : 6.0;
          final buttonFontSize = isPortrait ? 20.0 : 24.0;
          final dotSize = isPortrait ? 12.0 : 16.0;
          final dotSpacing = isPortrait ? 6.0 : 8.0;
          final verticalSpacing = isPortrait ? 16.0 : 24.0;
          final validateButtonHeight = isPortrait ? 44.0 : 50.0;
          
          return Container(
            constraints: BoxConstraints(
              maxWidth: isPortrait ? screenWidth * 0.9 : 500,
              maxHeight: screenHeight * 0.85,
            ),
            padding: EdgeInsets.all(dialogPadding),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title with back arrow
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.arrow_back),
                        iconSize: isPortrait ? 20 : 24,
                        color: const Color.fromRGBO(51, 61, 71, 1),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Expanded(
                        child: Text(
                          l10n.enterPassword,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromRGBO(51, 61, 71, 1),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(width: isPortrait ? 24 : 48),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),
                  
                  // Dots indicator with clear button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 6 dots
                      ...List.generate(_codeLength, (index) {
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: dotSpacing),
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index < _enteredCode.length
                                ? const Color.fromRGBO(51, 61, 71, 1)
                                : const Color.fromRGBO(51, 61, 71, 0.2),
                            border: Border.all(
                              color: const Color.fromRGBO(51, 61, 71, 1),
                              width: 2,
                            ),
                          ),
                        );
                      }),
                      SizedBox(width: dotSpacing * 2),
                      // Clear button
                      IconButton(
                        onPressed: isLockedOut ? null : _onClearPressed,
                        icon: Icon(Icons.close, size: isPortrait ? 22 : 28),
                        color: const Color.fromRGBO(51, 61, 71, 1),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: verticalSpacing * 0.3),
                  
                  // Error message area
                  SizedBox(
                    height: isPortrait ? 32 : 40,
                    child: Center(
                      child: _errorMessage != null
                          ? Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: isPortrait ? 12 : 14,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  
                  SizedBox(height: verticalSpacing * 0.25),
                  
                  // Numeric keyboard (2 rows of 5)
                  Opacity(
                    opacity: isLockedOut ? 0.3 : 1.0,
                    child: Column(
                      children: [
                        // First row (5 keys)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _shuffledKeys.sublist(0, 5).map((number) {
                            return _buildNumberButton(number, !isLockedOut, buttonSize, buttonMargin, buttonFontSize);
                          }).toList(),
                        ),
                        SizedBox(height: buttonMargin * 2),
                        // Second row (5 keys)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _shuffledKeys.sublist(5, 10).map((number) {
                            return _buildNumberButton(number, !isLockedOut, buttonSize, buttonMargin, buttonFontSize);
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: verticalSpacing),
                  
                  // Validate button
                  SizedBox(
                    width: double.infinity,
                    height: validateButtonHeight,
                    child: ElevatedButton(
                      onPressed: (_enteredCode.length == _codeLength && !isLockedOut)
                          ? _onValidatePressed
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(51, 61, 71, 1),
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        l10n.ok,
                        style: TextStyle(
                          fontSize: isPortrait ? 16 : 18,
                          color: (_enteredCode.length == _codeLength && !isLockedOut)
                              ? Colors.white
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNumberButton(int number, bool enabled, double size, double margin, double fontSize) {
    return Container(
      margin: EdgeInsets.all(margin),
      child: ElevatedButton(
        onPressed: enabled ? () => _onNumberPressed(number) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromRGBO(51, 61, 71, 1),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(0),
          minimumSize: Size(size, size),
          maximumSize: Size(size, size),
        ),
        child: Text(
          '$number',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
