import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/game_state.dart';
import 'screens/menu_screen.dart';
import 'services/local_campaign_progress_store.dart';

void main() {
  // Ensure widget bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => GameState(
        progressStore: LocalCampaignProgressStore(),
      )..loadCampaignProgress(),
      child: const MemoryDungeonApp(),
    ),
  );
}

class MemoryDungeonApp extends StatelessWidget {
  const MemoryDungeonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Dungeon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F141A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7F8C8D),
          secondary: Color(0xFFF1C40F),
          surface: Color(0xFF1E272C),
        ),
        useMaterial3: true,
      ),
      home: const MenuScreen(),
    );
  }
}
