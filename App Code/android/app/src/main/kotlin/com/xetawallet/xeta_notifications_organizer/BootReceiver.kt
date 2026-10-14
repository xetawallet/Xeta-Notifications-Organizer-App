package com.xetawallet.xeta_notifications_organizer

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                // Android does not automatically reconnect every listener at
                // the same point during boot on every device/vendor.
                NotificationListenerService.requestRebind(
                    ComponentName(context, NotificationCaptureService::class.java)
                )
            } catch (_: Exception) {
                // The service may not be enabled yet; Android will reconnect
                // it when notification access is granted.
            }
        }
    }
}
