import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/pickup_widgets.dart';

class ChangePickupTimeScreen extends StatefulWidget {
  final String initialTime;
  final ValueChanged<int> onNavTap;
  final Future<void> Function(String) onSave;

  const ChangePickupTimeScreen({
    super.key,
    this.initialTime = '4:00',
    required this.onNavTap,
    required this.onSave,
  });

  @override
  State<ChangePickupTimeScreen> createState() => _ChangePickupTimeScreenState();
}

class _ChangePickupTimeScreenState extends State<ChangePickupTimeScreen> {
  late String selectedTime;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    selectedTime = widget.initialTime;
  }

  Future<void> _savePickupTime() async {
    if (isSaving) return;

    setState(() {
      isSaving = true;
    });

    try {
      await widget.onSave(selectedTime);

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
                      title: 'Change pickup time',
                      onBack: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 36),
                    const Text(
                      'Need more time?',
                      style: TextStyle(
                        fontSize: 25,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Update the time you plan to return to your vehicle.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.lightPurple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NEW PICKUP TIME',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$selectedTime PM',
                            style: const TextStyle(
                              fontSize: 36,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SuggestedTimes(
                      selectedTime: selectedTime,
                      onChanged: (time) => setState(() => selectedTime = time),
                    ),
                    const SizedBox(height: 16),
                    PickupButton(
                      text: isSaving
                          ? 'Saving...'
                          : 'Save pickup time',
                      onPressed: isSaving
                          ? () {}
                          : _savePickupTime,
                    ),
                      
                    const SizedBox(height: 16),
                    PickupButton(
                      text: 'Back to my parking',
                      background: AppColors.white,
                      foreground: AppColors.primary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
            NavBar(currentIndex: 3, onTap: widget.onNavTap),
          ],
        ),
      ),
    );
  }
}
