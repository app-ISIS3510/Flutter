import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/controllers/parking_controller.dart';
import 'package:parku/controllers/session_controller.dart';
import 'package:parku/models/parking.dart';
import 'package:parku/models/parking_catalog_snapshot.dart';
import 'package:parku/models/parking_session.dart';
import 'package:parku/repositories/parking_repository.dart';
import 'package:parku/repositories/session_repository.dart';
import 'package:parku/screens/home.dart';
import 'package:parku/services/connectivity_service.dart';
import 'package:parku/services/distance_manager.dart';
import 'package:parku/services/parking_service.dart';
import 'package:parku/services/session_service.dart';
import 'package:parku/state/parking_list_state.dart';
import 'package:parku/state/session_state.dart';
import 'package:parku/theme/app_theme.dart';
import 'package:parku/widgets/parking_card.dart';
import 'package:parku/widgets/parking_catalog_list.dart';
import 'package:parku/widgets/parking_map_panel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/offline_fakes.dart';
import 'support/parking_fakes.dart';

class HomeConnection extends ConnectivityService {
  bool online;
  final changes = StreamController<bool>.broadcast();
  HomeConnection(this.online);

  void change(bool value) {
    online = value;
    changes.add(value);
  }

  @override
  Future<bool?> connectionStatus() async => online;
  @override
  Stream<bool> get onNetworkChanged => changes.stream;
}

class CatalogController extends ParkingController {
  List<Parking>? cached;
  List<Parking> remote = [];
  int cacheReads = 0;
  int catalogReads = 0;

  CatalogController(SupabaseClient client)
    : super(ParkingService(ParkingRepository(client), DistanceManager()));

  @override
  Future<ParkingCatalogSnapshot?> loadCachedParkingCatalog() async {
    cacheReads++;
    return cached == null
        ? null
        : ParkingCatalogSnapshot(
            parkingLots: cached!,
            updatedAt: DateTime.utc(2026, 10, 30),
            isFromCache: true,
          );
  }

  @override
  Stream<ParkingListState> watchParkingLots() async* {
    catalogReads++;
    yield ParkingListState(parkingLots: remote);
  }

  @override
  Future<ParkingCatalogSnapshot> loadParkingCatalog() async {
    // The native map is outside this test. Exercise its inline fallback.
    throw StateError('Map unavailable in the test');
  }
}

class HomeSessions extends SessionController {
  ParkingSession? saved;
  HomeSessions(SupabaseClient client)
    : super(SessionService(SessionRepository(client)), SessionState());

  @override
  Future<ParkingSession?> loadActiveSession() async => null;
  @override
  Future<ParkingSession?> loadSavedActiveSession() async => saved;
}

void main() {
  late SupabaseClient client;
  late CatalogController parking;
  late HomeSessions sessions;
  late HomeConnection connection;
  late List<Parking> lots;
  Map<String, String>? selected;
  var openedMyParking = 0;
  final navigation = <int>[];

  setUp(() {
    client = offlineTestClient();
    parking = CatalogController(client);
    sessions = HomeSessions(client);
    connection = HomeConnection(false);
    lots = List.generate(
      12,
      (i) => Parking.fromMap(
        parkingData(id: 'lot-$i', name: 'Campus parking ${i + 1}'),
      ),
    );
    parking.cached = lots;
    parking.remote = lots;
    selected = null;
    openedMyParking = 0;
    navigation.clear();
  });

  tearDown(() async {
    sessions.dispose();
    await connection.changes.close();
    await client.dispose();
  });

  Widget app({double textScale = 1}) => MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: HomeScreen(
        currentIndex: 0,
        onNavTap: navigation.add,
        onOpenMyParking: () => openedMyParking++,
        onSelectParking: (value) => selected = value,
        parkingController: parking,
        sessionController: sessions,
        connectivityService: connection,
      ),
    ),
  );

  testWidgets(
    'offline home shows saved cards immediately and opens their details',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(textScale: 1.3));
      await tester.pumpAndSettle();
      expect(find.byType(ParkingCatalogList), findsOneWidget);
      expect(find.byType(ParkingMapPanel), findsNothing);
      expect(find.text('Map unavailable'), findsNothing);
      expect(find.byKey(const ValueKey('home_catalog_toggle')), findsNothing);
      expect(find.text('View my parking'), findsOneWidget);
      expect(parking.catalogReads, 0);
      await tester.ensureVisible(find.text('View my parking'));
      await tester.tap(find.text('View my parking'));
      expect(openedMyParking, 1);
      await tester.scrollUntilVisible(
        find.text('Campus parking 12'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Campus parking 12'));
      expect(selected?['id'], 'lot-11');
      expect(navigation, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'header opens the complete online catalog without changing tabs',
    (tester) async {
      connection.online = true;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('My parking'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('home_catalog_toggle')));
      await tester.pumpAndSettle();
      expect(find.byType(ParkingCatalogList), findsOneWidget);
      expect(find.byType(ParkingMapPanel), findsNothing);
      expect(find.byType(ParkingCard), findsWidgets);
      expect(navigation, isEmpty);
      await tester.tap(find.text('Campus parking 1'));
      expect(selected?['id'], 'lot-0');
      await tester.tap(find.byKey(const ValueKey('home_catalog_toggle')));
      await tester.pumpAndSettle();
      expect(find.byType(ParkingMapPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reconnecting restores the map and hides the offline parking shortcut',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home_catalog_toggle')), findsNothing);
      connection.change(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home_catalog_toggle')), findsOneWidget);
      expect(find.byType(ParkingMapPanel), findsOneWidget);
      connection.change(false);
      await tester.pumpAndSettle();
      expect(find.byType(ParkingMapPanel), findsNothing);
      expect(find.byKey(const ValueKey('home_catalog_toggle')), findsNothing);
      expect(find.text('View my parking'), findsOneWidget);
      expect(find.text('Campus parking 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'an empty offline cache explains how to get the list without remote requests',
    (tester) async {
      parking.cached = null;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        find.text('Connect once to download the parking list.'),
        findsOneWidget,
      );
      expect(find.byType(ParkingCard), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(parking.cacheReads, 2);
      expect(parking.catalogReads, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('the map card uses a purple action that opens My parking', (
    tester,
  ) async {
    connection.online = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final card = tester
        .widget<ParkingMapPanel>(find.byType(ParkingMapPanel))
        .activeParkingCard;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(ElevatedButton, 'View my parking');
    expect(
      tester.widget<ElevatedButton>(button).style!.backgroundColor!.resolve({}),
      AppColors.primary,
    );
    await tester.tap(button);
    expect(openedMyParking, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('offline saved session appears in a card below the catalog', (
    tester,
  ) async {
    sessions.saved = ParkingSession(
      id: 'stay-1',
      parkingId: 'lot-0',
      pickupTime: DateTime(2026, 10, 30, 18),
      startedAt: DateTime(2026, 10, 30, 16),
      status: 'active',
      isFromCache: true,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('MY PARKING'), findsOneWidget);
    expect(find.text('Last confirmed session'), findsOneWidget);
    expect(find.textContaining('Pick up at'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_catalog_toggle')), findsNothing);
    final button = find.widgetWithText(ElevatedButton, 'View my parking');
    expect(
      tester.getTopLeft(button).dy,
      greaterThan(tester.getBottomLeft(find.byType(ParkingCatalogList)).dy),
    );
    await tester.tap(button);
    expect(openedMyParking, 1);
    expect(parking.catalogReads, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
