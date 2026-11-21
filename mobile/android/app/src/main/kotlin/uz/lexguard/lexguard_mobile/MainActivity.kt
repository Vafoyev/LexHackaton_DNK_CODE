package uz.lexguard.lexguard_mobile

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.MediaStore
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val SECURITY_CHANNEL = "uz.lexguard/security"
        private const val CAMERA_CHANNEL = "uz.lexguard/camera"
        private const val REQ_CAMERA_PERMISSION = 4101
        private const val REQ_CAPTURE_PHOTO = 4102
    }

    private var pendingCameraResult: MethodChannel.Result? = null
    private var pendingPhotoFile: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecureFlag" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread {
                            if (enabled) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                            result.success(enabled)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAMERA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "capturePhoto" -> {
                        if (pendingCameraResult != null) {
                            result.error("BUSY", "Camera capture already active", null)
                            return@setMethodCallHandler
                        }
                        pendingCameraResult = result
                        ensureCameraPermissionAndLaunch()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun ensureCameraPermissionAndLaunch() {
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

        if (granted) {
            launchNativeCamera()
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.CAMERA),
                REQ_CAMERA_PERMISSION
            )
        }
    }

    private fun launchNativeCamera() {
        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
        if (intent.resolveActivity(packageManager) == null) {
            finishCameraError("NO_CAMERA", "Kamera ilovasi topilmadi")
            return
        }

        try {
            val scansDir = File(cacheDir, "camera_scans")
            if (!scansDir.exists()) {
                scansDir.mkdirs()
            }
            val photoFile = File(scansDir, "scan_${System.currentTimeMillis()}.jpg")
            pendingPhotoFile = photoFile

            val photoUri = FileProvider.getUriForFile(
                this,
                "${packageName}.fileprovider",
                photoFile
            )
            intent.putExtra(MediaStore.EXTRA_OUTPUT, photoUri)
            intent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

            @Suppress("DEPRECATION")
            startActivityForResult(intent, REQ_CAPTURE_PHOTO)
        } catch (e: Exception) {
            finishCameraError("CAMERA_ERROR", e.message ?: "Kamerani ochib bo‘lmadi")
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_CAMERA_PERMISSION) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                launchNativeCamera()
            } else {
                finishCameraError("PERMISSION_DENIED", "Kamera ruxsati berilmadi")
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_CAPTURE_PHOTO) {
            val file = pendingPhotoFile
            val callback = pendingCameraResult
            pendingPhotoFile = null
            pendingCameraResult = null

            if (callback == null) return

            if (resultCode == Activity.RESULT_OK && file != null && file.exists() && file.length() > 0) {
                try {
                    val bytes = file.readBytes()
                    val name = file.name
                    file.delete()
                    callback.success(
                        mapOf(
                            "name" to name,
                            "bytes" to bytes
                        )
                    )
                } catch (e: Exception) {
                    callback.error("READ_ERROR", e.message ?: "Rasmni o‘qib bo‘lmadi", null)
                }
            } else {
                file?.delete()
                callback.success(null)
            }
        }
    }

    private fun finishCameraError(code: String, message: String) {
        val callback = pendingCameraResult
        pendingCameraResult = null
        pendingPhotoFile?.delete()
        pendingPhotoFile = null
        callback?.error(code, message, null)
    }
}
