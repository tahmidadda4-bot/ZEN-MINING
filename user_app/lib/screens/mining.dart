import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class MiningScreen extends StatefulWidget {
  const MiningScreen({super.key});
  @override State<MiningScreen> createState() => _MiningScreenState();
}

class _MiningScreenState extends State<MiningScreen> {
  Map<String,dynamic>? device;
  Map<String,dynamic>? config;
  bool loading = true;
  bool starting = false;
  Timer? ticker;

  @override void initState() {
    super.initState();
    load();
    ticker = Timer.periodic(const Duration(seconds: 30), (_) => load());
  }

  @override void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) return;
    try {
      final d = await Supabase.instance.client
          .from('devices').select()
          .eq('user_id', u.id)
          .order('created_at', ascending: false).limit(1).maybeSingle();
      final c = await Supabase.instance.client
          .from('mining_configs').select().limit(1).maybeSingle();
      if (mounted) setState(() { device=d; config=c; loading=false; });
    } catch (_) {
      if (mounted) setState(() => loading=false);
    }
  }

  double rate() => double.tryParse('${device?['mining_rate'] ?? config?['global_rate'] ?? 0}') ?? 0;

  DateTime? date(String? v) => v == null ? null : DateTime.tryParse(v)?.toLocal();

  double progress() {
    final start = date(device?['mining_started_at']?.toString());
    final end = date(device?['mining_ends_at']?.toString());
    if (start == null || end == null || end.isBefore(DateTime.now())) return 0;
    final total = end.difference(start).inMilliseconds;
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    if (total <= 0) return 0;
    return (elapsed / total).clamp(0, 1);
  }

  String remaining() {
    final end = date(device?['mining_ends_at']?.toString());
    if (end == null || end.isBefore(DateTime.now())) return '00:00:00';
    final d = end.difference(DateTime.now());
    final h = d.inHours.toString().padLeft(2,'0');
    final m = (d.inMinutes % 60).toString().padLeft(2,'0');
    final s = (d.inSeconds % 60).toString().padLeft(2,'0');
    return '$h:$m:$s';
  }

  Future<void> startMining() async {
    if (device == null || starting) return;
    setState(() => starting=true);
    try {
      await Supabase.instance.client.rpc('start_mining_secure', params:{
        'p_device_id': device!['id'],
      });
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => starting=false);
    }
  }

  @override Widget build(BuildContext context) {
    final active=device?['mining_status']=='active';
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(18), children:[
          const Text('Mining',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),
          const SizedBox(height:18),
          Card(child: Padding(padding:const EdgeInsets.all(24),child:Column(children:[
            SizedBox(width:180,height:180,child:Stack(alignment:Alignment.center,children:[
              CircularProgressIndicator(value:progress(),strokeWidth:12,color:AppTheme.green,backgroundColor:AppTheme.card2),
              Column(mainAxisSize:MainAxisSize.min,children:[
                Text('${(progress()*100).round()}%',style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900)),
                const Text('24 Hours',style:TextStyle(color:AppTheme.muted))
              ])
            ])),
            const SizedBox(height:18),
            Text(active?'● Mining in Progress':'● Mining Inactive',
              style:TextStyle(color:active?AppTheme.green:Colors.orange,fontWeight:FontWeight.w800)),
            const SizedBox(height:12),
            Text(active ? 'Time remaining: ${remaining()}' : 'Start a new 24-hour mining cycle.'),
            const SizedBox(height:12),
            ListTile(title:const Text('Mining Rate'),trailing:Text('৳${rate().toStringAsFixed(2)} / 24h')),
            ListTile(title:const Text('Calculation'),trailing:const Text('Server-side')),
            if (!active) SizedBox(width:double.infinity,child:ElevatedButton(
              onPressed: loading || config?['global_enabled']==false ? null : startMining,
              style:ElevatedButton.styleFrom(backgroundColor:AppTheme.green,foregroundColor:Colors.black),
              child:Text(starting?'Starting...':'Start Mining'),
            )),
            if (loading) const LinearProgressIndicator(),
          ])))
        ])
      )
    );
  }
}
