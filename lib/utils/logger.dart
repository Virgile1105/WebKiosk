import 'package:flutter/foundation.dart';

void log(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}