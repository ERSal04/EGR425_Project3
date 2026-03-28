import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart' show DEBUG_MODE;
import '../models/game_state.dart';
import '../constants.dart';
import '../widgets.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  bool _searchStarted = false;

  void _startSearch() {
    setState(() => _searchStarted = true);
    // TODO: Call actual BLE scan here
    // For now, the DebugManager.simulateM5Connection() in main.dart handles it
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Title
            HeadingText(
              'TRACE & EVADE',
              color: AppColors.neonGreen,
              fontSize: 32,
            ),
            AppSpacing.spacerXLarge,

            if (!_searchStarted) ...[
              // Before search starts - show START button
              LabelText('Ready to Connect', color: AppColors.cyan),
              AppSpacing.spacerXLarge,
              AppSpacing.spacerXLarge,
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                onPressed: _startSearch,
                child: const Text(
                  'START SEARCH',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              AppSpacing.spacerXLarge,
              AppSpacing.spacerXLarge,
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Make sure your M5Core2 is powered on and nearby.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontFamily: 'Courier',
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ] else ...[
              // After search starts - show connecting UI
              LabelText('Connecting to M5Core2...', color: AppColors.cyan),
              AppSpacing.spacerXLarge,
              AppSpacing.spacerXLarge,

              // Animated loading indicator
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.neonGreen.withOpacity(0.7),
                  ),
                  strokeWidth: 3,
                ),
              ),
              AppSpacing.spacerXLarge,
              AppSpacing.spacerXLarge,

              // Connection status text
              Consumer<GameState>(
                builder: (context, gameState, _) {
                  return Column(
                    children: [
                      Text(
                        gameState.isM5Connected
                            ? '✓ M5Core2 Connected'
                            : '○ Searching for device...',
                        style: TextStyle(
                          color: gameState.isM5Connected
                              ? AppColors.neonGreen
                              : AppColors.yellow,
                          fontSize: 14,
                          fontFamily: 'Courier',
                        ),
                      ),
                      AppSpacing.spacerLarge,
                      if (gameState.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            gameState.errorMessage!,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.errorText,
                          ),
                        ),
                    ],
                  );
                },
              ),
              AppSpacing.spacerXLarge,
              AppSpacing.spacerXLarge,

              // Info text
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Make sure your M5Core2 is powered on and nearby.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontFamily: 'Courier',
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            AppSpacing.spacerXLarge,
            AppSpacing.spacerXLarge,

            // DEBUG: Dev bypass button
            if (DEBUG_MODE)
              GlowButton(
                label: 'DEV: Skip to Entry\n(TODO: Remove)',
                color: AppColors.neonRed,
                onTap: () {
                  context.read<GameState>().setGamePhase(
                    GamePhase.selectingEntry,
                  );
                },
                fontSize: 10,
              ),
          ],
        ),
      ),
    );
  }
}
