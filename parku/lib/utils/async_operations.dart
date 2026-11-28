import 'dart:async';

class SingleFlight<K extends Object, T> {
  final Map<K, Future<T>> _pending = {};

  Future<T> run(K key, Future<T> Function() operation) {
    final existing = _pending[key];
    if (existing != null) return existing;

    final completer = Completer<T>();
    final result = completer.future;
    _pending[key] = result;
    void release() {
      if (identical(_pending[key], result)) _pending.remove(key);
    }

    unawaited(
      Future<T>.sync(operation).then<void>(
        (value) {
          release();
          completer.complete(value);
        },
        onError: (Object error, StackTrace stackTrace) {
          release();
          completer.completeError(error, stackTrace);
        },
      ),
    );
    return result;
  }
}

class AsyncSerialExecutor {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final result = _tail.then<T>((_) => Future<T>.sync(operation));
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

class OperationCancelledException implements Exception {
  const OperationCancelledException();

  @override
  String toString() => 'Operation cancelled';
}

class CancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw const OperationCancelledException();
    }
  }
}
