import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/login_page.dart';

// Paste your values from Supabase: Project Settings -> API
const String supabaseUrl = 'https://loelrdijdungvxjxdarb.supabase.co';
const String supabaseKey = 'sb_publishable_rdVNfKtgsfKZdW_MfNl2Yw_X2tpYylq';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const JobOrderApp());
}

class JobOrderApp extends StatelessWidget {
  const JobOrderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maintenance System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}