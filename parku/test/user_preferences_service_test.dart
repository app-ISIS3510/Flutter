import 'package:flutter_test/flutter_test.dart';
import 'package:parku/models/navigation_provider.dart';
import 'package:parku/services/user_preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('Google Maps is the default navigation provider', () async {
    final service = UserPreferencesService();

    expect(
      await service.getNavigationProvider(),
      NavigationProvider.googleMaps,
    );
  });

  test('Saves and retrieves Waze', () async {
    final service = UserPreferencesService();

    await service.saveNavigationProvider(NavigationProvider.waze);

    final anotherService = UserPreferencesService();

    expect(
      await anotherService.getNavigationProvider(),
      NavigationProvider.waze,
    );
  });

  test('Updates preferred navigation provider', () async {
    final service = UserPreferencesService();

    await service.saveNavigationProvider(NavigationProvider.waze);
    await service.saveNavigationProvider(NavigationProvider.googleMaps);

    expect(
      await service.getNavigationProvider(),
      NavigationProvider.googleMaps,
    );
  });

  test('Returns null when no synchronization has occurred', () async {
    final service = UserPreferencesService();

    expect(await service.getLastSyncTime(), isNull);
  });

  test('Saves and retrieves last synchronization time', () async {
    final service = UserPreferencesService();
    final timestamp = DateTime.utc(2026, 10, 30, 18, 30);

    await service.saveLastSyncTime(timestamp);

    final anotherService = UserPreferencesService();

    expect(await anotherService.getLastSyncTime(), timestamp);
  });
}
