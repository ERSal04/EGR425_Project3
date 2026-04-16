import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/game_state.dart';

/// ============================================================================
/// DEBUG MANAGER - All debug utilities in one place
/// ============================================================================
/// This file contains all debug helpers. It's called from main.dart based on
/// the DEBUG_MODE flag. Don't call these directly - use DEBUG_MODE in main.dart
/// to control debug features.
/// ============================================================================

class DebugManager {
  /// Initialize all debug features (traces, locked nodes, auto-start)
  static void initializeDebugGameState(
    BuildContext context, {
    bool isFirstLaunch = true,
  }) {
    Future.delayed(const Duration(seconds: 3), () {
      final gameState = context.read<GameState>();

      // DEBUG: Set map to MAP 1 (defender's choice simulated)
      gameState.debugSetMapFromDefender(2);

      // DEBUG: Deploy traces starting at nodes 4, 6
      gameState.setDebugTraces([4, 6]);

      // DEBUG: Lock nodes 7 and 11 for testing Crack tool
      gameState.setDebugLockedNodes([7, 11]);

      // On first launch, auto-start at entry A
      // On restart, let user pick entry point
      if (isFirstLaunch) {
        gameState.hackerSelectEntry(0); // Start at ENTRY_A (node 0)
        gameState.setGamePhase(GamePhase.playing);
        gameState.setCurrentTurn(CurrentTurn.hackerTurn);
      }
    });
  }

  /// Listen for game resets and re-initialize debug state
  static void setupGameStateListener(GameState gameState) {
    gameState.addListener(() {
      if (gameState.gamePhase == GamePhase.connecting) {
        // Re-initialize debug state on game reset (but don't force entry selection)
        Future.delayed(const Duration(seconds: 3), () {
          gameState.debugSetMapFromDefender(1);
          gameState.setDebugTraces([4, 6]);
          gameState.setDebugLockedNodes([7, 11]);
        });
      }
    });
  }

  /// Simulate M5 connection after a delay (for testing without real hardware)
  static void simulateM5Connection(BuildContext context) {
    Future.delayed(const Duration(seconds: 2), () {
      final gameState = context.read<GameState>();
      gameState.setM5Connected(true, deviceName: 'M5Core2 (SIM)');
    });
  }

  /// ========== DEBUG MAP SELECTION ==========
  /// Simulate defender choosing a map (debug bypass for BLE)
  static void debugChooseMap(BuildContext context, int mapId) {
    final gameState = context.read<GameState>();
    if (mapId != 1 && mapId != 2) {
      gameState.showTransientError('Invalid map. Choose 1 or 2.');
      return;
    }
    gameState.debugSetMapFromDefender(mapId);
    gameState.showTransientError(
      'DEBUG: MAP $mapId selected',
      duration: const Duration(seconds: 2),
    );
  }

  /// DEBUG: Check if map has been selected
  static bool hasMapBeenSelected(GameState gameState) {
    return gameState.mapReceivedFromDefender;
  }

  /// DEBUG: Get current map
  static int getCurrentDebugMap(GameState gameState) {
    return gameState.getCurrentMap();
  }
}
