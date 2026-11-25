import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/connection_controller.dart';
import '../controllers/parking_comparison_controller.dart';
import '../models/compared_parking.dart';
import '../models/parking.dart';
import '../models/parking_availability.dart';
import '../models/vehicle.dart';
import '../theme/app_theme.dart';
import '../widgets/offline_data_status_indicator.dart';
import '../widgets/user_error_notice.dart';

class ParkingComparisonScreen extends StatefulWidget {
  final ParkingComparisonController controller;
  final ConnectionController connection;
  final Future<Parking?> Function(String id) loadParking;
  final ValueChanged<Parking> onOpenDetails;

  const ParkingComparisonScreen({
    super.key,
    required this.controller,
    required this.connection,
    required this.loadParking,
    required this.onOpenDetails,
  });

  @override
  State<ParkingComparisonScreen> createState() =>
      _ParkingComparisonScreenState();
}

class _ParkingComparisonScreenState extends State<ParkingComparisonScreen> {
  final _scroll = ScrollController();
  bool? _hasNetwork;
  bool _refreshing = false;
  bool _refreshFailed = false;
  bool _refreshAfterCurrent = false;
  int _connectionVersion = 0;

  @override
  void initState() {
    super.initState();
    _hasNetwork = widget.connection.hasNetwork;
    widget.connection.addListener(_onConnectionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh(force: false));
    });
  }

  void _onConnectionChanged() {
    final hasNetwork = widget.connection.hasNetwork;
    if (hasNetwork == _hasNetwork) return;
    final reconnected = _hasNetwork == false && hasNetwork == true;
    setState(() {
      _hasNetwork = hasNetwork;
      if (hasNetwork == false) {
        _connectionVersion++;
        _refreshAfterCurrent = false;
      }
    });
    if (reconnected) unawaited(_refresh());
  }

  Future<void> _refresh({bool force = true}) async {
    if (_hasNetwork == false || widget.controller.count == 0) return;
    if (_refreshing) {
      _refreshAfterCurrent = true;
      return;
    }

    final version = _connectionVersion;
    setState(() {
      _refreshing = true;
      _refreshFailed = false;
    });
    try {
      final refreshed = await widget.controller.refresh(
        loadParking: widget.loadParking,
        shouldContinue: () => mounted && version == _connectionVersion,
        force: force,
      );
      if (mounted && version == _connectionVersion) _refreshFailed = !refreshed;
    } catch (_) {
      if (mounted && version == _connectionVersion) _refreshFailed = true;
    } finally {
      if (mounted) {
        final refreshAgain = _refreshAfterCurrent;
        _refreshAfterCurrent = false;
        setState(() => _refreshing = false);
        if (refreshAgain) unawaited(_refresh());
      }
    }
  }

  @override
  void dispose() {
    widget.connection.removeListener(_onConnectionChanged);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.darkText,
        title: const Text('Compare Parking Lots'),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final selection = widget.controller.selection;
            if (selection.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Add parking lots from the list or search results.',
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${selection.length} of ${ParkingComparisonController.maxSelection} selected',
                        style: const TextStyle(
                          color: AppColors.darkText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh comparison',
                      onPressed: _hasNetwork == false || _refreshing
                          ? null
                          : _refresh,
                      color: AppColors.primary,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!widget.controller.canCompare)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Add one more parking lot to compare.'),
                  ),
                if (_hasNetwork == false || _refreshFailed) ...[
                  OfflineDataStatusIndicator(
                    isFromCache: true,
                    title: _hasNetwork == false
                        ? 'Offline'
                        : 'Could not refresh comparison',
                    description: 'Showing the last available parking data. Availability may have changed.',
                  ),
                  const SizedBox(height: 12),
                ],
                if (_refreshing && _hasNetwork != false) ...[
                  const LinearProgressIndicator(
                    semanticsLabel: 'Refreshing comparison',
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.controller.storageError case final message?) ...[
                  UserErrorNotice(message),
                  const SizedBox(height: 12),
                ],
                _comparisonTable(selection),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _comparisonTable(List<ComparedParking> selection) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const labelWidth = 88.0;
        final columnWidth =
            ((constraints.maxWidth - labelWidth) / selection.length)
                .clamp(100.0, 240.0)
                .toDouble();
        final tableWidth = labelWidth + selection.length * columnWidth;

        return Scrollbar(
          controller: _scroll,
          thumbVisibility: tableWidth > constraints.maxWidth,
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: tableWidth,
                  child: Table(
                    columnWidths: const {0: FixedColumnWidth(labelWidth)},
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    border: const TableBorder(
                      horizontalInside: BorderSide(
                        color: AppColors.lightPurple,
                      ),
                      verticalInside: BorderSide(color: AppColors.lightPurple),
                    ),
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(
                          color: AppColors.lightPurple,
                        ),
                        children: [
                          _cell('Parking lot', label: true),
                          for (final item in selection)
                            _parkingHeader(item.parking),
                        ],
                      ),
                      _metricRow('Price per minute', selection, _price),
                      _metricRow('Hours', selection, _hours),
                      _metricRow(
                        'Car spaces',
                        selection,
                        (parking) => _spaces(parking, VehicleType.car),
                      ),
                      _metricRow(
                        'Motorcycle spaces',
                        selection,
                        (parking) => _spaces(parking, VehicleType.motorcycle),
                      ),
                      TableRow(
                        decoration: const BoxDecoration(color: Colors.white),
                        children: [
                          _cell('Data status', label: true),
                          for (final item in selection)
                            _cell(_dataStatus(item)),
                        ],
                      ),
                      TableRow(
                        decoration: const BoxDecoration(color: Colors.white),
                        children: [
                          const SizedBox.shrink(),
                          for (final item in selection)
                            Tooltip(
                              message: 'Open details for ${item.parking.name}',
                              child: TextButton(
                                onPressed: item.isUnavailable
                                    ? null
                                    : () => widget.onOpenDetails(item.parking),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                ),
                                child: const Text('Details'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _parkingHeader(Parking parking) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cell(parking.name, label: true),
        IconButton(
          onPressed: () => widget.controller.remove(parking.id),
          tooltip: 'Remove ${parking.name} from comparison',
          color: AppColors.primary,
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    );
  }

  TableRow _metricRow(
    String label,
    List<ComparedParking> selection,
    String Function(Parking) value,
  ) => TableRow(
    decoration: const BoxDecoration(color: Colors.white),
    children: [
      _cell(label, label: true),
      for (final item in selection)
        _cell(item.isUnavailable ? 'Unavailable' : value(item.parking)),
    ],
  );

  Widget _cell(String text, {bool label = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    child: Text(
      text,
      style: TextStyle(
        color: AppColors.darkText,
        fontSize: label ? 13 : 14,
        fontWeight: label ? FontWeight.w700 : FontWeight.w500,
      ),
    ),
  );

  String _price(Parking parking) {
    final amount = parking.pricePerMinute;
    if (!amount.isFinite || amount < 0) return 'Unavailable';
    final decimals = amount == amount.roundToDouble() ? 0 : 2;
    return 'COP ${amount.toStringAsFixed(decimals)}';
  }

  String _hours(Parking parking) {
    final opening = parking.openingTime;
    final closing = parking.closingTime;
    if (opening == null ||
        opening.length < 5 ||
        closing == null ||
        closing.length < 5) {
      return 'Unavailable';
    }
    return '${opening.substring(0, 5)}–${closing.substring(0, 5)}';
  }

  String _spaces(Parking parking, VehicleType type) {
    final availability = ParkingAvailability(parking: parking);
    final capacity = availability.capacityFor(type);
    return capacity == 0
        ? 'Not offered'
        : '${availability.availableFor(type)} of $capacity (est.)';
  }

  String _dataStatus(ComparedParking item) {
    if (item.isUnavailable) return 'Unavailable';
    final saved = _hasNetwork == false || item.isFromCache;
    final status = saved ? 'Last available' : 'Available';
    final updatedAt = item.updatedAt?.toLocal();
    if (updatedAt == null) return status;
    final localizations = MaterialLocalizations.of(context);
    return '$status\n${localizations.formatShortDate(updatedAt)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(updatedAt))}';
  }
}
