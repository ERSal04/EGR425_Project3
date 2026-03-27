import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Title
            const Text(
              'TRACE & EVADE',
              style: TextStyle(
                color: Colors.green,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Connecting to M5Core2...',
              style: TextStyle(
                color: Colors.cyan,
                fontSize: 16,
                fontFamily: 'Courier',
              ),
            ),
            const SizedBox(height: 40),

            // Animated loading indicator
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green[700]!),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 40),

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
                            ? Colors.green
                            : Colors.yellow,
                        fontSize: 14,
                        fontFamily: 'Courier',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (gameState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          gameState.errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontFamily: 'Courier',
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),

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
            const SizedBox(height: 40),

            // TODO: Remove before production - dev bypass button
            GestureDetector(
              onTap: () {
                context.read<GameState>().setGamePhase(
                  GamePhase.selectingEntry,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red, width: 1),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.red.withOpacity(0.1),
                ),
                child: const Column(
                  children: [
                    Text(
                      'DEV: Skip to Entry',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '(TODO: Remove before prod)',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 9,
                        fontFamily: 'Courier',
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
