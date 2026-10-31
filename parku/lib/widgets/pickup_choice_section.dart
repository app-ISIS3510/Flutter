import 'package:flutter/material.dart';

import '../models/pickup_choice_summary.dart';
import '../theme/app_theme.dart';

class PickupChoiceSection extends StatefulWidget {
  final Future<PickupChoiceSummary> Function() load;

  const PickupChoiceSection({super.key, required this.load});

  @override
  State<PickupChoiceSection> createState() => _PickupChoiceSectionState();
}

class _PickupChoiceSectionState extends State<PickupChoiceSection> {
  late Future<PickupChoiceSummary> _summary;

  @override
  void initState() {
    super.initState();
    _summary = widget.load();
  }

  String _date(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pickup time choices',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<PickupChoiceSummary>(
            future: _summary,
            builder: (context, snapshot) {
              final loading =
                  snapshot.connectionState == ConnectionState.waiting;
              final summary = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (loading)
                    const Text('Loading pickup choices...')
                  else if (snapshot.hasError || summary == null)
                    const Text(
                      'Pickup choices are unavailable. You can still choose a time.',
                    )
                  else ...[
                    Text(
                      summary.isFromCache
                          ? 'Saved results · 7-day period'
                          : 'Successful parking starts · Last 7 days',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (summary.total == 0)
                      const Text(
                        'No parking starts were recorded in this period.',
                      )
                    else ...[
                      _choice('Suggested', summary.suggestedPercentage),
                      _choice('Manual', summary.manualPercentage),
                      _choice('Not recorded', summary.notRecordedPercentage),
                      const SizedBox(height: 8),
                      Text(
                        'Based on ${summary.total} successful parking '
                        '${summary.total == 1 ? 'start' : 'starts'}.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.greyText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'Suggested means keeping the first time shown. Choose a time that fits your plans.',
                      style: TextStyle(fontSize: 12, color: AppColors.greyText),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary.isFromCache
                          ? 'Saved on ${_date(summary.updatedAt)}. Connect to update.'
                          : 'Updated ${_date(summary.updatedAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              setState(() {
                                _summary = widget.load();
                              });
                            },
                      child: Text(
                        snapshot.hasError ? 'Retry results' : 'Refresh results',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _choice(String label, double percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Text(
            '${percentage.toStringAsFixed(2)}%',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
