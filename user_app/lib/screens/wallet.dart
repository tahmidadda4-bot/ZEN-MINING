import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import 'withdraw.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletState();
}

class _WalletState extends State<WalletScreen> {
  Map<String, dynamic>? wallet;
  bool loading = true;

  Future<void> load() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        wallet = await Supabase.instance.client
            .from('wallets')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();
      }
    } catch (_) {
      // Keep the last known wallet state on transient errors.
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  String money(dynamic value) =>
      double.tryParse('${value ?? 0}')?.toStringAsFixed(2) ?? '0.00';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('Wallet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 15),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Available Balance', style: TextStyle(color: AppTheme.muted)),
                    Text(
                      '৳${money(wallet?['available_balance'])}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Total earned ৳${money(wallet?['total_earned'])}',
                      style: const TextStyle(color: AppTheme.green),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WithdrawScreen()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.green,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Withdraw'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Pending'),
                    trailing: Text('৳${money(wallet?['pending_amount'])}'),
                  ),
                  ListTile(
                    title: const Text('Total withdrawn'),
                    trailing: Text('৳${money(wallet?['total_withdrawn'])}'),
                  ),
                  if (loading) const LinearProgressIndicator(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
