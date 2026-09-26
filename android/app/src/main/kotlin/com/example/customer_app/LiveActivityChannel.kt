package com.example.customer_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Android's answer to ios/Runner/LiveActivityChannel.swift's ActivityKit
 * bridge — same channel name and method contract, so the Dart-side
 * LiveActivityService (lib/services/live_activity_service.dart) needs zero
 * platform branching. There is no Dynamic-Island-equivalent hardware UI on
 * Android; the closest analogue is DeliveryTrackingService's foreground-
 * service notification, styled like Google Maps'/Uber's ongoing-trip
 * notification (colorized card, round brand icon, rich content visible
 * without needing to expand it) — a foreground service specifically because
 * that's the only mechanism that gets the OS's "important ongoing task"
 * treatment; a plain NotificationManagerCompat.notify() call (this file's
 * first version) only ever produces an ordinary background-app notification
 * regardless of styling.
 *
 * This object is now just the MethodChannel-to-Intent dispatcher —
 * buildNotification() (the actual content/styling) is called by
 * DeliveryTrackingService itself, since that's what owns the foreground
 * lifecycle and must call startForeground() with it directly.
 */
object LiveActivityChannel {
    private const val CHANNEL_NAME = "com.example.customerApp/liveActivity"

    // _v2: a NotificationChannel's importance/sound is immutable once
    // created — bumping IMPORTANCE_LOW to IMPORTANCE_DEFAULT (needed for
    // colorized treatment to render reliably) in this same code wouldn't
    // actually change anything for a device that already created the old
    // "delivery_tracking" channel on a previous test install. A new id
    // guarantees this take effect everywhere, not just on fresh installs.
    const val NOTIFICATION_CHANNEL_ID = "delivery_tracking_v2"
    const val NOTIFICATION_ID = 4200
    private const val BRAND_COLOR = 0xFF2551CA.toInt()

    fun register(flutterEngine: FlutterEngine, context: Context) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                val requestId = call.argument<String>("requestId")
                if (requestId == null) {
                    result.error("BAD_ARGS", "requestId is required", null)
                    return@setMethodCallHandler
                }
                try {
                    when (call.method) {
                        "startOrUpdate" -> {
                            val intent = Intent(context, DeliveryTrackingService::class.java).apply {
                                action = DeliveryTrackingService.ACTION_UPDATE
                                putExtra(DeliveryTrackingService.EXTRA_STATUS_TEXT, call.argument<String>("statusText") ?: "")
                                putExtra(DeliveryTrackingService.EXTRA_ETA_TEXT, call.argument<String>("etaText") ?: "")
                                putExtra(DeliveryTrackingService.EXTRA_RIDER_NAME, call.argument<String>("riderName") ?: "")
                            }
                            ContextCompat.startForegroundService(context, intent)
                            result.success(null)
                        }
                        "end" -> {
                            // Not startForegroundService — the service is already
                            // running and in the foreground at this point, and
                            // this onStartCommand doesn't call startForeground()
                            // again, which startForegroundService() requires
                            // within a few seconds or the system kills the app.
                            context.startService(
                                Intent(context, DeliveryTrackingService::class.java).apply {
                                    action = DeliveryTrackingService.ACTION_STOP
                                },
                            )
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    android.util.Log.e("LiveActivityChannel", "${call.method} failed", e)
                    result.success(null)
                }
            }
    }

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(NOTIFICATION_CHANNEL_ID) != null) return
        // IMPORTANCE_DEFAULT (not LOW) — colorized notifications only render
        // their color reliably at DEFAULT+ importance on most OEMs. Sound
        // and vibration are explicitly disabled instead, since this is a
        // persistent status display, not an alert — actual "your bid was
        // accepted" etc. pushes already have their own, separately
        // configured FCM notification channel.
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Delivery tracking",
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        channel.description = "Shows your delivery's live status while it's in progress"
        channel.setShowBadge(false)
        channel.setSound(null, null)
        channel.enableVibration(false)
        manager.createNotificationChannel(channel)
    }

    // A filled brand-blue circle with the white pin mark inset — matches
    // the round app-brand icon Google Maps' own navigation notification
    // shows as its large icon, built from the same ic_notification vector
    // already used as the small icon rather than shipping a second asset.
    private fun buildLargeIcon(context: Context): Bitmap {
        val size = 128
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = Color.parseColor("#2551CA")
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
        val inset = (size * 0.24).toInt()
        ContextCompat.getDrawable(context, R.drawable.ic_notification)?.apply {
            setBounds(inset, inset, size - inset, size - inset)
            draw(canvas)
        }
        return bitmap
    }

    private fun contentIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    // Called by DeliveryTrackingService, which owns the foreground-service
    // lifecycle and must pass this straight into startForeground().
    fun buildNotification(context: Context, statusText: String, etaText: String, riderName: String): Notification {
        ensureChannel(context)
        val contentText = listOf(riderName, etaText).filter { it.isNotEmpty() }.joinToString(" · ")
        val builder = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setLargeIcon(buildLargeIcon(context))
            .setContentTitle(statusText)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setAutoCancel(false)
            .setContentIntent(contentIntent(context))
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setColor(BRAND_COLOR)
            .setColorized(true)
        if (contentText.isNotEmpty()) {
            builder.setContentText(contentText)
            builder.setStyle(NotificationCompat.BigTextStyle().bigText(contentText))
        }
        return builder.build()
    }
}
