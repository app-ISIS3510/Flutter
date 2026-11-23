import 'package:flutter/material.dart';

import '../controllers/parking_comparison_controller.dart';
import '../models/parking.dart';
import '../models/parking_availability.dart';
import '../models/vehicle.dart';
import '../theme/app_theme.dart';

class ParkingComparisonScreen extends StatefulWidget {
  final ParkingComparisonController controller;
  final ValueChanged<Parking> onOpenDetails;

  const ParkingComparisonScreen({
    super.key,
    required this.controller,
    required this.onOpenDetails,
  });

  @override
  State<ParkingComparisonScreen> createState() =>
      _ParkingComparisonScreenState();
}

class _ParkingComparisonScreenState extends State<ParkingComparisonScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
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
                Text(
                  '${selection.length} of ${ParkingComparisonController.maxSelection} selected',
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (!widget.controller.canCompare)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Add one more parking lot to compare.'),
                  ),
                _comparisonTable(selection),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _comparisonTable(List<Parking> selection) {
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
                          for (final parking in selection)
                            _parkingHeader(parking),
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
                          const SizedBox.shrink(),
                          for (final parking in selection)
                            Tooltip(
                              message: 'Open details for ${parking.name}',
                              child: TextButton(
                                onPressed: () => widget.onOpenDetails(parking),
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
    List<Parking> selection,
    String Function(Parking) value,
  ) => TableRow(
    decoration: const BoxDecoration(color: Colors.white),
    children: [
      _cell(label, label: true),
      for (final parking in selection) _cell(value(parking)),
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
}
