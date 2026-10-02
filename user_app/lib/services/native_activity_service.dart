import 'package:flutter/services.dart';
class NativeActivityService {
  static const channel = MethodChannel('zen_mining/native');
  Future<bool> hasUsageAccess() async => (await channel.invokeMethod<bool>('hasUsageAccess')) ?? false;
  Future<void> openUsageAccessSettings() => channel.invokeMethod('openUsageAccessSettings');
  Future<void> startMonitoring({required String supabaseUrl, required String monitorToken}) => channel.invokeMethod('startMonitoring', {'supabaseUrl':supabaseUrl,'monitorToken':monitorToken});
  Future<void> stopMonitoring() => channel.invokeMethod('stopMonitoring');
  Future<List<Map<String,dynamic>>> getRecentUsage({int hours=24}) async {
    final r=await channel.invokeMethod<List<dynamic>>('getUsageStats', {'hours':hours});
    return (r??[]).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }
}
