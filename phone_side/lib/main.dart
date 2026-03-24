import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/game_state.dart';
import 'screens/connection_screen.dart';
import 'screens/entry_selection_screen.dart';
import 'screens/game_screen.dart';
import 'screens/game_over_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => GameState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TRACE & EVADE',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // TODO: Initialize BLE scanning here
    // _simulateM5Connection();
  }

  /// For demo purposes - simulate M5 connection after a delay
  /// TODO: Remove when BLE is implemented
  void _simulateM5Connection() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.read<GameState>().setM5Connected(true, deviceName: 'M5Core2');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, gameState, _) {
        // Route to different screens based on game phase
        switch (gameState.gamePhase) {
          case GamePhase.connecting:
            return const ConnectionScreen();

          case GamePhase.selectingEntry:
            return const EntrySelectionScreen();

          case GamePhase.playing:
            return const GameScreen();

          case GamePhase.gameOver:
            return const GameOverScreen();
        }
      },
    );
  }
}
