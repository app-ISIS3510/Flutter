import 'package:flutter/material.dart';

import '../controllers/parking_comparison_controller.dart';
import '../models/parking.dart';
import '../theme/app_theme.dart';

class ParkingComparisonToggle extends StatelessWidget {
  final ParkingComparisonController controller;
  final Parking parking;

  const ParkingComparisonToggle({
    super.key,
    required this.controller,
    required this.parking,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final selected = controller.contains(parking.id);
      return Tooltip(
        message: selected
            ? 'Remove ${parking.name} from comparison'
            : 'Add ${parking.name} to comparison',
        child: TextButton.icon(
          onPressed: selected || controller.hasCapacity
              ? () => controller.toggle(parking)
              : null,
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          icon: Icon(
            selected ? Icons.check_circle_outline : Icons.add_circle_outline,
            size: 18,
          ),
          label: Text(selected ? 'Added to compare' : 'Add to compare'),
        ),
      );
    },
  );
}

class ParkingComparisonBar extends StatelessWidget {
  final ParkingComparisonController controller;
  final VoidCallback onCompare;

  const ParkingComparisonBar({
    super.key,
    required this.controller,
    required this.onCompare,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final count = controller.count;
      if (count == 0) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        decoration: BoxDecoration(
          color: AppColors.lightPurple,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  '$count of ${ParkingComparisonController.maxSelection} selected',
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: controller.canCompare ? onCompare : null,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Compare'),
            ),
          ],
        ),
      );
    },
  );
}
