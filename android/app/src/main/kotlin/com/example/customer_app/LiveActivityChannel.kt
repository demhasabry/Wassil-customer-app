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
    // Same "reached/completed" green used everywhere else in
    // design_handoff_wassil/LIVE-ACTIVITY-1c.md (Lock Screen dots, iOS
    // progress bars/ring) — kept here too so "green = further along" reads
    // consistently across both platforms.
    private const val PROGRESS_GREEN = 0xFF4ADE9B.toInt()

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
                                putExtra(DeliveryTrackingService.EXTRA_VEHICLE_TEXT, call.argument<String>("vehicleText") ?: "")
                                putExtra(DeliveryTrackingService.EXTRA_PLATE, call.argument<String>("plate") ?: "")
                                putExtra(DeliveryTrackingService.EXTRA_PROGRESS, call.argument<Double>("progress") ?: 0.0)
                                putExtra(DeliveryTrackingService.EXTRA_UNIT, call.argument<String>("unit") ?: "")
                                putExtra(DeliveryTrackingService.EXTRA_UNIT_SHORT, call.argument<String>("unitShort") ?: "")
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
    fun buildNotification(
        context: Context,
        statusText: String,
        etaText: String,
        riderName: String,
        vehicleText: String,
        plate: String,
        progress: Double,
        unit: String,
        unitShort: String,
    ): Notification {
        ensureChannel(context)
        val etaWithUnit = if (etaText.isNotEmpty()) "$etaText $unitShort" else ""
        val contentText = listOf(riderName, vehicleText, etaWithUnit).filter { it.isNotEmpty() }.joinToString(" · ")
        val progressPercent = (progress * 100).toInt().coerceIn(0, 100)
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
        if (contentText.isNotEmpty()) {
            builder.setContentText(contentText)
        }
        if (plate.isNotEmpty()) {
            // Puts the plate in the header next to the app name, where
            // Android users expect trip details (design_handoff_wassil/
            // LIVE-ACTIVITY-1c.md).
            builder.setSubText(plate)
        }
        if (Build.VERSION.SDK_INT >= 36) {
            // Android 16+ Live Updates. Colorized and promoted-ongoing are
            // mutually exclusive — Android's own documented eligibility
            // rule for setRequestPromotedOngoing(true) explicitly requires
            // setColorized(false) — so this branch skips colorized in
            // exchange for the actual promoted status-bar chip, a strictly
            // bigger visibility win on OS versions that support it.
            // Two segments (not the spec text's literal "three" — matching
            // the 2-phase 0–0.5/0.5–1.0 model used everywhere else in this
            // same spec for progress, e.g. the Lock Screen's own two
            // tracks between its three dots) with points at the 50/100
            // boundaries. Segment/point colors are this file's own judgment
            // call given the spec's wording here ("0-50 blue-white") is
            // ambiguous — blue for the first half, the same progress green
            // used everywhere else in the spec for the second, so
            // "reached = green" reads consistently across both platforms.
            val progressStyle = NotificationCompat.ProgressStyle()
                .setProgressSegments(
                    listOf(
                        NotificationCompat.ProgressStyle.Segment(50).setColor(BRAND_COLOR),
                        NotificationCompat.ProgressStyle.Segment(50).setColor(PROGRESS_GREEN),
                    ),
                )
                .setProgressPoints(
                    listOf(
                        NotificationCompat.ProgressStyle.Point(50).setColor(PROGRESS_GREEN),
                        NotificationCompat.ProgressStyle.Point(100).setColor(PROGRESS_GREEN),
                    ),
                )
                .setProgress(progressPercent)
            builder.setStyle(progressStyle)
            builder.setRequestPromotedOngoing(true)
        } else {
            // Pre-36: colorized renders a plain setProgress bar white on
            // the brand-blue card automatically — no extra styling needed
            // (design_handoff_wassil/LIVE-ACTIVITY-1c.md's own Android
            // section). BigTextStyle and ProgressStyle are mutually
            // exclusive, which is only reachable on the API 36+ branch
            // above anyway, but kept scoped to this branch for clarity.
            builder.setColorized(true)
            builder.setProgress(100, progressPercent, false)
            if (contentText.isNotEmpty()) {
                builder.setStyle(NotificationCompat.BigTextStyle().bigText(contentText))
            }
        }
        return builder.build()
    }
}
