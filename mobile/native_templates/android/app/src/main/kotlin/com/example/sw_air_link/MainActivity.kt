package com.example.sw_air_link

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val requestProjection = 4127
    private var projectionManager: MediaProjectionManager? = null

    companion object {
        private var sink: EventChannel.EventSink? = null
        private val main = Handler(Looper.getMainLooper())
        fun status(msg: String) = main.post { sink?.success(mapOf("type" to "status", "message" to msg)) }
        fun error(msg: String) = main.post { sink?.success(mapOf("type" to "error", "message" to msg)) }
        fun frame(data: String) = main.post { sink?.success(mapOf("type" to "frame", "data" to data)) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "sw_air_link/frames").setStreamHandler(object: EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events; status("Canal de frames pronto.") }
            override fun onCancel(arguments: Any?) { sink = null }
        })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sw_air_link/mirror").setMethodCallHandler { call, result ->
            when(call.method){
                "startProjection" -> {
                    try {
                        val intent = projectionManager?.createScreenCaptureIntent()
                        if(intent == null){ result.error("NO_MANAGER", "MediaProjection indisponível.", null); return@setMethodCallHandler }
                        status("Solicitando permissão de captura ao Android.")
                        startActivityForResult(intent, requestProjection)
                        result.success("permission_requested")
                    } catch(e: Exception){ result.error("START_FAILED", e.message ?: "Falha ao solicitar captura.", null) }
                }
                "stopProjection" -> {
                    try {
                        val i = Intent(this, ScreenCaptureService::class.java)
                        i.action = ScreenCaptureService.ACTION_STOP
                        startService(i)
                        result.success(true)
                    } catch(e: Exception){ result.error("STOP_FAILED", e.message ?: "Falha ao parar.", null) }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if(requestCode != requestProjection) return
        if(resultCode != Activity.RESULT_OK || data == null){ error("Permissão de captura cancelada."); return }
        try {
            val i = Intent(this, ScreenCaptureService::class.java)
            i.action = ScreenCaptureService.ACTION_START
            i.putExtra(ScreenCaptureService.EXTRA_RESULT_CODE, resultCode)
            i.putExtra(ScreenCaptureService.EXTRA_DATA, data)
            if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i) else startService(i)
            status("Permissão aceita. Serviço de captura iniciado.")
        } catch(e: Exception){ error("Falha ao iniciar serviço de captura: ${e.message}") }
    }
}
