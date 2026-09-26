package com.example.customer_app

import android.app.Service
import android.content.Intent
import android.os.IBinder

/**
 * A real foreground service — the standard, correct mechanism Android apps
 * like Uber and Google Maps use for a persistent, richly-laid-out ongoing
 * notification that's fully visible without the user needing to expand it.
 * LiveActivityChannel.kt (the MethodChannel dispatcher) starts/stops this;
 * it owns the foreground lifecycle and calls startForeground() with the
 * notification LiveActivityChannel.buildNotification() builds.
 */
class DeliveryTrackingService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            when (intent?.action) {
                ACTION_UPDATE -> {
                    val statusText = intent.getStringExtra(EXTRA_STATUS_TEXT) ?: ""
                    val etaText = intent.getStringExtra(EXTRA_ETA_TEXT) ?: ""
                    val riderName = intent.getStringExtra(EXTRA_RIDER_NAME) ?: ""
                    val notification = LiveActivityChannel.buildNotification(this, statusText, etaText, riderName)
                    startForeground(LiveActivityChannel.NOTIFICATION_ID, notification)
                }
                ACTION_STOP -> {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                }
            }
        } catch (e: Exception) {
            // Best-effort, matching LiveActivityService's own swallow-and-move-on
            // approach on the Dart side — a missed status update is not worth
            // crashing the app over. android.util.Log.e surfaces in `flutter
            // run`'s terminal (Flutter forwards the running app's own logcat).
            android.util.Log.e("DeliveryTrackingService", "onStartCommand failed for action=${intent?.action}", e)
            stopSelf()
        }
        return START_NOT_STICKY
    }

    companion object {
        const val ACTION_UPDATE = "com.example.customer_app.action.UPDATE_TRACKING"
        const val ACTION_STOP = "com.example.customer_app.action.STOP_TRACKING"
        const val EXTRA_STATUS_TEXT = "statusText"
        const val EXTRA_ETA_TEXT = "etaText"
        const val EXTRA_RIDER_NAME = "riderName"
    }
}
