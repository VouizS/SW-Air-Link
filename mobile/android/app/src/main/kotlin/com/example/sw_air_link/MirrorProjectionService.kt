package com.example.sw_air_link

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder

class MirrorProjectionService : Service() {
    private val channelId = "sw_air_link_projection"
    private val notificationId = 7301

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(notificationId, buildNotification())
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "SW Air Link espelhamento",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "Mantém a captura de tela ativa durante o espelhamento experimental."
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
                .setSmallIcon(android.R.drawable.presence_video_online)
                .setContentTitle("SW Air Link")
                .setContentText("Espelhamento experimental em andamento")
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setSmallIcon(android.R.drawable.presence_video_online)
                .setContentTitle("SW Air Link")
                .setContentText("Espelhamento experimental em andamento")
                .setOngoing(true)
                .build()
        }
    }
}
