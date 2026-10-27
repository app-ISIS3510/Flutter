import 'dart:async';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/analytics_controller.dart';
import '../controllers/favorite_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/parking_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/session_controller.dart';
import '../controllers/connection_controller.dart';
import '../models/parking.dart';
import '../models/parking_session.dart';
import '../models/vehicle.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/favorite_repository.dart';
import '../repositories/parking_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/user_local_store.dart';
import '../repositories/personal_data_repository.dart';
import '../services/analytics_service.dart';
import '../services/distance_manager.dart';
import '../services/favorite_service.dart';
import '../services/navigation_service.dart';
import '../services/parking_service.dart';
import '../services/profile_service.dart';
import '../services/session_service.dart';
import '../services/shared_dashboard_service.dart';
import '../services/connection_failure.dart';
import '../services/pickup_analytics_service.dart';
import '../state/session_state.dart';
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
import 'profile/parking_history_screen.dart';
import 'profile/vehicles_screen.dart';
import 'profile/profile_widgets.dart';
import 'search.dart';
import 'search_results.dart';

class MainNavigationScreen extends StatefulWidget {
  final VoidCallback? onSignedOut;
  final ProfileService? profileService;
  final SessionService? sessionService;
  final Stream<List<ConnectivityResult>>? connectionChanges;
  final Future<List<ConnectivityResult>> Function()? checkConnection;

  const MainNavigationScreen({
    super.key,
    this.onSignedOut,
    this.profileService,
    this.sessionService,
    this.connectionChanges,
    this.checkConnection,
  });

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

  late final NavigationService navigationService;
  late final NavigationController navigationController;

  late final AnalyticsRepository analyticsRepository;
  late final AnalyticsService analyticsService;
  late final AnalyticsController analyticsController;
  late final PickupAnalyticsService pickupAnalytics;

  final sharedDashboardService = SharedDashboardService();

  late final DistanceManager distanceManager;

  late final ProfileController profileController;
  late final UserLocalStore localStore;
  late final ConnectionController connection;
  String? _lastConnectionNotice;
  StreamSubscription<AuthState>? _authSubscription;
  String? _userId;

  int currentIndex = 0;
  bool showingMyParking = false;
  bool isLoadingSession = false;
  bool isOpeningSearch = false;
  String? _sessionError;
  Future<Parking?>? _sessionParking;
  String? _sessionParkingId;
  bool _usingSavedParking = false;

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
    localStore = UserLocalStore(supabase);
    analyticsRepository = AnalyticsRepository(supabase);
    pickupAnalytics = PickupAnalyticsService(
      analyticsRepository,
      widget.sessionService?.store ??
          widget.profileService?.store ??
          localStore,
    );
    final personalData = PersonalDataRepository();

    parkingRepository = ParkingRepository(supabase);
    distanceManager = DistanceManager();
    parkingService = ParkingService(parkingRepository, distanceManager);
    parkingController = ParkingController(parkingService);

    sessionRepository = SessionRepository(supabase);
    sessionService =
        widget.sessionService ??
        SessionService(
          sessionRepository,
          store: localStore,
          local: personalData,
          pickupAnalytics: pickupAnalytics,
        );
    sessionState = SessionState();
    sessionController = SessionController(sessionService, sessionState);

    favoriteRepository = FavoriteRepository(supabase);
    favoriteService = FavoriteService(favoriteRepository);
    favoriteController = FavoriteController(favoriteService);

    navigationService = NavigationService.create();
    navigationController = NavigationController(navigationService);

    analyticsService = AnalyticsService(analyticsRepository);
    analyticsController = AnalyticsController(analyticsService);

    profileController = ProfileController(
      widget.profileService ??
          ProfileService(
            SupabaseUserRepository(supabase),
            local: personalData,
            store: localStore,
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
      sessionController.clear();
      _sessionParking = null;
      _sessionParkingId = null;
      _sessionError = null;
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

    connection = ConnectionController(
      onReconnect: _refreshAfterReconnect,
      changes: widget.connectionChanges,
      checkConnection: widget.checkConnection,
    );
    connection.addListener(_showConnectionNotice);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(connection.start());
    });
  }

  Future<void> _refreshAfterReconnect() async {
    final owner = _userId;
    if (owner == null) return;
    unawaited(pickupAnalytics.flush());
    if (profileController.busy ||
        profileController.loading ||
        sessionController.busy) {
      throw const ConnectionFailure(
        'A request is still in progress. Refresh your information when it finishes.',
      );
    }

    await profileController.load();
    if (!mounted || owner != _userId) return;
    Object? sessionError;
    try {
      await sessionController.loadActiveSession();
    } catch (error) {
      sessionError = error;
    }
    if (!mounted || owner != _userId) return;
    if (showingMyParking) {
      setState(() {
        _sessionError = sessionError == null
            ? null
            : SessionController.messageFor(sessionError);
        _sessionParking = null;
        _sessionParkingId = null;
      });
    }
    if (sessionError != null ||
        profileController.error != null ||
        profileController.usingSavedData ||
        sessionService.usingSavedSession) {
      throw const ConnectionFailure(
        'The network is available, but some information could not be confirmed with the server. Refresh to retry.',
      );
    }
    if (sessionService.pendingRequest != null ||
        profileController.pendingChange != null) {
      throw const ConnectionFailure(
        'A previous request is still unconfirmed. Check your information before retrying it.',
      );
    }
  }

  void _showConnectionNotice() {
    final message = connection.notice;
    if (!mounted || message == _lastConnectionNotice) return;
    _lastConnectionNotice = message;
    if (message == null || connection.checking) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(connection.recheck(refresh: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    connection.removeListener(_showConnectionNotice);
    connection.dispose();
    _authSubscription?.cancel();
    profileController.dispose();
    sessionController.dispose();
    sessionState.dispose();
    super.dispose();
  }

  void _returnToMain() {
    final mainRoute = ModalRoute.of(context);

    if (mainRoute != null) {
      Navigator.of(context).popUntil((route) => route == mainRoute);
    }
  }

  void _profileNavTap(int index) {
    _returnToMain();
    changePage(index);
  }

  void openParkingHistory() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ParkingHistoryScreen(
          service: sessionService,
          onNavTap: _profileNavTap,
        ),
      ),
    );
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

  void _showRequestError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(SessionController.messageFor(error))),
    );
  }

  void _savePickupDraft(String key, String time, {String? vehicleId}) {
    final owner = _userId;
    unawaited(
      sessionService
          .savePickupDraft(key, {'time': time, 'vehicle_id': vehicleId})
          .catchError((Object _) {
            if (!mounted || owner != _userId) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Your selection is still on screen, but could not be saved for reopening.',
                ),
              ),
            );
          }),
    );
  }

  Future<Parking?> _loadSessionParking(String id) async {
    final owner = _userId;
    _usingSavedParking = false;
    try {
      final parking = await parkingController
          .loadParkingById(id)
          .timeout(sessionService.requestTimeout);
      if (!mounted || owner != _userId) return null;
      if (parking != null) await sessionService.saveParking(parking);
      return parking;
    } catch (error) {
      if (!isConnectionError(error)) rethrow;
      final saved = await sessionService.getSavedParking(id);
      if (!mounted || owner != _userId) return null;
      if (saved == null) {
        throw const ConnectionFailure(
          'No parking details are saved. Reconnect and refresh My parking.',
        );
      }
      _usingSavedParking = true;
      return saved;
    }
  }

  Future<void> _saveParkingPreview(Map<String, String> parking) async {
    final id = parking['id'];
    if (id == null) return;
    await sessionService.saveParking(
      Parking.fromMap({
        'id': id,
        'name': parking['name'] ?? 'Parking stay',
        'address': parking['address'] ?? '',
        'latitude': double.tryParse(parking['latitude'] ?? ''),
        'longitude': double.tryParse(parking['longitude'] ?? ''),
        'opening_time': parking['openingTime'],
        'closing_time': parking['closingTime'],
        'image_url': parking['imageUrl'],
        'price_per_minute':
            double.tryParse(parking['pricePerMinute'] ?? '') ?? 0,
      }),
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

  Future<void> openSearch() async {
    if (isOpeningSearch) return;
    isOpeningSearch = true;
    final userId = _userId;

    try {
      await profileController.load();
      if (!mounted || userId != _userId) return;

      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => ListenableBuilder(
            listenable: profileController,
            builder: (context, child) => SearchScreen(
              currentIndex: 1,
              parkingController: parkingController,
              selectedVehicle: profileController.error == null
                  ? profileController.selectedVehicle
                  : null,
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
        ),
      );
    } finally {
      isOpeningSearch = false;
    }
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

  Future<void> openPickupTime(Map<String, String> parking) async {
    final owner = _userId;
    try {
      await profileController.load();

      if (!mounted || owner != _userId) return;

      if (profileController.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(profileController.error!)));
        return;
      }

      final parkingId = parking['id'];
      if (parkingId == null) {
        throw const FormatException('Parking information is missing.');
      }
      await _saveParkingPreview(parking);
      final draft = await sessionService.getPickupDraft('start_$parkingId');
      await sessionService.restorePendingRequest();
      if (!mounted || owner != _userId) return;

      var vehicle = profileController.selectedVehicle;
      for (final savedVehicle in profileController.vehicles) {
        if (savedVehicle.id == draft?['vehicle_id']) vehicle = savedVehicle;
      }
      vehicle ??= await _chooseVehicle();

      if (vehicle == null || !mounted || owner != _userId) return;

      if (parkingId.isNotEmpty) {
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

      String? suggestedTime;
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => PickupTimeScreen(
            onSuggestionReady: (time) => suggestedTime = time,
            onNavTap: _profileNavTap,
            vehicle: vehicle!,
            initialTime: draft?['time'] as String?,
            notice: sessionService.notice ?? profileController.notice,
            onDraftChanged: (time, chosen) {
              if (owner == _userId) {
                _savePickupDraft(
                  'start_$parkingId',
                  time,
                  vehicleId: chosen.id,
                );
              }
            },
            onCheckStatus: () {
              _returnToMain();
              openMyParking();
            },
            onChangeVehicle: () async {
              final chosen = await _chooseVehicle();
              if (chosen != null) {
                vehicle = chosen;
              } else if (!profileController.vehicles.any(
                (saved) => saved.id == vehicle?.id,
              )) {
                vehicle = null;
              }
              return vehicle;
            },
            openingTime: (parking['openingTime']?.length ?? 0) >= 5
                ? parking['openingTime']!
                : '00:00:00',
            closingTime: (parking['closingTime']?.length ?? 0) >= 5
                ? parking['closingTime']!
                : '23:59:00',
            onStartParking: (time, chosenVehicle) async {
              if (owner != _userId) {
                throw const AuthException('Sign in to continue.');
              }
              await sessionService.savePickupDraft('start_$parkingId', {
                'time': time,
                'vehicle_id': chosenVehicle.id,
              });

              final pickup = _buildPickupDateTime(time);

              final stopwatch = Stopwatch()..start();

              final session = await sessionController.startParking(
                parkingId: parkingId,
                pickupTime: pickup,
                vehicleId: chosenVehicle.id,
                parkingName: parking['name'] ?? 'Parking stay',
                suggestedPickupTime: suggestedTime == null
                    ? null
                    : _buildPickupDateTime(suggestedTime!),
              );

              stopwatch.stop();

              final durationMs = stopwatch.elapsedMilliseconds;
              if (!mounted || owner != _userId) return;

              unawaited(
                analyticsController
                    .track(
                      eventType: 'parking_started',
                      screen: 'pickup_time',
                      parkingId: parkingId,
                      metadata: {
                        'pickup_time': pickup.toIso8601String(),
                        if (!sessionService.recoveredRequest)
                          'duration_ms': durationMs,
                        'recovered_request': sessionService.recoveredRequest,
                        'platform': 'flutter',
                        'session_id': session.id,
                      },
                    )
                    .catchError((Object _) {}),
              );

              if (!context.mounted) return;

              _returnToMain();
              openMyParking();
              if (session.status == 'completed') {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'The earlier parking request was confirmed, but that session has already ended.',
                    ),
                  ),
                );
              }
            },
          ),
        ),
      );
    } catch (error) {
      if (mounted && owner == _userId) _showRequestError(error);
    }
  }

  void openChangePickupTime() async {
    final owner = _userId;
    try {
      final session = await sessionController.loadActiveSession();

      if (!mounted || owner != _userId) return;

      if (session == null) {
        return;
      }

      final parking = await _loadSessionParking(session.parkingId);
      final draft = await sessionService.getPickupDraft('change_${session.id}');

      if (parking == null || !mounted || owner != _userId) {
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => ChangePickupTimeScreen(
            onNavTap: _profileNavTap,
            initialTime:
                draft?['time'] as String? ??
                _formatTimeForPicker(session.pickupTime),
            notice:
                sessionService.notice ??
                (_usingSavedParking
                    ? 'Showing saved parking hours. Reconnect and refresh to update them.'
                    : null),
            onDraftChanged: (time) {
              if (owner == _userId) {
                _savePickupDraft('change_${session.id}', time);
              }
            },
            openingTime: parking.openingTime ?? '00:00:00',
            closingTime: parking.closingTime ?? '23:59:00',
            onSave: (time) async {
              if (owner != _userId) {
                throw const AuthException('Sign in to continue.');
              }
              await sessionService.savePickupDraft('change_${session.id}', {
                'time': time,
              });
              final newPickupTime = _buildPickupDateTime(time);

              try {
                await sessionController.changePickupTime(
                  sessionId: session.id,
                  pickupTime: newPickupTime,
                  parkingName: parking.name,
                );
              } finally {
                if (mounted && owner == _userId) setState(() {});
              }

              if (!mounted || owner != _userId) return;

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
      if (mounted && owner == _userId) _showRequestError(error);
    }
  }

  Future<void> endParking({
    required ParkingSession session,
    required String parkingName,
  }) async {
    final owner = _userId;
    try {
      await sessionController.endParking(
        sessionId: session.id,
        parkingName: parkingName,
      );
    } finally {
      if (mounted && owner == _userId) setState(() {});
    }
    if (!mounted || owner != _userId) return;

    if (mounted &&
        _userId == session.userId &&
        sessionService.historySaveFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Parking ended, but its summary could not be saved on this device.',
          ),
        ),
      );
    }

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
    final owner = _userId;
    setState(() {
      _sessionError = null;
      _sessionParking = null;
      _sessionParkingId = null;
      isLoadingSession = true;
      currentIndex = 3;
      showingMyParking = true;
    });

    try {
      await sessionController.loadActiveSession();
    } catch (error) {
      if (mounted && owner == _userId) {
        _sessionError = SessionController.messageFor(error);
      }
    } finally {
      if (mounted && owner == _userId) {
        setState(() {
          isLoadingSession = false;
        });
      }
    }
  }

  Widget _buildMyParking(ParkingSession session) {
    if (_sessionParking == null || _sessionParkingId != session.parkingId) {
      _sessionParkingId = session.parkingId;
      _sessionParking = _loadSessionParking(session.parkingId);
    }
    return FutureBuilder<Parking?>(
      future: _sessionParking,
      builder: (context, parkingSnapshot) {
        if (parkingSnapshot.connectionState == ConnectionState.waiting) {
          return ProfilePage(
            title: 'My parking',
            onNavTap: changePage,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (parkingSnapshot.hasError) {
          return _parkingFailure(
            SessionController.messageFor(parkingSnapshot.error!),
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
          navigationController: navigationController,
          onEndParking: () =>
              endParking(session: session, parkingName: parking.name),
          notice:
              sessionService.notice ??
              (_usingSavedParking
                  ? 'Showing saved parking details. Reconnect and refresh to update them.'
                  : null),
          onRefresh: openMyParking,
          onChangePickupTime: openChangePickupTime,
        );
      },
    );
  }

  Widget _parkingFailure(String message) => ProfilePage(
    title: 'My parking',
    onNavTap: changePage,
    child: Column(
      children: [
        ProfileError(message),
        const SizedBox(height: 16),
        ProfileButton(text: 'Check parking status', onPressed: openMyParking),
      ],
    ),
  );

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
            onParkingHistory: sessionService.historyAvailable
                ? openParkingHistory
                : null,
            onAnalyticsDashboard: openAnalyticsDashboard,
            onSignedOut: () {
              changePage(0);
            },
          );
        }

        if (isLoadingSession) {
          return ProfilePage(
            title: 'My parking',
            onNavTap: changePage,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (_sessionError != null) return _parkingFailure(_sessionError!);

        return ListenableBuilder(
          listenable: sessionState,
          builder: (context, child) {
            final session = sessionState.activeSession;

            if (session == null) {
              if (sessionService.pendingRequest != null) {
                return _parkingFailure(sessionService.notice!);
              }
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
