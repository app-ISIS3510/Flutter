import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';
import '../controllers/parking_controller.dart';
import '../models/parking_option.dart';
import '../models/vehicle.dart';

class SearchScreen extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final ValueChanged<String> onSearch;
  final ParkingController parkingController;
  final Vehicle? selectedVehicle;

  const SearchScreen({
    super.key,
    required this.currentIndex,
    required this.onNavTap,
    required this.onSearch,
    required this.parkingController,
    this.selectedVehicle,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late Future<List<ParkingOption>> _optionsFuture;

  @override
  void initState() {
    super.initState();
    _optionsFuture = _loadOptions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  Future<List<ParkingOption>> _loadOptions() {
    return widget.parkingController.loadParkingOptions(
      vehicleType: widget.selectedVehicle?.type,
    );
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedVehicle?.type != widget.selectedVehicle?.type ||
        oldWidget.parkingController != widget.parkingController) {
      _optionsFuture = _loadOptions();
    }
  }

  String _locationMessage(Object? error) {
    if (error is TimeoutException) {
      return 'Could not get your location. Check your GPS and reopen search.';
    }
    final message = error.toString();
    if (message.startsWith('Exception: Location ')) {
      return message.replaceFirst('Exception: ', '');
    }
    return 'Could not load nearby parking lots. Check your location settings and connection.';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();
    widget.onSearch(query);
  }

  void _selectSuggestion(String parkingName) {
    _searchController.text = parkingName;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: parkingName.length),
    );

    FocusScope.of(context).unfocus();
    widget.onSearch(parkingName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'Search',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Search by name',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 9),
                    TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _performSearch(),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.white,
                        hintText: 'Enter parking lot name',
                        hintStyle: const TextStyle(color: AppColors.greyText),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0DCEA),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'NEAREST PARKING LOTS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.selectedVehicle == null
                          ? 'Select a vehicle in Profile to see its availability.'
                          : 'Availability for your ${widget.selectedVehicle!.type.label.toLowerCase()} · ${widget.selectedVehicle!.plate}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<ParkingOption>>(
                      future: _optionsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Text(
                            _locationMessage(snapshot.error),
                            style: const TextStyle(color: AppColors.greyText),
                          );
                        }

                        final suggestedParkingLots = snapshot.data ?? [];

                        if (suggestedParkingLots.isEmpty) {
                          return const Text(
                            'No nearby parking lots are available to display.',
                            style: TextStyle(color: AppColors.greyText),
                          );
                        }

                        return Column(
                          children: suggestedParkingLots.take(4).map((option) {
                            final parking = option.parking;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                onTap: () {
                                  _selectSuggestion(parking.name);
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        parking.name,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      if (option.availableSpaces != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          '${option.availableSpaces} estimated spaces · ${(option.availabilityRatio! * 100).round()}% of capacity',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.greyText,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            NavBar(currentIndex: widget.currentIndex, onTap: widget.onNavTap),
          ],
        ),
      ),
    );
  }
}
