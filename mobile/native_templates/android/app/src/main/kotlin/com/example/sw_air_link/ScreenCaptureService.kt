package com.example.sw_air_link

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.util.Base64
import android.util.DisplayMetrics
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicBoolean

class ScreenCaptureService : Service() {
    companion object {
        const val ACTION_START = "swair.START_CAPTURE"
        const val ACTION_STOP = "swair.STOP_CAPTURE"
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_DATA = "data"
        private const val CHANNEL = "sw_air_link_capture"
        private const val NOTIF = 3305
    }
    private var projection: MediaProjection? = null
    private var display: VirtualDisplay? = null
    private var reader: ImageReader? = null
    private var thread: HandlerThread? = null
    private var handler: Handler? = null
    private var last = 0L
    private val busy = AtomicBoolean(false)

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onCreate(){ super.onCreate(); thread = HandlerThread("SWAirCapture").also{it.start()}; handler = Handler(thread!!.looper); channel() }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if(intent?.action == ACTION_STOP){ stopAll(); stopSelf(); return START_NOT_STICKY }
        if(intent?.action == ACTION_START){
            try {
                foreground()
                val code = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
                val data = if(Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(EXTRA_DATA, Intent::class.java) else @Suppress("DEPRECATION") intent.getParcelableExtra(EXTRA_DATA)
                if(code == 0 || data == null){ MainActivity.error("Dados da permissão ausentes."); stopSelf(); return START_NOT_STICKY }
                startCapture(code, data)
            } catch(e: Exception){ MainActivity.error("Crash Guard: ${e.javaClass.simpleName}: ${e.message}"); stopSelf() }
        }
        return START_STICKY
    }

    private fun channel(){ if(Build.VERSION.SDK_INT >= 26) getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel(CHANNEL, "SW Air Link captura", NotificationManager.IMPORTANCE_LOW)) }
    private fun foreground(){ val n = notif(); if(Build.VERSION.SDK_INT >= 29) startForeground(NOTIF, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION) else startForeground(NOTIF, n) }
    private fun notif(): Notification { val b = if(Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else @Suppress("DEPRECATION") Notification.Builder(this); return b.setContentTitle("SW Air Link").setContentText("Espelhamento experimental ativo").setSmallIcon(applicationInfo.icon).setOngoing(true).build() }

    private fun startCapture(resultCode: Int, data: Intent){
        val m = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        projection = m.getMediaProjection(resultCode, data)
        val h = handler ?: Handler(mainLooper)
        projection?.registerCallback(object: MediaProjection.Callback(){ override fun onStop(){ MainActivity.status("Captura encerrada pelo Android."); stopAll() } }, h)
        val metrics = DisplayMetrics(); @Suppress("DEPRECATION") windowManager.defaultDisplay.getRealMetrics(metrics)
        val sw = metrics.widthPixels.coerceAtLeast(1); val sh = metrics.heightPixels.coerceAtLeast(1)
        val scale = if(sw > 360) 360f / sw.toFloat() else 1f
        val w = (sw * scale).toInt().coerceAtLeast(160); val hh = (sh * scale).toInt().coerceAtLeast(160)
        reader = ImageReader.newInstance(w, hh, PixelFormat.RGBA_8888, 2)
        display = projection?.createVirtualDisplay("SWAirLinkDisplay", w, hh, metrics.densityDpi, DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, reader!!.surface, null, h)
        reader?.setOnImageAvailableListener({ r ->
            val now = System.currentTimeMillis()
            if(now - last < 350){ r.acquireLatestImage()?.close(); return@setOnImageAvailableListener }
            if(!busy.compareAndSet(false,true)){ r.acquireLatestImage()?.close(); return@setOnImageAvailableListener }
            last = now
            try {
                val img = r.acquireLatestImage() ?: return@setOnImageAvailableListener
                img.use {
                    val p = it.planes[0]; val buf = p.buffer; val rowPad = p.rowStride - p.pixelStride * w; val bw = w + rowPad / p.pixelStride
                    val bmp = Bitmap.createBitmap(bw, hh, Bitmap.Config.ARGB_8888); bmp.copyPixelsFromBuffer(buf)
                    val crop = Bitmap.createBitmap(bmp, 0, 0, w, hh)
                    val out = ByteArrayOutputStream(); crop.compress(Bitmap.CompressFormat.JPEG, 45, out)
                    MainActivity.frame(Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP))
                    crop.recycle(); bmp.recycle(); out.close()
                }
            } catch(e: Exception){ MainActivity.error("Erro ao processar frame: ${e.message}") } finally { busy.set(false) }
        }, h)
        MainActivity.status("Captura ativa. Aguardando primeiro frame.")
    }

    private fun stopAll(){ try{reader?.setOnImageAvailableListener(null,null)}catch(_:Exception){}; try{display?.release()}catch(_:Exception){}; try{projection?.stop()}catch(_:Exception){}; reader=null; display=null; projection=null }
    override fun onDestroy(){ stopAll(); try{thread?.quitSafely()}catch(_:Exception){}; super.onDestroy() }
}
