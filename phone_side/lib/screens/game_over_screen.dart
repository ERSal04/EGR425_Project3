import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../constants.dart';
import '../widgets.dart';

class GameOverScreen extends StatelessWidget {
  const GameOverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Consumer<GameState>(
          builder: (context, gameState, _) {
            final gameWinner = gameState.gameWinner;
            bool hackerWon = gameWinner == 'hacker';

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Winner text
                Text(
                  hackerWon ? 'ACCESS GRANTED ✓' : 'CONNECTION TERMINATED ✗',
                  style: TextStyle(
                    color: hackerWon ? AppColors.neonGreen : AppColors.neonRed,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.spacerXLarge,

                // Winner message
                Text(
                  hackerWon
                      ? 'You successfully breached the system!'
                      : 'You were traced and caught!',
                  style: TextStyle(
                    color: hackerWon ? AppColors.neonGreen : AppColors.neonRed,
                    fontSize: 16,
                    fontFamily: 'Courier',
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.spacerXLarge,
                AppSpacing.spacerLarge,

                // Stats panel
                GlowContainer(
                  color: hackerWon ? AppColors.neonGreen : AppColors.neonRed,
                  padding: const EdgeInsets.all(24),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HeadingText(
                        'FINAL STATS',
                        color: AppColors.cyan,
                        fontSize: 14,
                      ),
                      AppSpacing.spacerLarge,
                      StatRow(
                        label: 'Time Survived:',
                        value: '${300 - gameState.timeRemaining}s',
                        labelColor: AppColors.cyan,
                        valueColor: AppColors.neonGreen,
                      ),
                      StatRow(
                        label: 'Tools Used:',
                        value:
                            '${(1 - gameState.spoofUsesRemaining) + (1 - gameState.tunnelUsesRemaining) + (1 - gameState.crackUsesRemaining)}',
                        labelColor: AppColors.cyan,
                        valueColor: AppColors.neonGreen,
                      ),
                      StatRow(
                        label: 'Final Position:',
                        value: 'Node ${gameState.hackerCurrentNode}',
                        labelColor: AppColors.cyan,
                        valueColor: AppColors.neonGreen,
                      ),
                    ],
                  ),
                ),
                AppSpacing.spacerXLarge,
                AppSpacing.spacerLarge,

                // Restart button
                GlowButton(
                  label: 'RESTART GAME',
                  color: AppColors.neonGreen,
                  onTap: () {
                    context.read<GameState>().resetGame();
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
