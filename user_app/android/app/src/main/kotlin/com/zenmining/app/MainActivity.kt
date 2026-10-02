package com.zenmining.app

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.HashMap
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val channelName = "zen_mining/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "openUsageAccessSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "getUsageStats" -> {
                        result.success(getUsage(call.argument<Int>("hours") ?: 24))
                    }
                    "startMonitoring" -> {
                        val serviceIntent = Intent(this, UsageMonitorService::class.java)
                            .putExtra("supabaseUrl", call.argument<String>("supabaseUrl"))
                            .putExtra("monitorToken", call.argument<String>("monitorToken"))
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(null)
                    }
                    "stopMonitoring" -> {
                        stopService(Intent(this, UsageMonitorService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName
        ) == AppOpsManager.MODE_ALLOWED
    }

    private fun getUsage(hours: Int): List<Map<String, Any>> {
        if (!hasUsageAccess()) return emptyList()

        val usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val safeHours = hours.coerceIn(1, 168)
        val start = end - safeHours * 3_600_000L
        val events = usageStatsManager.queryEvents(start, end)
        val event = UsageEvents.Event()
        val open = HashMap<String, Long>()
        val output = ArrayList<Map<String, Any>>()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageName = event.packageName ?: continue

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED,
                UsageEvents.Event.MOVE_TO_FOREGROUND -> open[packageName] = event.timeStamp

                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val started = open.remove(packageName) ?: continue
                    val seconds = ((event.timeStamp - started) / 1000L).coerceAtLeast(0)
                    if (seconds < 5) continue

                    val appName = try {
                        packageManager.getApplicationLabel(
                            packageManager.getApplicationInfo(packageName, 0)
                        ).toString()
                    } catch (_: Exception) {
                        packageName
                    }

                    output.add(
                        mapOf(
                            "sessionKey" to "$packageName:$started",
                            "packageName" to packageName,
                            "appName" to appName,
                            "startedAt" to iso(started),
                            "endedAt" to iso(event.timeStamp),
                            "durationSeconds" to seconds,
                            "durationMinutes" to seconds / 60
                        )
                    )
                }
            }
        }

        return output.sortedByDescending { it["startedAt"].toString() }.take(200)
    }

    private fun iso(milliseconds: Long): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US).format(Date(milliseconds))
}
