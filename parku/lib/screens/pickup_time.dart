import 'package:flutter/material.dart';

import '../utils/user_error_message.dart';
import '../widgets/user_error_notice.dart';

import '../theme/app_theme.dart';
import '../models/vehicle.dart';
import '../services/driving_restriction_service.dart';
import '../widgets/design_icon.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/pickup_widgets.dart';
import 'profile/profile_widgets.dart';

class PickupTimeScreen extends StatefulWidget {
  final ValueChanged<int> onNavTap;
  final Future<void> Function(String, Vehicle) onStartParking;

  final Vehicle vehicle;
  final Future<Vehicle?> Function() onChangeVehicle;
  final String openingTime;
  final String closingTime;
  final DateTime Function()? currentTime;
  final String? initialTime;
  final void Function(String, Vehicle)? onDraftChanged;
  final VoidCallback? onCheckStatus;
  final String? notice;
  final ValueChanged<String>? onSuggestionReady;

  const PickupTimeScreen({
    super.key,
    required this.onNavTap,
    required this.onStartParking,
    required this.vehicle,
    required this.onChangeVehicle,
    required this.openingTime,
    required this.closingTime,
    this.currentTime,
    this.initialTime,
    this.onDraftChanged,
    this.onCheckStatus,
    this.notice,
    this.onSuggestionReady,
  });

  @override
  State<PickupTimeScreen> createState() => _PickupTimeScreenState();
}

class _PickupTimeScreenState extends State<PickupTimeScreen> {
  String? selectedTime;
  Vehicle? selectedVehicle;

  bool isStartingParking = false;
  bool _requestFailed = false;

  late List<String> availableTimes;

  @override
  void initState() {
    super.initState();

    selectedVehicle = widget.vehicle;
    availableTimes = _generateAvailableTimes();
    if (availableTimes.isNotEmpty) {
      widget.onSuggestionReady?.call(availableTimes.first);
    }

    if (availableTimes.contains(widget.initialTime)) {
      selectedTime = widget.initialTime;
    } else if (availableTimes.isNotEmpty) {
      selectedTime = availableTimes.first;
    }
  }

  DateTime _parseParkingTime(String time, DateTime day) {
    final parts = time.split(':');

    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  DateTime _roundToNext30Minutes(DateTime dateTime) {
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
    final now = widget.currentTime?.call() ?? DateTime.now();

    final opening = _parseParkingTime(widget.openingTime, now);

    final closing = _parseParkingTime(widget.closingTime, now);

    DateTime firstPossibleTime = _roundToNext30Minutes(now);

    if (firstPossibleTime.isBefore(opening)) {
      firstPossibleTime = opening;
    }

    if (firstPossibleTime.isAfter(closing)) {
      return [];
    }

    final times = <String>[];

    DateTime current = firstPossibleTime;

    while (!current.isAfter(closing)) {
      final hour = current.hour.toString().padLeft(2, '0');

      final minute = current.minute.toString().padLeft(2, '0');

      times.add('$hour:$minute');

      current = current.add(const Duration(minutes: 30));
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

    final vehicle = selectedVehicle;
    final time = selectedTime;
    if (vehicle == null) return;

    if (time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There are no available pickup times today.'),
        ),
      );

      return;
    }

    setState(() {
      isStartingParking = true;
    });

    try {
      final canContinue = await _showDrivingRestriction(vehicle);
      if (!canContinue || !mounted) return;

      await widget.onStartParking(time, vehicle);
    } catch (error) {
      if (!mounted) return;
      setState(() => _requestFailed = true);

      showUserError(context, error, action: ErrorAction.startParking);
    } finally {
      if (mounted) {
        setState(() {
          isStartingParking = false;
        });
      }
    }
  }

  Future<bool> _showDrivingRestriction(Vehicle vehicle) async {
    final restriction = DrivingRestrictionService().check(
      vehicle,
      now: widget.currentTime?.call(),
    );
    if (restriction.restricted == false) return true;

    final date = restriction.date;
    final today = '${date.day}/${date.month}/${date.year}';
    final isRestricted = restriction.restricted == true;

    final continueParking = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        scrollable: true,
        title: Text(
          isRestricted ? 'Pico y placa today' : 'Check driving restrictions',
          style: const TextStyle(
            color: AppColors.darkText,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          isRestricted
              ? '${vehicle.plate} has driving restrictions in Bogotá today ($today).\n\n'
                    'Restricted hours: ${restriction.hours}.\n'
                    '${restriction.explanation ?? ''}\n'
                    'You can still park. Check the restrictions before driving.'
              : 'We could not confirm today’s restrictions for ${vehicle.plate}. '
                    'Check the official information before driving.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Continue parking'),
          ),
        ],
      ),
    );
    return continueParking == true;
  }

  @override
  Widget build(BuildContext context) {
    final hasAvailableTimes = availableTimes.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScreenHeader(
                      title: 'Pickup time',
                      onBack: () => Navigator.pop(context),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'When will you pick it up?',
                      style: TextStyle(
                        fontSize: 25,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Choose an approximate time to pick up your vehicle.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: AppColors.greyText,
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (widget.notice != null) ...[
                      ProfileNotice(widget.notice!),
                      const SizedBox(height: 16),
                    ],

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              selectedVehicle?.type != VehicleType.motorcycle
                                  ? const DesignIcon('car')
                                  : const Icon(
                                      Icons.two_wheeler_outlined,
                                      color: AppColors.primary,
                                    ),
                              SizedBox(width: 10),
                              Text(
                                selectedVehicle?.type.label ??
                                    'No vehicle selected',
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkText,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Text(
                            selectedVehicle?.plate ??
                                'Add a vehicle to continue.',
                            style: TextStyle(
                              fontSize: 22,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText,
                            ),
                          ),

                          const SizedBox(height: 12),

                          PickupButton(
                            text: 'Change vehicle',
                            background: AppColors.white,
                            foreground: AppColors.primary,
                            onPressed: () async {
                              if (isStartingParking) return;
                              final vehicle = await widget.onChangeVehicle();
                              if (mounted) {
                                setState(() => selectedVehicle = vehicle);
                                if (selectedTime != null && vehicle != null) {
                                  widget.onDraftChanged?.call(
                                    selectedTime!,
                                    vehicle,
                                  );
                                }
                              }
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
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Parking closes at ${_formatTime(widget.closingTime.substring(0, 5))}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (hasAvailableTimes) ...[
                      Text(
                        'Suggested pickup time: ${_formatTime(availableTimes.first)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.greyText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.lightPurple,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const DesignIcon('clock', size: 28),

                            const SizedBox(width: 12),

                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedTime,
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: AppColors.primary,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                  items: availableTimes.map((time) {
                                    return DropdownMenuItem<String>(
                                      value: time,
                                      child: Text(_formatTime(time)),
                                    );
                                  }).toList(),
                                  onChanged: isStartingParking
                                      ? null
                                      : (value) {
                                          if (value == null) {
                                            return;
                                          }

                                          setState(() {
                                            selectedTime = value;
                                          });
                                          if (selectedVehicle != null) {
                                            widget.onDraftChanged?.call(
                                              value,
                                              selectedVehicle!,
                                            );
                                          }
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
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.lightPurple,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No pickup times available',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkText,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'This parking lot is closing soon or has already closed for today.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.greyText,
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
                              isStartingParking ||
                              selectedVehicle == null
                          ? null
                          : _startParking,
                    ),

                    const SizedBox(height: 16),

                    if ((_requestFailed || widget.notice != null) &&
                        widget.onCheckStatus != null) ...[
                      PickupButton(
                        text: 'Check My parking',
                        background: AppColors.white,
                        foreground: AppColors.primary,
                        onPressed: isStartingParking
                            ? null
                            : widget.onCheckStatus,
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Text(
                      'You can change this time whenever you need.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            NavBar(currentIndex: 1, onTap: widget.onNavTap),
          ],
        ),
      ),
    );
  }
}
