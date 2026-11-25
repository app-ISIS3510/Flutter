import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../data/local/parking_comparison_store.dart';
import '../data/memory/lfu_cache.dart';
import '../models/compared_parking.dart';
import '../models/parking.dart';

class ParkingComparisonController extends ChangeNotifier {
  static const minSelection = 2;
  static const maxSelection = 3;
  static const _cacheLifetime = Duration(seconds: 60);

  final ParkingComparisonStore? store;
  final DateTime Function() _now;
  final _selection = <String, ComparedParking>{};
  final _cache = LfuCache<String, ComparedParking>(8);
  final _work = _ParkingWorkQueue();

  String? _owner;
  int _accountVersion = 0;
  bool _disposed = false;
  bool _restoring = false;
  String? _storageError;
  Future<void> _writes = Future<void>.value();

  ParkingComparisonController({this.store, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  List<ComparedParking> get selection => List.unmodifiable(_selection.values);
  int get count => _selection.length;
  bool get canCompare => count >= minSelection;
  bool get hasCapacity => !_restoring && count < maxSelection;
  bool get restoring => _restoring;
  String? get storageError => _storageError;

  bool contains(String id) => _selection.containsKey(id);

  Future<void> setAccount(String? owner) async {
    if (_disposed || owner == _owner) return;
    final version = ++_accountVersion;
    final localStore = store;
    _owner = owner;
    _selection.clear();
    _cache.clear();
    _storageError = null;
    _restoring = owner != null && localStore != null;
    notifyListeners();

    if (owner == null || localStore == null) return;
    try {
      await _writes;
      if (!_isCurrent(version)) return;
      final saved = await localStore.read(owner);
      if (!_isCurrent(version)) return;
      for (final item in saved.take(maxSelection)) {
        _selection[item.parking.id] = item;
      }
    } catch (error, stack) {
      developer.log(
        'Could not restore parking comparison',
        error: error,
        stackTrace: stack,
      );
      if (_isCurrent(version)) {
        _storageError = 'Could not load the saved comparison.';
      }
    } finally {
      if (_isCurrent(version)) {
        _restoring = false;
        notifyListeners();
      }
    }
  }

  void toggle(
    Parking parking, {
    DateTime? updatedAt,
    bool isFromCache = false,
  }) {
    if (contains(parking.id)) {
      remove(parking.id);
    } else if (hasCapacity) {
      _selection[parking.id] = ComparedParking(
        parking,
        updatedAt: updatedAt,
        isFromCache: isFromCache,
      );
      _saveSelection();
      notifyListeners();
    }
  }

  void remove(String id) {
    if (_selection.remove(id) == null) return;
    _saveSelection();
    notifyListeners();
  }

  void _saveSelection() {
    final localStore = store;
    final owner = _owner;
    if (localStore == null || owner == null) return;
    final version = _accountVersion;
    final snapshot = selection;

    _writes = _writes.then((_) async {
      try {
        await localStore.write(owner, snapshot);
        if (_isCurrent(version) && _storageError != null) {
          _storageError = null;
          notifyListeners();
        }
      } catch (error, stack) {
        developer.log(
          'Could not save parking comparison',
          error: error,
          stackTrace: stack,
        );
        if (_isCurrent(version)) {
          _storageError = 'Could not save this comparison on this device.';
          notifyListeners();
        }
      }
    });
  }

  Future<bool> refresh({
    required Future<Parking?> Function(String id) loadParking,
    required bool Function() shouldContinue,
    bool force = false,
  }) async {
    final version = _accountVersion;
    bool isCurrent() => _isCurrent(version) && shouldContinue();
    if (!isCurrent()) return true;

    final work = [
      for (final item in selection)
        _refreshParking(item, loadParking, isCurrent, force: force),
    ];
    final results = await Future.wait(work);
    if (isCurrent() && results.contains(_RefreshResult.updated)) {
      _saveSelection();
    }
    return !results.contains(_RefreshResult.failed);
  }

  Future<_RefreshResult> _refreshParking(
    ComparedParking item,
    Future<Parking?> Function(String) loadParking,
    bool Function() isCurrent, {
    required bool force,
  }) async {
    final id = item.parking.id;
    bool canApply() => isCurrent() && identical(_selection[id], item);
    if (!canApply()) return _RefreshResult.skipped;

    if (!force) {
      final cached = _cache.get(id);
      if (cached != null) {
        final age = _now().difference(cached.updatedAt!);
        if (!age.isNegative &&
            age < _cacheLifetime &&
            (item.updatedAt == null ||
                !cached.updatedAt!.isBefore(item.updatedAt!))) {
          if (identical(cached, item)) return _RefreshResult.skipped;
          _selection[id] = cached;
          notifyListeners();
          return _RefreshResult.updated;
        }
      }
    }

    return _work.add(() async {
      if (!canApply()) return _RefreshResult.skipped;
      try {
        final parking = await loadParking(id);
        if (!canApply()) return _RefreshResult.skipped;

        final updated = ComparedParking(
          parking ?? item.parking,
          updatedAt: _now().toUtc(),
          isUnavailable: parking == null,
        );
        if (parking == null) {
          _cache.remove(id);
        } else {
          _cache.put(id, updated);
        }
        _selection[id] = updated;
        notifyListeners();
        return _RefreshResult.updated;
      } catch (error, stack) {
        if (!canApply()) return _RefreshResult.skipped;
        developer.log(
          'Could not refresh compared parking',
          error: error,
          stackTrace: stack,
        );
        _selection[id] = ComparedParking(
          item.parking,
          updatedAt: item.updatedAt,
          isFromCache: true,
          isUnavailable: item.isUnavailable,
        );
        notifyListeners();
        return _RefreshResult.failed;
      }
    });
  }

  bool _isCurrent(int version) => !_disposed && version == _accountVersion;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

enum _RefreshResult { updated, skipped, failed }

class _ParkingWorkQueue {
  static const _maxWorkers = 2;
  final _pending = Queue<Future<void> Function()>();
  int _workers = 0;

  Future<_RefreshResult> add(Future<_RefreshResult> Function() task) {
    final result = Completer<_RefreshResult>();
    _pending.addLast(() async {
      try {
        result.complete(await task());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    if (_workers < _maxWorkers) unawaited(_runWorker());
    return result.future;
  }

  Future<void> _runWorker() async {
    _workers++;
    try {
      while (_pending.isNotEmpty) {
        await _pending.removeFirst()();
      }
    } finally {
      _workers--;
    }
  }
}
