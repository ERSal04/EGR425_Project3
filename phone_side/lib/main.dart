import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/game_state.dart';
import 'debug_manager.dart';
import 'screens/connection_screen.dart';
import 'screens/entry_selection_screen.dart';
import 'screens/game_screen.dart';
import 'screens/game_over_screen.dart';
import 'services/ble_service.dart';

// ============================================================================
// DEBUG MODE - Toggle this to enable/disable all debug features
// Set to false for production - true for development with debug traces/locks
// ============================================================================
const bool DEBUG_MODE = false;

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
  late BleService _bleService;
  late GameState _gameStateRef;

  @override
  void initState() {
    super.initState();

    _gameStateRef = context.read<GameState>();

    // Initialize BLE service
    _bleService = BleService(gameState: _gameStateRef);

    // Wire up move callback so moves are sent to M5 via BLE
    _gameStateRef.onMoveSend = _bleService.sendHackerMove;

    // Defer initialization until after first frame to avoid setState() during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (DEBUG_MODE) {
        // For development/testing, also enable debug mode
        DebugManager.simulateM5Connection(context);
        DebugManager.initializeDebugGameState(context, isFirstLaunch: true);
        DebugManager.setupGameStateListener(_gameStateRef);
      } else {
        // Production: start BLE scanning for M5Core2
        _bleService.startScan();
      }
    });
  }

  @override
  void dispose() {
    _bleService.dispose();
    super.dispose();
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
