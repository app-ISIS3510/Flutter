import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/analytics_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/favorite_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/parking_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/session_controller.dart';
import '../models/parking.dart';
import '../models/parking_session.dart';
import '../models/vehicle.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/dashboard_repository.dart';
import '../repositories/favorite_repository.dart';
import '../repositories/parking_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/user_repository.dart';
import '../services/analytics_service.dart';
import '../services/dashboard_service.dart';
import '../services/distance_manager.dart';
import '../services/favorite_service.dart';
import '../services/navigation_service.dart';
import '../services/parking_service.dart';
import '../services/profile_service.dart';
import '../services/session_service.dart';
import '../state/session_state.dart';
import 'analytics_dashboard.dart';
import 'change_pickup_time.dart';
import 'favorites.dart';
import 'home.dart';
import 'my_parking.dart';
import 'no_active_parking.dart';
import 'no_favorites.dart';
import 'parking_detail.dart';
import 'parking_list.dart';
import 'pickup_time.dart';
import 'profile/profile_screen.dart';
import 'profile/vehicles_screen.dart';
import 'search.dart';
import 'search_results.dart';

class MainNavigationScreen extends StatefulWidget {
  final VoidCallback? onSignedOut;

  const MainNavigationScreen({
    super.key,
    this.onSignedOut,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late final ParkingRepository parkingRepository;
  late final ParkingService parkingService;
  late final ParkingController parkingController;

  late final SessionRepository sessionRepository;
  late final SessionService sessionService;
  late final SessionState sessionState;
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

  late final ProfileController profileController;
  StreamSubscription<AuthState>? _authSubscription;
  String? _userId;

  int currentIndex = 0;
  bool showingMyParking = false;
  bool isLoadingSession = false;

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
    parkingController = ParkingController(parkingService);

    sessionRepository = SessionRepository(supabase);
    sessionService = SessionService(sessionRepository);
    sessionState = SessionState();
    sessionController = SessionController(
      sessionService,
      sessionState,
    );

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

    profileController = ProfileController(
      ProfileService(
        SupabaseUserRepository(supabase),
      ),
    );
  

    _userId = supabase.auth.currentUser?.id;

    _authSubscription = supabase.auth.onAuthStateChange.listen((state) {
      final nextUser = state.session?.user.id;

      if (!mounted) return;

      if (nextUser == _userId) {
        if (state.event == AuthChangeEvent.userUpdated &&
            !profileController.busy) {
          profileController.load();
        }
        return;
      }

      _userId = nextUser;
      profileController.clear();
      sessionState.clearSession();
      _returnToMain();

      setState(() {
        showingMyParking = false;
        if (nextUser == null) {
          currentIndex = 0;
        }
      });

      if (nextUser == null) {
        widget.onSignedOut?.call();
      } else {
        profileController.load();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    profileController.dispose();
    sessionState.dispose();
    super.dispose();
  }

  void _returnToMain() {
    final mainRoute = ModalRoute.of(context);

    if (mainRoute != null) {
      Navigator.of(context).popUntil(
        (route) => route == mainRoute,
      );
    }
  }

  void _profileNavTap(int index) {
    _returnToMain();
    changePage(index);
  }

  Future<Vehicle?> _chooseVehicle() {
    return Navigator.push<Vehicle>(
      context,
      MaterialPageRoute(
        builder: (_) => VehiclesScreen(
          controller: profileController,
          onNavTap: _profileNavTap,
          choosingVehicle: true,
        ),
      ),
    );
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

  void changePage(int index) {
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

    unawaited(
      analyticsController
          .track(
            eventType: 'parking_detail_viewed',
            screen: 'parking_detail',
            parkingId: parkingId,
          )
          .catchError((Object _) {}),
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
                        content: Text(
                          ProfileController.messageFor(error),
                        ),
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

  Future<void> openPickupTime(Map<String, String> parking) async {
    await profileController.load();

    if (!mounted) return;

    if (profileController.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(profileController.error!),
        ),
      );
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

            if (parkingId == null) {
              throw Exception('Parking ID is missing');
            }

            final pickup = _buildPickupDateTime(time);

            await sessionController.startParking(
              parkingId: parkingId,
              pickupTime: pickup,
              vehicleId: chosenVehicle.id,
            );

            unawaited(
              analyticsController
                  .track(
                    eventType: 'parking_started',
                    screen: 'pickup_time',
                    parkingId: parkingId,
                    metadata: {
                      'pickup_time': pickup.toIso8601String(),
                    },
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

    final parking = await parkingController.loadParkingById(
      session.parkingId,
    );

    if (parking == null || !mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ChangePickupTimeScreen(
          onNavTap: _profileNavTap,
          initialTime: _formatTimeForPicker(session.pickupTime),
          openingTime: parking.openingTime ?? '00:00:00',
          closingTime: parking.closingTime ?? '23:59:00',
          onSave: (time) async {
            final newPickupTime = _buildPickupDateTime(time);

            await sessionController.changePickupTime(
              sessionId: session.id,
              pickupTime: newPickupTime,
            );

            unawaited(
              analyticsController
                  .track(
                    eventType: 'pickup_time_changed',
                    screen: 'change_pickup_time',
                    parkingId: session.parkingId,
                    metadata: {
                      'new_pickup_time': newPickupTime.toIso8601String(),
                    },
                  )
                  .catchError((Object _) {}),
            );
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

    unawaited(
      analyticsController
          .track(
            eventType: 'parking_ended',
            screen: 'end_parking',
            parkingId: session.parkingId,
          )
          .catchError((Object _) {}),
    );
  }

  void openMyParking() async {
    setState(() {
      isLoadingSession = true;
      currentIndex = 3;
      showingMyParking = true;
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
  }

  Widget _buildMyParking(ParkingSession session) {
    return FutureBuilder<Parking?>(
      future: parkingController.loadParkingById(
        session.parkingId,
      ),
      builder: (context, parkingSnapshot) {
        if (parkingSnapshot.connectionState == ConnectionState.waiting) {
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
                'Error loading parking:\n${parkingSnapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final parking = parkingSnapshot.data;

        if (parking == null) {
          return const Scaffold(
            body: Center(
              child: Text('Parking lot not found.'),
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
                await favoriteController.removeFavorite(parking.id);

                unawaited(
                  analyticsController
                      .track(
                        eventType: 'favorite_removed',
                        screen: 'favorites',
                        parkingId: parking.id,
                      )
                      .catchError((Object _) {}),
                );

                if (!mounted) return;
                setState(() {});
              },
            );
          },
        );

      case 3:
      if (!showingMyParking) {
        return ProfileScreen(
          controller: profileController,
          onNavTap: _profileNavTap,
          onMyParking: openMyParking,
          onAnalyticsDashboard:
              openAnalyticsDashboard,
          onSignedOut: () {
            changePage(0);
          },
        );
      }

      if (isLoadingSession) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      return ListenableBuilder(
        listenable: sessionState,
        builder: (context, child) {
          final session =
              sessionState.activeSession;

          if (session == null) {
            return NoActiveParkingScreen(
              currentIndex: currentIndex,
              onNavTap: changePage,
            );
          }

          return _buildMyParking(session);
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
