package hu.akihabarai.kronikas_platform_probe

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "hu.akihabarai.kronikas_platform_probe/storage",
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "openGitHubBrowser" -> {
                        val uri = Uri.parse(requireNotNull(call.arguments as? String))
                        require(uri.scheme == "https" && uri.host == "github.com" && uri.userInfo == null)
                        startActivity(Intent(Intent.ACTION_VIEW, uri))
                        result.success(null)
                    }
                    "storagePath" -> result.success(noBackupFilesDir.absolutePath)
                    "protect" -> result.success(ProbeStorage.protect(requireNotNull(call.arguments as? ByteArray)))
                    "unprotect" -> result.success(ProbeStorage.unprotect(requireNotNull(call.arguments as? ByteArray)))
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("keystore_probe_failed", "Protected storage operation failed.", null)
            }
        }
    }
}
