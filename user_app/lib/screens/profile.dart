import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'device_info.dart';
import 'notifications.dart';
import 'settings.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 15),
          const CircleAvatar(radius: 38, child: Icon(Icons.person, size: 42)),
          const SizedBox(height: 8),
          const Center(child: Text('User123', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          const Center(child: Text('user123@email.com', style: TextStyle(color: AppTheme.muted))),
          const SizedBox(height: 20),
          _item('Personal Information', Icons.person_outline, () {}),
          _item('Device Information', Icons.phone_android, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceInfoScreen()));
          }),
          _item('Notifications', Icons.notifications_none, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          }),
          _item('Settings', Icons.settings_outlined, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }),
        ],
      ),
    );
  }

  Widget _item(String title, IconData icon, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
