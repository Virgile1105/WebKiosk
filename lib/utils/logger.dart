import 'package:flutter/foundation.dart';

void log(String message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('[DeviceGate] $message');
  }
}