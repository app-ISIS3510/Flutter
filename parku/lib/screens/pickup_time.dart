import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/design_icon.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/pickup_widgets.dart';

class PickupTimeScreen extends StatefulWidget {
  final ValueChanged<int> onNavTap;
  final Future<void> Function(String) onStartParking;

  final String openingTime;
  final String closingTime;

  const PickupTimeScreen({
    super.key,
    required this.onNavTap,
    required this.onStartParking,
    required this.openingTime,
    required this.closingTime,
  });

  @override
  State<PickupTimeScreen> createState() =>
      _PickupTimeScreenState();
}

class _PickupTimeScreenState
    extends State<PickupTimeScreen> {
  String? selectedTime;

  bool isStartingParking = false;

  late List<String> availableTimes;

  @override
  void initState() {
    super.initState();

    availableTimes = _generateAvailableTimes();

    if (availableTimes.isNotEmpty) {
      selectedTime = availableTimes.first;
    }
  }

  DateTime _parseParkingTime(
    String time,
    DateTime day,
  ) {
    final parts = time.split(':');

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
    final parts = time.split(':');

    int hour = int.parse(parts[0]);
    final minute = parts[1];

    final period = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;

    if (hour == 0) {
      hour = 12;
    }

    return '$hour:$minute $period';
  }

  Future<void> _startParking() async {
    if (isStartingParking) return;

    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'There are no available pickup times today.',
          ),
        ),
      );

      return;
    }

    setState(() {
      isStartingParking = true;
    });

    try {
      await widget.onStartParking(
        selectedTime!,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not start parking: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isStartingParking = false;
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
                padding:
                    const EdgeInsets.fromLTRB(
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
                      title: 'Pickup time',
                      onBack: () =>
                          Navigator.pop(context),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'When will you pick it up?',
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
                      'Choose an approximate time to pick up your vehicle.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color:
                            AppColors.greyText,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(
                        16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius:
                            BorderRadius.circular(
                          20,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              DesignIcon('car'),
                              SizedBox(width: 10),
                              Text(
                                'Car',
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.35,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                  color: AppColors
                                      .darkText,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          const Text(
                            'ABC123',
                            style: TextStyle(
                              fontSize: 22,
                              height: 1.35,
                              fontWeight:
                                  FontWeight.w700,
                              color:
                                  AppColors.darkText,
                            ),
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          PickupButton(
                            text:
                                'Change vehicle',
                            background:
                                AppColors.white,
                            foreground:
                                AppColors.primary,
                            onPressed: () {
                              ScaffoldMessenger
                                      .of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Demo vehicle: Car · ABC123',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Today · Pickup time',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            AppColors.darkText,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Parking closes at ${_formatTime(widget.closingTime.substring(0, 5))}',
                      style: const TextStyle(
                        fontSize: 12,
                        color:
                            AppColors.greyText,
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (hasAvailableTimes) ...[
                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),
                        decoration:
                            BoxDecoration(
                          color: AppColors
                              .lightPurple,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                        ),
                        child: Row(
                          children: [
                            const DesignIcon(
                              'clock',
                              size: 28,
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            Expanded(
                              child:
                                  DropdownButtonHideUnderline(
                                child:
                                    DropdownButton<String>(
                                  value:
                                      selectedTime,
                                  isExpanded:
                                      true,
                                  icon:
                                      const Icon(
                                    Icons
                                        .keyboard_arrow_down,
                                    color: AppColors
                                        .primary,
                                  ),
                                  style:
                                      const TextStyle(
                                    fontSize: 26,
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                    color: AppColors
                                        .primary,
                                  ),
                                  items:
                                      availableTimes
                                          .map(
                                    (time) {
                                      return DropdownMenuItem<
                                          String>(
                                        value:
                                            time,
                                        child:
                                            Text(
                                          _formatTime(
                                            time,
                                          ),
                                        ),
                                      );
                                    },
                                  ).toList(),
                                  onChanged:
                                      (value) {
                                    if (value ==
                                        null) {
                                      return;
                                    }

                                    setState(
                                      () {
                                        selectedTime =
                                            value;
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(
                          18,
                        ),
                        decoration:
                            BoxDecoration(
                          color: AppColors
                              .lightPurple,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                        ),
                        child: const Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'No pickup times available',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight
                                        .w700,
                                color: AppColors
                                    .darkText,
                              ),
                            ),
                            SizedBox(
                              height: 6,
                            ),
                            Text(
                              'This parking lot is closing soon or has already closed for today.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors
                                    .greyText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    PickupButton(
                      text: isStartingParking
                          ? 'Starting parking...'
                          : 'Start parking',
                      onPressed:
                          !hasAvailableTimes ||
                                  isStartingParking
                              ? () {}
                              : _startParking,
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'You can change this time whenever you need.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color:
                            AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            NavBar(
              currentIndex: 1,
              onTap: widget.onNavTap,
            ),
          ],
        ),
      ),
    );
  }
}