import 'package:flutter/material.dart';

import '../controllers/analytics_controller.dart';
import '../controllers/parking_controller.dart';
import '../models/parking.dart';
import '../state/parking_list_state.dart';
import '../theme/app_theme.dart';
import '../utils/screen_load_reporter.dart';
import 'parking_card.dart';

/// The complete catalog, without GPS, distance filters or live availability.
class ParkingCatalogList extends StatefulWidget {
  final ParkingController controller;
  final AnalyticsController? analytics;
  final bool isOffline;
  final ValueChanged<Map<String, String>> onSelectParking;

  const ParkingCatalogList({
    super.key,
    required this.controller,
    required this.onSelectParking,
    this.analytics,
    this.isOffline = false,
  });

  @override
  State<ParkingCatalogList> createState() => _ParkingCatalogListState();
}

class _ParkingCatalogListState extends State<ParkingCatalogList> {
  late Stream<ParkingListState> _parking;
  late ScreenLoadReporter _screenLoad;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  void _startLoad({String trigger = 'initial'}) {
    _screenLoad = ScreenLoadReporter(
      widget.analytics,
      'parking_catalog',
      trigger: trigger,
    );
    _parking = _load();
  }

  Stream<ParkingListState> _load() async* {
    if (!widget.isOffline) {
      yield* widget.controller.watchParkingLots();
      return;
    }
    // Offline browsing must not wait for a remote request to fail first.
    final cached = await widget.controller.loadCachedParkingCatalog();
    yield ParkingListState(
      parkingLots: cached?.parkingLots,
      updatedAt: cached?.updatedAt,
      isFromCache: true,
    );
  }

  @override
  void didUpdateWidget(covariant ParkingCatalogList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.isOffline != widget.isOffline) {
      _screenLoad.cancel();
      _startLoad(trigger: 'refresh');
    }
  }

  void _refresh() {
    setState(() {
      _screenLoad.cancel();
      _startLoad(trigger: 'refresh');
    });
  }

  @override
  void dispose() {
    _screenLoad.cancel();
    super.dispose();
  }

  Map<String, String> _selection(Parking parking) => {
    'id': parking.id,
    'name': parking.name,
    'address': parking.address,
    'latitude': parking.latitude?.toString() ?? '',
    'longitude': parking.longitude?.toString() ?? '',
    'carSpaces': parking.availableCarSpaces.toString(),
    'motorcycleSpaces': parking.availableMotorcycleSpaces.toString(),
    'pricePerMinute': parking.pricePerMinute.toString(),
    'openingTime': parking.openingTime ?? '',
    'closingTime': parking.closingTime ?? '',
    'imageUrl': parking.imageUrl ?? '',
  };

  Widget _notice(String title, String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        const Icon(
          Icons.local_parking_rounded,
          size: 42,
          color: AppColors.primary,
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.greyText),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => StreamBuilder<ParkingListState>(
    stream: _parking,
    builder: (context, snapshot) {
      final state = snapshot.data;
      final lots = state?.parkingLots;
      final loading =
          !snapshot.hasError &&
          (snapshot.connectionState == ConnectionState.waiting ||
              state?.isRefreshing == true);
      if (lots != null) {
        _screenLoad.presented(
          context,
          source: state!.isFromCache ? 'sqlite' : 'network',
        );
      } else if (!loading) {
        _screenLoad.presented(context, source: 'none', failed: true);
      }
      return CustomScrollView(
        key: const PageStorageKey('home_parking_catalog'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Parking lots',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                  if (lots != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightPurple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${lots.length}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: _refresh,
                    tooltip: 'Refresh parking lots',
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (loading)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (lots != null && lots.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              sliver: SliverList.separated(
                itemCount: lots.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final parking = lots[index];
                  return ParkingCard(
                    name: parking.name,
                    address: parking.address,
                    type:
                        '${parking.carSpaces} car spaces · '
                        '${parking.motorcycleSpaces} motorcycle spaces',
                    onTap: () => widget.onSelectParking(_selection(parking)),
                  );
                },
              ),
            )
          else if (!loading)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: snapshot.hasError
                    ? _notice(
                        'Could not read saved parking lots',
                        'Please try again.',
                      )
                    : widget.isOffline
                    ? _notice(
                        'No parking lots saved yet',
                        'Connect once to download the parking list.',
                      )
                    : lots != null && lots.isEmpty
                    ? _notice('No parking lots available', 'Check back soon.')
                    : _notice(
                        'Could not load parking lots',
                        'Please try again later.',
                      ),
              ),
            ),
        ],
      );
    },
  );
}
