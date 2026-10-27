import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../services/connection_failure.dart';

class ConnectionController extends ChangeNotifier {
  final Future<void> Function() onReconnect;
  final Stream<List<ConnectivityResult>> changes;
  final Future<List<ConnectivityResult>> Function() checkConnection;
  final Duration delay;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _timer;
  final _closed = Completer<List<ConnectivityResult>>();
  bool? hasNetwork;
  bool checking = false;
  String? error;
  bool _checkAgain = false;
  bool _disposed = false;
  int _events = 0;

  ConnectionController({
    required this.onReconnect,
    Stream<List<ConnectivityResult>>? changes,
    Future<List<ConnectivityResult>> Function()? checkConnection,
    this.delay = const Duration(milliseconds: 400),
  }) : changes = changes ?? Connectivity().onConnectivityChanged,
       checkConnection = checkConnection ?? Connectivity().checkConnectivity;

  String? get notice {
    if (error != null) return error;
    if (hasNetwork == false) {
      return 'No network connection. Saved information may be out of date.';
    }
    if (checking) {
      return 'Network available. Checking your saved information...';
    }
    return null;
  }

  Future<void> start() async {
    if (_disposed || _subscription != null) return;
    _subscription = changes.listen(
      _receive,
      onError: (Object _) {
        if (_disposed) return;
        _events++;
        error =
            'Could not monitor the connection. You can still refresh manually.';
        notifyListeners();
      },
    );
    await recheck();
  }

  void _receive(List<ConnectivityResult> results) {
    if (_disposed) return;
    _events++;
    final available = results.any(
      (result) => result != ConnectivityResult.none,
    );
    if (available == hasNetwork) return;
    hasNetwork = available;
    error = null;
    if (available) {
      _schedule();
    } else {
      _timer?.cancel();
      _checkAgain = false;
    }
    notifyListeners();
  }

  Future<void> recheck({bool refresh = false}) async {
    final version = _events;
    try {
      final results = await Future.any([checkConnection(), _closed.future])
          .timeout(const Duration(seconds: 4));
      if (_disposed || version != _events) return;
      _receive(results);
      if (refresh && hasNetwork == true) _schedule();
    } catch (_) {
      if (_disposed || version != _events) return;
      error = 'Could not check the connection. You can still refresh manually.';
      notifyListeners();
    }
  }

  void _schedule() {
    if (_disposed || hasNetwork != true) return;
    if (checking) {
      _checkAgain = true;
      return;
    }
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(_refresh()));
  }

  Future<void> _refresh() async {
    if (_disposed || hasNetwork != true) return;
    checking = true;
    error = null;
    notifyListeners();
    try {
      await onReconnect();
    } catch (failure) {
      if (!_disposed) {
        error = failure is ConnectionFailure ? failure.message : 'Could not reach the server. Your last confirmed data has been kept. Refresh to retry.';
      }
    } finally {
      if (!_disposed) {
        checking = false;
        notifyListeners();
        if (_checkAgain) {
          _checkAgain = false;
          _schedule();
        }
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _closed.complete([]);
    _timer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
