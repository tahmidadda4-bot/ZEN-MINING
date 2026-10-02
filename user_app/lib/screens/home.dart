import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/native_activity_service.dart';
import 'mining.dart';
import 'wallet.dart';
import 'profile.dart';
import 'withdraw.dart';
import 'notifications.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  int tab = 0;
  final pages = const [HomeBody(), MiningScreen(), WalletScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: 'Mining'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    ),
  );
}

class HomeBody extends StatefulWidget {
  const HomeBody({super.key});
  @override State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  Map<String,dynamic>? wallet, device;
  bool busy = true;
  final n = NativeActivityService();

  Future<void> load() async {
    try {
      final u = Supabase.instance.client.auth.currentUser;
      if (u == null) return;
      wallet = await Supabase.instance.client.from('wallets').select().eq('user_id', u.id).maybeSingle();
      device = await Supabase.instance.client.from('devices').select().eq('user_id', u.id).order('created_at', ascending: false).limit(1).maybeSingle();
      if (device != null) {
        await Supabase.instance.client.functions.invoke('heartbeat', body: {'deviceId': device!['id']});
        final usage = await n.getRecentUsage();
        if (usage.isNotEmpty) {
          await Supabase.instance.client.functions.invoke('sync-activity', body: {'deviceId': device!['id'], 'activities': usage});
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override void initState() { super.initState(); load(); }
  String money(dynamic v) => double.tryParse('${v ?? 0}')?.toStringAsFixed(2) ?? '0.00';

  @override
  Widget build(BuildContext c) => SafeArea(
    child: RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(18), children: [
        Row(children: [
          const Text('ZEN MINING', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const Spacer(),
          IconButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const NotificationsScreen())), icon: const Icon(Icons.notifications_none)),
        ]),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Total Balance', style: TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 5),
          Text('৳${money(wallet?['available_balance'])}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
          Text('+ ৳${money(wallet?['total_earned'])} total earned', style: const TextStyle(color: AppTheme.green)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const WithdrawScreen())), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green, foregroundColor: Colors.black), child: const Text('Withdraw')),
        ]))),
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mining Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(children: [Icon(Icons.circle, size: 12, color: device?['mining_status'] == 'active' ? AppTheme.green : Colors.orange), const SizedBox(width: 7), Text(device?['mining_status'] == 'active' ? 'Active' : 'Inactive')]),
          const SizedBox(height: 15),
          const Text('24h Progress'), const SizedBox(height: 8),
          const LinearProgressIndicator(value: .68, minHeight: 8), const SizedBox(height: 8),
          const Text('Server calculated'),
        ]))),
        const SizedBox(height: 14),
        const Card(child: ListTile(leading: Icon(Icons.shield_outlined, color: AppTheme.green), title: Text('Privacy protected'), subtitle: Text('Only app usage metadata is collected; message content is not collected.'))),
        if (busy) const Padding(padding: EdgeInsets.only(top: 14), child: LinearProgressIndicator()),
      ]),
    ),
  );
}
