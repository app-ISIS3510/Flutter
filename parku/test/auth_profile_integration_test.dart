import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/main.dart';
import 'package:parku/screens/sign_in.dart';
import 'package:parku/screens/profile/edit_profile_screen.dart';
import 'package:parku/screens/profile/vehicles_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/memory_auth_storage.dart';
import 'support/parking_fakes.dart';

import 'package:parku/services/profile_service.dart';
import 'package:parku/repositories/user_repository.dart';
import 'package:parku/repositories/user_local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var parkingAvailable = false;
  List<Map<String, dynamic>> vehicles = [];
  setUp(() async {
    parkingAvailable = false;
    vehicles = [];
    final user = {
      'id': 'user-1',
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'juan@example.com',
      'created_at': '2026-09-01T00:00:00Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata': {'full_name': 'Juan'},
    };
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'sub': 'user-1',
              'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
            }),
          ),
        )
        .replaceAll('=', '');
    await Supabase.initialize(
      url: 'https://test.invalid',
      publishableKey: 'test-key',
      debug: false,
      authOptions: FlutterAuthClientOptions(
        pkceAsyncStorage: MemoryAuthStorage(),
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUri: false,
        authFlowType: AuthFlowType.implicit,
      ),
      httpClient: MockClient((request) async {
        Object body = {};
        int status = 200;
        switch (request.url.path) {
          case '/auth/v1/token':
            body = {
              'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
              'refresh_token': 'test-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': user,
            };
          case '/auth/v1/user':
            body = user;
          case '/rest/v1/vehicles':
            body = vehicles;
          case '/rest/v1/parking_sessions':
          case '/rest/v1/app_admins':
            body = [];
          case '/rest/v1/parking_lots_with_availability':
            if (parkingAvailable) {
              body = [parkingData()];
            } else {
              status = 400;
              body = {'message': 'Map unavailable in this test'};
            }
          case '/auth/v1/logout':
            body = {};
          default:
            throw StateError('Unexpected request: ${request.url.path}');
        }
        return http.Response(
          jsonEncode(body),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDown(() async => Supabase.instance.dispose());

  Widget app() {
    final client = Supabase.instance.client;
    return ParkUApp(
      profileService: ProfileService(
        SupabaseUserRepository(client),
        store: UserLocalStore.memory(client),
      ),
    );
  }

  testWidgets(
    'search loads the saved vehicle and reads it again when reopened',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final originalPlatform = GeolocatorPlatform.instance;
      final location = FakeLocationPlatform();
      GeolocatorPlatform.instance = location;
      addTearDown(() => GeolocatorPlatform.instance = originalPlatform);
      vehicles = [
        {
          'id': 'car-1',
          'vehicle_type': 'car',
          'plate': 'ABC123',
          'is_selected': true,
        },
      ];

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'juan@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'test-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      parkingAvailable = true;
      await tester.tap(find.text('Parking lots'));
      await tester.pumpAndSettle();
      final previousLocationCalls = location.positionCalls;
      await tester.tap(find.text('Search parking lots'));
      await tester.pumpAndSettle();
      expect(find.text('Availability for your car · ABC123'), findsOneWidget);
      expect(find.text('8 estimated spaces · 40% of capacity'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      vehicles = [
        {
          'id': 'moto-1',
          'vehicle_type': 'motorcycle',
          'plate': 'XYZ45D',
          'is_selected': true,
        },
      ];
      await tester.tap(find.text('Search parking lots'));
      await tester.pumpAndSettle();
      expect(
        find.text('Availability for your motorcycle · XYZ45D'),
        findsOneWidget,
      );
      expect(find.text('7 estimated spaces · 70% of capacity'), findsOneWidget);
      expect(location.positionCalls - previousLocationCalls, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'sign in opens the complete profile and sign out returns to login',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'juan@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'test-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Juan'), findsOneWidget);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My vehicles'));
      await tester.pumpAndSettle();
      expect(find.byType(VehiclesScreen), findsOneWidget);
      expect(find.text('Add your first vehicle'), findsOneWidget);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sign out'));
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(
        Supabase.instance.client.auth.currentUser,
        isNull,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '),
      );
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
