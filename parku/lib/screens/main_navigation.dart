import 'package:flutter/material.dart';

import 'home.dart';
import 'parking_list.dart';
import 'my_parking.dart';
import 'no_active_parking.dart';
import 'pickup_time.dart';
import 'change_pickup_time.dart';
import 'favorites.dart';
import 'no_favorites.dart';
import 'search.dart';
import 'search_results.dart';
import 'parking_detail.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int currentIndex = 0;

  bool hasActiveParking = true;

  String pickupTime = '4:00';

  String parkingName = 'City U Parking';

  String parkingAddress = 'Calle 20 · Las Aguas, Bogotá';

  final List<Map<String, String>> favorites = [
    {
      'name': 'City U Parking',
      'address': 'Calle 20 · Las Aguas, Bogotá',
    },
    {
      'name': 'MetroPark Center',
      'address': '45 Market St',
    },
    {
      'name': 'University Lot C',
      'address': '102 Campus Drive',
    },
    {
      'name': 'Library Underground',
      'address': '250 Civic Center',
    },
  ];

  void changePage(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  bool isParkingFavorite(Map<String, String> parking) {
    return favorites.any(
      (favorite) => favorite['name'] == parking['name'],
    );
  }

  void toggleFavorite(Map<String, String> parking) {
    setState(() {
      final index = favorites.indexWhere(
        (favorite) => favorite['name'] == parking['name'],
      );

      if (index >= 0) {
        favorites.removeAt(index);
      } else {
        favorites.add({
          'name': parking['name'] ?? '',
          'address': parking['address'] ?? '',
        });
      }
    });
  }

  void openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SearchScreen(
          currentIndex: 1,
          onNavTap: (index) {
            Navigator.pop(context);
            changePage(index);
          },
          onSearch: (query) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => SearchResultsScreen(
                  initialQuery: query,
                  currentIndex: 1,
                  onNavTap: (index) {
                    Navigator.popUntil(
                      context,
                      (route) => route.isFirst,
                    );

                    changePage(index);
                  },
                  onSelectParking: openParkingDetail,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void openParkingDetail(Map<String, String> parking) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) {
          return StatefulBuilder(
            builder: (context, refreshDetail) {
              return ParkingDetailScreen(
                parking: parking,
                currentIndex: 1,
                isFavorite: isParkingFavorite(parking),
                onToggleFavorite: () {
                  toggleFavorite(parking);
                  refreshDetail(() {});
                },
                onNavTap: (index) {
                  Navigator.popUntil(
                    context,
                    (route) => route.isFirst,
                  );

                  changePage(index);
                },
                onParkHere: () {
                  openPickupTime(parking);
                },
              );
            },
          );
        },
      ),
    );
  }

  void changePageFromPickup(int index) {
    Navigator.pop(context);
    changePage(index);
  }

  void openPickupTime(Map<String, String> parking) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => PickupTimeScreen(
          onNavTap: changePageFromPickup,
          onStartParking: (time) {
            Navigator.pop(context);

            setState(() {
              pickupTime = time;
              parkingName = parking['name'] ?? 'Parking lot';
              parkingAddress =
                  parking['address'] ?? 'Address unavailable';
              hasActiveParking = true;
              currentIndex = 3;
            });
          },
        ),
      ),
    );
  }

  void openChangePickupTime() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ChangePickupTimeScreen(
          initialTime: pickupTime,
          onNavTap: changePageFromPickup,
          onSave: (time) {
            Navigator.pop(context);

            setState(() {
              pickupTime = time;
            });
          },
        ),
      ),
    );
  }

  void endParking() {
    setState(() {
      hasActiveParking = false;
    });
  }

  void openMyParking() {
    changePage(3);
  }

  @override
  Widget build(BuildContext context) {
    switch (currentIndex) {
      case 1:
        return ParkingListScreen(
          currentIndex: currentIndex,
          onNavTap: changePage,
          onSelectParking: openParkingDetail,
          onSearchTap: openSearch,
        );

      case 2:
        if (favorites.isEmpty) {
          return NoFavoritesScreen(
            onNavTap: changePage,
          );
        }

        return FavoritesScreen(
          favorites: favorites,
          onNavTap: changePage,
          onSelectParking: openParkingDetail,
          onRemove: (index) {
            setState(() {
              favorites.removeAt(index);
            });
          },
        );

      case 3:
        if (hasActiveParking) {
          return MyParkingScreen(
            currentIndex: currentIndex,
            onNavTap: changePage,
            onEndParking: endParking,
            onChangePickupTime: openChangePickupTime,
            pickupTime: pickupTime,
            parkingName: parkingName,
            parkingAddress: parkingAddress,
          );
        }

        return NoActiveParkingScreen(
          currentIndex: currentIndex,
          onNavTap: changePage,
        );

      default:
        return HomeScreen(
          currentIndex: currentIndex,
          onNavTap: changePage,
          hasActiveParking: hasActiveParking,
          onOpenMyParking: openMyParking,
          onSelectParking: openParkingDetail,
        );
    }
  }
}
