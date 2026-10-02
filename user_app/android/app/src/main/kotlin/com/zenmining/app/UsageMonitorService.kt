package com.zenmining.app

import android.app.*
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*

class UsageMonitorService: Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var url = ""
    private var token = ""

    private val work = object : Runnable {
        override fun run() {
            Thread { sync() }.start()
            handler.postDelayed(this, 60_000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        val p = getSharedPreferences("zen_monitor", MODE_PRIVATE)
        url = p.getString("supabaseUrl", "") ?: ""
        token = p.getString("monitorToken", "") ?: ""
        startForeground(1101, notification())
        handler.post(work)
    }

    override fun onStartCommand(i: Intent?, flags: Int, startId: Int): Int {
        if (i?.hasExtra("supabaseUrl") == true) {
            url = i.getStringExtra("supabaseUrl") ?: ""
            token = i.getStringExtra("monitorToken") ?: ""
            getSharedPreferences("zen_monitor", MODE_PRIVATE).edit()
                .putString("supabaseUrl", url)
                .putString("monitorToken", token)
                .apply()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(work)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?) = null

    private fun sync() {
        if (url.isBlank() || token.isBlank()) return
        val rows = getUsage(24)

        try {
            val conn = URL("$url/functions/v1/sync-device-activity").openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 15_000
            conn.readTimeout = 15_000
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json")

            val payload = JSONObject().apply {
                put("monitorToken", token)
                put("activities", JSONArray(rows.map { JSONObject(it as Map<*, *>) }))
            }

            OutputStreamWriter(conn.outputStream).use { it.write(payload.toString()) }
            conn.responseCode
            conn.disconnect()
        } catch (_: Exception) {
            // The next scheduled sync retries. No private activity data is logged.
        }
    }

    private fun getUsage(hours: Int): List<Map<String, Any>> {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
        if (appOps.checkOpNoThrow(
                android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            ) != android.app.AppOpsManager.MODE_ALLOWED
        ) return emptyList()

        val usage = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val start = end - hours.coerceIn(1, 168) * 3_600_000L
        val events = usage.queryEvents(start, end)
        val event = UsageEvents.Event()
        val open = HashMap<String, Long>()
        val out = ArrayList<Map<String, Any>>()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED,
                UsageEvents.Event.MOVE_TO_FOREGROUND -> open[pkg] = event.timeStamp

                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val started = open.remove(pkg) ?: continue
                    val seconds = ((event.timeStamp - started) / 1000L).coerceAtLeast(0)
                    if (seconds >= 5) {
                        out.add(session(pkg, started, event.timeStamp, seconds))
                    }
                }
            }
        }

        // Keep the currently foreground app as an open session so Admin can see
        // Current App + live duration. The server upserts this by sessionKey.
        for ((pkg, started) in open) {
            val seconds = ((end - started) / 1000L).coerceAtLeast(0)
            if (seconds >= 5) out.add(session(pkg, started, null, seconds))
        }

        return out.takeLast(300)
    }

    private fun session(pkg: String, started: Long, ended: Long?, seconds: Long): Map<String, Any> {
        val label = try {
            packageManager.getApplicationLabel(
                packageManager.getApplicationInfo(pkg, 0)
            ).toString()
        } catch (_: Exception) { pkg }

        return mapOf(
            "sessionKey" to "$pkg:$started",
            "packageName" to pkg,
            "appName" to label,
            "startedAt" to iso(started),
            "endedAt" to (ended?.let { iso(it) } ?: ""),
            "durationSeconds" to seconds
        )
    }

    private fun iso(ms: Long) =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US).format(Date(ms))

    private fun notification(): Notification {
        val id = "zen_monitor"
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(id, "ZEN MINING Monitoring", NotificationManager.IMPORTANCE_LOW)
            )
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, id)
                .setContentTitle("ZEN MINING")
                .setContentText("Device activity monitoring is active")
                .setSmallIcon(android.R.drawable.ic_popup_sync)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("ZEN MINING")
                .setContentText("Device activity monitoring is active")
                .setSmallIcon(android.R.drawable.ic_popup_sync)
                .setOngoing(true)
                .build()
        }
    }
}
