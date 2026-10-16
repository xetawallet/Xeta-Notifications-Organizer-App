package com.xetawallet.xeta_notifications_organizer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.app.NotificationManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val storageExecutor = Executors.newSingleThreadExecutor { task ->
        Thread(task, "notification-archive-reader").apply { isDaemon = true }
    }
    private lateinit var channel: MethodChannel
    private var notificationsReceiverRegistered = false
    private val notificationsChangedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (::channel.isInitialized) {
                channel.invokeMethod("notificationsChanged", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "xeta_notifications")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "notifications" -> runStorage(result) { NotificationStore.load(this) }
                "setFlag" -> runStorage(result) { NotificationStore.setFlag(this, call.argument("id"), call.argument("flag"), call.argument("value") ?: false) }
                "setReadMany" -> runStorage(result) { NotificationStore.setReadMany(this, call.argument<List<String>>("ids").orEmpty(), call.argument("value") ?: false) }
                "clearNotifications" -> runStorage(result) { NotificationStore.clearNotifications(this) }
                "deleteGroups" -> runStorage(result) {
                    NotificationStore.deleteGroups(
                        this,
                        call.argument<String>("type") ?: "",
                        call.argument<List<String>>("values").orEmpty(),
                    )
                }
                "importantApps" -> result.success(NotificationStore.importantApps(this).toList())
                "repetitiveApps" -> result.success(NotificationStore.repetitiveApps(this).toList())
                "setImportantApps" -> {
                    val saved = NotificationStore.setImportantApps(this, call.argument<List<String>>("apps").orEmpty())
                    if (saved) NotificationCaptureService.refresh(this)
                    result.success(saved)
                }
                "setRepetitiveApps" -> result.success(NotificationStore.setRepetitiveApps(this, call.argument<List<String>>("apps").orEmpty()))
                "installedApps" -> result.success(NotificationStore.installedApps(this))
                "silenceNonImportant" -> result.success(NotificationStore.silenceNonImportant(this))
                "setSilenceNonImportant" -> {
                    val saved = NotificationStore.setSilenceNonImportant(this, call.argument<Boolean>("value") ?: true)
                    if (saved) NotificationCaptureService.refresh(this)
                    result.success(saved)
                }
                "onboarded" -> result.success(NotificationStore.onboarded(this))
                "setOnboarded" -> result.success(NotificationStore.setOnboarded(this, call.argument<Boolean>("value") ?: true))
                "privacyConsent" -> result.success(NotificationStore.privacyConsent(this))
                "setPrivacyConsent" -> result.success(NotificationStore.setPrivacyConsent(this, call.argument<Boolean>("value") ?: false))
                "darkMode" -> result.success(NotificationStore.darkMode(this))
                "setDarkMode" -> result.success(NotificationStore.setDarkMode(this, call.argument<Boolean>("value") ?: false))
                "restrictedDone" -> result.success(NotificationStore.restrictedDone(this))
                "setRestrictedDone" -> result.success(NotificationStore.setRestrictedDone(this, call.argument<Boolean>("value") ?: true))
                "viewMode" -> result.success(NotificationStore.viewMode(this, call.argument<String>("key") ?: "notifications"))
                "setViewMode" -> result.success(NotificationStore.setViewMode(this, call.argument<String>("key") ?: "notifications", call.argument<String>("value") ?: "all"))
                "openNotification" -> result.success(NotificationCaptureService.open(this, call.argument("id")))
                "listenerEnabled" -> {
                    val component = android.content.ComponentName(this, NotificationCaptureService::class.java).flattenToString()
                    val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                        .orEmpty().split(':').contains(component)
                    result.success(enabled)
                }
                "appNotificationsEnabled" -> result.success(getSystemService(NotificationManager::class.java).areNotificationsEnabled())
                "openListenerSettings" -> { startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)); result.success(null) }
                "openAppNotificationSettings" -> {
                    startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                    result.success(null)
                }
                "openAppSettings" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                    result.success(null)
                }
                "openSource" -> {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/xetawallet/Xeta-Notifications-Organizer-App")))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        registerNotificationsReceiver()
    }

    private fun <T> runStorage(result: MethodChannel.Result, task: () -> T) {
        storageExecutor.execute {
            try {
                val value = task()
                runOnUiThread { result.success(value) }
            } catch (error: Exception) {
                runOnUiThread { result.error("notification_storage", error.message, null) }
            }
        }
    }

    private fun registerNotificationsReceiver() {
        if (notificationsReceiverRegistered) return
        val filter = IntentFilter(NotificationCaptureService.ACTION_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(notificationsChangedReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(notificationsChangedReceiver, filter)
        }
        notificationsReceiverRegistered = true
    }

    override fun onDestroy() {
        if (notificationsReceiverRegistered) {
            unregisterReceiver(notificationsChangedReceiver)
            notificationsReceiverRegistered = false
        }
        super.onDestroy()
    }
}
