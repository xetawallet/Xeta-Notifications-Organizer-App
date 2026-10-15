package com.xetawallet.xeta_notifications_organizer

import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.net.Uri
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
import android.os.Parcel
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object NotificationStore {
    private const val PREF = "xeta_notification_store"
    private const val IMPORTANT = "important_apps"
    private const val REPETITIVE = "repetitive_apps"
    private const val SILENCE = "silence_non_important"
    private const val ONBOARDED = "onboarded"
    private const val PRIVACY_CONSENT = "privacy_consent"
    private const val RESTRICTED_DONE = "restricted_done"
    private const val DARK_MODE = "dark_mode"
    private const val VIEW_PREFIX = "view_"
    private const val TABLE = "notifications"
    private const val META_TABLE = "archive_meta"
    private const val MIGRATED = "legacy_json_imported"
    private val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
    private var dbHelper: ArchiveDb? = null

    /**
     * JSON history used to rewrite a full day's file for every notification.
     * Keep the old files until one transaction imports them into this indexed,
     * private database; then remove the migrated copies.
     */
    private fun database(ctx: Context): SQLiteDatabase = synchronized(this) {
        val helper = dbHelper ?: ArchiveDb(ctx.applicationContext).also { dbHelper = it }
        val db = helper.writableDatabase
        val imported = db.rawQuery(
            "SELECT 1 FROM $META_TABLE WHERE name = ? LIMIT 1",
            arrayOf(MIGRATED),
        ).use { it.moveToFirst() }
        if (!imported) migrateLegacyJson(ctx, db)
        db
    }

    private fun migrateLegacyJson(ctx: Context, db: SQLiteDatabase) {
        val legacyDir = File(ctx.filesDir, "notifications")
        val files = legacyDir.listFiles { f -> f.isFile && f.extension == "json" }
            ?.sortedBy { it.name }
            .orEmpty()
        db.beginTransaction()
        try {
            for (file in files) {
                val day = file.nameWithoutExtension
                val records = try { JSONArray(file.readText()) } catch (_: Exception) { JSONArray() }
                for (i in 0 until records.length()) {
                    val item = records.optJSONObject(i) ?: continue
                    val id = item.optString("id")
                    if (id.isBlank()) continue
                    db.insertWithOnConflict(
                        TABLE,
                        null,
                        values(item, day),
                        SQLiteDatabase.CONFLICT_REPLACE,
                    )
                }
            }
            db.insertWithOnConflict(
                META_TABLE,
                null,
                ContentValues().apply { put("name", MIGRATED) },
                SQLiteDatabase.CONFLICT_REPLACE,
            )
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
        files.forEach { it.delete() }
        legacyDir.delete()
    }

    fun save(ctx: Context, item: JSONObject) {
        val db = database(ctx)
        val id = item.optString("id")
        if (id.isBlank()) return
        db.query(
            TABLE,
            arrayOf("key", "time", "title", "body", "packageName", "read", "starred"),
            "id = ?",
            arrayOf(id),
            null,
            null,
            null,
        ).use { cursor ->
            if (cursor.moveToFirst() && sameCapturedNotification(cursor, item)) {
                item.put("read", cursor.getInt(5) != 0)
                item.put("starred", cursor.getInt(6) != 0)
            }
        }
        db.insertWithOnConflict(
            TABLE,
            null,
            values(item, fmt.format(Date(item.optLong("time")))),
            SQLiteDatabase.CONFLICT_REPLACE,
        )
    }

    fun load(ctx: Context): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        // Parcel data is large and only needed when a notification is opened.
        // Omitting it from list results avoids serializing it across the method channel.
        val columns = arrayOf(
            "id", "packageName", "appName", "title", "body", "time", "date", "color",
            "iconPath", "key", "tag", "notificationId", "channelId", "category",
            "groupKey", "shortcutId", "creatorPackage", "link", "actionKind", "read", "starred",
        )
        database(ctx).query(TABLE, columns, null, null, null, null, "time DESC, id DESC")
            .use { cursor -> while (cursor.moveToNext()) out += toMap(cursor) }
        return out
    }

    fun deleteGroups(ctx: Context, type: String, values: List<String>): Int {
        if (values.isEmpty()) return 0
        val column = when (type) {
            "day" -> "date"
            "app" -> "packageName"
            "notification" -> "id"
            else -> return 0
        }
        val db = database(ctx)
        var deleted = 0
        values.distinct().chunked(500).forEach { batch ->
            val where = batch.joinToString(",") { "?" }
            deleted += db.delete(TABLE, "$column IN ($where)", batch.toTypedArray())
        }
        return deleted
    }

    fun setFlag(ctx: Context, id: String?, flag: String?, value: Boolean): Boolean {
        if (id == null || flag !in listOf("read", "starred")) return false
        return database(ctx).update(
            TABLE,
            ContentValues().apply { put(flag, if (value) 1 else 0) },
            "id = ?",
            arrayOf(id),
        ) > 0
    }

    fun setReadMany(ctx: Context, ids: List<String>, value: Boolean): Boolean {
        if (ids.isEmpty()) return false
        val db = database(ctx)
        val values = ContentValues().apply { put("read", if (value) 1 else 0) }
        var changed = false
        // Stay under SQLite's bind-parameter limit for long days.
        ids.distinct().chunked(500).forEach { batch ->
            val where = batch.joinToString(",") { "?" }
            if (db.update(TABLE, values, "id IN ($where)", batch.toTypedArray()) > 0) changed = true
        }
        return changed
    }

    fun clearNotifications(ctx: Context): Boolean {
        database(ctx).delete(TABLE, null, null)
        return true
    }

    fun importantApps(ctx: Context): Set<String> = ctx.getSharedPreferences(PREF, 0).getStringSet(IMPORTANT, emptySet()).orEmpty()
    fun setImportantApps(ctx: Context, apps: List<String>): Boolean = ctx.getSharedPreferences(PREF, 0).edit().putStringSet(IMPORTANT, apps.toSet()).commit()
    fun repetitiveApps(ctx: Context): Set<String> = ctx.getSharedPreferences(PREF, 0).getStringSet(REPETITIVE, emptySet()).orEmpty()
    fun setRepetitiveApps(ctx: Context, apps: List<String>): Boolean = ctx.getSharedPreferences(PREF, 0).edit().putStringSet(REPETITIVE, apps.toSet()).commit()
    fun shouldSilence(ctx: Context, packageName: String): Boolean = silenceNonImportant(ctx) && packageName !in importantApps(ctx)
    fun silenceNonImportant(ctx: Context): Boolean = ctx.getSharedPreferences(PREF, 0).getBoolean(SILENCE, true)
    fun setSilenceNonImportant(ctx: Context, value: Boolean): Boolean = ctx.getSharedPreferences(PREF, 0).edit().putBoolean(SILENCE, value).commit()
    fun onboarded(ctx: Context): Boolean = ctx.getSharedPreferences(PREF, 0).getBoolean(ONBOARDED, false)
    fun setOnboarded(ctx: Context, value: Boolean): Boolean = ctx.getSharedPreferences(PREF, 0).edit().putBoolean(ONBOARDED, value).commit()
    fun privacyConsent(ctx: Context): Boolean = ctx.getSharedPreferences(PREF, 0).getBoolean(PRIVACY_CONSENT, false)
    fun setPrivacyConsent(ctx: Context, value: Boolean): Boolean = ctx.getSharedPreferences(PREF, 0).edit().putBoolean(PRIVACY_CONSENT, value).commit()
    fun restrictedDone(ctx: Context): Boolean = ctx.getSharedPreferences(PREF, 0).getBoolean(RESTRICTED_DONE, false)
    fun setRestrictedDone(ctx: Context, value: Boolean): Boolean = ctx.getSharedPreferences(PREF, 0).edit().putBoolean(RESTRICTED_DONE, value).commit()
    fun darkMode(ctx: Context): Boolean = ctx.getSharedPreferences(PREF, 0).getBoolean(DARK_MODE, true)
    fun setDarkMode(ctx: Context, value: Boolean): Boolean = ctx.getSharedPreferences(PREF, 0).edit().putBoolean(DARK_MODE, value).commit()
    fun viewMode(ctx: Context, key: String): String = ctx.getSharedPreferences(PREF, 0).getString(VIEW_PREFIX + key, "all") ?: "all"
    fun setViewMode(ctx: Context, key: String, value: String): Boolean = ctx.getSharedPreferences(PREF, 0).edit().putString(VIEW_PREFIX + key, value).commit()

    fun installedApps(ctx: Context): List<Map<String, String>> {
        val pm = ctx.packageManager
        val q = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(q, 0).map {
            val pkg = it.activityInfo.packageName
            mapOf("packageName" to pkg, "appName" to it.loadLabel(pm).toString(), "iconPath" to iconPath(ctx, pkg))
        }.distinctBy { it["packageName"] }.sortedBy { it["appName"]?.lowercase(Locale.US) }
    }

    fun appName(ctx: Context, pkg: String): String = try {
        val pm = ctx.packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
    } catch (_: Exception) { pkg }

    fun iconPath(ctx: Context, pkg: String): String = try {
        val f = File(File(ctx.filesDir, "icons").also { it.mkdirs() }, pkg.replace(Regex("[^A-Za-z0-9._-]"), "_") + ".png")
        if (!f.exists()) {
            val d = ctx.packageManager.getApplicationIcon(pkg)
            val b = if (d is BitmapDrawable) d.bitmap else Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888).also {
                val c = Canvas(it)
                d.setBounds(0, 0, c.width, c.height)
                d.draw(c)
            }
            f.outputStream().use { b.compress(Bitmap.CompressFormat.PNG, 100, it) }
        }
        f.absolutePath
    } catch (_: Exception) { "" }

    fun find(ctx: Context, id: String?): JSONObject? {
        if (id == null) return null
        return database(ctx).query(TABLE, null, "id = ?", arrayOf(id), null, null, null)
            .use { cursor -> if (cursor.moveToFirst()) toJson(cursor) else null }
    }

    fun openStored(ctx: Context, id: String?): Boolean {
        return try {
            val o = find(ctx, id) ?: return false
            when (o.optString("actionKind")) {
                "pendingIntent" -> {
                    val action = pendingIntentFrom(o.optString("pendingIntent")) ?: return false
                    action.send()
                    true
                }
                "link" -> {
                    val link = o.optString("link")
                    if (link.isBlank()) return false
                    ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(link)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    true
                }
                else -> false
            }
        } catch (_: Exception) { false }
    }

    fun linkFrom(vararg text: String): String {
        val r = Regex("https?://[^\\s)]+")
        return text.firstNotNullOfOrNull { r.find(it)?.value }.orEmpty()
    }

    fun encodePendingIntent(intent: PendingIntent?): String {
        if (intent == null) return ""
        val parcel = Parcel.obtain()
        return try {
            intent.writeToParcel(parcel, 0)
            Base64.encodeToString(parcel.marshall(), Base64.NO_WRAP)
        } catch (_: Exception) {
            ""
        } finally {
            parcel.recycle()
        }
    }

    private fun pendingIntentFrom(encoded: String): PendingIntent? {
        if (encoded.isBlank()) return null
        val parcel = Parcel.obtain()
        return try {
            val bytes = Base64.decode(encoded, Base64.NO_WRAP)
            parcel.unmarshall(bytes, 0, bytes.size)
            parcel.setDataPosition(0)
            PendingIntent.CREATOR.createFromParcel(parcel)
        } catch (_: Exception) {
            null
        } finally {
            parcel.recycle()
        }
    }

    private fun sameCapturedNotification(cursor: Cursor, item: JSONObject): Boolean =
        cursor.getString(0) == item.optString("key") &&
            cursor.getLong(1) == item.optLong("time") &&
            cursor.getString(2) == item.optString("title") &&
            cursor.getString(3) == item.optString("body") &&
            cursor.getString(4) == item.optString("packageName")

    private fun Cursor.string(name: String) = getString(getColumnIndexOrThrow(name))
    private fun Cursor.int(name: String) = getInt(getColumnIndexOrThrow(name))
    private fun Cursor.long(name: String) = getLong(getColumnIndexOrThrow(name))

    private fun values(item: JSONObject, date: String) = ContentValues().apply {
        put("id", item.optString("id"))
        put("key", item.optString("key"))
        put("tag", item.optString("tag"))
        put("time", item.optLong("time"))
        put("date", date)
        put("notificationId", item.optInt("notificationId"))
        put("packageName", item.optString("packageName"))
        put("appName", item.optString("appName"))
        put("title", item.optString("title"))
        put("body", item.optString("body"))
        put("color", item.optInt("color", Color.rgb(37, 99, 235)))
        put("iconPath", item.optString("iconPath"))
        put("channelId", item.optString("channelId"))
        put("category", item.optString("category"))
        put("groupKey", item.optString("groupKey"))
        put("shortcutId", item.optString("shortcutId"))
        put("creatorPackage", item.optString("creatorPackage"))
        put("pendingIntent", item.optString("pendingIntent"))
        put("link", item.optString("link"))
        put("actionKind", item.optString("actionKind"))
        put("read", if (item.optBoolean("read")) 1 else 0)
        put("starred", if (item.optBoolean("starred")) 1 else 0)
    }

    private fun toJson(cursor: Cursor) = JSONObject().apply {
        put("id", cursor.string("id"))
        put("key", cursor.string("key"))
        put("tag", cursor.string("tag"))
        put("time", cursor.long("time"))
        put("notificationId", cursor.int("notificationId"))
        put("packageName", cursor.string("packageName"))
        put("appName", cursor.string("appName"))
        put("title", cursor.string("title"))
        put("body", cursor.string("body"))
        put("color", cursor.int("color"))
        put("iconPath", cursor.string("iconPath"))
        put("channelId", cursor.string("channelId"))
        put("category", cursor.string("category"))
        put("groupKey", cursor.string("groupKey"))
        put("shortcutId", cursor.string("shortcutId"))
        put("creatorPackage", cursor.string("creatorPackage"))
        put("pendingIntent", cursor.string("pendingIntent"))
        put("link", cursor.string("link"))
        put("actionKind", cursor.string("actionKind"))
        put("read", cursor.int("read") != 0)
        put("starred", cursor.int("starred") != 0)
    }

    private fun toMap(cursor: Cursor) = mapOf(
        "id" to cursor.string("id"),
        "packageName" to cursor.string("packageName"),
        "appName" to cursor.string("appName"),
        "title" to cursor.string("title"),
        "body" to cursor.string("body"),
        "time" to cursor.long("time"),
        "date" to cursor.string("date"),
        "color" to cursor.int("color"),
        "iconPath" to cursor.string("iconPath"),
        "key" to cursor.string("key"),
        "tag" to cursor.string("tag"),
        "notificationId" to cursor.int("notificationId"),
        "channelId" to cursor.string("channelId"),
        "category" to cursor.string("category"),
        "groupKey" to cursor.string("groupKey"),
        "shortcutId" to cursor.string("shortcutId"),
        "creatorPackage" to cursor.string("creatorPackage"),
        "link" to cursor.string("link"),
        "actionKind" to cursor.string("actionKind"),
        "read" to (cursor.int("read") != 0),
        "starred" to (cursor.int("starred") != 0),
    )

    private class ArchiveDb(context: Context) : SQLiteOpenHelper(context, "notification_archive.db", null, 1) {
        init { setWriteAheadLoggingEnabled(true) }

        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL(
                """CREATE TABLE $TABLE (
                    id TEXT PRIMARY KEY NOT NULL,
                    key TEXT NOT NULL DEFAULT '',
                    tag TEXT NOT NULL DEFAULT '',
                    time INTEGER NOT NULL,
                    date TEXT NOT NULL,
                    notificationId INTEGER NOT NULL DEFAULT 0,
                    packageName TEXT NOT NULL DEFAULT '',
                    appName TEXT NOT NULL DEFAULT '',
                    title TEXT NOT NULL DEFAULT '',
                    body TEXT NOT NULL DEFAULT '',
                    color INTEGER NOT NULL,
                    iconPath TEXT NOT NULL DEFAULT '',
                    channelId TEXT NOT NULL DEFAULT '',
                    category TEXT NOT NULL DEFAULT '',
                    groupKey TEXT NOT NULL DEFAULT '',
                    shortcutId TEXT NOT NULL DEFAULT '',
                    creatorPackage TEXT NOT NULL DEFAULT '',
                    pendingIntent TEXT NOT NULL DEFAULT '',
                    link TEXT NOT NULL DEFAULT '',
                    actionKind TEXT NOT NULL DEFAULT '',
                    read INTEGER NOT NULL DEFAULT 0,
                    starred INTEGER NOT NULL DEFAULT 0
                )""".trimIndent(),
            )
            db.execSQL("CREATE INDEX notifications_time_idx ON $TABLE(time DESC, id DESC)")
            db.execSQL("CREATE INDEX notifications_date_idx ON $TABLE(date)")
            db.execSQL("CREATE TABLE $META_TABLE (name TEXT PRIMARY KEY NOT NULL)")
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit
    }
}
