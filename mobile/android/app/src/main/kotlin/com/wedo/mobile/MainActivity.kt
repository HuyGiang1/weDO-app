package com.wedo.mobile

import android.Manifest
import android.app.Dialog
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.SurfaceTexture
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.hardware.Camera
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.util.TypedValue
import android.view.Gravity
import android.view.TextureView
import android.view.ViewGroup
import android.view.Window
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import com.google.zxing.BarcodeFormat
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.MultiFormatReader
import com.google.zxing.PlanarYUVLuminanceSource
import com.google.zxing.common.HybridBinarizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.EnumMap
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

@Suppress("DEPRECATION")
class MainActivity : FlutterActivity() {
    private var pendingSave: (() -> Unit)? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingScanResult: MethodChannel.Result? = null
    private var deepLinkChannel: MethodChannel? = null
    private var initialDeepLink: String? = null
    private var activeScannerDialog: Dialog? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wedo/media_gallery")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveImage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingResult != null) {
                    result.error("save_busy", "Save already in progress", null)
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val mime = call.argument<String>("contentType")
                val suffix = mapOf("image/jpeg" to "jpg", "image/png" to "png", "image/webp" to "webp")[mime]
                if (bytes == null || bytes.isEmpty() || bytes.size > 10 * 1024 * 1024 || suffix == null) {
                    result.error("invalid_file", "Unsupported image", null)
                    return@setMethodCallHandler
                }
                pendingResult = result
                val save = {
                    Thread {
                        var failed = false
                        try { saveOriginal(bytes, mime!!, suffix) } catch (_: Exception) { failed = true }
                        runOnUiThread {
                            pendingResult = null
                            if (failed) result.error("save_failed", "Unable to save image", null)
                            else result.success(null)
                        }
                    }.start()
                }
                if (Build.VERSION.SDK_INT < 29 && checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                    pendingSave = save
                    requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), 3901)
                } else save()
            }

        val linkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wedo/deep_links")
        deepLinkChannel = linkChannel
        linkChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    val link = initialDeepLink
                    initialDeepLink = null
                    result.success(link)
                }
                "shareText" -> {
                    val text = call.argument<String>("text")?.trim()
                    val subject = call.argument<String>("subject")?.trim()
                    if (text.isNullOrEmpty()) {
                        result.error("invalid_args", "Text is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val sendIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                            if (!subject.isNullOrEmpty()) {
                                putExtra(Intent.EXTRA_SUBJECT, subject)
                            }
                        }
                        val chooser = Intent.createChooser(sendIntent, subject ?: "Chia sẻ liên kết")
                        startActivity(chooser)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("share_failed", e.message, null)
                    }
                }
                "scanQr" -> {
                    if (pendingScanResult != null) {
                        result.error("scan_busy", "Scanner already active", null)
                        return@setMethodCallHandler
                    }
                    pendingScanResult = result
                    if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                        requestPermissions(arrayOf(Manifest.permission.CAMERA), 3902)
                    } else {
                        openQrScannerDialog()
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 3901) {
            val save = pendingSave
            pendingSave = null
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) save?.invoke()
            else {
                pendingResult?.error("permission_denied", "Photo permission denied", null)
                pendingResult = null
            }
        } else if (requestCode == 3902) {
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
                openQrScannerDialog()
            } else {
                val res = pendingScanResult
                pendingScanResult = null
                res?.error("camera_permission_denied", "Camera permission denied", null)
            }
        }
    }

    private fun openQrScannerDialog() {
        val scanFinished = AtomicBoolean(false)
        val executor = Executors.newSingleThreadExecutor()
        val decodingFrame = AtomicBoolean(false)
        var camera: Camera? = null

        val reader = MultiFormatReader().apply {
            val hints = EnumMap<DecodeHintType, Any>(DecodeHintType::class.java)
            hints[DecodeHintType.POSSIBLE_FORMATS] = listOf(BarcodeFormat.QR_CODE)
            hints[DecodeHintType.TRY_HARDER] = true
            setHints(hints)
        }

        val dialog = Dialog(this, android.R.style.Theme_Black_NoTitleBar_Fullscreen)
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)
        activeScannerDialog = dialog

        fun finishScan(qrValue: String?, errorCode: String? = null, errorMessage: String? = null) {
            if (!scanFinished.compareAndSet(false, true)) return
            runOnUiThread {
                try {
                    camera?.setPreviewCallback(null)
                    camera?.stopPreview()
                    camera?.release()
                } catch (_: Exception) {}
                camera = null
                executor.shutdownNow()
                try {
                    if (dialog.isShowing) dialog.dismiss()
                } catch (_: Exception) {}
                activeScannerDialog = null
                val res = pendingScanResult
                pendingScanResult = null
                if (errorCode != null) {
                    res?.error(errorCode, errorMessage, null)
                } else {
                    res?.success(qrValue)
                }
            }
        }

        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        val textureView = TextureView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        root.addView(textureView)

        val dp = { v: Int ->
            TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                v.toFloat(),
                resources.displayMetrics
            ).toInt()
        }

        val ReticleSize = dp(240)
        val reticle = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(ReticleSize, ReticleSize, Gravity.CENTER)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(24).toFloat()
                setStroke(dp(3), Color.parseColor("#B880FF"))
                setColor(Color.TRANSPARENT)
            }
        }
        root.addView(reticle)

        val topBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(20), dp(40), dp(20), dp(16))
            setBackgroundColor(Color.parseColor("#88000000"))
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP
            )
        }

        val titleView = TextView(this).apply {
            text = "Quét mã QR bạn bè"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }
        topBar.addView(titleView)

        val closeBtn = Button(this).apply {
            text = "Đóng"
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener { finishScan(null) }
        }
        topBar.addView(closeBtn)
        root.addView(topBar)

        val bottomHint = TextView(this).apply {
            text = "Đặt mã QR weDO vào trong khung để mở hồ sơ"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            gravity = Gravity.CENTER
            setPadding(dp(24), dp(16), dp(24), dp(48))
            setBackgroundColor(Color.parseColor("#88000000"))
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM
            )
        }
        root.addView(bottomHint)

        textureView.surfaceTextureListener = object : TextureView.SurfaceTextureListener {
            override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
                try {
                    val cam = Camera.open()
                    camera = cam
                    cam.setDisplayOrientation(90)
                    val params = cam.parameters
                    val focusModes = params.supportedFocusModes
                    if (focusModes != null) {
                        when {
                            focusModes.contains(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE) ->
                                params.focusMode = Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE
                            focusModes.contains(Camera.Parameters.FOCUS_MODE_AUTO) ->
                                params.focusMode = Camera.Parameters.FOCUS_MODE_AUTO
                        }
                    }
                    cam.parameters = params
                    cam.setPreviewTexture(surface)
                    cam.setPreviewCallback { data, c ->
                        if (scanFinished.get() || data == null) return@setPreviewCallback
                        if (!decodingFrame.compareAndSet(false, true)) return@setPreviewCallback
                        val previewSize = try { c.parameters.previewSize } catch (_: Exception) { null }
                        if (previewSize == null) {
                            decodingFrame.set(false)
                            return@setPreviewCallback
                        }
                        val w = previewSize.width
                        val h = previewSize.height
                        val frameCopy = data.clone()
                        executor.execute {
                            try {
                                val decoded = decodeQrFrame(reader, frameCopy, w, h)
                                if (!decoded.isNullOrBlank()) {
                                    finishScan(decoded)
                                }
                            } catch (_: Exception) {
                            } finally {
                                decodingFrame.set(false)
                            }
                        }
                    }
                    cam.startPreview()
                } catch (e: Exception) {
                    finishScan(null, "camera_unavailable", e.message ?: "Unable to start camera")
                }
            }

            override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {}
            override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
                finishScan(null)
                return true
            }
            override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {}
        }

        dialog.setOnCancelListener { finishScan(null) }
        dialog.setContentView(root)
        dialog.show()
    }

    private fun decodeQrFrame(reader: MultiFormatReader, yuv: ByteArray, width: Int, height: Int): String? {
        try {
            val source = PlanarYUVLuminanceSource(yuv, width, height, 0, 0, width, height, false)
            val bitmap = BinaryBitmap(HybridBinarizer(source))
            return reader.decodeWithState(bitmap).text
        } catch (_: Exception) {
            reader.reset()
        }
        // Try rotated 90 degrees for portrait camera sensor orientation
        try {
            val rotated = ByteArray(width * height)
            var k = 0
            for (x in 0 until width) {
                for (y in height - 1 downTo 0) {
                    rotated[k++] = yuv[y * width + x]
                }
            }
            val source = PlanarYUVLuminanceSource(rotated, height, width, 0, 0, height, width, false)
            val bitmap = BinaryBitmap(HybridBinarizer(source))
            return reader.decodeWithState(bitmap).text
        } catch (_: Exception) {
            reader.reset()
        }
        return null
    }

    private fun saveOriginal(bytes: ByteArray, mime: String, suffix: String) {
        val name = "weDO-${UUID.randomUUID()}.$suffix"
        if (Build.VERSION.SDK_INT >= 29) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, name)
                put(MediaStore.Images.Media.MIME_TYPE, mime)
                put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/weDO")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Save failed")
            try {
                contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                    ?: throw IllegalStateException("Save failed")
                val completed = ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }
                check(contentResolver.update(uri, completed, null, null) == 1)
            } catch (error: Exception) {
                contentResolver.delete(uri, null, null)
                throw error
            }
        } else {
            val directory = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "weDO")
            check(directory.isDirectory || directory.mkdirs())
            val file = File(directory, name)
            try { file.outputStream().use { it.write(bytes) } }
            catch (error: Exception) { file.delete(); throw error }
            MediaScannerConnection.scanFile(this, arrayOf(file.absolutePath), arrayOf(mime), null)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureDeepLinkIntent(intent, isLaunch = true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(
                    "wedo_notifications",
                    "WeDo notifications",
                    NotificationManager.IMPORTANCE_DEFAULT
                )
            )
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureDeepLinkIntent(intent, isLaunch = false)
    }

    private fun captureDeepLinkIntent(intent: Intent?, isLaunch: Boolean) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val link = intent.dataString?.trim()
        if (link.isNullOrEmpty()) return
        val channel = deepLinkChannel
        if (!isLaunch && channel != null) {
            channel.invokeMethod("onDeepLink", link)
        } else {
            initialDeepLink = link
        }
    }
}
