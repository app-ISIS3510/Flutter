import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/pickup_widgets.dart';

class ChangePickupTimeScreen extends StatefulWidget {
  final String initialTime;
  final String openingTime;
  final String closingTime;

  final ValueChanged<int> onNavTap;
  final Future<void> Function(String) onSave;

  const ChangePickupTimeScreen({
    super.key,
    required this.initialTime,
    required this.openingTime,
    required this.closingTime,
    required this.onNavTap,
    required this.onSave,
  });

  @override
  State<ChangePickupTimeScreen> createState() =>
      _ChangePickupTimeScreenState();
}

class _ChangePickupTimeScreenState
    extends State<ChangePickupTimeScreen> {
  String? selectedTime;
  bool isSaving = false;

  late List<String> availableTimes;

  @override
  void initState() {
    super.initState();

    availableTimes = _generateAvailableTimes();

    if (availableTimes.contains(widget.initialTime)) {
      selectedTime = widget.initialTime;
    } else if (availableTimes.isNotEmpty) {
      selectedTime = availableTimes.first;
    }
  }

  DateTime _parseParkingTime(
    String time,
    DateTime day,
  ) {
    final cleanTime =
        time.length >= 5 ? time.substring(0, 5) : time;

    final parts = cleanTime.split(':');

    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    return DateTime(
      day.year,
      day.month,
      day.day,
      hour,
      minute,
    );
  }

  DateTime _roundToNext30Minutes(
    DateTime dateTime,
  ) {
    if (dateTime.minute < 30) {
      return DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
        dateTime.hour,
        30,
      );
    }

    return DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour + 1,
      0,
    );
  }

  List<String> _generateAvailableTimes() {
    final now = DateTime.now();

    final opening =
        _parseParkingTime(widget.openingTime, now);

    final closing =
        _parseParkingTime(widget.closingTime, now);

    DateTime firstPossibleTime =
        _roundToNext30Minutes(now);

    if (firstPossibleTime.isBefore(opening)) {
      firstPossibleTime = opening;
    }

    if (firstPossibleTime.isAfter(closing)) {
      return [];
    }

    final times = <String>[];

    DateTime current = firstPossibleTime;

    while (!current.isAfter(closing)) {
      final hour =
          current.hour.toString().padLeft(2, '0');

      final minute =
          current.minute.toString().padLeft(2, '0');

      times.add('$hour:$minute');

      current = current.add(
        const Duration(minutes: 30),
      );
    }

    return times;
  }

  String _formatTime(String time) {
    final cleanTime =
        time.length >= 5 ? time.substring(0, 5) : time;

    final parts = cleanTime.split(':');

    int hour = int.parse(parts[0]);
    final minute = parts[1];

    final period = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;

    if (hour == 0) {
      hour = 12;
    }

    return '$hour:$minute $period';
  }

  Future<void> _savePickupTime() async {
    if (isSaving || selectedTime == null) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await widget.onSave(
        selectedTime!,
      );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update pickup time: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAvailableTimes =
        availableTimes.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  18,
                  24,
                  24,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    ScreenHeader(
                      title: 'Change pickup time',
                      onBack: () =>
                          Navigator.pop(context),
                    ),

                    const SizedBox(height: 36),

                    const Text(
                      'Need more time?',
                      style: TextStyle(
                        fontSize: 25,
                        height: 1.35,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            AppColors.darkText,
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Update the time you plan to return to your vehicle.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        color:
                            AppColors.greyText,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Parking closes at ${_formatTime(widget.closingTime)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.greyText,
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (hasAvailableTimes) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(
                          16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightPurple,
                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NEW PICKUP TIME',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                fontWeight:
                                    FontWeight.w600,
                                color:
                                    AppColors.primary,
                              ),
                            ),

                            const SizedBox(height: 12),

                            DropdownButtonHideUnderline(
                              child:
                                  DropdownButton<String>(
                                value: selectedTime,
                                isExpanded: true,
                                icon: const Icon(
                                  Icons
                                      .keyboard_arrow_down,
                                  color:
                                      AppColors.primary,
                                ),
                                style:
                                    const TextStyle(
                                  fontSize: 30,
                                  fontWeight:
                                      FontWeight.w700,
                                  color:
                                      AppColors.primary,
                                ),
                                items:
                                    availableTimes
                                        .map(
                                  (time) {
                                    return DropdownMenuItem<
                                        String>(
                                      value: time,
                                      child: Text(
                                        _formatTime(
                                          time,
                                        ),
                                      ),
                                    );
                                  },
                                ).toList(),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    selectedTime =
                                        value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(
                          18,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightPurple,
                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                        ),
                        child: const Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No pickup times available',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.w700,
                                color:
                                    AppColors.darkText,
                              ),
                            ),

                            SizedBox(height: 6),

                            Text(
                              'This parking lot is closing soon or has already closed for today.',
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    AppColors.greyText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    PickupButton(
                      text: isSaving
                          ? 'Saving...'
                          : 'Save pickup time',
                      onPressed:
                          !hasAvailableTimes ||
                                  isSaving
                              ? () {}
                              : _savePickupTime,
                    ),

                    const SizedBox(height: 16),

                    PickupButton(
                      text: 'Back to my parking',
                      background: AppColors.white,
                      foreground: AppColors.primary,
                      onPressed: () =>
                          Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),

            NavBar(
              currentIndex: 3,
              onTap: widget.onNavTap,
            ),
          ],
        ),
      ),
    );
  }
}