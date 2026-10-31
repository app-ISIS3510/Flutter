import 'package:flutter/material.dart';

import '../models/most_used_parking.dart';
import '../models/most_used_parking_ranking.dart';
import '../theme/app_theme.dart';
import 'offline_data_status_indicator.dart';

class MostUsedParkingSection extends StatelessWidget {
  final Future<MostUsedParkingRanking> future;
  final VoidCallback onRetry;
  final ValueChanged<MostUsedParking>? onSelectParking;
  final String? openingParkingId;

  const MostUsedParkingSection({
    super.key,
    required this.future,
    required this.onRetry,
    this.onSelectParking,
    this.openingParkingId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: FutureBuilder<MostUsedParkingRanking>(
        future: future,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final ranking = loading || snapshot.hasError ? null : snapshot.data;
          final saved = ranking?.isFromCache ?? false;
          final items = ranking?.parkingLots ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                saved
                    ? 'Most used parking lots (saved)'
                    : 'Most used parking lots this week',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                saved
                    ? 'Top 3 in the 7 days before the last update.'
                    : 'Top 3 by completed sessions in the last 7 days.',
                style: const TextStyle(fontSize: 13, color: AppColors.greyText),
              ),
              const SizedBox(height: 12),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError) ...[
                const Text(
                  'Could not load this ranking. Check your connection and retry.',
                  style: TextStyle(fontSize: 13, color: AppColors.greyText),
                ),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry ranking'),
                ),
              ] else ...[
                if (saved) ...[
                  OfflineDataStatusIndicator(
                    isFromCache: true,
                    updatedAt: ranking!.updatedAt,
                    title: 'Saved ranking',
                    description: 'Could not refresh this ranking. These results may have changed.',
                  ),
                  const SizedBox(height: 12),
                ],
                if (items.isEmpty)
                  Text(
                    saved
                        ? 'No completed parking sessions were recorded in the saved period.'
                        : 'No completed parking sessions were recorded in the last 7 days.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.greyText,
                    ),
                  ),
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const SizedBox(height: 10),
                  _parkingTile(items[index], index + 1),
                ],
                _refreshButton(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _refreshButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: onRetry,
        child: const Text('Refresh ranking'),
      ),
    );
  }

  Widget _parkingTile(MostUsedParking parking, int rank) {
    final opening = openingParkingId == parking.parkingId;
    return InkWell(
      onTap: openingParkingId != null || onSelectParking == null
          ? null
          : () => onSelectParking!(parking),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.lightPurple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parking.parkingName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    parking.completedSessions == 1
                        ? '1 completed session'
                        : '${parking.completedSessions} completed sessions',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (opening)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.chevron_right, color: AppColors.greyText),
          ],
        ),
      ),
    );
  }
}
