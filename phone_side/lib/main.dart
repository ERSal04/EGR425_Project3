import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/game_state.dart';
import 'debug_manager.dart';
import 'screens/connection_screen.dart';
import 'screens/entry_selection_screen.dart';
import 'screens/game_screen.dart';
import 'screens/game_over_screen.dart';

// ============================================================================
// DEBUG MODE - Toggle this to enable/disable all debug features
// Set to false for production - true for development with debug traces/locks
// ============================================================================
const bool DEBUG_MODE = true;

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
  late GameState _gameStateRef;

  @override
  void initState() {
    super.initState();

    // ============ PRODUCTION: BLE INITIALIZATION ============
    // TODO: Replace DebugManager.simulateM5Connection() with:
    //  1. Call flutter_blue_plus to scan for M5Core2 devices
    //  2. Connect to M5Core2 BLE device
    //  3. Subscribe to CHAR_DEFENDER_UUID for state updates (defender traces, locks, time)
    //  4. Listen for updates as JSON: {"traces": [9, 13, 15], "locked": [7], "ping": false, "timeLeft": 42}
    //  5. Call _handleDefenderStateUpdate() with received data
    // See connection_screen.dart for BLE scanning UI reference

    if (DEBUG_MODE) {
      DebugManager.simulateM5Connection(context);
      DebugManager.initializeDebugGameState(context, isFirstLaunch: true);

      // Setup game state listener for debug re-initialization on restart
      _gameStateRef = context.read<GameState>();
      DebugManager.setupGameStateListener(_gameStateRef);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// ============ PRODUCTION: Handle real defender state updates from M5 ============
  /// TODO: Call this from BLE notification listener when CHAR_DEFENDER receives data
  /// Expected JSON from M5: {"traces": [nodeIds], "locked": [nodeIds], "ping": bool, "timeLeft": seconds}
  void _handleDefenderStateUpdate(Map<String, dynamic> defenderState) {
    final gameState = context.read<GameState>();

    // Parse incoming data from M5Core2
    final traces = List<int>.from(defenderState['traces'] ?? []);
    final locked = List<int>.from(defenderState['locked'] ?? []);
    final timeLeft = defenderState['timeLeft'] ?? 300;

    // Update game state with defender's current state
    gameState.updateMapFromDefender(
      traces: traces,
      locked: locked,
      timeLeft: timeLeft,
    );

    // Check win condition: if trace is on hacker position
    if (traces.contains(gameState.hackerCurrentNode)) {
      gameState.setGameOver('defender');
    }
  }

  /// ============ PRODUCTION: Send hacker move to M5 ============
  /// TODO: Call this when hacker moves to new node
  /// Send as JSON to CHAR_HACKER: {"nodeId": 15, "tool": "spoof", "toolsLeft": [2, 1, 1]}
  void _sendHackerMoveToDefender(int targetNodeId, {String? tool}) {
    // Example code to send BLE write:
    // final movePayload = {
    //   'nodeId': targetNodeId,
    //   'tool': tool,
    //   'toolsLeft': [
    //     gameState.spoofUsesRemaining,
    //     gameState.tunnelUsesRemaining,
    //     gameState.crackUsesRemaining,
    //   ],
    // };
    // await bleCharacteristicWrite(CHAR_HACKER_UUID, jsonEncode(movePayload));
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
