import 'dart:async';

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
import '../controllers/analytics_controller.dart';
import '../repositories/analytics_repository.dart';
import '../services/analytics_service.dart';
import '../controllers/dashboard_controller.dart';
import '../repositories/dashboard_repository.dart';
import '../services/dashboard_service.dart';
import '../services/distance_manager.dart';
import 'analytics_dashboard.dart';
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
import '../models/vehicle.dart';
import '../controllers/profile_controller.dart';
import '../repositories/user_repository.dart';
import '../services/profile_service.dart';
import 'profile/profile_screen.dart';
import 'profile/vehicles_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final VoidCallback? onSignedOut;
  const MainNavigationScreen({super.key, this.onSignedOut});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
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
  late final AnalyticsRepository analyticsRepository;
  late final AnalyticsService analyticsService;
  late final AnalyticsController analyticsController;
  late final DashboardRepository dashboardRepository;
  late final DashboardService dashboardService;
  late final DashboardController dashboardController;
  late final DistanceManager distanceManager;
  late SessionState sessionState;

  int currentIndex = 0;

  DateTime _buildPickupDateTime(String time) {
    final parts = time.split(':');

    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  @override
  void initState() {
    super.initState();

    final supabase = Supabase.instance.client;

    parkingRepository = ParkingRepository(supabase);
    distanceManager = DistanceManager();
    parkingService = ParkingService(parkingRepository, distanceManager);

    parkingController = ParkingController(parkingService);
    sessionRepository = SessionRepository(supabase);
    sessionService = SessionService(sessionRepository);
    favoriteRepository = FavoriteRepository(supabase);
    favoriteService = FavoriteService(favoriteRepository);
    favoriteController = FavoriteController(favoriteService);
    navigationService = NavigationService.create();
    navigationController = NavigationController(navigationService);
    analyticsRepository = AnalyticsRepository(supabase);
    analyticsService = AnalyticsService(analyticsRepository);
    analyticsController = AnalyticsController(analyticsService);
    dashboardRepository = DashboardRepository(supabase);
    dashboardService = DashboardService(dashboardRepository);
    dashboardController = DashboardController(dashboardService);
  }

  void openAnalyticsDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) {
          return AnalyticsDashboardScreen(
            dashboardController: dashboardController,
          );
        },
      ),
    );
  }

  String _formatTimeForPicker(DateTime dateTime) {
    final local = dateTime.toLocal();

    final hour = local.hour.toString().padLeft(2, '0');

    final minute = local.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Future<void> changePage(int index) async {
    if (index == 3) {
      setState(() {
        isLoadingSession = true;
        currentIndex = index;
      });

      try {
        await sessionController.loadActiveSession();
      } finally {
        if (mounted) {
          setState(() {
            isLoadingSession = false;
          });
        }
      }

      return;
    }

    setState(() {
      currentIndex = index;
      showingMyParking = false;
    });
  }

  void openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SearchScreen(
          currentIndex: 1,
          parkingController: parkingController,
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
                  parkingController: parkingController,
                  onNavTap: (index) {
                    _returnToMain();

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

    await analyticsController.track(
      eventType: 'parking_detail_viewed',
      screen: 'parking_detail',
      parkingId: parkingId,
    );

    bool isFavorite = await favoriteController.isFavorite(parkingId);

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
                analyticsController: analyticsController,

                onToggleFavorite: () async {
                  try {
                    final wasFavorite = isFavorite;
                    await favoriteController.toggleFavorite(parkingId);
                    isFavorite = await favoriteController.isFavorite(parkingId);
                    if (!context.mounted) return;
                    refreshDetail(() {});
                    unawaited(
                      analyticsController
                          .track(
                            eventType: wasFavorite
                                ? 'favorite_removed'
                                : 'favorite_added',
                            screen: 'parking_detail',
                            parkingId: parkingId,
                          )
                          .catchError((Object _) {}),
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ProfileController.messageFor(error)),
                      ),
                    );
                  }
                },

                onNavTap: (index) {
                  _returnToMain();

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

  Future<void> openPickupTime(Map<String, String> parking) async {
    await profileController.load();
    if (!mounted) return;
    if (profileController.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(profileController.error!)));
      return;
    }
    var vehicle = profileController.selectedVehicle;
    vehicle ??= await _chooseVehicle();
    if (vehicle == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => PickupTimeScreen(
          onNavTap: _profileNavTap,
          vehicle: vehicle!,
          onChangeVehicle: () async {
            await _chooseVehicle();
            return profileController.selectedVehicle;
          },
          openingTime: parking['openingTime'] ?? '00:00:00',
          closingTime: parking['closingTime'] ?? '23:59:00',
          onStartParking: (time, chosenVehicle) async {
            final parkingId = parking['id'];
            if (parkingId == null) throw Exception('Parking ID is missing');
            final pickup = _buildPickupDateTime(time);
            await sessionController.startParking(
              parkingId: parkingId,
              pickupTime: pickup,
              vehicleId: chosenVehicle.id,
            );
            // El registro de estadísticas no debe impedir mostrar una sesión ya creada.
            unawaited(
              analyticsController
                  .track(
                    eventType: 'parking_started',
                    screen: 'pickup_time',
                    parkingId: parkingId,
                    metadata: {'pickup_time': pickup.toIso8601String()},
                  )
                  .catchError((Object _) {}),
            );
            if (!context.mounted) return;
            _returnToMain();
            openMyParking();
          },
        ),
      ),
    );
  }

  void openChangePickupTime() async {
    final session = await sessionController.loadActiveSession();

    if (session == null) {
      return;
    }

    final parking = await parkingController.loadParkingById(session.parkingId);

    if (parking == null) {
      return;
    }

    if (!mounted) return;

    final currentTime =
        _formatTimeForPicker(session.pickupTime);

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ChangePickupTimeScreen(
          currentTime: _formatTimeForPicker(
            session.pickupTime,
          ),
          openingTime:
              parking.openingTime ?? '00:00:00',
          closingTime:
              parking.closingTime ?? '23:59:00',
          onSave: (time) async {
            final newPickupTime = _buildPickupDateTime(time);
            await sessionController.changePickupTime(
              sessionId: session.id,
              pickupTime: newPickupTime,
            );

            await analyticsController.track(
              eventType: 'pickup_time_changed',
              screen: 'change_pickup_time',
              parkingId: session.parkingId,
              metadata: {'new_pickup_time': newPickupTime.toIso8601String()},
            );

            if (!mounted) return;

            setState((){})

          },
        ),
      ),
    );
  }

  Future<void> endParking() async {
    final session = await sessionController.loadActiveSession();

    if (session == null) return;

    await sessionController.endParking(
      sessionId: session.id,
    );

    await analyticsController.track(
      eventType: 'parking_ended',
      screen: 'end_parking',
      parkingId: session.parkingId,
    );

  }

  void openMyParking() {
    setState(() {
      currentIndex = 3;
      showingMyParking = true;
    });
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
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
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
              return NoFavoritesScreen(onNavTap: changePage);
            }

            return FavoritesScreen(
              favorites: favorites,
              onNavTap: changePage,
              onSelectParking: openParkingDetail,

              onRemove: (parking) async {
                await favoriteController.removeFavorite(parking.id);

                await analyticsController.track(
                  eventType: 'favorite_removed',
                  screen: 'favorites',
                  parkingId: parking.id,
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

        return ListenableBuilder(
          listenable: sessionState,
          builder: (context, child) {
            final session = sessionState.activeSession;

            if (session == null) {
              return NoActiveParkingScreen(
                currentIndex: currentIndex,
                onNavTap: changePage,
              );
            }

            return FutureBuilder<Parking?>(
              future: parkingController.loadParkingById(session.parkingId),
              builder: (context, parkingSnapshot) {
                if (parkingSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
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
                    body: Center(child: Text('Parking lot not found.')),
                  );
                }

                return MyParkingScreen(
                  currentIndex: currentIndex,
                  onNavTap: changePage,
                  session: session,
                  parking: parking,
                  navigationController:
                      navigationController,
                  onEndParking: endParking,
                  onChangePickupTime:
                      openChangePickupTime,
                );
              },
            );
          },
        );

      default:
        return HomeScreen(
          currentIndex: currentIndex,
          onNavTap: changePage,
          onOpenMyParking: openMyParking,
          onSelectParking: openParkingDetail,
          parkingController: parkingController,
          sessionController: sessionController,
        );
    }
  }
}
