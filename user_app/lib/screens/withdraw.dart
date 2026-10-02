import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawState();
}

class _WithdrawState extends State<WithdrawScreen> {
  String method = 'bKash';
  final amount = TextEditingController();
  final destination = TextEditingController();
  bool busy = false;
  String? message;

  Future<void> submit() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final value = double.tryParse(amount.text.trim());
      if (value == null || value <= 0) throw Exception('Enter a valid amount');
      if (destination.text.trim().isEmpty) throw Exception('Payment destination is required');

      final response = await Supabase.instance.client.functions.invoke(
        'request-withdrawal',
        body: {
          'amount': value,
          'paymentMethod': method,
          'paymentDestination': destination.text.trim(),
        },
      );

      if (response.data is Map && response.data['error'] != null) {
        throw Exception(response.data['error']);
      }
      if (mounted) setState(() => message = 'Withdrawal request submitted');
    } catch (error) {
      if (mounted) setState(() => message = error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    amount.dispose();
    destination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Withdraw')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('Withdrawal Method'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: method,
            items: const ['bKash', 'Nagad', 'Bank Transfer']
                .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
            onChanged: busy ? null : (value) => setState(() => method = value!),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount', prefixText: '৳ '),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: destination,
            decoration: const InputDecoration(labelText: 'Payment destination'),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                message!,
                style: TextStyle(
                  color: message!.contains('submitted') ? AppTheme.green : AppTheme.red,
                ),
              ),
            ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: busy ? null : submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.green,
              foregroundColor: Colors.black,
            ),
            child: Text(busy ? 'Submitting...' : 'Request Withdrawal'),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Withdrawal is available only when unlocked by Admin.',
              style: TextStyle(color: AppTheme.muted),
            ),
          ),
        ],
      ),
    );
  }
}
