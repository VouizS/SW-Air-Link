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
import android.os.Build
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
    private var frameCounter = 0

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
                    stopCaptureInternal(stopServiceToo = true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                sendStatus("Canal de frames pronto. Ao autorizar o Android, a captura será iniciada.")
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun startCapture(result: MethodChannel.Result) {
        if (mediaProjection != null && virtualDisplay != null) {
            result.success("capturing")
            sendStatus("Captura já está ativa. Enviando frames para o navegador.")
            return
        }

        if (pendingResult != null) {
            result.success("permission_requested")
            sendStatus("Permissão de captura já foi solicitada. Responda ao aviso do Android.")
            return
        }

        pendingResult = result
        sendStatus("Solicitando permissão real de captura do Android...")

        try {
            val intent = projectionManager?.createScreenCaptureIntent()
            if (intent == null) {
                pendingResult?.error("NO_MANAGER", "MediaProjectionManager indisponível", null)
                pendingResult = null
                sendStatus("Falha: MediaProjectionManager indisponível neste dispositivo.")
                return
            }
            startActivityForResult(intent, requestCaptureCode)
        } catch (error: Throwable) {
            pendingResult?.error("CAPTURE_START_ERROR", error.message ?: "erro desconhecido", null)
            pendingResult = null
            sendStatus("Falha ao abrir permissão de captura: ${error.message ?: "erro desconhecido"}")
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != requestCaptureCode) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            pendingResult?.success("permission_denied")
            pendingResult = null
            sendStatus("Permissão de captura cancelada ou negada pelo Android.")
            return
        }

        try {
            sendStatus("Permissão aceita. Preparando serviço de captura...")
            startProjectionService()
            mediaProjection = projectionManager?.getMediaProjection(resultCode, data)
            pendingResult?.success("permission_granted")
            pendingResult = null
            setupCapture()
            sendStatus("Captura real iniciada. Enviando frames para o navegador.")
        } catch (error: Throwable) {
            pendingResult?.success("permission_granted")
            pendingResult = null
            sendStatus("Falha ao iniciar captura após permissão: ${error.message ?: error.javaClass.simpleName}")
            stopCaptureInternal(stopServiceToo = true)
        }
    }

    private fun startProjectionService() {
        val serviceIntent = Intent(this, MirrorProjectionService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun setupCapture() {
        val projection = mediaProjection ?: throw IllegalStateException("MediaProjection ausente")
        stopping = false
        frameCounter = 0

        captureThread = HandlerThread("SWAirLinkCaptureThread").also { it.start() }
        captureHandler = Handler(captureThread!!.looper)

        val metrics = resources.displayMetrics
        val sourceWidth = metrics.widthPixels.coerceAtLeast(1)
        val sourceHeight = metrics.heightPixels.coerceAtLeast(1)
        val density = metrics.densityDpi

        captureWidth = min(540, sourceWidth)
        captureHeight = (sourceHeight * (captureWidth.toFloat() / sourceWidth.toFloat())).toInt().coerceAtLeast(1)

        projection.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                if (!stopping) {
                    stopCaptureInternal(stopServiceToo = true)
                    sendStatus("Captura encerrada pelo sistema Android.")
                }
            }
        }, captureHandler)

        imageReader = ImageReader.newInstance(captureWidth, captureHeight, PixelFormat.RGBA_8888, 3)
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

        if (virtualDisplay == null) {
            throw IllegalStateException("VirtualDisplay não foi criado")
        }
    }

    private fun processImage(reader: ImageReader) {
        val now = System.currentTimeMillis()
        val maybeImage = try { reader.acquireLatestImage() } catch (_: Throwable) { null } ?: return

        if (now - lastFrameMs < 360) {
            maybeImage.close()
            return
        }
        lastFrameMs = now

        val image: Image = maybeImage
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

            val output = ByteArrayOutputStream()
            cropped.compress(Bitmap.CompressFormat.JPEG, 45, output)
            cropped.recycle()

            frameCounter += 1
            val base64 = Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
            runOnUiThread {
                eventSink?.success(
                    mapOf(
                        "type" to "frame",
                        "image" to base64,
                        "width" to captureWidth,
                        "height" to captureHeight,
                        "nativeFrame" to frameCounter
                    )
                )
            }
        } catch (error: Throwable) {
            sendStatus("Falha ao processar frame: ${error.message ?: error.javaClass.simpleName}")
        } finally {
            image.close()
        }
    }

    private fun sendStatus(message: String) {
        runOnUiThread {
            eventSink?.success(mapOf("type" to "status", "message" to message))
        }
    }

    private fun stopCaptureInternal(stopServiceToo: Boolean) {
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
        frameCounter = 0
        if (stopServiceToo) {
            try { stopService(Intent(this, MirrorProjectionService::class.java)) } catch (_: Throwable) {}
        }
    }

    override fun onDestroy() {
        stopCaptureInternal(stopServiceToo = true)
        super.onDestroy()
    }
}
