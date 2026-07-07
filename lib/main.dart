import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'services/supabase_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  runApp(const RummyScorerApp());
}

class RummyScorerApp extends StatelessWidget {
  const RummyScorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<SupabaseService>(
      create: (_) => SupabaseService(),
      child: MaterialApp(
        title: 'Points Rummy Scorer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.teal,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
