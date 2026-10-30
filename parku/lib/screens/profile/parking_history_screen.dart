import 'package:flutter/material.dart';

import '../../models/parking_summary.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import 'profile_widgets.dart';

class ParkingHistoryScreen extends StatefulWidget {
  final SessionService service;
  final ValueChanged<int> onNavTap;

  const ParkingHistoryScreen({
    super.key,
    required this.service,
    required this.onNavTap,
  });

  @override
  State<ParkingHistoryScreen> createState() => _ParkingHistoryScreenState();
}

class _ParkingHistoryScreenState extends State<ParkingHistoryScreen> {
  late Future<List<ParkingSummary>> _summaries;

  @override
  void initState() {
    super.initState();
    _summaries = widget.service.getSavedSessions();
  }

  void _reload() {
    setState(() {
      _summaries = widget.service.getSavedSessions();
    });
  }

  String _dateTime(DateTime value) {
    final local = value.toLocal();
    final date = '${local.day}/${local.month}/${local.year}';
    final time = TimeOfDay.fromDateTime(local).format(context);
    return '$date · $time';
  }

  Widget _summaryCard(ParkingSummary summary) {
    return ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.parkingName,
            style: profileText(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            '${summary.vehicleType == 'motorcycle' ? 'Motorcycle' : 'Car'}'
            '${summary.vehiclePlate == null ? '' : ' · ${summary.vehiclePlate}'}',
            style: profileText(14),
          ),
          const SizedBox(height: 10),
          Text(
            'Started: ${_dateTime(summary.startedAt)}',
            style: profileText(13, color: AppColors.greyText),
          ),
          const SizedBox(height: 6),
          Text(
            'Ended: ${_dateTime(summary.endedAt)}',
            style: profileText(13, color: AppColors.greyText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfilePage(
      title: 'Saved parking',
      onBack: () => Navigator.pop(context),
      onNavTap: widget.onNavTap,
      child: FutureBuilder<List<ParkingSummary>>(
        future: _summaries,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Column(
              children: [
                const ProfileError(
                  'Could not read your saved parking on this device.',
                ),
                const SizedBox(height: 16),
                ProfileButton(text: 'Try again', onPressed: _reload),
              ],
            );
          }

          final summaries = snapshot.data ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Completed stays saved on this device. Available without internet.',
                style: profileText(13, color: AppColors.greyText),
              ),
              const SizedBox(height: 20),
              if (summaries.isEmpty)
                ProfileCard(
                  color: AppColors.lightPurple,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.history,
                        size: 36,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No saved parking yet',
                        style: profileText(20, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your next completed parking stay will appear here.',
                        style: profileText(14, color: AppColors.greyText),
                      ),
                    ],
                  ),
                )
              else
                for (final summary in summaries) ...[
                  _summaryCard(summary),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}
