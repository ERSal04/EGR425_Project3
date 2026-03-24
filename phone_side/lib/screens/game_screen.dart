import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Simple node data structure for demo
  static const List<Map<String, dynamic>> nodes = [
    // Entry nodes
    {'id': 0, 'x': 80, 'y': 800, 'type': 'entry', 'label': 'ENTRY_A'},
    {'id': 1, 'x': 820, 'y': 800, 'type': 'entry', 'label': 'ENTRY_B'},
    {'id': 2, 'x': 80, 'y': 100, 'type': 'entry', 'label': 'ENTRY_C'},
    {'id': 3, 'x': 820, 'y': 100, 'type': 'entry', 'label': 'ENTRY_D'},
    // Other nodes (sample - you'd add all 24)
    {'id': 15, 'x': 450, 'y': 350, 'type': 'junction', 'label': 'JUNCTION'},
    {'id': 23, 'x': 450, 'y': 450, 'type': 'core', 'label': 'CORE'},
  ];

  bool showGameStateOverlay = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top bar: Timer and connection
                _buildTopBar(),
                const SizedBox(height: 8),

                // Main game area with canvas
                Expanded(child: _buildGameArea()),
              ],
            ),

            // Game state overlay (toggleable)
            if (showGameStateOverlay) _buildGameStateOverlay(),

            // Error snackbar area (bottom)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Consumer<GameState>(
                builder: (context, gameState, _) {
                  if (gameState.errorMessage == null) {
                    return const SizedBox.shrink();
                  }
                  return _buildErrorSnackbar(gameState.errorMessage!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Consumer<GameState>(
      builder: (context, gameState, _) {
        return Container(
          color: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Connection indicator
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: gameState.isM5Connected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  gameState.displayDeviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontFamily: 'Courier',
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Timer
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.cyan, width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  gameState.formattedTime,
                  style: const TextStyle(
                    color: Colors.cyan,
                    fontSize: 12,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Game state toggle button
              GestureDetector(
                onTap: () {
                  setState(() => showGameStateOverlay = !showGameStateOverlay);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.yellow, width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'STATUS',
                    style: TextStyle(
                      color: Colors.yellow,
                      fontSize: 10,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGameArea() {
    return Consumer<GameState>(
      builder: (context, gameState, _) {
        return Container(
          color: Colors.black,
          child: CustomPaint(
            painter: GameMapPainter(
              hackerNode: gameState.hackerCurrentNode,
              traceNodes: gameState.tracePositions,
              lockedNodes: gameState.lockedNodes,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  Widget _buildGameStateOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() => showGameStateOverlay = false);
        },
        child: Container(
          color: Colors.black54,
          child: Center(child: _GameStatePanel()),
        ),
      ),
    );
  }

  Widget _buildErrorSnackbar(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[900],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red, width: 1),
      ),
      child: Row(
        children: [
          const Text('⚠ ', style: TextStyle(color: Colors.red, fontSize: 14)),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontFamily: 'Courier',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter to draw the game map
class GameMapPainter extends CustomPainter {
  final int hackerNode;
  final List<int> traceNodes;
  final List<int> lockedNodes;

  GameMapPainter({
    required this.hackerNode,
    required this.traceNodes,
    required this.lockedNodes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    // Draw grid lines (optional for cyberpunk feel)
    _drawGrid(canvas, size);

    // Draw edges (simplified for now)
    _drawEdges(canvas, size);

    // Draw nodes
    _drawNodes(canvas, size);

    // Draw hacker (current position)
    _drawHacker(canvas, size);

    // Draw traces
    _drawTraces(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withOpacity(0.1)
      ..strokeWidth = 0.5;

    const gridSpacing = 40;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawEdges(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withOpacity(0.6)
      ..strokeWidth = 1;

    // Draw placeholder edges (in real implementation, draw from node connections)
    // For now, just a simple demo
  }

  void _drawNodes(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.green;
    const radius = 6.0;

    // Draw placeholder nodes
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.2),
      radius,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.2),
      radius,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      radius,
      paint,
    );
  }

  void _drawHacker(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.cyan;
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.3), 8, paint);
  }

  void _drawTraces(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.red;
    const radius = 5.0;

    // Draw placeholder traces
    for (int i = 0; i < 2; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.3 + (i * 100), size.height * 0.4),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GameMapPainter oldDelegate) {
    return oldDelegate.hackerNode != hackerNode ||
        oldDelegate.traceNodes != traceNodes ||
        oldDelegate.lockedNodes != lockedNodes;
  }
}

class _GameStatePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, gameState, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GAME STATE',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier',
                ),
              ),
              const SizedBox(height: 16),
              _StatRow(
                'Hacker Position:',
                'Node ${gameState.hackerCurrentNode}',
              ),
              _StatRow(
                'Traces:',
                gameState.tracePositions.isNotEmpty
                    ? gameState.tracePositions.join(', ')
                    : 'None',
              ),
              _StatRow(
                'Locked Nodes:',
                gameState.lockedNodes.isNotEmpty
                    ? gameState.lockedNodes.join(', ')
                    : 'None',
              ),
              _StatRow('Time:', gameState.formattedTime),
              const SizedBox(height: 12),
              _StatRow('Spoof:', '${gameState.spoofUsesRemaining}/1'),
              _StatRow('Tunnel:', '${gameState.tunnelUsesRemaining}/1'),
              _StatRow(
                'Firewall Break:',
                '${gameState.firewallBreakUsesRemaining}/1',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
