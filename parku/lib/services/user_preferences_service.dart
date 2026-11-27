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

  String _parkingBudgetKey(String userId) =>
      'parku.parking_budget.${Uri.encodeComponent(userId)}';

  Future<void> saveParkingBudget(
    String userId, {
    required int minutes,
    required int budget,
  }) {
    return _preferences.setStringList(_parkingBudgetKey(userId), [
      minutes.toString(),
      budget.toString(),
    ]);
  }

  Future<({int minutes, int budget})?> getParkingBudget(String userId) async {
    final saved = await _preferences.getStringList(_parkingBudgetKey(userId));
    if (saved == null || saved.length != 2) return null;

    final minutes = int.tryParse(saved[0], radix: 10);
    final budget = int.tryParse(saved[1], radix: 10);
    if (minutes == null || minutes <= 0 || budget == null || budget < 0) {
      return null;
    }
    return (minutes: minutes, budget: budget);
  }
}
