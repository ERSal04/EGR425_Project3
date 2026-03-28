import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../constants.dart';
import '../widgets.dart';

class EntrySelectionScreen extends StatelessWidget {
  const EntrySelectionScreen({super.key});

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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with connection status
            _buildHeader(),
            AppSpacing.spacerXLarge,

            // Title
            HeadingText(
              'SELECT ENTRY NODE',
              color: AppColors.neonGreen,
              fontSize: 20,
            ),
            AppSpacing.spacerXLarge,

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
          padding: AppSpacing.paddingMedium,
          child: Row(
            children: [
              // Connection indicator
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
      child: GlowContainer(
        color: AppColors.neonGreen,
        borderRadius: BorderRadius.circular(8),
        padding: AppSpacing.paddingMedium,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.neonGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonGreen.withOpacity(0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            AppSpacing.spacerMedium,
            ValueText(label, color: AppColors.neonGreen, fontSize: 14),
            AppSpacing.spacerSmall,
            LabelText(position, color: AppColors.cyan, fontSize: 10),
          ],
        ),
      ),
    );
  }
}
