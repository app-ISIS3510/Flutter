import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/controllers/profile_controller.dart';
import 'package:parku/models/parking_summary.dart';
import 'package:parku/repositories/session_history_repository.dart';
import 'package:parku/repositories/session_repository.dart';
import 'package:parku/screens/profile/parking_history_screen.dart';
import 'package:parku/screens/profile/profile_screen.dart';
import 'package:parku/services/profile_service.dart';
import 'package:parku/services/session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_user_repository.dart';
import 'support/memory_auth_storage.dart';

class FakeSessionHistory extends SessionHistoryRepository {
  List<ParkingSummary> summaries = [];
  Object? failure;

  FakeSessionHistory(super.client);

  @override
  Future<List<ParkingSummary>> getSavedSessions() async {
    if (failure != null) throw failure!;
    return summaries;
  }
}

void main() {
  late SupabaseClient client;
  late FakeSessionHistory history;
  late SessionService service;

  setUp(() {
    client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryAuthStorage(),
      ),
    );
    history = FakeSessionHistory(client);
    service = SessionService(
      SessionRepository(client),
      historyRepository: history,
    );
  });

  tearDown(() async => client.dispose());

  Widget historyPage() => MaterialApp(
    home: ParkingHistoryScreen(service: service, onNavTap: (_) {}),
  );

  testWidgets('saved parking explains the empty state', (tester) async {
    await tester.pumpWidget(historyPage());
    await tester.pumpAndSettle();

    expect(find.text('No saved parking yet'), findsOneWidget);
    expect(find.textContaining('Available without internet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved parking shows a stay on small and regular phones', (
    tester,
  ) async {
    history.summaries = [
      ParkingSummary(
        sessionId: 'session-1',
        userId: 'user-1',
        parkingId: 'parking-1',
        parkingName: 'City U Parking',
        vehicleType: 'car',
        vehiclePlate: 'ABC123',
        startedAt: DateTime.utc(2026, 10, 26, 16),
        pickupTime: DateTime.utc(2026, 10, 26, 17, 30),
        endedAt: DateTime.utc(2026, 10, 26, 17),
      ),
    ];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(historyPage());
      await tester.pumpAndSettle();

      expect(find.text('City U Parking'), findsOneWidget);
      expect(find.text('Car · ABC123'), findsOneWidget);
      expect(find.textContaining('Started:'), findsOneWidget);
      expect(find.textContaining('Ended:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a local read error can be retried', (tester) async {
    history.failure = const FileSystemException('Could not read file');
    await tester.pumpWidget(historyPage());
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not read your saved parking'),
      findsOneWidget,
    );

    history.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('No saved parking yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved parking stays accessible when the profile cannot load', (
    tester,
  ) async {
    final users = FakeUserRepository()
      ..failure = const SocketException('Offline');
    final controller = ProfileController(ProfileService(users));
    addTearDown(controller.dispose);
    var openedHistory = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          controller: controller,
          onNavTap: (_) {},
          onMyParking: () {},
          onAnalyticsDashboard: () {},
          onSignedOut: () {},
          onParkingHistory: () => openedHistory = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.profile, isNull);
    await tester.tap(find.text('Saved parking'));

    expect(openedHistory, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
