import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parku/models/most_used_parking.dart';
import 'package:parku/repositories/parking_repository.dart';
import 'package:parku/repositories/user_local_store.dart';
import 'package:parku/services/connectivity_service.dart';
import 'package:parku/services/distance_manager.dart';
import 'package:parku/services/parking_service.dart';
import 'package:parku/utils/error_messages.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/offline_fakes.dart' show offlineTestClient, signInAs;

class RankingRepository extends ParkingRepository {
  RankingRepository(super.client);

  List<MostUsedParking> ranking = [
    const MostUsedParking(
      parkingId: 'lot-1',
      parkingName: 'City U Parking',
      completedSessions: 8,
    ),
  ];
  Object? error;
  Completer<void>? gate;
  Completer<void>? received;
  int calls = 0;

  @override
  Future<List<MostUsedParking>> getMostUsedParkingLots() async {
    calls++;
    if (received != null && !received!.isCompleted) received!.complete();
    await gate?.future;
    if (error != null) throw error!;
    return List.of(ranking);
  }
}

class RankingConnectivity extends ConnectivityService {
  bool? connected = true;

  @override
  Future<bool?> connectionStatus() async => connected;
}

class UnwritableRankingStore extends UserLocalStore {
  UnwritableRankingStore(super.client);

  @override
  Future<void> write(String key, Map<String, dynamic> data) async {
    throw const FileSystemException('Storage unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SupabaseClient client;
  late RankingRepository repository;
  late RankingConnectivity connectivity;
  late ParkingService service;

  UserLocalStore store() =>
      UserLocalStore(client, getDirectory: () async => directory);

  ParkingService reopen({UserLocalStore? localStore}) => ParkingService(
    repository,
    DistanceManager(),
    store: localStore ?? store(),
    connectivityService: connectivity,
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('parku-ranking-');
    client = offlineTestClient();
    await signInAs(client, 'user-1');
    repository = RankingRepository(client);
    connectivity = RankingConnectivity();
    service = reopen();
  });

  tearDown(() async {
    await client.dispose();
    await directory.delete(recursive: true);
  });

  test('the result and original date survive reopening offline', () async {
    final live = await service.getMostUsedParkingRanking();
    connectivity.connected = false;
    final cached = await reopen().getMostUsedParkingRanking();
    expect(live.isFromCache, isFalse);
    expect(cached.isFromCache, isTrue);
    expect(cached.parkingLots.single.parkingId, 'lot-1');
    expect(cached.parkingLots.single.completedSessions, 8);
    expect(cached.updatedAt, live.updatedAt);
    expect(repository.calls, 1);
    final saved = (await store().read('most_used_parking_ranking'))!;
    expect(saved.keys.toSet(), {'parking_lots', 'updated_at'});
  });

  test(
    'the browser also keeps the ranking after recreating the store',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      UserLocalStore browserStore() =>
          UserLocalStore(client, browserPreferences: preferences);
      final live = await reopen(localStore: browserStore())
          .getMostUsedParkingRanking();
      connectivity.connected = false;
      final cached = await reopen(localStore: browserStore())
          .getMostUsedParkingRanking();
      expect(cached.isFromCache, isTrue);
      expect(cached.updatedAt, live.updatedAt);
      expect(cached.parkingLots.single.completedSessions, 8);
    },
  );

  test('an offline first visit does not invent a ranking', () async {
    connectivity.connected = false;
    await expectLater(
      service.getMostUsedParkingRanking(),
      throwsA(isA<OfflineActionException>()),
    );
    expect(repository.calls, 0);
  });

  for (final error in [
    const SocketException('No internet despite Wi-Fi'),
    TimeoutException('The server did not answer'),
    const PostgrestException(message: 'Unavailable', code: '503'),
  ]) {
    test('a connection failure uses saved data: $error', () async {
      final live = await service.getMostUsedParkingRanking();
      repository.error = error;
      final cached = await service.getMostUsedParkingRanking();
      expect(cached.isFromCache, isTrue);
      expect(cached.updatedAt, live.updatedAt);
      expect(cached.parkingLots.single.completedSessions, 8);
    });
  }

  test('an unknown connection status still tries the server', () async {
    connectivity.connected = null;
    final result = await service.getMostUsedParkingRanking();
    expect(result.isFromCache, isFalse);
    expect(repository.calls, 1);
  });

  test('a refreshed empty week replaces an older populated ranking', () async {
    await service.getMostUsedParkingRanking();
    repository.ranking = [];
    final empty = await service.getMostUsedParkingRanking();
    connectivity.connected = false;
    final cached = await reopen().getMostUsedParkingRanking();
    expect(empty.parkingLots, isEmpty);
    expect(cached.parkingLots, isEmpty);
    expect(cached.updatedAt, empty.updatedAt);
    expect(cached.isFromCache, isTrue);
  });

  test('reconnecting refreshes the saved names, counts and order', () async {
    await service.getMostUsedParkingRanking();
    repository.ranking = [
      const MostUsedParking(
        parkingId: 'lot-2',
        parkingName: 'MetroPark Center',
        completedSessions: 15,
      ),
      const MostUsedParking(
        parkingId: 'lot-1',
        parkingName: 'City U Parking',
        completedSessions: 9,
      ),
    ];
    final refreshed = await service.getMostUsedParkingRanking();
    connectivity.connected = false;
    final cached = await reopen().getMostUsedParkingRanking();
    expect(refreshed.isFromCache, isFalse);
    expect(cached.parkingLots.map((lot) => lot.parkingId), ['lot-2', 'lot-1']);
    expect(cached.parkingLots.map((lot) => lot.completedSessions), [15, 9]);
    expect(cached.updatedAt, refreshed.updatedAt);
  });

  test('accounts cannot read each other saved ranking', () async {
    await service.getMostUsedParkingRanking();
    await signInAs(client, 'user-2');
    connectivity.connected = false;
    await expectLater(
      service.getMostUsedParkingRanking(),
      throwsA(isA<OfflineActionException>()),
    );
    await signInAs(client, 'user-1');
    expect((await service.getMostUsedParkingRanking()).parkingLots.length, 1);
  });

  test(
    'a late response cannot be returned or saved for another account',
    () async {
      repository.gate = Completer<void>();
      repository.received = Completer<void>();
      final loading = service.getMostUsedParkingRanking();
      await repository.received!.future;
      await signInAs(client, 'user-2');
      final failure = expectLater(loading, throwsA(isA<AuthException>()));
      repository.gate!.complete();
      await failure;
      expect(await store().read('most_used_parking_ranking'), isNull);
      await signInAs(client, 'user-1');
      expect(await store().read('most_used_parking_ranking'), isNull);
    },
  );

  test(
    'simultaneous refreshes share a request, a later refresh is new',
    () async {
      repository.gate = Completer<void>();
      repository.received = Completer<void>();
      final first = service.getMostUsedParkingRanking();
      final second = service.getMostUsedParkingRanking();
      await repository.received!.future;
      expect(repository.calls, 1);
      repository.gate!.complete();
      final results = await Future.wait([first, second]);
      expect(results[0].updatedAt, results[1].updatedAt);
      await service.getMostUsedParkingRanking();
      expect(repository.calls, 2);
    },
  );

  test('permission errors do not silently return an old ranking', () async {
    await service.getMostUsedParkingRanking();
    repository.error = const PostgrestException(
      message: 'Permission denied',
      code: '42501',
    );
    await expectLater(
      service.getMostUsedParkingRanking(),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('a failed local write does not hide the server result', () async {
    final result = await reopen(localStore: UnwritableRankingStore(client))
        .getMostUsedParkingRanking();
    expect(result.isFromCache, isFalse);
    expect(result.parkingLots.single.completedSessions, 8);
  });

  test(
    'invalid saved data gives an error and can be replaced online',
    () async {
      await store().write('most_used_parking_ranking', {
        'updated_at': '2026-10-31T12:00:00Z',
        'parking_lots': [
          {
            'parking_id': 'lot-1',
            'parking_name': 'City U Parking',
            'completed_sessions': -2,
          },
        ],
      });
      connectivity.connected = false;
      await expectLater(
        service.getMostUsedParkingRanking(),
        throwsA(isA<FormatException>()),
      );
      connectivity.connected = true;
      expect((await service.getMostUsedParkingRanking()).isFromCache, isFalse);
      connectivity.connected = false;
      expect(
        (await service.getMostUsedParkingRanking())
            .parkingLots
            .single
            .completedSessions,
        8,
      );
    },
  );

  test('a signed-out account does not read or fetch a ranking', () async {
    final guest = offlineTestClient();
    try {
      await expectLater(
        ParkingService(
          RankingRepository(guest),
          DistanceManager(),
        ).getMostUsedParkingRanking(),
        throwsA(isA<AuthException>()),
      );
    } finally {
      await guest.dispose();
    }
  });
}
