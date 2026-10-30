package com.example.parku

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "parku/analytics_device_context")
            .setMethodCallHandler { call, result ->
                if (call.method == "read") {
                    result.success(mapOf(
                        "device_model" to Build.MODEL,
                        "device_brand" to Build.MANUFACTURER,
                        "os_version" to Build.VERSION.RELEASE,
                        "os_api_level" to Build.VERSION.SDK_INT
                    ))
                } else {
                    result.notImplemented()
                }
            }
    }
}
