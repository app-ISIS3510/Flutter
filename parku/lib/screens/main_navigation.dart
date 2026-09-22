import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/parking_controller.dart';
import '../repositories/parking_repository.dart';
import '../services/parking_service.dart';
import '../controllers/session_controller.dart';
import '../repositories/session_repository.dart';
import '../services/session_service.dart';
import '../controllers/favorite_controller.dart';
import '../repositories/favorite_repository.dart';
import '../services/favorite_service.dart';
import '../controllers/navigation_controller.dart';
import '../services/navigation_service.dart';
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
import '../models/parking.dart';
import '../models/parking_session.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late final ParkingRepository parkingRepository;
  late final ParkingService parkingService;
  late final ParkingController parkingController;
  late final SessionRepository sessionRepository;
  late final SessionService sessionService;
  late final SessionController sessionController;
  late final FavoriteRepository favoriteRepository;
  late final FavoriteService favoriteService;
  late final FavoriteController favoriteController;
  late final NavigationService navigationService;
  late final NavigationController navigationController;

  int currentIndex = 0;

  bool hasActiveParking = true;

  String pickupTime = '4:00';

  String parkingName = 'City U Parking';

  String parkingAddress = 'Calle 20 · Las Aguas, Bogotá';

  DateTime _buildPickupDateTime(String time) {
    final parts = time.split(':');

    int hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    // La pantalla actualmente trabaja con horas PM.
    if (hour < 12) {
      hour += 12;
    }

    final now = DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
  }

  @override
  void initState() {
    super.initState();

    final supabase = Supabase.instance.client;

    parkingRepository = ParkingRepository(supabase);
    parkingService = ParkingService(parkingRepository);
    parkingController = ParkingController(parkingService);
    sessionRepository = SessionRepository(supabase);
    sessionService = SessionService(sessionRepository);
    sessionController = SessionController(sessionService);
    favoriteRepository = FavoriteRepository(supabase);
    favoriteService = FavoriteService(favoriteRepository);
    favoriteController = FavoriteController(favoriteService);
    navigationService = NavigationService.create();
    navigationController = NavigationController(navigationService);
  }

  String _formatTimeForPicker(DateTime dateTime) {
    final localTime = dateTime.toLocal();

    int hour = localTime.hour;

    if (hour >= 12) {
      hour -= 12;
    }

    if (hour == 0) {
      hour = 12;
    }

    final minute =
        localTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  void changePage(int index) {
    setState(() {
      currentIndex = index;
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

  void openParkingDetail(Map<String, String> parking) async {
    final parkingId = parking['id'];

    if (parkingId == null || parkingId.isEmpty) {
      return;
    }

    bool isFavorite =
        await favoriteController.isFavorite(parkingId);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) {
          return StatefulBuilder(
            builder: (context, refreshDetail) {
              return ParkingDetailScreen(
                parking: parking,
                currentIndex: 1,
                isFavorite: isFavorite,
                navigationController: navigationController,

                onToggleFavorite: () async {
                  await favoriteController.toggleFavorite(
                    parkingId,
                  );

                  isFavorite =
                      await favoriteController.isFavorite(
                    parkingId,
                  );

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

          onStartParking: (time) async {
            final parkingId = parking['id'];

            if (parkingId == null || parkingId.isEmpty) {
              throw Exception('Parking ID is missing');
            }
            
            final alreadyHasActiveSession = await sessionController.hasActiveSession();

            if (alreadyHasActiveSession) {
              throw Exception(
                'You already have an active parking session.',
              );
            }

            final pickupDateTime = _buildPickupDateTime(time);

            final session = await sessionController.startParking(
              parkingId: parkingId,
              pickupTime: pickupDateTime,
            );

            if (!mounted) return;

            Navigator.pop(context);

            setState(() {
              pickupTime = time;

              parkingName =
                  parking['name'] ?? 'Parking lot';

              parkingAddress =
                  parking['address'] ?? 'Address unavailable';

              hasActiveParking = true;

              currentIndex = 3;
            });

            debugPrint(
              'Parking session created: ${session.id}',
            );
          },
        ),
      ),
    );
  }
  
  void openChangePickupTime() async {
    final session =
        await sessionController.loadActiveSession();

    if (session == null) {
      return;
    }

    if (!mounted) return;

    final currentTime =
        _formatTimeForPicker(session.pickupTime);

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ChangePickupTimeScreen(
          initialTime: currentTime,
          onNavTap: changePageFromPickup,
          onSave: (time) async {
            final newPickupTime =
                _buildPickupDateTime(time);

            await sessionController.changePickupTime(
              sessionId: session.id,
              pickupTime: newPickupTime,
            );

            if (!mounted) return;

            setState(() {
              pickupTime = time;
            });
          },
        ),
      ),
    );
  }
  
  Future<void> endParking() async {
    final session = await sessionController.loadActiveSession();

    if (session == null) {
      return;
    }

    await sessionController.endParking(
      sessionId: session.id,
    );

    if (!mounted) return;

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
          controller: parkingController,
          onSelectParking: openParkingDetail,
          onSearchTap: openSearch,
        );

      case 2:
        return FutureBuilder<List<Parking>>(
          future: favoriteController.loadFavorites(),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Text(
                    'Error loading favorites:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final favorites = snapshot.data ?? [];

            if (favorites.isEmpty) {
              return NoFavoritesScreen(
                onNavTap: changePage,
              );
            }

            return FavoritesScreen(
              favorites: favorites,
              onNavTap: changePage,
              onSelectParking: openParkingDetail,

              onRemove: (parking) async {
                await favoriteController.removeFavorite(
                  parking.id,
                );

                if (!mounted) return;

                setState(() {});
              },
            );
          },
        );

      case 3:
        return FutureBuilder<ParkingSession?>(
          future: sessionController.loadActiveSession(),
          builder: (context, sessionSnapshot) {
            if (sessionSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (sessionSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Text(
                    'Error loading parking session:\n'
                    '${sessionSnapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final session = sessionSnapshot.data;

            if (session == null) {
              return NoActiveParkingScreen(
                currentIndex: currentIndex,
                onNavTap: changePage,
              );
            }

            return FutureBuilder<Parking?>(
              future: parkingController.loadParkingById(
                session.parkingId,
              ),
              builder: (context, parkingSnapshot) {
                if (parkingSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (parkingSnapshot.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Text(
                        'Error loading parking:\n'
                        '${parkingSnapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final parking = parkingSnapshot.data;

                if (parking == null) {
                  return const Scaffold(
                    body: Center(
                      child: Text(
                        'Parking lot not found.',
                      ),
                    ),
                  );
                }

                return MyParkingScreen(
                  currentIndex: currentIndex,
                  onNavTap: changePage,
                  session: session,
                  parking: parking,
                  navigationController: navigationController,
                  onEndParking: endParking,
                  onChangePickupTime: openChangePickupTime,
                );
              },
            );
          },
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
