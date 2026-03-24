import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';

class EntrySelectionScreen extends StatelessWidget {
  const EntrySelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Map of entry node IDs to display names and positions
    const entries = {
      0: ('ENTRY_A', 'Bottom-Left'),
      1: ('ENTRY_B', 'Bottom-Right'),
      2: ('ENTRY_C', 'Top-Left'),
      3: ('ENTRY_D', 'Top-Right'),
    };

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header with connection status
            _buildHeader(),
            const SizedBox(height: 32),

            // Title
            const Text(
              'SELECT ENTRY NODE',
              style: TextStyle(
                color: Colors.green,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),

            // Entry selection grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.all(16),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: entries.entries.map((entry) {
                  int nodeId = entry.key;
                  String label = entry.value.$1;
                  String position = entry.value.$2;

                  return _EntryNodeButton(
                    nodeId: nodeId,
                    label: label,
                    position: position,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<GameState>(
      builder: (context, gameState, _) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Connection indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: gameState.isM5Connected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  gameState.displayDeviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontFamily: 'Courier',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EntryNodeButton extends StatelessWidget {
  final int nodeId;
  final String label;
  final String position;

  const _EntryNodeButton({
    required this.nodeId,
    required this.label,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<GameState>().hackerSelectEntry(nodeId);
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green, width: 2),
          borderRadius: BorderRadius.circular(8),
          color: Colors.black87,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.green,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              position,
              style: const TextStyle(
                color: Colors.cyan,
                fontSize: 10,
                fontFamily: 'Courier',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
