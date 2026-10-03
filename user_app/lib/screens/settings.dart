import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/native_activity_service.dart';
import '../theme/app_theme.dart';
import 'login.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to log in again on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await NativeActivityService().stopMonitoring();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('device_monitor_token');
    await Supabase.instance.client.auth.signOut();

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SwitchListTile(value: true, onChanged: null, title: Text('Dark Mode')),
          const ListTile(title: Text('Language'), trailing: Text('English')),
          const SwitchListTile(value: true, onChanged: null, title: Text('Auto Start')),
          const SwitchListTile(value: true, onChanged: null, title: Text('Background Sync')),
          const ListTile(title: Text('Clear Cache'), trailing: Text('12.5 MB')),
          const SizedBox(height: 25),
          OutlinedButton(
            onPressed: () => _logout(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            child: const Text('Logout'),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Sign out stops background monitoring on this device.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
