package com.example.sw_air_link

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlin.math.min

class MainActivity : FlutterActivity() {
    private val requestCaptureCode = 7310
    private val methodChannelName = "sw_air_link/mirror"
    private val eventChannelName = "sw_air_link/mirror_frames"

    private var pendingResult: MethodChannel.Result? = null
    private var eventSink: EventChannel.EventSink? = null
    private var projectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var captureThread: HandlerThread? = null
    private var captureHandler: Handler? = null
    private var captureWidth = 0
    private var captureHeight = 0
    private var lastFrameMs = 0L
    private var stopping = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "startCapture" -> startCapture(result)
                "stopCapture" -> {
                    stopCaptureInternal()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun startCapture(result: MethodChannel.Result) {
        if (mediaProjection != null && virtualDisplay != null) {
            result.success("capturing")
            return
        }
        pendingResult = result
        try {
            val intent = projectionManager?.createScreenCaptureIntent()
            if (intent == null) {
                pendingResult?.error("NO_MANAGER", "MediaProjectionManager indisponível", null)
                pendingResult = null
                return
            }
            startActivityForResult(intent, requestCaptureCode)
        } catch (error: Throwable) {
            pendingResult?.error("CAPTURE_START_ERROR", error.message, null)
            pendingResult = null
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != requestCaptureCode) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            pendingResult?.error("PERMISSION_DENIED", "Permissão de captura negada", null)
            pendingResult = null
            sendStatus("Permissão de captura negada pelo Android.")
            return
        }

        try {
            mediaProjection = projectionManager?.getMediaProjection(resultCode, data)
            setupCapture()
            pendingResult?.success("capturing")
            pendingResult = null
            sendStatus("Captura real iniciada. Enviando frames para o navegador.")
        } catch (error: Throwable) {
            pendingResult?.error("CAPTURE_ERROR", error.message, null)
            pendingResult = null
            sendStatus("Falha ao iniciar captura: ${error.message ?: "erro desconhecido"}")
            stopCaptureInternal()
        }
    }

    private fun setupCapture() {
        val projection = mediaProjection ?: throw IllegalStateException("MediaProjection ausente")
        stopping = false

        captureThread = HandlerThread("SWAirLinkCaptureThread").also { it.start() }
        captureHandler = Handler(captureThread!!.looper)

        val metrics = resources.displayMetrics
        captureWidth = metrics.widthPixels
        captureHeight = metrics.heightPixels
        val density = metrics.densityDpi

        projection.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                if (!stopping) {
                    stopCaptureInternal()
                    sendStatus("Captura encerrada pelo sistema Android.")
                }
            }
        }, captureHandler)

        imageReader = ImageReader.newInstance(captureWidth, captureHeight, PixelFormat.RGBA_8888, 2)
        imageReader?.setOnImageAvailableListener({ reader ->
            captureHandler?.post { processImage(reader) }
        }, captureHandler)

        virtualDisplay = projection.createVirtualDisplay(
            "SWAirLinkScreenCapture",
            captureWidth,
            captureHeight,
            density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface,
            null,
            captureHandler
        )
    }

    private fun processImage(reader: ImageReader) {
        val now = System.currentTimeMillis()
        if (now - lastFrameMs < 320) {
            reader.acquireLatestImage()?.close()
            return
        }
        lastFrameMs = now

        val image: Image = reader.acquireLatestImage() ?: return
        try {
            val plane = image.planes.firstOrNull() ?: return
            val buffer = plane.buffer
            val pixelStride = plane.pixelStride
            val rowStride = plane.rowStride
            val rowPadding = rowStride - pixelStride * captureWidth
            val bitmapWidth = captureWidth + rowPadding / pixelStride

            val rawBitmap = Bitmap.createBitmap(bitmapWidth, captureHeight, Bitmap.Config.ARGB_8888)
            rawBitmap.copyPixelsFromBuffer(buffer)

            val cropped = Bitmap.createBitmap(rawBitmap, 0, 0, captureWidth, captureHeight)
            rawBitmap.recycle()

            val targetWidth = min(540, captureWidth)
            val targetHeight = (captureHeight * (targetWidth.toFloat() / captureWidth)).toInt().coerceAtLeast(1)
            val scaled = Bitmap.createScaledBitmap(cropped, targetWidth, targetHeight, true)
            cropped.recycle()

            val output = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 42, output)
            scaled.recycle()

            val base64 = Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
            runOnUiThread {
                eventSink?.success(
                    mapOf(
                        "type" to "frame",
                        "image" to base64,
                        "width" to targetWidth,
                        "height" to targetHeight
                    )
                )
            }
        } catch (error: Throwable) {
            sendStatus("Falha ao processar frame: ${error.message ?: "erro desconhecido"}")
        } finally {
            image.close()
        }
    }

    private fun sendStatus(message: String) {
        runOnUiThread {
            eventSink?.success(mapOf("type" to "status", "message" to message))
        }
    }

    private fun stopCaptureInternal() {
        stopping = true
        try { virtualDisplay?.release() } catch (_: Throwable) {}
        try { imageReader?.close() } catch (_: Throwable) {}
        try { mediaProjection?.stop() } catch (_: Throwable) {}
        try { captureThread?.quitSafely() } catch (_: Throwable) {}
        virtualDisplay = null
        imageReader = null
        mediaProjection = null
        captureThread = null
        captureHandler = null
        lastFrameMs = 0L
    }

    override fun onDestroy() {
        stopCaptureInternal()
        super.onDestroy()
    }
}
