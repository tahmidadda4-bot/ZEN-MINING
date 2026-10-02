import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
