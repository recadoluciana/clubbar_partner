package br.com.clubbar.partner

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "clubbar/app_control")
            .setMethodCallHandler { call, result ->
                if (call.method == "finishAndRemoveTask") {
                    finishAndRemoveTask()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
