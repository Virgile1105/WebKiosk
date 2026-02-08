import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

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
            _errorMessage = _getLockoutMessage();
          });
          // Start the countdown timer
          _startLockoutTimer();
        } else {
          // Lockout expired, reset
          await prefs.remove('failed_password_attempts');
          await prefs.remove('lockout_until_timestamp');
        }
      } else {
        setState(() {
          _failedAttempts = failedAttempts;
        });
      }
    } catch (e) {
      log('Error loading lockout status: $e');
    }
  }

  String _getLockoutMessage() {
    if (_lockoutUntil == null) return '';
    final remaining = _lockoutUntil!.difference(DateTime.now());
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return 'Trop de tentatives échouées.\nRéessayez dans ${minutes}min ${seconds}s';
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
        _errorMessage = _getLockoutMessage();
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
          _errorMessage = _getLockoutMessage();
          _enteredCode.clear();
          _shuffleKeys();
        });
        
        // Start timer to update countdown
        _startLockoutTimer();
      } else {
        await _saveLockoutStatus();
        setState(() {
          _errorMessage = 'Code incorrect. Veuillez réessayer.\nTentative ${_failedAttempts}/3';
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
          _errorMessage = _getLockoutMessage();
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
    final bool isLockedOut = _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title with back arrow
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.arrow_back),
                  color: const Color.fromRGBO(51, 61, 71, 1),
                ),
                const Expanded(
                  child: Text(
                    'Code d\'accès',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(51, 61, 71, 1),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // Balance the back button
              ],
            ),
            const SizedBox(height: 32),
            
            // Dots indicator with clear button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 6 dots
                ...List.generate(_codeLength, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
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
                const SizedBox(width: 16),
                // Clear button
                IconButton(
                  onPressed: isLockedOut ? null : _onClearPressed,
                  icon: const Icon(Icons.close, size: 28),
                  color: const Color.fromRGBO(51, 61, 71, 1),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Error message area (fixed height)
            SizedBox(
              height: 48,
              child: Center(
                child: _errorMessage != null
                    ? Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Numeric keyboard (2 rows of 5)
            Opacity(
              opacity: isLockedOut ? 0.3 : 1.0,
              child: Column(
                children: [
                  // First row (5 keys)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _shuffledKeys.sublist(0, 5).map((number) {
                      return _buildNumberButton(number, !isLockedOut);
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // Second row (5 keys)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _shuffledKeys.sublist(5, 10).map((number) {
                      return _buildNumberButton(number, !isLockedOut);
                    }).toList(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Validate button
            SizedBox(
              width: double.infinity,
              height: 50,
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
                  'Valider',
                  style: TextStyle(
                    fontSize: 18,
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
  }

  Widget _buildNumberButton(int number, bool enabled) {
    return Container(
      margin: const EdgeInsets.all(6),
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
          minimumSize: const Size(60, 60),
        ),
        child: Text(
          '$number',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
