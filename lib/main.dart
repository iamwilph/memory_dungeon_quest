import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/game_state.dart';
import 'screens/menu_screen.dart';
import 'screens/tutorial_hint.dart';
import 'services/local_campaign_progress_store.dart';
import 'services/audio_service.dart';
import 'services/high_score_service.dart';
import 'services/achievement_manager.dart';

Future<void> main() async {
  // Ensure widget bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize audio service (non-blocking — SFX may not be ready yet)
  AudioService().init();
  
  // Initialize high score service
  await HighScoreService().init();
  
  // Initialize achievement manager
  AchievementManager().init();
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => GameState(
        progressStore: LocalCampaignProgressStore(),
      )..loadCampaignProgress(),
      child: const MemoryDungeonApp(),
    ),
  );
}

class MemoryDungeonApp extends StatefulWidget {
  const MemoryDungeonApp({super.key});

  @override
  State<MemoryDungeonApp> createState() => _MemoryDungeonAppState();
}

class _MemoryDungeonAppState extends State<MemoryDungeonApp> {
  @override
  void initState() {
    super.initState();
    // Show tutorial on first launch (after the app frame is ready)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showTutorialIfNeeded(context);
    });
  }

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
