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
  late final AnalyticsRepository analyticsRepository;
  late final AnalyticsService analyticsService;
  late final AnalyticsController analyticsController;
  late final DashboardRepository dashboardRepository;
  late final DashboardService dashboardService;
  late final DashboardController dashboardController;
  late final DistanceManager distanceManager;

  int currentIndex = 0;

  DateTime _buildPickupDateTime(String time) {
    final parts = time.split(':');

    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

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
    distanceManager = DistanceManager();
    parkingService = ParkingService(
        parkingRepository,
        distanceManager,
      );

parkingController =
    ParkingController(parkingService);
    sessionRepository = SessionRepository(supabase);
    sessionService = SessionService(sessionRepository);
    sessionController = SessionController(sessionService);
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
            dashboardController:
                dashboardController,
          );
        },
      ),
    );
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

    await analyticsController.track(
      eventType: 'parking_detail_viewed',
      screen: 'parking_detail',
      parkingId: parkingId,
    );

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
                analyticsController: analyticsController,

                onToggleFavorite: () async {
                  final wasFavorite = isFavorite;

                  await favoriteController.toggleFavorite(
                    parkingId,
                  );

                  isFavorite = await favoriteController.isFavorite(
                    parkingId,
                  );

                  await analyticsController.track(
                    eventType: wasFavorite
                        ? 'favorite_removed'
                        : 'favorite_added',
                    screen: 'parking_detail',
                    parkingId: parkingId,
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

          openingTime:
              parking['openingTime'] ?? '00:00:00',

          closingTime:
              parking['closingTime'] ?? '23:59:00',

          onStartParking: (time) async {
          final parkingId = parking['id'];

          if (parkingId == null || parkingId.isEmpty) {
            throw Exception('Parking ID is missing');
          }

          final alreadyHasActiveSession =
              await sessionController.hasActiveSession();

          if (alreadyHasActiveSession) {
            throw Exception(
              'You already have an active parking session.',
            );
          }

          final pickupDateTime =
              _buildPickupDateTime(time);

          try {
            final session =
                await sessionController.startParking(
              parkingId: parkingId,
              pickupTime: pickupDateTime,
            );

            await analyticsController.track(
              eventType: 'parking_started',
              screen: 'pickup_time',
              parkingId: parkingId,
              metadata: {
                'pickup_time':
                    pickupDateTime.toIso8601String(),
              },
            );

            if (!context.mounted) return;

            Navigator.popUntil(
              context,
              (route) => route.isFirst,
            );

            setState(() {
              currentIndex = 3;
            });

            debugPrint(
              'Parking session created: ${session.id}',
            );
          } catch (error) {
            if (!context.mounted) return;

            final message = error.toString();

            if (message.contains(
              'NO_AVAILABLE_SPACES',
            )) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(
                const SnackBar(
                  content: Text(
                    'This parking lot has no available spaces.',
                  ),
                ),
              );

              return;
            }

            ScaffoldMessenger.of(context)
                .showSnackBar(
              SnackBar(
                content: Text(
                  'Could not start parking: $error',
                ),
              ),
            );
          }
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

            await analyticsController.track(
              eventType: 'pickup_time_changed',
              screen: 'change_pickup_time',
              parkingId: session.parkingId,
              metadata: {
                'new_pickup_time': newPickupTime.toIso8601String(),
              },
            );

            if (!mounted) return;

          },
        ),
      ),
    );
  }
  
  Future<void> endParking() async {
    final session =
        await sessionController.loadActiveSession();

    if (session == null) return;

    await sessionController.endParking(
      sessionId: session.id,
    );

    await analyticsController.track(
      eventType: 'parking_ended',
      screen: 'end_parking',
      parkingId: session.parkingId,
    );

    if (!mounted) return;

    setState(() {});
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
          onOpenMyParking: openMyParking,
          onSelectParking: openParkingDetail,
          parkingController: parkingController,
          sessionController: sessionController,
        );
    }
  }
}
