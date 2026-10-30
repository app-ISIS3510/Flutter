import 'package:connectivity_plus/connectivity_plus.dart';

import '../utils/error_messages.dart';

class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  bool _hasNetwork(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<bool> hasNetworkConnection() async {
    final results = await _connectivity.checkConnectivity();
    return _hasNetwork(results);
  }

  /// A missing plugin or failed check is unknown, not proof of being offline.
  Future<bool?> connectionStatus() async {
    try {
      return await hasNetworkConnection().timeout(const Duration(seconds: 1));
    } catch (_) {
      return null;
    }
  }

  Future<void> requireConnection() async {
    if (await connectionStatus() == false) {
      throw const OfflineActionException();
    }
  }

  Stream<bool> get onNetworkChanged {
    return _connectivity.onConnectivityChanged.map(_hasNetwork).distinct();
  }
}
