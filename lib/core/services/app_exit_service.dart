import 'package:flutter/services.dart';

class AppExitService {
  AppExitService._();

  static const _channel = MethodChannel('clubbar/app_control');

  static Future<void> fechar() async {
    try {
      await _channel.invokeMethod<void>('finishAndRemoveTask');
    } on MissingPluginException {
      await SystemNavigator.pop();
    } on PlatformException {
      await SystemNavigator.pop();
    }
  }
}
