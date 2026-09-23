import 'package:flutter/material.dart';

import '../controllers/parking_controller.dart';
import '../models/parking.dart';
import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/parking_card.dart';

class SearchResultsScreen extends StatefulWidget {
  final String initialQuery;
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final ValueChanged<Map<String, String>>? onSelectParking;
  final ParkingController parkingController;

  const SearchResultsScreen({
    super.key,
    required this.initialQuery,
    required this.currentIndex,
    required this.onNavTap,
    required this.parkingController,
    this.onSelectParking,
  });

  @override
  State<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState
    extends State<SearchResultsScreen> {
  late TextEditingController _searchController;

  final FocusNode _searchFocusNode = FocusNode();

  late Future<List<Parking>> _resultsFuture;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController(
      text: widget.initialQuery,
    );

    _resultsFuture = widget.parkingController
        .searchParkingLots(widget.initialQuery);
  }

  Map<String, String> _parkingToMap(Parking parking) {
    return {
      'id': parking.id,
      'name': parking.name,
      'address': parking.address,
      'latitude': parking.latitude?.toString() ?? '',
      'longitude': parking.longitude?.toString() ?? '',
      'carSpaces': parking.carSpaces.toString(),
      'motorcycleSpaces': parking.motorcycleSpaces.toString(),
      'pricePerMinute': parking.pricePerMinute.toString(),
      'openingTime': parking.openingTime ?? '',
      'closingTime': parking.closingTime ?? '',
    };
  }

  String _parkingType(Parking parking) {
    if (parking.carSpaces > 0 &&
        parking.motorcycleSpaces > 0) {
      return 'Cars and motorcycles';
    }

    if (parking.carSpaces > 0) {
      return 'Cars';
    }

    if (parking.motorcycleSpaces > 0) {
      return 'Motorcycles';
    }

    return 'Parking lot';
  }

  void _search(String query) {
    final trimmedQuery = query.trim();

    setState(() {
      if (trimmedQuery.isEmpty) {
        _resultsFuture =
            Future<List<Parking>>.value([]);
      } else {
        _resultsFuture = widget.parkingController
            .searchParkingLots(trimmedQuery);
      }
    });
  }

  void _onSearchChanged(String value) {
    _search(value);
  }

  void _clearSearch() {
    Navigator.pop(context);
  }

  void _editSearch() {
    _searchFocusNode.requestFocus();

    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
  }

  void _showAllParkingLots() {
    Navigator.popUntil(
      context,
      (route) => route.isFirst,
    );

    widget.onNavTap(1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();

    super.dispose();
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
                padding: const EdgeInsets.fromLTRB(
                  30,
                  20,
                  30,
                  24,
                ),
                child: FutureBuilder<List<Parking>>(
                  future: _resultsFuture,
                  builder: (context, snapshot) {
                    final isLoading =
                        snapshot.connectionState ==
                            ConnectionState.waiting;

                    final parkingLots =
                        snapshot.data ?? [];

                    final hasResults =
                        parkingLots.isNotEmpty;

                    return Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              borderRadius:
                                  BorderRadius.circular(14),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius:
                                      BorderRadius.circular(
                                    14,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),

                            const SizedBox(width: 14),

                            Expanded(
                              child: Text(
                                hasResults
                                    ? 'Search results'
                                    : 'No search results',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight:
                                      FontWeight.w700,
                                  color:
                                      AppColors.darkText,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        const Text(
                          'Search by name',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w600,
                            color: AppColors.darkText,
                          ),
                        ),

                        const SizedBox(height: 9),

                        TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          textInputAction:
                              TextInputAction.search,
                          onChanged: _onSearchChanged,
                          onSubmitted: _search,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.white,
                            contentPadding:
                                const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 18,
                            ),
                            enabledBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                              borderSide:
                                  const BorderSide(
                                color:
                                    Color(0xFFE0DCEA),
                              ),
                            ),
                            focusedBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                              borderSide:
                                  const BorderSide(
                                color:
                                    AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        if (isLoading)
                          const Padding(
                            padding:
                                EdgeInsets.symmetric(
                              vertical: 40,
                            ),
                            child: Center(
                              child:
                                  CircularProgressIndicator(),
                            ),
                          )
                        else if (snapshot.hasError)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 30,
                            ),
                            child: Center(
                              child: Text(
                                'Error searching parking lots:\n${snapshot.error}',
                                textAlign:
                                    TextAlign                                    .center,
                              ),
                            ),
                          )
                        else if (hasResults) ...[
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _clearSearch,
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.white,
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Clear search',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          const Text(
                            'MATCHING PARKING LOTS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.greyText,
                            ),
                          ),

                          const SizedBox(height: 12),

                          ...parkingLots.map(
                            (parking) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 12,
                                ),
                                child: ParkingCard(
                                  name: parking.name,
                                  address: parking.address,
                                  type: _parkingType(parking),
                                  onTap: widget.onSelectParking == null
                                      ? null
                                      : () {
                                          widget.onSelectParking!(
                                            _parkingToMap(parking),
                                          );
                                        },
                                ),
                              );
                            },
                          ),
                        ] else ...[
                          const SizedBox(height: 4),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(
                              20,
                              22,
                              20,
                              20,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.lightPurple,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No parking lots found',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkText,
                                  ),
                                ),
                                SizedBox(height: 18),
                                Text(
                                  'Try another name or browse all parking lots near campus.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.4,
                                    color: AppColors.greyText,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _editSearch,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 17,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Edit search',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _showAllParkingLots,
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.white,
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 17,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Show all parking lots',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),

            NavBar(
              currentIndex: widget.currentIndex,
              onTap: widget.onNavTap,
            ),
          ],
        ),
      ),
    );
  }
}