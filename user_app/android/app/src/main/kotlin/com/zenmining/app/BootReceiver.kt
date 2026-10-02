package com.zenmining.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        val prefs = context.getSharedPreferences("zen_monitor", Context.MODE_PRIVATE)
        val token = prefs.getString("monitorToken", "") ?: ""
        val url = prefs.getString("supabaseUrl", "") ?: ""
        if (token.isBlank() || url.isBlank()) return

        val service = Intent(context, UsageMonitorService::class.java)
            .putExtra("supabaseUrl", url)
            .putExtra("monitorToken", token)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(service)
        } else {
            context.startService(service)
        }
    }
}
