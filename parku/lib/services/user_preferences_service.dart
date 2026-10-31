import 'package:shared_preferences/shared_preferences.dart';

import '../models/navigation_provider.dart';

class UserPreferencesService {
  static const String _navigationProviderKey =
      'parku.preferred_navigation_provider';

  static const String _lastSyncTimeKey = 'parku.last_sync_time';

  final SharedPreferencesAsync _preferences;

  UserPreferencesService({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  Future<void> saveNavigationProvider(NavigationProvider provider) async {
    await _preferences.setString(
      _navigationProviderKey,
      provider.name,
    );
  }

  Future<NavigationProvider> getNavigationProvider() async {
    final saved = await _preferences.getString(_navigationProviderKey);

    for (final provider in NavigationProvider.values) {
      if (provider.name == saved) {
        return provider;
      }
    }

    return NavigationProvider.googleMaps;
  }

  Future<void> saveLastSyncTime(DateTime timestamp) async {
    await _preferences.setString(
      _lastSyncTimeKey,
      timestamp.toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> getLastSyncTime() async {
    final saved = await _preferences.getString(_lastSyncTimeKey);

    if (saved == null) return null;

    return DateTime.tryParse(saved);
  }
}