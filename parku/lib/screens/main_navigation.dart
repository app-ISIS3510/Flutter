import 'dart:async';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/analytics_controller.dart';
import '../controllers/connection_controller.dart';
import '../controllers/favorite_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/parking_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/session_controller.dart';
import '../data/local/analytics_local_data_source.dart';
import '../models/analytics_measurements.dart';
import '../models/parking.dart';
import '../models/parking_session.dart';
import '../models/vehicle.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/favorite_repository.dart';
import '../repositories/parking_repository.dart';
import '../repositories/personal_data_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/user_local_store.dart';
import '../repositories/user_repository.dart';
import '../services/analytics_service.dart';
import '../services/connection_failure.dart';
import '../services/connectivity_service.dart';
import '../services/distance_manager.dart';
import '../services/favorite_service.dart';
import '../services/favorite_sync_service.dart';
import '../services/navigation_service.dart';
import '../services/parking_service.dart';
import '../services/pickup_analytics_service.dart';
import '../services/profile_service.dart';
import '../services/session_service.dart';
import '../services/shared_dashboard_service.dart';
import '../state/favorite_list_state.dart';
import '../state/favorite_status_state.dart';
import '../state/parking_detail_state.dart';
import '../state/session_state.dart';
import '../utils/screen_load_reporter.dart';
import '../utils/user_error_message.dart';
import '../widgets/managed_future_builder.dart';
import '../widgets/user_error_notice.dart';
import 'change_pickup_time.dart';
import 'favorites.dart';
import 'home.dart';
import 'my_parking.dart';
import 'no_active_parking.dart';
import 'no_favorites.dart';
import 'parking_detail.dart';
import 'parking_list.dart';
import 'pickup_time.dart';
import 'profile/parking_history_screen.dart';
import 'profile/profile_screen.dart';
import 'profile/profile_widgets.dart';
import 'profile/vehicles_screen.dart';
import 'search.dart';
import 'search_results.dart';

class MainNavigationScreen extends StatefulWidget {
  final VoidCallback? onSignedOut;
  final ProfileService? profileService;
  final SessionService? sessionService;
  final Stream<List<ConnectivityResult>>? connectionChanges;
  final Future<List<ConnectivityResult>> Function()? checkConnection;
  final DateTime Function()? currentTime;
  final AnalyticsLocalDataSource? analyticsLocalDataSource;

  const MainNavigationScreen({
    super.key,
    this.onSignedOut,
    this.profileService,
    this.sessionService,
    this.connectionChanges,
    this.checkConnection,
    this.currentTime,
    this.analyticsLocalDataSource,
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
  late final FavoriteSyncService favoriteSyncService;

  late final NavigationService navigationService;
  late final NavigationController navigationController;

  late final AnalyticsRepository analyticsRepository;
  late final AnalyticsService analyticsService;
  late final AnalyticsController analyticsController;
  late final PickupAnalyticsService pickupAnalytics;

  late final DistanceManager distanceManager;
  late final ProfileController profileController;
  late final UserLocalStore localStore;
  late final ConnectionController connection;

  final sharedDashboardService = SharedDashboardService();
  final _connection = ConnectivityService();
  final Set<String> _removingFavoriteIds = {};

  StreamSubscription<AuthState>? _authSubscription;
  String? _userId;
  String? _lastConnectionNotice;
  String? _sessionLoadError;
  ScreenLoadReporter? _myParkingLoad;

  int currentIndex = 0;
  int _favoritesRequestVersion = 0;
  int _myParkingRequestVersion = 0;

  bool showingMyParking = false;
  bool isLoadingSession = false;
  bool isOpeningSearch = false;
  bool _isOpeningPickup = false;
  bool _isOpeningPickupChange = false;

  bool _sameUser(String? owner) =>
      mounted &&
      owner != null &&
      owner == _userId &&
      owner == Supabase.instance.client.auth.currentUser?.id;

  void _requireUser(String? owner) {
    if (!_sameUser(owner)) {
      throw const AuthException('The signed-in account changed.');
    }
  }

  void _track({
    required String eventType,
    required String screen,
    String? parkingId,
    Map<String, dynamic>? metadata,
    DateTime? occurredAt,
  }) {
    unawaited(
      analyticsController
          .track(
            eventType: eventType,
            screen: screen,
            parkingId: parkingId,
            metadata: metadata,
            occurredAt: occurredAt,
          )
          .catchError((Object _) {}),
    );
  }

  DateTime _buildPickupDateTime(String time) {
    final parts = time.split(':');
    final now = widget.currentTime?.call() ?? DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  String _formatTimeForPicker(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  void initState() {
    super.initState();

    final supabase = Supabase.instance.client;
    _userId = supabase.auth.currentUser?.id;

    localStore = UserLocalStore(supabase);
    final personalData = PersonalDataRepository();

    analyticsRepository = AnalyticsRepository(
      supabase,
      localDataSource: widget.analyticsLocalDataSource,
    );
    pickupAnalytics = PickupAnalyticsService(
      analyticsRepository,
      widget.sessionService?.store ??
          widget.profileService?.store ??
          localStore,
    );
    analyticsService = AnalyticsService(analyticsRepository);
    analyticsController = AnalyticsController(analyticsService);
    analyticsService.start();

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
    favoriteSyncService = FavoriteSyncService(favoriteRepository);
    favoriteSyncService.addListener(_onFavoriteSync);
    favoriteSyncService.start();

    navigationService = NavigationService.create();
    navigationController = NavigationController(navigationService);

    profileController = ProfileController(
      widget.profileService ??
          ProfileService(
            SupabaseUserRepository(supabase),
            local: personalData,
            store: localStore,
          ),
    );

    _authSubscription = supabase.auth.onAuthStateChange.listen(
      (state) {
        if (!mounted) return;

        final nextUser = state.session?.user.id;

        if (nextUser == _userId) {
          if (state.event == AuthChangeEvent.userUpdated &&
              !profileController.busy) {
            unawaited(profileController.load());
          }
          return;
        }

        _userId = nextUser;
        _myParkingLoad?.cancel();
        _myParkingRequestVersion++;
        _favoritesRequestVersion++;
        _removingFavoriteIds.clear();

        profileController.clear();
        sessionController.clear();
        _returnToMain();

        setState(() {
          isLoadingSession = false;
          _sessionLoadError = null;
          showingMyParking = false;
          currentIndex = 0;
        });

        if (nextUser == null) {
          widget.onSignedOut?.call();
        } else {
          unawaited(profileController.load());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'Could not observe authentication changes',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );

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
    if (!_sameUser(owner)) return;

    unawaited(analyticsService.flushPending());
    unawaited(favoriteSyncService.flush());
    unawaited(pickupAnalytics.flush());

    if (profileController.busy ||
        profileController.loading ||
        sessionController.busy ||
        isLoadingSession) {
      throw const ConnectionFailure(
        'A request is still in progress. Refresh when it finishes.',
      );
    }

    await profileController.load();
    if (!_sameUser(owner)) return;

    if (showingMyParking) {
      await openMyParking();
    } else {
      await sessionController.loadActiveSession();
    }

    if (!_sameUser(owner)) return;

    if (_sessionLoadError != null ||
        profileController.error != null ||
        profileController.usingSavedData ||
        sessionService.usingSavedSession ||
        sessionState.isFromCache) {
      throw const ConnectionFailure(
        'Some information could not be refreshed. Please try again later.',
      );
    }

    if (sessionService.pendingRequest != null ||
        profileController.pendingChange != null) {
      throw const ConnectionFailure(
        'A previous request is unconfirmed. Check its status before retrying.',
      );
    }
  }

  void _showConnectionNotice() {
    final message = connection.notice;
    if (!mounted || message == _lastConnectionNotice) return;

    _lastConnectionNotice = message;

    if (message != null && !connection.checking) {
      showUserMessage(context, message);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(analyticsService.flushPending());
      unawaited(favoriteSyncService.flush());
      unawaited(pickupAnalytics.flush());
      unawaited(connection.recheck(refresh: true));
    }
  }

  @override
  void dispose() {
    _myParkingLoad?.cancel();
    WidgetsBinding.instance.removeObserver(this);

    connection.removeListener(_showConnectionNotice);
    connection.dispose();

    analyticsService.dispose();
    favoriteSyncService.removeListener(_onFavoriteSync);
    favoriteSyncService.dispose();

    _authSubscription?.cancel();
    profileController.dispose();
    sessionController.dispose();
    sessionState.dispose();

    super.dispose();
  }

  void _returnToMain() {
    if (!mounted) return;

    final mainRoute = ModalRoute.of(context);

    if (mainRoute != null) {
      Navigator.of(context).popUntil((route) => route == mainRoute);
    }
  }

  void _profileNavTap(int index) {
    _returnToMain();
    changePage(index);
  }

  void changePage(int index) {
    if (!mounted) return;

    _myParkingLoad?.cancel();
    _myParkingRequestVersion++;

    setState(() {
      if (index == 2 && currentIndex != 2) {
        _favoritesRequestVersion++;
      }
      currentIndex = index;
      showingMyParking = false;
      isLoadingSession = false;
      _sessionLoadError = null;
    });
  }

  void _onFavoriteSync() {
    if (mounted && currentIndex == 2) {
      _refreshFavorites();
    }
  }

  void _refreshFavorites() {
    if (mounted) {
      setState(() => _favoritesRequestVersion++);
    }
  }

  Future<void> _removeFavorite(String parkingId) async {
    final owner = _userId;

    if (!_sameUser(owner) || _removingFavoriteIds.contains(parkingId)) {
      return;
    }

    setState(() => _removingFavoriteIds.add(parkingId));

    try {
      await favoriteController.removeFavorite(parkingId);
      if (!_sameUser(owner)) return;

      _track(
        eventType: 'favorite_removed',
        screen: 'favorites',
        parkingId: parkingId,
      );

      _refreshFavorites();
    } catch (error) {
      if (mounted && _sameUser(owner)) {
        showUserError(context, error, action: ErrorAction.favorites);
      }
    } finally {
      if (_sameUser(owner)) {
        setState(() => _removingFavoriteIds.remove(parkingId));
      }
    }
  }

  void _showRequestError(Object error, ErrorAction action) {
    if (!mounted) return;

    if (error is ConnectionFailure) {
      showUserMessage(context, error.message);
    } else {
      showUserError(context, error, action: action);
    }
  }

  Future<T> _parkingRequest<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ConnectionFailure catch (error) {
      throw UserInputException(error.message);
    }
  }

  Widget _loadFailure(
    String message,
    VoidCallback retry, {
    String title = 'ParkU',
  }) => ProfilePage(
    title: title,
    onNavTap: changePage,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileError(message),
        const SizedBox(height: 16),
        ProfileButton(text: 'Retry', onPressed: retry),
        TextButton(
          onPressed: () => changePage(1),
          child: const Text('Parking lots'),
        ),
      ],
    ),
  );

  void openParkingHistory() {
    if (!mounted) return;

    Navigator.push<void>(
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
      MaterialPageRoute<Vehicle>(
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
      if (mounted) {
        showUserMessage(
          context,
          'Could not open the analytics dashboard. Please try again later.',
        );
      }
    }
  }

  void _savePickupDraft(String key, String time, {String? vehicleId}) {
    final owner = _userId;

    unawaited(
      sessionService
          .savePickupDraft(key, {'time': time, 'vehicle_id': vehicleId})
          .catchError((Object _) {
            if (mounted && _sameUser(owner)) {
              showUserMessage(
                context,
                'Could not save your selection on this device.',
              );
            }
          }),
    );
  }

  Future<ParkingDetailState> _loadSessionParking(String id) async {
    final owner = _userId;
    _requireUser(owner);

    try {
      final details = await parkingController
          .loadParkingDetails(id)
          .timeout(sessionService.requestTimeout);

      _requireUser(owner);

      if (details.parking != null) {
        await sessionService.saveParking(details.parking!);
        _requireUser(owner);
        return details;
      }

      final saved = await sessionService.getSavedParking(id);
      _requireUser(owner);

      return saved == null
          ? details
          : ParkingDetailState(parking: saved, isFromCache: true);
    } catch (error) {
      if (!isConnectionError(error)) rethrow;

      _requireUser(owner);
      final saved = await sessionService.getSavedParking(id);
      _requireUser(owner);

      if (saved == null) {
        throw const ConnectionFailure(
          'No parking details are saved. Reconnect and refresh My parking.',
        );
      }

      return ParkingDetailState(parking: saved, isFromCache: true);
    }
  }

  Future<void> _saveParkingPreview(Map<String, String> parking) async {
    final id = parking['id'];
    if (id == null || id.isEmpty) return;

    await sessionService.saveParking(
      Parking.fromMap({
        'id': id,
        'name': parking['name'] ?? 'Parking stay',
        'address': parking['address'] ?? '',
        'latitude': double.tryParse(parking['latitude'] ?? ''),
        'longitude': double.tryParse(parking['longitude'] ?? ''),
        'car_spaces': int.tryParse(parking['carSpaces'] ?? '') ?? 0,
        'motorcycle_spaces':
            int.tryParse(parking['motorcycleSpaces'] ?? '') ?? 0,
        'opening_time': parking['openingTime'],
        'closing_time': parking['closingTime'],
        'image_url': parking['imageUrl'],
        'price_per_minute':
            double.tryParse(parking['pricePerMinute'] ?? '') ?? 0,
      }),
    );
  }

  Future<void> openSearch() async {
    if (isOpeningSearch || !mounted) return;

    isOpeningSearch = true;
    final owner = _userId;

    try {
      unawaited(profileController.load());
      if (!_sameUser(owner)) return;

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ListenableBuilder(
            listenable: profileController,
            builder: (context, child) => SearchScreen(
              analytics: analyticsController,
              currentIndex: 1,
              parkingController: parkingController,
              selectedVehicle: profileController.selectedVehicle,
              onSelectParking: openParkingDetail,
              onNavTap: _profileNavTap,
              onSearch: (query) {
                if (query.trim().isNotEmpty) {
                  unawaited(
                    analyticsController
                        .track(
                          eventType: 'parking_search_performed',
                          screen: 'search',
                          metadata: {
                            'search_method': 'text',
                            'platform': 'flutter',
                          },
                        )
                        .catchError((Object _) {}),
                  );
                }

                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SearchResultsScreen(
                      analytics: analyticsController,
                      initialQuery: query,
                      currentIndex: 1,
                      parkingController: parkingController,
                      onNavTap: _profileNavTap,
                      onSelectParking: openParkingDetail,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    } catch (error) {
      if (_sameUser(owner)) {
        _showRequestError(error, ErrorAction.load);
      }
    } finally {
      isOpeningSearch = false;
    }
  }

  Future<void> openParkingDetail(Map<String, String> parking) async {
    final parkingId = parking['id'];

    if (parkingId == null || parkingId.isEmpty) return;
    if (!_sameUser(_userId)) return;

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

                            if (analyticsController.currentUserId ==
                                detailUserId) {
                              _track(
                                eventType: nextIsFavorite
                                    ? 'favorite_added'
                                    : 'favorite_removed',
                                screen: 'parking_detail',
                                parkingId: parkingId,
                                metadata: detailVisit.favoriteMetadata(
                                  nextIsFavorite,
                                ),
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

                            // The heart already confirms an online change.
                            // Explain the local save only when actually offline.
                            final online = await _connection.connectionStatus();
                            if (online == false &&
                                context.mounted &&
                                detailIsOpen &&
                                detailUserId == _userId) {
                              showUserInfo(
                                context,
                                'Saved on this device. Syncs when online.',
                              );
                            }
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
                      'imageUrl': selectedParking.imageUrl ?? '',
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
    if (_isOpeningPickup || !mounted) return;

    _isOpeningPickup = true;
    final owner = _userId;

    try {
      // Reject from the details screen before loading profile, vehicle or draft.
      await _connection.requireConnection();
      if (!mounted || !_sameUser(owner)) return;
      await profileController.load();
      if (!mounted || !_sameUser(owner)) return;

      if (profileController.error != null) {
        showUserMessage(
          context,
          'Could not load your vehicle. Please try again later.',
        );
        return;
      }

      final parkingId = parking['id'];

      if (parkingId == null || parkingId.isEmpty) {
        throw const UserInputException('Parking information is missing.');
      }

      await _saveParkingPreview(parking);
      _requireUser(owner);

      final draft = await sessionService.getPickupDraft('start_$parkingId');
      _requireUser(owner);

      await sessionService.restorePendingRequest();
      if (!_sameUser(owner)) return;

      var vehicle = profileController.selectedVehicle;

      for (final savedVehicle in profileController.vehicles) {
        if (savedVehicle.id == draft?['vehicle_id']) {
          vehicle = savedVehicle;
        }
      }

      vehicle ??= await _chooseVehicle();

      if (!mounted || vehicle == null || !_sameUser(owner)) return;

      _track(
        eventType: 'pickup_time_viewed',
        screen: 'pickup_time',
        parkingId: parkingId,
      );

      String? suggestedTime;

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (routeContext) => PickupTimeScreen(
            currentTime: widget.currentTime,
            onSuggestionReady: (time) => suggestedTime = time,
            onNavTap: _profileNavTap,
            vehicle: vehicle!,
            initialTime: draft?['time'] as String?,
            notice: sessionService.notice ?? profileController.notice,
            onDraftChanged: (time, chosen) {
              if (_sameUser(owner)) {
                _savePickupDraft(
                  'start_$parkingId',
                  time,
                  vehicleId: chosen.id,
                );
              }
            },
            onCheckStatus: () {
              _returnToMain();
              unawaited(openMyParking());
            },
            onChangeVehicle: () async {
              final chosen = await _chooseVehicle();

              if (!_sameUser(owner)) return null;

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
              _requireUser(owner);

              await sessionService.savePickupDraft('start_$parkingId', {
                'time': time,
                'vehicle_id': chosenVehicle.id,
              });

              _requireUser(owner);
              await _connection.requireConnection();
              _requireUser(owner);

              final pickup = _buildPickupDateTime(time);
              final stopwatch = Stopwatch()..start();

              final session = await _parkingRequest(
                () => sessionController.startParking(
                  parkingId: parkingId,
                  pickupTime: pickup,
                  vehicleId: chosenVehicle.id,
                  parkingName: parking['name'] ?? 'Parking stay',
                  suggestedPickupTime: suggestedTime == null
                      ? null
                      : _buildPickupDateTime(suggestedTime!),
                ),
              );

              stopwatch.stop();

              if (!_sameUser(owner)) return;

              _track(
                eventType: 'parking_started',
                screen: 'pickup_time',
                parkingId: parkingId,
                occurredAt: session.startedAt,
                metadata: {
                  'event_schema_version': 2,
                  'session_started_at': session.startedAt
                      .toUtc()
                      .toIso8601String(),
                  'pickup_time': pickup.toIso8601String(),
                  if (!sessionService.recoveredRequest)
                    'duration_ms': stopwatch.elapsedMilliseconds,
                  'recovered_request': sessionService.recoveredRequest,
                  'platform': 'flutter',
                  'session_id': session.id,
                },
              );

              if (!mounted || !routeContext.mounted) return;

              _returnToMain();
              unawaited(openMyParking());

              if (session.status == 'completed') {
                showUserMessage(
                  context,
                  'The earlier request was confirmed. That parking has already ended.',
                );
              }
            },
          ),
        ),
      );
    } catch (error) {
      if (_sameUser(owner)) {
        _showRequestError(error, ErrorAction.startParking);
      }
    } finally {
      _isOpeningPickup = false;
    }
  }

  Future<void> openChangePickupTime() async {
    if (_isOpeningPickupChange || !mounted) return;

    _isOpeningPickupChange = true;
    final owner = _userId;

    try {
      // Keep the user on My parking instead of loading data for a blocked action.
      await _connection.requireConnection();
      if (!mounted || !_sameUser(owner)) return;
      final session = await sessionController.loadActiveSession();

      if (!_sameUser(owner) || session == null) return;

      final details = await _loadSessionParking(session.parkingId);
      if (!_sameUser(owner)) return;

      final parking = details.parking;

      if (parking == null) {
        throw const UserInputException(
          'Parking details are unavailable. Please try again later.',
        );
      }

      final draft = await sessionService.getPickupDraft('change_${session.id}');

      if (!mounted || !_sameUser(owner)) return;

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChangePickupTimeScreen(
            currentTime: widget.currentTime,
            onNavTap: _profileNavTap,
            initialTime:
                draft?['time'] as String? ??
                _formatTimeForPicker(session.pickupTime),
            notice:
                sessionService.notice ??
                (details.isFromCache ? 'Using saved parking hours.' : null),
            onDraftChanged: (time) {
              if (_sameUser(owner)) {
                _savePickupDraft('change_${session.id}', time);
              }
            },
            openingTime: parking.openingTime ?? '00:00:00',
            closingTime: parking.closingTime ?? '23:59:00',
            onSave: (time) async {
              _requireUser(owner);

              await sessionService.savePickupDraft('change_${session.id}', {
                'time': time,
              });

              _requireUser(owner);
              await _connection.requireConnection();
              _requireUser(owner);

              final pickup = _buildPickupDateTime(time);

              try {
                await _parkingRequest(
                  () => sessionController.changePickupTime(
                    sessionId: session.id,
                    pickupTime: pickup,
                    parkingName: parking.name,
                  ),
                );
              } finally {
                if (_sameUser(owner)) {
                  setState(() {});
                }
              }

              if (!_sameUser(owner)) return;

              _track(
                eventType: 'pickup_time_changed',
                screen: 'change_pickup_time',
                parkingId: session.parkingId,
                metadata: {'new_pickup_time': pickup.toIso8601String()},
              );
            },
          ),
        ),
      );
    } catch (error) {
      if (_sameUser(owner)) {
        _showRequestError(error, ErrorAction.updatePickup);
      }
    } finally {
      _isOpeningPickupChange = false;
    }
  }

  Future<void> endParking({
    required ParkingSession session,
    required String parkingName,
  }) async {
    final owner = _userId;

    _requireUser(owner);
    await _connection.requireConnection();
    _requireUser(owner);

    try {
      await _parkingRequest(
        () => sessionController.endParking(
          sessionId: session.id,
          parkingName: parkingName,
        ),
      );
    } finally {
      if (_sameUser(owner)) {
        setState(() {});
      }
    }

    if (!mounted || !_sameUser(owner)) return;

    if (sessionService.historySaveFailed) {
      showUserMessage(
        context,
        'Parking ended, but its summary could not be saved on this device.',
      );
    }

    _track(
      eventType: 'parking_ended',
      screen: 'end_parking',
      parkingId: session.parkingId,
    );
  }

  Future<void> openMyParking() async {
    if (!mounted || isLoadingSession) return;

    final owner = _userId;
    if (!_sameUser(owner)) return;

    _myParkingLoad?.cancel();
    _myParkingLoad = ScreenLoadReporter(analyticsController, 'my_parking');

    final version = ++_myParkingRequestVersion;

    setState(() {
      _sessionLoadError = null;
      isLoadingSession = true;
      currentIndex = 3;
      showingMyParking = true;
    });

    try {
      await sessionController.loadActiveSession();
    } catch (error) {
      if (_sameUser(owner) && version == _myParkingRequestVersion) {
        _sessionLoadError = error is ConnectionFailure
            ? error.message
            : userErrorMessage(error, action: ErrorAction.load);
      }
    } finally {
      if (_sameUser(owner) && version == _myParkingRequestVersion) {
        setState(() => isLoadingSession = false);
      }
    }
  }

  Widget _buildMyParking(ParkingSession session) {
    return ManagedFutureBuilder<ParkingDetailState>(
      requestKey: (
        _userId,
        session.id,
        session.parkingId,
        _myParkingRequestVersion,
      ),
      load: () => _loadSessionParking(session.parkingId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ProfilePage(
            title: 'My parking',
            onNavTap: changePage,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final details = snapshot.data;
        final parking = details?.parking;

        if (snapshot.hasError || parking == null) {
          _myParkingLoad?.presented(context, source: 'none', failed: true);

          return _loadFailure(
            'Could not load parking details. Please try again later.',
            openMyParking,
            title: 'My parking',
          );
        }

        final cachedSession = sessionState.isFromCache;
        final source = details!.isFromCache
            ? (cachedSession ? 'sqlite' : 'mixed')
            : (cachedSession ? 'mixed' : 'network');

        _myParkingLoad?.presented(context, source: source);

        return MyParkingScreen(
          currentIndex: currentIndex,
          onNavTap: changePage,
          session: session,
          parking: parking,
          navigationController: navigationController,
          analyticsController: analyticsController,
          onEndParking: () =>
              endParking(session: session, parkingName: parking.name),
          notice: sessionService.pendingRequest != null
              ? 'Request pending. Refresh to confirm.'
              : cachedSession || sessionService.usingSavedSession
              ? 'Last confirmed session'
              : sessionService.localSaveFailed
              ? 'Offline copy could not be saved.'
              : details.isFromCache
              ? 'Saved parking details'
              : null,
          onRefresh: openMyParking,
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
          analytics: analyticsController,
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

            final storageNotice = (saved?.pendingCount ?? 0) > 0
                ? 'Changes sync when online.'
                : saved?.isFromCache == true
                ? 'Saved favorites'
                : null;

            if (favorites.isEmpty) {
              return NoFavoritesScreen(
                onNavTap: changePage,
                storageNotice: storageNotice,
                onRefresh: _refreshFavorites,
              );
            }

            return FavoritesScreen(
              favorites: favorites,
              pendingRemovalIds: Set.unmodifiable(_removingFavoriteIds),
              storageNotice: storageNotice,
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_sessionLoadError != null) {
          _myParkingLoad?.presented(context, source: 'none', failed: true);

          return _loadFailure(
            _sessionLoadError!,
            openMyParking,
            title: 'My parking',
          );
        }

        return ListenableBuilder(
          listenable: sessionState,
          builder: (context, child) {
            final session = sessionState.activeSession;

            if (session == null && sessionService.pendingRequest != null) {
              _myParkingLoad?.presented(context, source: 'none', failed: true);

              return _loadFailure(
                sessionService.notice ??
                    'Check the status of your previous parking request.',
                openMyParking,
                title: 'My parking',
              );
            }

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
