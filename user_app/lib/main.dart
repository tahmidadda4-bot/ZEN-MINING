import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home.dart';
import 'screens/permissions.dart';
import 'screens/splash.dart';
import 'screens/welcome.dart';
import 'theme/app_theme.dart';
import 'widgets/zen_logo.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(const ConfigError());
    return;
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const ZenMiningApp());
}

class ConfigError extends StatelessWidget {
  const ConfigError({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Missing SUPABASE_URL / SUPABASE_ANON_KEY. Build with --dart-define.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}

class ZenMiningApp extends StatelessWidget {
  const ZenMiningApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ZEN MINING',
        theme: AppTheme.dark(),
        home: const NetworkGate(child: StartupRouter()),
        onGenerateRoute: (settings) {
          if (settings.name == '/home') {
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          }
          return null;
        },
      );
}

class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key});

  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  bool ready = false;
  bool? loggedIn;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    setState(() {
      loggedIn = session != null;
      ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const SplashScreen();

    if (loggedIn == true) {
      return const PermissionsScreen(autoContinue: true);
    }
    return const LoginOrWelcomeScreen();
  }
}

class LoginOrWelcomeScreen extends StatelessWidget {
  const LoginOrWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const WelcomeScreen();
}

class NetworkGate extends StatefulWidget {
  final Widget child;
  const NetworkGate({super.key, required this.child});

  @override
  State<NetworkGate> createState() => _NetworkGateState();
}

class _NetworkGateState extends State<NetworkGate>
    with WidgetsBindingObserver {
  Timer? timer;
  bool online = true;
  bool checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    bool ok = false;
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 4));
      ok = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      online = ok;
      checking = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (checking && !online) return const _OfflineScreen();
    if (!online) return const _OfflineScreen();
    return widget.child;
  }
}

class _OfflineScreen extends StatelessWidget {
  const _OfflineScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ZenLogo(size: 86),
                  const SizedBox(height: 24),
                  const Text(
                    'Connect Internet',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Internet connection is required to use ZEN MINING.\nTurn on Wi-Fi or mobile data and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted, height: 1.5),
                  ),
                  const SizedBox(height: 22),
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppTheme.green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Waiting for connection…',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () {
                      final state = context.findAncestorStateOfType<_NetworkGateState>();
                      state?._check();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
