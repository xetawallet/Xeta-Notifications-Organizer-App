package com.xetawallet.xeta_notifications_organizer

import android.app.Notification
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.graphics.Color
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONObject
import java.util.LinkedHashMap
import java.util.concurrent.Executors

class NotificationCaptureService : NotificationListenerService() {
    override fun onListenerConnected() {
        // Rebuild the click-action cache after an app/process restart before
        // re-saving active notifications.  The stored copy keeps their read
        // state when this is just a listener reconnect.
        connectedService = this
        activeNotifications.orEmpty().forEach { capture(it) }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        capture(sbn)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // Keep the action cached after the shade row is dismissed. Archived
        // notifications should still try their original action first.
    }

    override fun onListenerDisconnected() {
        if (connectedService === this) connectedService = null
        super.onListenerDisconnected()
    }

    private fun capture(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return
        if (!NotificationStore.privacyConsent(this)) return
        val n = sbn.notification ?: return
        // Apply the filter before inspecting display text. Group summaries and
        // progress notifications often have no title/body, but still need to
        // be cleared when their app is not important.
        val silence = NotificationStore.shouldSilence(this, sbn.packageName)
        if (silence) cancelNotification(sbn.key)

        val title = n.extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val body = (n.extras.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: n.extras.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty()
        if (title.isBlank() && body.isBlank()) return
        val id = notificationId(sbn)
        // Keep the current action hot in memory and save its system token as
        // well. Key by the captured notification instance rather than Android's
        // reusable package/tag/id key so a late removal cannot evict a newer
        // notification's action.
        n.contentIntent?.let { rememberAction(id, it) } ?: removeAction(id)
        val link = NotificationStore.linkFrom(
            title,
            body,
            NotificationStore.textFromExtras(n.extras),
        )
        val repetitive = sbn.packageName in NotificationStore.repetitiveApps(this)
        val record = JSONObject(mapOf(
            "id" to id,
            "key" to sbn.key,
            "tag" to sbn.tag.orEmpty(),
            "notificationId" to sbn.id,
            "packageName" to sbn.packageName,
            "appName" to NotificationStore.appName(this, sbn.packageName),
            "title" to title,
            "body" to body,
            "time" to sbn.postTime,
            "color" to if (n.color != Notification.COLOR_DEFAULT) n.color else Color.rgb(37, 99, 235),
            "iconPath" to "",
            "channelId" to n.channelId.orEmpty(),
            "category" to n.category.orEmpty(),
            "groupKey" to sbn.groupKey.orEmpty(),
            "shortcutId" to n.shortcutId.orEmpty(),
            "creatorPackage" to (n.contentIntent?.creatorPackage ?: ""),
            "pendingIntent" to NotificationStore.encodePendingIntent(n.contentIntent),
            "link" to link,
            "actionKind" to if (n.contentIntent != null) "pendingIntent" else if (link.isNotBlank()) "link" else "openApp",
            "read" to repetitive,
            "starred" to false
        ))
        // NotificationListener callbacks must stay short. Storage migration,
        // icon extraction, and database writes run on one ordered worker.
        storageExecutor.execute {
            try {
                record.put("iconPath", NotificationStore.iconPath(this, sbn.packageName))
                NotificationStore.save(this, record)
                notifyChanged()
            } catch (_: Exception) {
                // A later notification or app refresh can retry persistence.
            }
        }
    }

    private fun notifyChanged() {
        sendBroadcast(android.content.Intent(ACTION_CHANGED).setPackage(packageName))
    }

    companion object {
        const val ACTION_CHANGED = "com.xetawallet.xeta_notifications_organizer.NOTIFICATIONS_CHANGED"
        private const val MAX_CACHED_ACTIONS = 2000
        private val active = LinkedHashMap<String, PendingIntent>(16, .75f, true)
        @Volatile private var connectedService: NotificationCaptureService? = null
        private val storageExecutor = Executors.newSingleThreadExecutor { task ->
            Thread(task, "notification-archive-writer").apply { isDaemon = true }
        }

        fun refresh(ctx: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                try {
                    NotificationListenerService.requestRebind(
                        ComponentName(ctx, NotificationCaptureService::class.java)
                    )
                } catch (_: Exception) {
                    // Notification access may not be enabled yet.
                }
            }
        }

        private fun rememberAction(id: String, pendingIntent: PendingIntent) {
            synchronized(active) {
                active[id] = pendingIntent
                while (active.size > MAX_CACHED_ACTIONS) {
                    val oldest = active.entries.iterator()
                    if (!oldest.hasNext()) break
                    oldest.next()
                    oldest.remove()
                }
            }
        }

        private fun cachedAction(id: String): PendingIntent? = synchronized(active) { active[id] }

        private fun removeAction(id: String) {
            synchronized(active) { active.remove(id) }
        }

        fun open(ctx: Context, id: String?): Boolean {
            if (id.isNullOrBlank()) return false
            val live = try {
                connectedService?.activeNotifications
                    ?.firstOrNull { notificationId(it) == id }
                    ?.notification?.contentIntent
            } catch (_: Exception) {
                null
            }
            val action = live ?: cachedAction(id)
            if (action != null) {
                try {
                    action.send()
                    rememberAction(id, action)
                    return true
                } catch (_: Exception) {
                    synchronized(active) { if (active[id] === action) active.remove(id) }
                }
            }
            return NotificationStore.openStored(ctx, id)
        }

        private fun notificationId(sbn: StatusBarNotification) = "${sbn.postTime}-${sbn.key}"
    }
}
