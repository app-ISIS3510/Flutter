import 'package:flutter/material.dart';

import '../services/user_preferences_service.dart';
import '../state/parking_detail_state.dart';
import '../theme/app_theme.dart';
import '../widgets/offline_data_status_indicator.dart';
import '../widgets/pickup_widgets.dart';

class ParkingBudgetPlannerScreen extends StatefulWidget {
  final ParkingDetailState details;
  final String userId;

  const ParkingBudgetPlannerScreen({
    super.key,
    required this.details,
    required this.userId,
  });

  @override
  State<ParkingBudgetPlannerScreen> createState() =>
      _ParkingBudgetPlannerScreenState();
}

class _ParkingBudgetPlannerScreenState
    extends State<ParkingBudgetPlannerScreen> {
  final _preferences = UserPreferencesService();
  final _formKey = GlobalKey<FormState>();
  final _minutes = TextEditingController();
  final _budget = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  double? _estimatedCost;
  String? _notice;

  double? get _rate {
    final rate = widget.details.parking?.pricePerMinute;
    return rate != null && rate.isFinite && rate > 0 ? rate : null;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedPlan();
  }

  Future<void> _loadSavedPlan() async {
    try {
      final saved = await _preferences.getParkingBudget(widget.userId);
      if (!mounted || saved == null) return;
      _minutes.text = saved.minutes.toString();
      _budget.text = saved.budget.toString();
    } catch (_) {
      if (mounted) _notice = 'Could not load your saved plan.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _calculate(double rate) async {
    if (_saving || !_formKey.currentState!.validate()) return;

    final minutes = int.parse(_minutes.text.trim(), radix: 10);
    final budget = int.parse(_budget.text.trim(), radix: 10);
    final total = rate * minutes;
    if (!total.isFinite) {
      setState(() => _notice = 'This estimate is too large.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _estimatedCost = double.parse(total.toStringAsFixed(2));
      _notice = null;
      _saving = true;
    });

    try {
      await _preferences.saveParkingBudget(
        widget.userId,
        minutes: minutes,
        budget: budget,
      );
    } catch (_) {
      if (mounted) _notice = 'Could not save this plan on your device.';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearEstimate(String _) {
    if (_estimatedCost == null && _notice == null) return;
    setState(() {
      _estimatedCost = null;
      _notice = null;
    });
  }

  String _formatCop(double amount) {
    final text = amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2);
    final parts = text.split('.');
    final whole = int.tryParse(parts.first);
    if (whole == null) return 'COP $text';
    final formatted = MaterialLocalizations.of(context).formatDecimal(whole);
    return parts.length == 1 ? 'COP $formatted' : 'COP $formatted.${parts[1]}';
  }

  @override
  void dispose() {
    _minutes.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rate = _rate;
    final estimate = _estimatedCost;
    final budget = int.tryParse(_budget.text.trim(), radix: 10);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          children: [
            ScreenHeader(
              title: 'Parking Budget Planner',
              onBack: () => Navigator.pop(context),
            ),
            const SizedBox(height: 24),
            Text(
              widget.details.parking?.name ?? 'Parking lot',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            if (rate == null)
              const Text('No rate is available to estimate the cost.')
            else ...[
              Text('${_formatCop(rate)} per minute'),
              if (widget.details.isFromCache) ...[
                const SizedBox(height: 12),
                OfflineDataStatusIndicator(
                  isFromCache: true,
                  updatedAt: widget.details.updatedAt,
                  title: 'Saved parking rate',
                  description: 'The estimate uses the last saved rate.',
                ),
              ],
              const SizedBox(height: 20),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _minutes,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Duration (minutes)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onChanged: _clearEstimate,
                        validator: (value) {
                          final minutes = int.tryParse(
                            value?.trim() ?? '',
                            radix: 10,
                          );
                          return minutes == null || minutes <= 0
                              ? 'Enter a positive number of minutes.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _budget,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Budget (COP)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: _clearEstimate,
                        validator: (value) {
                          final budget = int.tryParse(
                            value?.trim() ?? '',
                            radix: 10,
                          );
                          return budget == null || budget < 0
                              ? 'Enter a budget in whole pesos.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      PickupButton(
                        text: 'Calculate estimate',
                        onPressed: _saving ? null : () => _calculate(rate),
                      ),
                    ],
                  ),
                ),
              if (estimate != null && budget != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.lightPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated cost: ${_formatCop(estimate)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        estimate <= budget ? 'Within budget' : 'Over budget',
                      ),
                    ],
                  ),
                ),
              ],
              if (_notice != null) ...[
                const SizedBox(height: 12),
                Text(_notice!),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
