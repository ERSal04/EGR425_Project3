import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart' show DEBUG_MODE;
import '../models/game_state.dart';
import '../constants.dart';
import '../widgets.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  /// Node definitions with positions and metadata
  /// Positions in 900x900 world space (normalized to 0-1 scale)
  static final List<Map<String, dynamic>> nodes = [
    // Entry nodes (4 starting points for hacker)
    {'id': 0, 'x': 0.089, 'y': 0.889, 'type': 'entry', 'label': 'ENTRY_A'},
    {'id': 1, 'x': 0.911, 'y': 0.889, 'type': 'entry', 'label': 'ENTRY_B'},
    {'id': 2, 'x': 0.089, 'y': 0.111, 'type': 'entry', 'label': 'ENTRY_C'},
    {'id': 3, 'x': 0.911, 'y': 0.111, 'type': 'entry', 'label': 'ENTRY_D'},
    // First ring of nodes
    {'id': 4, 'x': 0.222, 'y': 0.778, 'type': 'node', 'label': 'NODE_04'},
    {'id': 5, 'x': 0.778, 'y': 0.778, 'type': 'node', 'label': 'NODE_05'},
    {'id': 6, 'x': 0.167, 'y': 0.611, 'type': 'node', 'label': 'NODE_06'},
    {'id': 7, 'x': 0.500, 'y': 0.722, 'type': 'node', 'label': 'NODE_07'},
    {'id': 8, 'x': 0.833, 'y': 0.611, 'type': 'node', 'label': 'NODE_08'},
    // Second ring
    {'id': 9, 'x': 0.333, 'y': 0.533, 'type': 'node', 'label': 'NODE_09'},
    {'id': 10, 'x': 0.667, 'y': 0.533, 'type': 'node', 'label': 'NODE_10'},
    {'id': 11, 'x': 0.111, 'y': 0.422, 'type': 'node', 'label': 'NODE_11'},
    {'id': 12, 'x': 0.889, 'y': 0.422, 'type': 'node', 'label': 'NODE_12'},
    // Chokepoint layer
    {'id': 13, 'x': 0.278, 'y': 0.333, 'type': 'node', 'label': 'NODE_13'},
    {'id': 14, 'x': 0.722, 'y': 0.333, 'type': 'node', 'label': 'NODE_14'},
    {'id': 15, 'x': 0.500, 'y': 0.389, 'type': 'junction', 'label': 'JUNCTION'},
    // Upper paths toward core
    {'id': 16, 'x': 0.167, 'y': 0.222, 'type': 'node', 'label': 'NODE_16'},
    {'id': 17, 'x': 0.833, 'y': 0.222, 'type': 'node', 'label': 'NODE_17'},
    {'id': 18, 'x': 0.389, 'y': 0.244, 'type': 'node', 'label': 'NODE_18'},
    {'id': 19, 'x': 0.611, 'y': 0.244, 'type': 'node', 'label': 'NODE_19'},
    {'id': 20, 'x': 0.278, 'y': 0.133, 'type': 'node', 'label': 'NODE_20'},
    {'id': 21, 'x': 0.722, 'y': 0.133, 'type': 'node', 'label': 'NODE_21'},
    {'id': 22, 'x': 0.500, 'y': 0.178, 'type': 'node', 'label': 'NODE_22'},
    // CORE - goal (center of map, only reachable via JUNCTION)
    {'id': 23, 'x': 0.500, 'y': 0.500, 'type': 'core', 'label': 'CORE'},
  ];

  bool showGameStateOverlay = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top bar: Timer and connection
                _buildTopBar(),
                AppSpacing.spacerSmall,

                // Main game area with interactive map
                Expanded(child: _buildGameArea()),

                // Bottom navigation controls
                _buildNavigationBar(),
              ],
            ),

            // Game state overlay (toggleable)
            if (showGameStateOverlay) _buildGameStateOverlay(),

            // Error snackbar area (bottom)
            Positioned(
              bottom: 100,
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
          decoration: AppDecorations.topBarDecoration,
          padding: AppSpacing.panelPadding,
          child: Row(
            children: [
              // Connection indicator and device name
              ConnectionIndicator(isConnected: gameState.isM5Connected),
              AppSpacing.spacerWidthSmall,
              Expanded(
                child: Text(
                  gameState.displayDeviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.deviceName,
                ),
              ),
              AppSpacing.spacerWidthLarge,

              // ============ TURN INDICATOR ============
              GlowContainer(
                color: gameState.currentTurn == CurrentTurn.hackerTurn
                    ? AppColors.hackerTurn
                    : AppColors.defenderTurn,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  gameState.currentTurn == CurrentTurn.hackerTurn
                      ? 'YOUR TURN'
                      : 'DEF TURN',
                  style: AppTextStyles.turnIndicator(
                    color: gameState.currentTurn == CurrentTurn.hackerTurn
                        ? AppColors.hackerTurn
                        : AppColors.defenderTurn,
                  ),
                ),
              ),
              AppSpacing.spacerWidthSmall,

              // Timer
              GlowButton(
                label: gameState.formattedTime,
                onTap: () {}, // Timer is not clickable
                color: AppColors.cyan,
                fontSize: 12,
                enabled: false,
              ),
              AppSpacing.spacerWidthSmall,

              // Debug buttons
              if (DEBUG_MODE)
                GlowButton(
                  label: 'STATUS',
                  color: AppColors.yellow,
                  onTap: () => setState(
                    () => showGameStateOverlay = !showGameStateOverlay,
                  ),
                ),
              if (DEBUG_MODE) AppSpacing.spacerWidthSmall,
              if (DEBUG_MODE)
                GlowButton(
                  label: 'DBG',
                  color: AppColors.magenta,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'DEBUG - H:${gameState.hackerCurrentNode} T:${gameState.tracePositions.join(",")} L:${gameState.lockedNodes.join(",")}',
                          style: const TextStyle(fontFamily: 'Courier'),
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
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
        return GestureDetector(
          onTapUp: (details) {
            _handleNodeTap(details.globalPosition, context);
          },
          child: Container(
            color: AppColors.background,
            child: CustomPaint(
              painter: InteractiveGameMapPainter(
                hackerNode: gameState.hackerCurrentNode,
                accessibleNeighbors: gameState.getAccessibleNeighbors(),
                traceNodes: gameState.tracePositions,
                lockedNodes: gameState.lockedNodes,
                nodes: nodes,
                spoofActive: gameState.spoofActive,
                toolSelectionMode: gameState.toolSelectionMode,
                validToolTargets: gameState.validToolTargets,
              ),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }

  void _handleNodeTap(Offset globalPosition, BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
    final Offset localPosition = renderBox.globalToLocal(globalPosition);

    // Calculate coordinates relative to game area (accounting for top bar)
    final gameAreaPosition =
        localPosition - const Offset(0, 90); // Approximate top bar height
    if (gameAreaPosition.dy < 0) return; // Tap was on top bar

    final gameState = context.read<GameState>();

    for (final node in nodes) {
      final nodeX = (node['x'] as double) * size.width;
      final nodeY =
          gameAreaPosition.dy + ((node['y'] as double) * (size.height - 200));

      const tapRadius = 30.0;
      final distance = (Offset(nodeX, nodeY) - gameAreaPosition).distance;

      if (distance < tapRadius) {
        final nodeId = node['id'] as int;

        // Handle tool selection modes
        if (gameState.toolSelectionMode == ToolSelectionMode.tunnel) {
          gameState.selectTunnelTarget(nodeId);
        } else if (gameState.toolSelectionMode == ToolSelectionMode.crack) {
          gameState.selectCrackTarget(nodeId);
        } else {
          // Normal movement
          gameState.moveToNode(nodeId);
        }
        break;
      }
    }
  }

  Widget _buildNavigationBar() {
    return Consumer<GameState>(
      builder: (context, gameState, _) {
        final neighbors = gameState.getAccessibleNeighbors();
        final currentNode = gameState.hackerCurrentNode;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border(top: BorderSide(color: Color(0xFF00FFFF), width: 2)),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Current node display with visual indicator
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFF00FFFF), width: 2),
                    borderRadius: BorderRadius.circular(6),
                    color: Color(0xFF00FFFF).withOpacity(0.08),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Color(0xFF00FFFF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          currentNode < 0
                              ? '●●● NOT PLACED ●●●'
                              : nodes[currentNode]['label'] as String,
                          style: TextStyle(
                            color: Color(0xFF00FFFF),
                            fontSize: 15,
                            fontFamily: 'Courier New',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tool selection targets (if in selection mode)
                if (gameState.toolSelectionMode != ToolSelectionMode.none)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gameState.toolSelectionMode == ToolSelectionMode.tunnel
                            ? 'TUNNEL TARGETS (Entry Nodes):'
                            : 'CRACK TARGETS (Locked Nodes):',
                        style: TextStyle(
                          color:
                              gameState.toolSelectionMode ==
                                  ToolSelectionMode.tunnel
                              ? Color(0xFF00FFFF)
                              : Color(0xFFFF0055),
                          fontSize: 12,
                          fontFamily: 'Courier New',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: gameState.validToolTargets.map((nodeId) {
                          final nodeName = nodes[nodeId]['label'] as String;
                          final bgColor =
                              gameState.toolSelectionMode ==
                                  ToolSelectionMode.tunnel
                              ? Color(0xFF00FFFF)
                              : Color(0xFFFF0055);
                          return GestureDetector(
                            onTap: () {
                              if (gameState.toolSelectionMode ==
                                  ToolSelectionMode.tunnel) {
                                gameState.selectTunnelTarget(nodeId);
                              } else if (gameState.toolSelectionMode ==
                                  ToolSelectionMode.crack) {
                                gameState.selectCrackTarget(nodeId);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: bgColor, width: 2),
                                borderRadius: BorderRadius.circular(4),
                                color: bgColor.withOpacity(0.12),
                              ),
                              child: Text(
                                nodeName,
                                style: TextStyle(
                                  color: bgColor,
                                  fontSize: 11,
                                  fontFamily: 'Courier New',
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  )
                else
                  const SizedBox(height: 16),

                // Accessible neighbors as clickable buttons (only if not in tool selection mode)
                if (gameState.toolSelectionMode == ToolSelectionMode.none &&
                    neighbors.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACCESSIBLE NODES:',
                        style: TextStyle(
                          color: Color(0xFF00FF41),
                          fontSize: 12,
                          fontFamily: 'Courier New',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: neighbors.map((nodeId) {
                          final nodeName = nodes[nodeId]['label'] as String;
                          return GestureDetector(
                            onTap: () {
                              context.read<GameState>().moveToNode(nodeId);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Color(0xFF00FF41),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                color: Color(0xFF00FF41).withOpacity(0.12),
                              ),
                              child: Text(
                                nodeName,
                                style: TextStyle(
                                  color: Color(0xFF00FF41),
                                  fontSize: 11,
                                  fontFamily: 'Courier New',
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                // Check for adjacent locked nodes (only if not in selection mode)
                if (currentNode >= 0 &&
                    gameState.toolSelectionMode == ToolSelectionMode.none)
                  Builder(
                    builder: (context) {
                      final allNeighbors =
                          GameState.nodeConnections[currentNode] ?? [];
                      final lockedNeighbors = allNeighbors
                          .where((n) => gameState.lockedNodes.contains(n))
                          .toList();
                      if (lockedNeighbors.isNotEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            Text(
                              'LOCKED NODES:',
                              style: TextStyle(
                                color: Color(0xFFFF0055),
                                fontSize: 12,
                                fontFamily: 'Courier New',
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: lockedNeighbors.map((nodeId) {
                                final nodeName =
                                    nodes[nodeId]['label'] as String;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Color(0xFFFF0055),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    color: Color(0xFFFF0055).withOpacity(0.12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        '🔒 ',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        nodeName,
                                        style: TextStyle(
                                          color: Color(0xFFFF0055),
                                          fontSize: 11,
                                          fontFamily: 'Courier New',
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                const SizedBox(height: 16),

                // Tools section
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFFF00FF), width: 2),
                    borderRadius: BorderRadius.circular(6),
                    color: Color(0xFFFF00FF).withOpacity(0.08),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HACKER TOOLS',
                        style: TextStyle(
                          color: Color(0xFFFF00FF),
                          fontSize: 13,
                          fontFamily: 'Courier New',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Spoof tool
                          _buildToolButton(
                            label: 'SPOOF',
                            uses: gameState.spoofUsesRemaining,
                            isAvailable: gameState.spoofUsesRemaining > 0,
                            totalUses: 3,
                            color: Color(0xFF00FF41), // Bright neon green
                            onPressed: () {
                              context.read<GameState>().useSpoof();
                            },
                          ),
                          // Tunnel tool
                          _buildToolButton(
                            label: 'TUNNEL',
                            uses: gameState.tunnelUsesRemaining,
                            isAvailable: gameState.tunnelUsesRemaining > 0,
                            totalUses: 1,
                            color: Color(0xFF00FFFF), // Bright cyan
                            onPressed: () {
                              context.read<GameState>().useTunnel();
                            },
                          ),
                          // Crack tool
                          _buildToolButton(
                            label: 'CRACK',
                            uses: gameState.crackUsesRemaining,
                            isAvailable: gameState.crackUsesRemaining > 0,
                            totalUses: 1,
                            color: Color(0xFFFF0055), // Bright neon red
                            onPressed: () {
                              context.read<GameState>().useCrack();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolButton({
    required String label,
    required int uses,
    required bool isAvailable,
    required int totalUses,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: isAvailable ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: isAvailable ? color : Colors.grey[700]!,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(6),
          color: isAvailable ? color.withOpacity(0.12) : Colors.grey[900],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isAvailable ? color : Colors.grey[700],
                fontWeight: FontWeight.bold,
                fontSize: 11,
                fontFamily: 'Courier New',
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$uses/$totalUses',
              style: TextStyle(
                color: isAvailable ? color : Colors.grey[700],
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier New',
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
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
    return ErrorSnackbarContent(message: message);
  }
}

/// Custom painter to draw the interactive game map with node highlighting
class InteractiveGameMapPainter extends CustomPainter {
  final int hackerNode;
  final List<int> accessibleNeighbors;
  final List<int> traceNodes;
  final List<int> lockedNodes;
  final List<Map<String, dynamic>> nodes;
  final bool spoofActive;
  final ToolSelectionMode toolSelectionMode;
  final List<int> validToolTargets;

  InteractiveGameMapPainter({
    required this.hackerNode,
    required this.accessibleNeighbors,
    required this.traceNodes,
    required this.lockedNodes,
    required this.nodes,
    required this.spoofActive,
    required this.toolSelectionMode,
    required this.validToolTargets,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    // Draw grid lines
    _drawGrid(canvas, size);

    // Draw edges/connections
    _drawConnections(canvas, size);

    // Draw nodes with highlighting
    _drawNodes(canvas, size);
    _drawToolEffects(canvas, size);

    // Draw hacker position (cyan highlight on current node)
    if (hackerNode >= 0) {
      _drawHackerPosition(canvas, size);
    }

    // TODO: Traces are hidden from the map - see STATUS panel for debug info
    // In production, defender traces will be completely invisible to hacker
    // _drawTraces(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withOpacity(0.08)
      ..strokeWidth = 0.5;

    const gridSpacing = 40;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawConnections(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withOpacity(0.3)
      ..strokeWidth = 1;

    for (final node in nodes) {
      final nodeId = node['id'] as int;
      final nodeX = (node['x'] as double) * size.width;
      final nodeY = (node['y'] as double) * size.height;

      // Draw lines to connected nodes
      final neighbors = GameState.nodeConnections[nodeId] ?? [];
      for (final neighborId in neighbors) {
        if (neighborId > nodeId) {
          // Only draw once per connection
          final neighbor = nodes.firstWhere(
            (n) => n['id'] == neighborId,
            orElse: () => {},
          );
          if (neighbor.isNotEmpty) {
            final neighborX = (neighbor['x'] as double) * size.width;
            final neighborY = (neighbor['y'] as double) * size.height;
            canvas.drawLine(
              Offset(nodeX, nodeY),
              Offset(neighborX, neighborY),
              paint,
            );
          }
        }
      }
    }
  }

  void _drawNodes(Canvas canvas, Size size) {
    const nodeRadius = 8.0;
    const accessibleRadius = 12.0;

    for (final node in nodes) {
      final nodeId = node['id'] as int;
      final nodeX = (node['x'] as double) * size.width;
      final nodeY = (node['y'] as double) * size.height;
      final nodeType = node['type'] as String;
      final isValidToolTarget = validToolTargets.contains(nodeId);

      // Draw tool target highlight first (underneath)
      if (isValidToolTarget) {
        if (toolSelectionMode == ToolSelectionMode.tunnel) {
          // Tunnel targets (entry nodes) - blue pulsing ring
          canvas.drawCircle(
            Offset(nodeX, nodeY),
            20.0,
            Paint()
              ..color = Colors.blue.withOpacity(0.4)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3,
          );
        } else if (toolSelectionMode == ToolSelectionMode.crack) {
          // Crack targets (locked nodes) - orange pulsing ring
          canvas.drawCircle(
            Offset(nodeX, nodeY),
            20.0,
            Paint()
              ..color = Colors.orange.withOpacity(0.4)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3,
          );
        }
      }

      // Determine node color based on type and state
      Color nodeColor;
      double radius = nodeRadius;

      // Special colors for JUNCTION and CORE
      if (nodeType == 'core') {
        // CORE node - red, larger
        if (hackerNode == nodeId) {
          nodeColor = Colors.red;
          radius = 16.0;
          // Strong glow when current
          canvas.drawCircle(
            Offset(nodeX, nodeY),
            20.0,
            Paint()..color = Colors.red.withOpacity(0.3),
          );
        } else if (accessibleNeighbors.contains(nodeId)) {
          nodeColor = Colors.red;
          radius = 14.0;
          canvas.drawCircle(
            Offset(nodeX, nodeY),
            16.0,
            Paint()..color = Colors.red.withOpacity(0.2),
          );
        } else {
          nodeColor = Colors.red;
          radius = 12.0;
        }
      } else if (nodeType == 'junction') {
        // JUNCTION node - yellow, medium
        if (hackerNode == nodeId) {
          nodeColor = Colors.yellow;
          radius = 14.0;
          canvas.drawCircle(
            Offset(nodeX, nodeY),
            16.0,
            Paint()..color = Colors.yellow.withOpacity(0.3),
          );
        } else if (accessibleNeighbors.contains(nodeId)) {
          nodeColor = Colors.yellow;
          radius = 12.0;
          canvas.drawCircle(
            Offset(nodeX, nodeY),
            14.0,
            Paint()..color = Colors.yellow.withOpacity(0.2),
          );
        } else {
          nodeColor = Colors.yellow;
          radius = 10.0;
        }
      } else if (lockedNodes.contains(nodeId)) {
        // Locked node - grey with lock symbol
        nodeColor = Colors.grey[600] ?? Colors.grey;
        radius = nodeRadius;
      } else if (hackerNode == nodeId) {
        // Current node - bright cyan glow
        nodeColor = Colors.cyan;
        radius = 14.0;
        // Draw glow effect
        canvas.drawCircle(
          Offset(nodeX, nodeY),
          16.0,
          Paint()..color = Colors.cyan.withOpacity(0.2),
        );
      } else if (accessibleNeighbors.contains(nodeId)) {
        // Accessible neighbor - green highlight
        nodeColor = Colors.green;
        radius = accessibleRadius;
        // Draw subtle glow
        canvas.drawCircle(
          Offset(nodeX, nodeY),
          accessibleRadius + 2,
          Paint()..color = Colors.green.withOpacity(0.2),
        );
      } else {
        // Default node
        nodeColor = Colors.white.withOpacity(0.6);
      }

      // Draw node
      canvas.drawCircle(
        Offset(nodeX, nodeY),
        radius,
        Paint()..color = nodeColor,
      );

      // Draw lock symbol on locked nodes
      if (lockedNodes.contains(nodeId)) {
        _drawLockSymbol(canvas, nodeX, nodeY);
      }

      // Draw label
      _drawNodeLabel(canvas, nodeX, nodeY, node['label'] as String);
    }
  }

  void _drawLockSymbol(Canvas canvas, double x, double y) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw a simple lock icon
    // Lock body (rectangle)
    canvas.drawRect(Rect.fromLTWH(x - 3, y - 1, 6, 4), paint);
    // Lock shackle (arc)
    canvas.drawArc(
      Rect.fromLTWH(x - 4, y - 4, 8, 5),
      0.5, // start angle
      3.14, // sweep angle (π)
      false,
      paint,
    );
  }

  void _drawNodeLabel(Canvas canvas, double x, double y, String label) {
    // Render text on canvas using TextPainter
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontFamily: 'Courier',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y + 14));
  }

  void _drawHackerPosition(Canvas canvas, Size size) {
    final node = nodes[hackerNode];
    final nodeX = (node['x'] as double) * size.width;
    final nodeY = (node['y'] as double) * size.height;

    // Draw bright cyan circle indicator
    canvas.drawCircle(
      Offset(nodeX, nodeY),
      18.0,
      Paint()
        ..color = Colors.cyan.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawToolEffects(Canvas canvas, Size size) {
    // SPOOF - orange pulsing rings around hacker
    if (spoofActive && hackerNode >= 0) {
      final node = nodes[hackerNode];
      final nx = (node['x'] as double) * size.width;
      final ny = (node['y'] as double) * size.height;
      for (int i = 3; i >= 1; i--) {
        canvas.drawCircle(
          Offset(nx, ny),
          20.0 + (i * 4),
          Paint()
            ..color = Colors.orange.withOpacity(0.15 / i)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
    // Tunnel and crack are now selection-based,
    // so no automatic visual effects needed here
  }

  void _drawTraces(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.red.withOpacity(0.8);
    const radius = 7.0;

    for (final traceNodeId in traceNodes) {
      if (traceNodeId < nodes.length) {
        final node = nodes[traceNodeId];
        final nodeX = (node['x'] as double) * size.width;
        final nodeY = (node['y'] as double) * size.height;
        canvas.drawCircle(Offset(nodeX, nodeY), radius, paint);

        // Draw warning X
        final xPaint = Paint()
          ..color = Colors.red
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(nodeX - 5, nodeY - 5),
          Offset(nodeX + 5, nodeY + 5),
          xPaint,
        );
        canvas.drawLine(
          Offset(nodeX - 5, nodeY + 5),
          Offset(nodeX + 5, nodeY - 5),
          xPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(InteractiveGameMapPainter oldDelegate) {
    return oldDelegate.hackerNode != hackerNode ||
        oldDelegate.accessibleNeighbors != accessibleNeighbors ||
        oldDelegate.traceNodes != traceNodes ||
        oldDelegate.lockedNodes != lockedNodes ||
        oldDelegate.spoofActive != spoofActive ||
        oldDelegate.toolSelectionMode != toolSelectionMode ||
        oldDelegate.validToolTargets != validToolTargets;
  }
}

class _GameStatePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, gameState, _) {
        return GlowContainer(
          color: AppColors.neonGreen,
          padding: const EdgeInsets.all(20),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeadingText('GAME STATE', color: AppColors.neonGreen),
              AppSpacing.spacerLarge,
              StatRow(
                label: 'Hacker Position:',
                value: 'Node ${gameState.hackerCurrentNode}',
                labelColor: AppColors.yellow,
                valueColor: AppColors.neonGreen,
              ),
              StatRow(
                label: 'Trace Positions:',
                value: gameState.tracePositions.isEmpty
                    ? 'None'
                    : gameState.tracePositions.join(', '),
                labelColor: AppColors.yellow,
                valueColor: AppColors.neonGreen,
              ),
              StatRow(
                label: 'Locked Nodes:',
                value: gameState.lockedNodes.isEmpty
                    ? 'None'
                    : gameState.lockedNodes.join(', '),
                labelColor: AppColors.yellow,
                valueColor: AppColors.neonGreen,
              ),
              AppSpacing.spacerMedium,
              LabelText('TOOL STATUS:', color: AppColors.yellow),
              AppSpacing.spacerSmall,
              StatRow(
                label: 'Spoof:',
                value:
                    '${gameState.spoofUsesRemaining}/3 ${gameState.spoofActive ? '⚡ ACTIVE' : ''}',
                labelColor: AppColors.yellow,
                valueColor: AppColors.neonGreen,
              ),
              StatRow(
                label: 'Tunnel:',
                value:
                    '${gameState.tunnelUsesRemaining}/1 ${gameState.toolSelectionMode == ToolSelectionMode.tunnel ? '⚡ SELECTING' : ''}',
                labelColor: AppColors.yellow,
                valueColor: AppColors.neonGreen,
              ),
              StatRow(
                label: 'Crack:',
                value:
                    '${gameState.crackUsesRemaining}/1 ${gameState.toolSelectionMode == ToolSelectionMode.crack ? '⚡ SELECTING' : ''}',
                labelColor: AppColors.yellow,
                valueColor: AppColors.neonGreen,
              ),
              AppSpacing.spacerXLarge,
              // ═══════════════════════════════════════════════════════════════════════════
              // 🗑️  DEBUG PANEL - DELETE EVERYTHING BELOW THIS WHEN BLE IS IMPLEMENTED
              // 🗑️  These buttons simulate defender behavior for testing without M5Core2
              // ═══════════════════════════════════════════════════════════════════════════
              if (DEBUG_MODE) ...[
                GlowDivider(color: AppColors.magenta),
                AppSpacing.spacerMedium,
                LabelText(
                  'DEBUG TRACE CONTROLS (TODO: Remove)',
                  color: AppColors.magenta,
                ),
                AppSpacing.spacerMedium,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.magenta,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () {
                        gameState.advanceDebugTraces();
                      },
                      child: const Text(
                        'Advance Traces',
                        style: TextStyle(fontSize: 10, color: Colors.black),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonRed,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () {
                        gameState.debugCheckIfCaught();
                      },
                      child: const Text(
                        'Check Caught?',
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () {
                        gameState.debugSwitchTurn();
                      },
                      child: const Text(
                        'Switch Turn',
                        style: TextStyle(fontSize: 10, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ],
              // ═══════════════════════════════════════════════════════════════════════════
              // 🗑️  END DEBUG PANEL - DELETE EVERYTHING ABOVE
              // ═══════════════════════════════════════════════════════════════════════════
            ],
          ),
        );
      },
    );
  }
}
