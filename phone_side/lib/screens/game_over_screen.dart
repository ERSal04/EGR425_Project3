import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';

class GameOverScreen extends StatelessWidget {
  const GameOverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Consumer<GameState>(
          builder: (context, gameState, _) {
            bool hackerWon = gameState.gameWinner == 'hacker';

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Winner text
                Text(
                  hackerWon ? 'ACCESS GRANTED ✓' : 'CONNECTION TERMINATED ✗',
                  style: TextStyle(
                    color: hackerWon ? Colors.green : Colors.red,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Winner message
                Text(
                  hackerWon
                      ? 'You successfully breached the system!'
                      : 'You were traced and caught!',
                  style: TextStyle(
                    color: hackerWon ? Colors.green : Colors.red,
                    fontSize: 16,
                    fontFamily: 'Courier',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Stats panel
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: hackerWon ? Colors.green : Colors.red,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FINAL STATS',
                        style: TextStyle(
                          color: Colors.cyan,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _StatLine(
                        'Time Survived:',
                        '${300 - gameState.timeRemaining}s',
                      ),
                      _StatLine(
                        'Tools Used:',
                        '${(1 - gameState.spoofUsesRemaining) + (1 - gameState.tunnelUsesRemaining) + (1 - gameState.crackUsesRemaining)}',
                      ),
                      _StatLine(
                        'Final Position:',
                        'Node ${gameState.hackerCurrentNode}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                // Restart button
                GestureDetector(
                  onTap: () {
                    context.read<GameState>().resetGame();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'RESTART GAME',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Courier',
                        letterSpacing: 2,
                      ),
                    ),
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

class _StatLine extends StatelessWidget {
  final String label;
  final String value;

  const _StatLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.cyan,
              fontSize: 12,
              fontFamily: 'Courier',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.green,
              fontSize: 12,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
