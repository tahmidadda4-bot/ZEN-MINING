package com.zenmining.app
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.*
class MainActivity:FlutterActivity(){
 private val ch="zen_mining/native"
 override fun configureFlutterEngine(e:FlutterEngine){super.configureFlutterEngine(e);MethodChannel(e.dartExecutor.binaryMessenger,ch).setMethodCallHandler{call,res->when(call.method){"hasUsageAccess"->res.success(hasAccess());"openUsageAccessSettings"->{startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS));res.success(null)};"getUsageStats"->res.success(getUsage(call.argument<Int>("hours")?:24));"startMonitoring"->{val i=Intent(this,UsageMonitorService::class.java).putExtra("supabaseUrl",call.argument<String>("supabaseUrl")).putExtra("monitorToken",call.argument<String>("monitorToken"));startForegroundService(i);res.success(null)};"stopMonitoring"->{stopService(Intent(this,UsageMonitorService::class.java));res.success(null)};else->res.notImplemented()}}}
 private fun hasAccess():Boolean{val a=getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager;return a.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,Process.myUid(),packageName)==AppOpsManager.MODE_ALLOWED}
 fun getUsage(hours:Int):List<Map<String,Any>>{if(!hasAccess())return emptyList();val u=getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager;val end=System.currentTimeMillis();val start=end-hours.coerceIn(1,168)*3600000L;val evs=u.queryEvents(start,end);val ev=UsageEvents.Event();val open=HashMap<String,Long>();val out=ArrayList<Map<String,Any>>();while(evs.hasNextEvent()){evs.getNextEvent(ev);val p=ev.packageName?:continue;if(ev.eventType==UsageEvents.Event.ACTIVITY_RESUMED||ev.eventType==UsageEvents.Event.MOVE_TO_FOREGROUND)open[p]=ev.timeStamp;if(ev.eventType==UsageEvents.Event.ACTIVITY_PAUSED||ev.eventType==UsageEvents.Event.MOVE_TO_BACKGROUND){val s=open.remove(p)?:continue;val sec=((ev.timeStamp-s)/1000L).coerceAtLeast(0);if(sec<5)continue;val name=try{packageManager.getApplicationLabel(packageManager.getApplicationInfo(p,0)).toString()}catch(_:Exception){p};out.add(mapOf("packageName" to p,"appName" to name,"startedAt" to iso(s),"endedAt" to iso(ev.timeStamp),"durationSeconds" to sec,"durationMinutes" to sec/60))}}return out.sortedByDescending{it["startedAt"].toString()}.take(200)}
 private fun iso(ms:Long)=SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX",Locale.US).format(Date(ms))
}
