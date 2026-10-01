import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/splash.dart';
import 'screens/home.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) { runApp(const ConfigError()); return; }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const ZenMiningApp());
}

class ConfigError extends StatelessWidget { const ConfigError({super.key}); @override Widget build(BuildContext c)=>Scaffold(backgroundColor:AppTheme.bg,body:const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('Missing SUPABASE_URL / SUPABASE_ANON_KEY. Build with --dart-define.',textAlign:TextAlign.center)))); }
class ZenMiningApp extends StatelessWidget{
 const ZenMiningApp({super.key});
 @override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,title:'ZEN MINING',theme:AppTheme.dark(),home:const SplashScreen(),onGenerateRoute:(settings){
    if(settings.name=='/home') return MaterialPageRoute(builder:(_)=>const HomeScreen());
    return null;
  });
}
