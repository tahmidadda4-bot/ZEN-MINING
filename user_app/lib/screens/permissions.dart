import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/native_activity_service.dart';
import '../widgets/green_button.dart';
import 'home.dart';

class PermissionsScreen extends StatefulWidget {
  final bool autoContinue;

  const PermissionsScreen({super.key, this.autoContinue = false});

  @override
  State<PermissionsScreen> createState() => _PermissionsState();
}

class _PermissionsState extends State<PermissionsScreen> {
  final n = NativeActivityService();
  bool granted = false;
  bool busy = true;
  bool _started = false;
  String? error;

  Future<void> check() async {
    final v = await n.hasUsageAccess();
    if (!mounted) return;
    setState(() {
      granted = v;
      busy = false;
    });

    if (v && widget.autoContinue) {
      await registerOrResume();
    }
  }

  Future<void> registerOrResume() async {
    if (_started) return;
    _started = true;
    if (mounted) setState(() { busy = true; error = null; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedToken = prefs.getString('device_monitor_token');

      if (cachedToken != null && cachedToken.isNotEmpty) {
        await Permission.notification.request();
        await n.startMonitoring(
          supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
          monitorToken: cachedToken,
        );
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (_) => false,
          );
        }
        return;
      }

      final android = await DeviceInfoPlugin().androidInfo;
      final info = await PackageInfo.fromPlatform();
      final fp = android.id;

      final response = await Supabase.instance.client.functions.invoke(
        'register-device',
        body: {
          'deviceFingerprint': fp,
          'deviceName': android.device,
          'model': android.model,
          'androidVersion': android.version.release,
          'appVersion': info.version,
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw Exception('Invalid device registration response');
      }
      final token = data['monitorToken'];
      if (token is! String || token.isEmpty) {
        throw Exception('Device monitoring token was not issued');
      }

      await prefs.setString('device_monitor_token', token);
      await Permission.notification.request();
      await n.startMonitoring(
        supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
        monitorToken: token,
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = _friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
      _started = false;
    }
  }

  String _friendlyError(Object e) {
    try {
      final dynamic d = e;
      final details = d.details;
      if (details is Map && details['error'] != null) {
        return '${details['error']}';
      }
    } catch (_) {}

    final text = e.toString();
    if (text.contains('Bad Request') || text.contains('status: 400')) {
      return 'Device registration failed. Please check your internet connection and try again.';
    }
    return text;
  }

  @override
  void initState() {
    super.initState();
    check();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Required Permissions',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Usage access is required to measure which apps are used and for how long. Message content is not collected.',
                  style: TextStyle(color: Color(0xFF91A9A0)),
                ),
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.data_usage, color: Color(0xFF39E58C)),
                    title: const Text('Usage Access'),
                    subtitle: Text(granted ? 'Granted' : 'Required'),
                    trailing: TextButton(
                      onPressed: () => n.openUsageAccessSettings(),
                      child: Text(granted ? 'Open' : 'Allow'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.security, color: Color(0xFF39E58C)),
                    title: Text('Privacy'),
                    subtitle: Text('Only app/package usage metadata is synchronized.'),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Color(0xFFFF5470)),
                    ),
                  ),
                const Spacer(),
                GreenButton(
                  label: busy
                      ? 'Please wait'
                      : granted
                          ? 'Continue'
                          : 'Open Settings',
                  onTap: busy
                      ? null
                      : granted
                          ? registerOrResume
                          : () => n.openUsageAccessSettings(),
                ),
              ],
            ),
          ),
        ),
      );
}
