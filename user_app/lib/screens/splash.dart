import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/zen_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0xFF063D29), AppTheme.bg],
              radius: 1.1,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RotationTransition(
                  turns: controller,
                  child: const ZenLogo(size: 110),
                ),
                const SizedBox(height: 24),
                const Text(
                  'ZEN MINING',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your Device • Our Network • Real Rewards',
                  style: TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 35),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppTheme.green,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Loading...',
                  style: TextStyle(color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ),
      );
}
