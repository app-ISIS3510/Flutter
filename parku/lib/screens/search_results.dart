import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/parking_card.dart';

class SearchResultsScreen extends StatefulWidget {
  final String initialQuery;
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final ValueChanged<Map<String, String>>? onSelectParking;

  const SearchResultsScreen({
    super.key,
    required this.initialQuery,
    required this.currentIndex,
    required this.onNavTap,
    this.onSelectParking,
  });

  @override
  State<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late TextEditingController _searchController;

  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, String>> filteredParkingLots = [];

 
  final List<Map<String, String>> parkingLots = [
    {
      'name': 'City U Parking',
      'address': 'Calle 20 · Las Aguas, Bogotá',
      'type': 'Cars and motorcycles · Indoor',
    },
    {
      'name': 'MetroPark Center',
      'address': '45 Market St',
      'type': 'Indoor',
    },
    {
      'name': 'University Lot C',
      'address': '102 Campus Drive',
      'type': 'Outdoor',
    },
    {
      'name': 'Library Underground',
      'address': '250 Civic Center',
      'type': 'Indoor',
    },
  ];

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController(
      text: widget.initialQuery,
    );

    _filterParkingLots(widget.initialQuery);
  }



  void _filterParkingLots(String query) {
    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      filteredParkingLots = [];
      return;
    }

    filteredParkingLots = parkingLots.where((parking) {
      final name = parking['name']!.toLowerCase();

      return name.contains(normalizedQuery);
    }).toList();
  }



  void _onSearchChanged(String value) {
    setState(() {
      _filterParkingLots(value);
    });
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
    final bool hasResults = filteredParkingLots.isNotEmpty;

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

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              

                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                          },
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

                        Expanded(
                          child: Text(
                            hasResults
                                ? 'Search results'
                                : 'No search results',

                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText,
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
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                    ),

                    const SizedBox(height: 9),

               

                    TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      textInputAction: TextInputAction.search,

                      onChanged: _onSearchChanged,

                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.white,

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

                    const SizedBox(height: 12),

              

                    if (hasResults) ...[
                     

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

              

                      ...filteredParkingLots.map(
                        (parking) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: 12,
                            ),

                            child: ParkingCard(
                              name: parking['name']!,
                              address: parking['address']!,
                              type: parking['type']!,

                              onTap: widget.onSelectParking == null
                                  ? null
                                  : () {
                                      widget.onSelectParking!(
                                        parking,
                                      );
                                    },
                            ),
                          );
                        },
                      ),
                    ]

       

                    else ...[
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
                          crossAxisAlignment: CrossAxisAlignment.start,

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