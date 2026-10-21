import 'dart:io';

import 'package:flutter/services.dart';

/// Blocks screenshots and screen recording on Android while enabled.
/// iOS doesn't allow apps to block screenshots, so it's a no-op there.
class SecureScreen {
  static const _channel = MethodChannel('amore/secure_screen');

  static Future<void> enable() => _call('enable');
  static Future<void> disable() => _call('disable');

  static Future<void> _call(String method) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException {
      // Not fatal: the media still shows, just without screenshot blocking.
    }
  }
}
