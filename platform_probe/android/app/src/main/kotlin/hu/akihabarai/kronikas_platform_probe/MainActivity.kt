package hu.akihabarai.kronikas_platform_probe

import android.app.Activity
import android.content.Intent
import android.provider.OpenableColumns
import java.io.ByteArrayOutputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var documentResult: MethodChannel.Result? = null
    private var debugLogExport: Pair<MethodChannel.Result, ByteArray>? = null

    @Suppress("DEPRECATION")
    private fun saveDebugLog(bytes: ByteArray, result: MethodChannel.Result) {
        if (debugLogExport != null || bytes.isEmpty() || bytes.size > 256 * 1024) {
            result.error("debug_log_export_unavailable", null, null)
            return
        }
        val picker = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "text/plain"
            putExtra(Intent.EXTRA_TITLE, "kronikas-debug.txt")
        }
        debugLogExport = result to bytes
        try {
            startActivityForResult(picker, 151)
        } catch (_: Exception) {
            debugLogExport = null
            result.error("debug_log_picker_failed", null, null)
        }
    }

    private fun completeDebugLogExport(resultCode: Int, data: Intent?) {
        val (result, bytes) = debugLogExport ?: return
        debugLogExport = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        Thread {
            try {
                val name = contentResolver.query(
                    uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null,
                )?.use { if (it.moveToFirst()) it.getString(0) else null }
                val stream = requireNotNull(contentResolver.openOutputStream(uri, "wt"))
                stream.use { it.write(bytes) }
                runOnUiThread { result.success(name ?: "kronikas-debug.txt") }
            } catch (_: Exception) {
                runOnUiThread { result.error("debug_log_write_failed", null, null) }
            }
        }.start()
    }

    @Suppress("DEPRECATION")
    private fun pickStoryDocument(result: MethodChannel.Result) {
        if (documentResult != null) {
            result.error("document_picker_busy", null, null)
            return
        }
        val picker = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                "text/plain", "text/markdown", "text/x-markdown", "application/octet-stream",
            ))
        }
        documentResult = result
        try {
            startActivityForResult(picker, 150)
        } catch (_: Exception) {
            documentResult = null
            result.error("document_picker_failed", null, null)
        }
    }

    @Deprecated("FlutterActivity uses Android activity results")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 151) {
            completeDebugLogExport(resultCode, data)
            return
        }
        if (requestCode != 150) return
        val result = documentResult ?: return
        documentResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        Thread {
            try {
                val name = contentResolver.query(
                    uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null,
                )?.use { if (it.moveToFirst()) it.getString(0) else null }
                require(!name.isNullOrBlank())
                val stream = requireNotNull(contentResolver.openInputStream(uri))
                val bytes = stream.use { input ->
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    while (true) {
                        val read = input.read(buffer)
                        if (read == -1) break
                        require(output.size() + read <= 8 * 1024 * 1024)
                        output.write(buffer, 0, read)
                    }
                    output.toByteArray()
                }
                runOnUiThread { result.success(mapOf("name" to name, "bytes" to bytes, "uri" to uri.toString())) }
            } catch (_: Exception) {
                runOnUiThread { result.error("document_read_failed", null, null) }
            }
        }.start()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "hu.akihabarai.kronikas_platform_probe/storage",
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "pickStoryDocument" -> pickStoryDocument(result)
                    "saveDebugLog" -> saveDebugLog(requireNotNull(call.arguments as? ByteArray), result)
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
