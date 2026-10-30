import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/analytics_controller.dart';
import '../controllers/favorite_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/parking_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/session_controller.dart';
import '../models/parking_session.dart';
import '../models/analytics_measurements.dart';
import '../models/vehicle.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/favorite_repository.dart';
import '../repositories/parking_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/user_repository.dart';
import '../services/analytics_service.dart';
import '../services/distance_manager.dart';
import '../services/favorite_service.dart';
import '../services/favorite_sync_service.dart';
import '../services/navigation_service.dart';
import '../services/parking_service.dart';
import '../services/profile_service.dart';
import '../services/session_service.dart';
import '../services/shared_dashboard_service.dart';
import '../state/session_state.dart';
import '../state/favorite_list_state.dart';
import '../state/favorite_status_state.dart';
import '../services/connectivity_service.dart';
import '../state/parking_detail_state.dart';
import '../widgets/managed_future_builder.dart';
import '../widgets/user_error_notice.dart';
import '../utils/user_error_message.dart';
import '../utils/screen_load_reporter.dart';
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

  const MainNavigationScreen({super.key, this.onSignedOut});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
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
  late final FavoriteSyncService favoriteSyncService;

  late final NavigationService navigationService;
  late final NavigationController navigationController;

  late final AnalyticsRepository analyticsRepository;
  late final AnalyticsService analyticsService;
  late final AnalyticsController analyticsController;

  final sharedDashboardService = SharedDashboardService();

  late final DistanceManager distanceManager;

  late final ProfileController profileController;
  StreamSubscription<AuthState>? _authSubscription;
  String? _userId;

  int currentIndex = 0;
  bool showingMyParking = false;
  bool isLoadingSession = false;
  bool isOpeningSearch = false;
  String? _sessionLoadError;
  int _favoritesRequestVersion = 0;
  int _myParkingRequestVersion = 0;
  bool _isOpeningPickupChange = false;
  final Set<String> _removingFavoriteIds = {};
  ScreenLoadReporter? _myParkingLoad;
  final _connection = ConnectivityService();
  bool _isOpeningPickup = false;

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
    WidgetsBinding.instance.addObserver(this);

    final supabase = Supabase.instance.client;

    parkingRepository = ParkingRepository(supabase);
    distanceManager = DistanceManager();
    parkingService = ParkingService(parkingRepository, distanceManager);
    parkingController = ParkingController(parkingService);

    sessionRepository = SessionRepository(supabase);
    sessionService = SessionService(sessionRepository);
    sessionState = SessionState();
    sessionController = SessionController(sessionService, sessionState);

    favoriteRepository = FavoriteRepository(supabase);
    favoriteService = FavoriteService(favoriteRepository);
    favoriteController = FavoriteController(favoriteService);
    favoriteSyncService = FavoriteSyncService(favoriteRepository);
    favoriteSyncService.addListener(_onFavoriteSync);
    favoriteSyncService.start();

    navigationService = NavigationService.create();
    navigationController = NavigationController(navigationService);

    analyticsRepository = AnalyticsRepository(supabase);
    analyticsService = AnalyticsService(analyticsRepository);
    analyticsService.start();
    analyticsController = AnalyticsController(analyticsService);

    profileController = ProfileController(
      ProfileService(SupabaseUserRepository(supabase)),
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
      _myParkingLoad?.cancel();
      _favoritesRequestVersion++;
      _myParkingRequestVersion++;
      isLoadingSession = false;
      _removingFavoriteIds.clear();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(analyticsService.flushPending());
      unawaited(favoriteSyncService.flush());
    }
  }

  @override
  void dispose() {
    _myParkingLoad?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    analyticsService.dispose();
    favoriteSyncService.removeListener(_onFavoriteSync);
    favoriteSyncService.dispose();
    _authSubscription?.cancel();
    profileController.dispose();
    sessionState.dispose();
    super.dispose();
  }

  void _returnToMain() {
    final mainRoute = ModalRoute.of(context);

    if (mainRoute != null) {
      Navigator.of(context).popUntil((route) => route == mainRoute);
    }
  }

  void _onFavoriteSync() {
    if (mounted && currentIndex == 2) _refreshFavorites();
  }

  void _refreshFavorites() {
    if (!mounted) return;
    setState(() => _favoritesRequestVersion++);
  }

  Future<void> _removeFavorite(String parkingId) async {
    if (!mounted || _removingFavoriteIds.contains(parkingId)) return;
    final userId = _userId;
    setState(() => _removingFavoriteIds.add(parkingId));
    try {
      await favoriteController.removeFavorite(parkingId);
      if (!mounted || userId != _userId) return;
      unawaited(
        analyticsController
            .track(
              eventType: 'favorite_removed',
              screen: 'favorites',
              parkingId: parkingId,
            )
            .catchError((Object _) {}),
      );
      _refreshFavorites();
    } catch (_) {
      if (!mounted || userId != _userId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the favorite change. Please retry.'),
        ),
      );
    } finally {
      if (mounted && userId == _userId) {
        setState(() => _removingFavoriteIds.remove(parkingId));
      }
    }
  }

  Widget _loadFailure(String message, VoidCallback retry) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              TextButton(onPressed: retry, child: const Text('Retry')),
              TextButton(
                onPressed: () => changePage(1),
                child: const Text('Parking lots'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

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

  Future<void> openAnalyticsDashboard() async {
    if (!profileController.isAdmin) return;

    try {
      await sharedDashboardService.open();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the analytics dashboard. Please try again.',
          ),
        ),
      );
    }
  }

  String _formatTimeForPicker(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  void changePage(int index) {
    _myParkingLoad?.cancel();
    setState(() {
      if (index == 2 && currentIndex != 2) _favoritesRequestVersion++;
      currentIndex = index;
      showingMyParking = false;
    });
  }

  Future<void> openSearch() async {
    if (isOpeningSearch) return;
    isOpeningSearch = true;
    final userId = _userId;

    try {
      // Nearby parking must remain accessible when the profile cannot refresh.
      unawaited(profileController.load());
      if (!mounted || userId != _userId) return;

      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => ListenableBuilder(
            listenable: profileController,
            builder: (context, child) => SearchScreen(
              analytics: analyticsController,
              currentIndex: 1,
              parkingController: parkingController,
              selectedVehicle: profileController.selectedVehicle,
              onSelectParking: openParkingDetail,
              onNavTap: (index) {
                Navigator.pop(context);
                changePage(index);
              },
              onSearch: (query) {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => SearchResultsScreen(
                      analytics: analyticsController,
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
        ),
      );
    } finally {
      isOpeningSearch = false;
    }
  }

  Future<void> openParkingDetail(Map<String, String> parking) async {
    final parkingId = parking['id'];

    if (parkingId == null || parkingId.isEmpty) {
      return;
    }

    if (!mounted) return;

    final detailUserId = _userId;
    final detailVisit = ParkingDetailVisit(parkingId);
    final favoriteStatus = ValueNotifier<FavoriteStatusState>(
      const FavoriteStatusState(isBusy: true),
    );
    var detailIsOpen = true;
    var favoriteIsSaving = false;
    var favoriteIsLoading = false;

    Future<void> loadFavoriteStatus() async {
      if (!detailIsOpen ||
          !mounted ||
          detailUserId != _userId ||
          favoriteIsLoading) {
        return;
      }
      favoriteIsLoading = true;
      favoriteStatus.value = FavoriteStatusState(
        isFavorite: favoriteStatus.value.isFavorite,
        isBusy: true,
      );
      try {
        final value = await favoriteController
            .isFavorite(parkingId)
            .timeout(const Duration(seconds: 15));
        if (detailIsOpen && mounted && detailUserId == _userId) {
          favoriteStatus.value = FavoriteStatusState(isFavorite: value);
        }
      } catch (error, stackTrace) {
        developer.log(
          'Could not load favorite status for parking details',
          error: error,
          stackTrace: stackTrace,
        );
        if (detailIsOpen && mounted && detailUserId == _userId) {
          favoriteStatus.value = FavoriteStatusState(
            isFavorite: favoriteStatus.value.isFavorite,
            errorMessage: userErrorMessage(
              error,
              action: ErrorAction.favorites,
            ),
          );
        }
      } finally {
        favoriteIsLoading = false;
      }
    }

    unawaited(loadFavoriteStatus());

    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (context) {
            return ValueListenableBuilder<FavoriteStatusState>(
              valueListenable: favoriteStatus,
              builder: (context, favoriteState, child) {
                return ParkingDetailScreen(
                  parking: parking,
                  parkingController: parkingController,
                  currentIndex: 1,
                  isFavorite: favoriteState.isFavorite ?? false,
                  isFavoriteBusy: favoriteState.isBusy,
                  favoriteErrorMessage: favoriteState.errorMessage,
                  navigationController: navigationController,
                  analyticsController: analyticsController,
                  visit: detailVisit,
                  onToggleFavorite: favoriteState.isFavorite == null
                      ? () {
                          showUserMessage(
                            context,
                            favoriteState.errorMessage ??
                                'Checking favorites. Please wait.',
                          );
                          if (!favoriteState.isBusy) {
                            unawaited(loadFavoriteStatus());
                          }
                        }
                      : () async {
                          if (favoriteIsSaving) return;
                          favoriteIsSaving = true;
                          try {
                            favoriteStatus.value = FavoriteStatusState(
                              isFavorite: favoriteState.isFavorite,
                              isBusy: true,
                            );

                            final nextIsFavorite = await favoriteController
                                .toggleFavorite(parkingId);
                            // The preference is durable locally. Record it even
                            // if the user left the details while it was saving.
                            if (analyticsController.currentUserId ==
                                detailUserId) {
                              unawaited(
                                analyticsController
                                    .track(
                                      eventType: nextIsFavorite
                                          ? 'favorite_added'
                                          : 'favorite_removed',
                                      screen: 'parking_detail',
                                      parkingId: parkingId,
                                      metadata: detailVisit.favoriteMetadata(
                                        nextIsFavorite,
                                      ),
                                    )
                                    .catchError((Object _) {}),
                              );
                            }

                            if (!context.mounted ||
                                !detailIsOpen ||
                                detailUserId != _userId) {
                              return;
                            }
                            favoriteStatus.value = FavoriteStatusState(
                              isFavorite: nextIsFavorite,
                            );
                            _refreshFavorites();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Favorite saved. It will sync when online.',
                                ),
                              ),
                            );
                          } catch (error) {
                            if (!context.mounted ||
                                !detailIsOpen ||
                                detailUserId != _userId) {
                              return;
                            }
                            favoriteStatus.value = favoriteState;

                            showUserError(
                              context,
                              error,
                              action: ErrorAction.favorites,
                            );
                          } finally {
                            favoriteIsSaving = false;
                          }
                        },
                  onNavTap: (index) {
                    _returnToMain();
                    changePage(index);
                  },
                  onParkHere: (selectedParking) {
                    openPickupTime({
                      ...parking,
                      'id': selectedParking.id,
                      'name': selectedParking.name,
                      'address': selectedParking.address,
                      'latitude': selectedParking.latitude?.toString() ?? '',
                      'longitude': selectedParking.longitude?.toString() ?? '',
                      'carSpaces': selectedParking.availableCarSpaces
                          .toString(),
                      'motorcycleSpaces': selectedParking
                          .availableMotorcycleSpaces
                          .toString(),
                      'pricePerMinute': selectedParking.pricePerMinute
                          .toString(),
                      'openingTime': selectedParking.openingTime ?? '',
                      'closingTime': selectedParking.closingTime ?? '',
                    });
                  },
                );
              },
            );
          },
        ),
      );
    } finally {
      detailIsOpen = false;
      favoriteStatus.dispose();
    }
  }

  Future<void> openPickupTime(Map<String, String> parking) async {
    if (_isOpeningPickup) return;
    _isOpeningPickup = true;
    final userId = _userId;
    try {
      await _connection.requireConnection();
      if (!mounted || userId != analyticsController.currentUserId) return;
      await _openPickupTime(parking);
    } catch (error) {
      if (mounted) {
        showUserError(context, error, action: ErrorAction.startParking);
      }
    } finally {
      _isOpeningPickup = false;
    }
  }

  Future<void> _openPickupTime(Map<String, String> parking) async {
    final pickupUserId = analyticsController.currentUserId;
    await profileController.load();

    if (!mounted || pickupUserId != analyticsController.currentUserId) return;

    if (profileController.error != null) {
      showUserMessage(
        context,
        'Could not load your vehicle. Please try again later.',
      );
      return;
    }

    var vehicle = profileController.selectedVehicle;
    vehicle ??= await _chooseVehicle();

    if (vehicle == null ||
        !mounted ||
        pickupUserId != analyticsController.currentUserId) {
      return;
    }

    final parkingId = parking['id'];

    if (parkingId != null && parkingId.isNotEmpty) {
      unawaited(
        analyticsController
            .track(
              eventType: 'pickup_time_viewed',
              screen: 'pickup_time',
              parkingId: parkingId,
            )
            .catchError((Object _) {}),
      );
    }

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
            await _connection.requireConnection();
            if (pickupUserId != analyticsController.currentUserId) {
              throw const AuthException('The signed-in account changed.');
            }
            final parkingId = parking['id'];

            if (parkingId == null) {
              throw Exception('Parking ID is missing');
            }

            final pickup = _buildPickupDateTime(time);

            final stopwatch = Stopwatch()..start();

            final session = await sessionController.startParking(
              parkingId: parkingId,
              pickupTime: pickup,
              vehicleId: chosenVehicle.id,
            );

            stopwatch.stop();

            final durationMs = stopwatch.elapsedMilliseconds;

            unawaited(
              analyticsController
                  .track(
                    eventType: 'parking_started',
                    screen: 'pickup_time',
                    parkingId: parkingId,
                    metadata: {
                      'pickup_time': pickup.toIso8601String(),
                      'duration_ms': durationMs,
                      'platform': 'flutter',
                      'session_id': session.id,
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

  Future<void> openChangePickupTime() async {
    if (_isOpeningPickupChange || !mounted) return;
    _isOpeningPickupChange = true;
    final userId = _userId;
    try {
      await _connection.requireConnection();
      final session = await sessionController.loadActiveSession();

      if (session == null || !mounted || _userId != userId) {
        return;
      }

      final parking = await parkingController.loadParkingById(
        session.parkingId,
      );

      if (parking == null || !mounted || _userId != userId) {
        return;
      }

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (context) => ChangePickupTimeScreen(
            onNavTap: _profileNavTap,
            initialTime: _formatTimeForPicker(session.pickupTime),
            openingTime: parking.openingTime ?? '00:00:00',
            closingTime: parking.closingTime ?? '23:59:00',
            onSave: (time) async {
              await _connection.requireConnection();
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
    } catch (error) {
      if (!mounted || _userId != userId) return;
      showUserError(context, error, action: ErrorAction.updatePickup);
    } finally {
      _isOpeningPickupChange = false;
    }
  }

  Future<void> endParking() async {
    final userId = analyticsController.currentUserId;
    await _connection.requireConnection();
    if (userId != analyticsController.currentUserId) {
      throw const AuthException('The signed-in account changed.');
    }
    final session = await sessionController.loadActiveSession();

    if (session == null) return;
    if (userId != analyticsController.currentUserId) {
      throw const AuthException('The signed-in account changed.');
    }

    await sessionController.endParking(sessionId: session.id);

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

  Future<void> openMyParking() async {
    if (!mounted || isLoadingSession) return;
    _myParkingLoad?.cancel();
    _myParkingLoad = ScreenLoadReporter(analyticsController, 'my_parking');
    final requestVersion = ++_myParkingRequestVersion;
    final userId = _userId;
    setState(() {
      _sessionLoadError = null;
      isLoadingSession = true;
      currentIndex = 3;
      showingMyParking = true;
    });

    try {
      await sessionController.loadActiveSession();
    } catch (_) {
      if (mounted &&
          requestVersion == _myParkingRequestVersion &&
          userId == _userId) {
        _sessionLoadError =
            'Could not refresh your session. No '
            'confirmed session is saved for this account. Reconnect and retry.';
      }
    } finally {
      if (mounted &&
          requestVersion == _myParkingRequestVersion &&
          userId == _userId) {
        setState(() {
          isLoadingSession = false;
        });
      }
    }
  }

  Widget _buildMyParking(ParkingSession session) {
    return ManagedFutureBuilder<ParkingDetailState>(
      requestKey: (_userId, session.id, session.parkingId, parkingController),
      load: () => parkingController.loadParkingDetails(session.parkingId),
      builder: (context, parkingSnapshot) {
        if (parkingSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (parkingSnapshot.hasError) {
          _myParkingLoad?.presented(context, source: 'none', failed: true);
          return _loadFailure(
            'Could not load parking details. Check your connection and retry.',
            openMyParking,
          );
        }

        final parking = parkingSnapshot.data?.parking;

        if (parking == null) {
          _myParkingLoad?.presented(context, source: 'none', failed: true);
          return _loadFailure(
            parkingSnapshot.data?.errorMessage ?? 'Parking lot not found.',
            openMyParking,
          );
        }

        final detailsCached = parkingSnapshot.data?.isFromCache == true;
        _myParkingLoad?.presented(
          context,
          source: sessionState.isFromCache
              ? (detailsCached ? 'sqlite' : 'mixed')
              : (detailsCached ? 'mixed' : 'network'),
        );
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
          analytics: analyticsController,
          currentIndex: currentIndex,
          onNavTap: changePage,
          controller: parkingController,
          onSelectParking: openParkingDetail,
          onSearchTap: openSearch,
        );

      case 2:
        return ManagedFutureBuilder<FavoriteListState>(
          analytics: analyticsController,
          screenName: 'favorites',
          loadSource: (data) =>
              data?.isFromCache == true ? 'sqlite' : 'network',
          requestKey: (_userId, _favoritesRequestVersion),
          load: favoriteController.loadFavoriteSnapshot,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return _loadFailure(
                'Could not load favorites. Check your connection and retry.',
                _refreshFavorites,
              );
            }

            final saved = snapshot.data;
            final favorites = saved?.favorites ?? [];
            final storageNotice = [
              if (saved?.isFromCache == true)
                'Showing saved favorites. They may be incomplete or outdated.',
              if ((saved?.pendingCount ?? 0) > 0)
                '${saved!.pendingCount} change(s) saved on this device and waiting to sync.',
              if (saved?.updatedAt != null)
                'Last server update: ${saved!.updatedAt!.toLocal().toString().split('.').first}',
            ].join('\n');

            if (favorites.isEmpty) {
              return NoFavoritesScreen(
                onNavTap: changePage,
                storageNotice: storageNotice.isEmpty ? null : storageNotice,
                onRefresh: _refreshFavorites,
              );
            }

            return FavoritesScreen(
              favorites: favorites,
              pendingRemovalIds: Set.unmodifiable(_removingFavoriteIds),
              storageNotice: storageNotice.isEmpty ? null : storageNotice,
              onRefresh: _refreshFavorites,
              onNavTap: changePage,
              onSelectParking: openParkingDetail,
              onRemove: (parking) => _removeFavorite(parking.id),
            );
          },
        );

      case 3:
        if (!showingMyParking) {
          return ProfileScreen(
            analytics: analyticsController,
            controller: profileController,
            onNavTap: _profileNavTap,
            onMyParking: openMyParking,
            onAnalyticsDashboard: openAnalyticsDashboard,
            onSignedOut: () {
              changePage(0);
            },
          );
        }

        if (isLoadingSession) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_sessionLoadError != null) {
          _myParkingLoad?.presented(context, source: 'none', failed: true);
          return Scaffold(
            appBar: AppBar(title: const Text('My parking')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_sessionLoadError!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: openMyParking,
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () => changePage(1),
                      child: const Text('Parking lots'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ListenableBuilder(
          listenable: sessionState,
          builder: (context, child) {
            final session = sessionState.activeSession;

            if (session == null) {
              _myParkingLoad?.presented(
                context,
                source: sessionState.isFromCache ? 'sqlite' : 'network',
              );
              return NoActiveParkingScreen(
                currentIndex: currentIndex,
                onNavTap: changePage,
                isFromCache: sessionState.isFromCache,
              );
            }

            return _buildMyParking(session);
          },
        );
      default:
        return HomeScreen(
          analytics: analyticsController,
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
