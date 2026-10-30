import 'dart:async';

/// Shares only in-flight work. Success and failure both release the key,
/// so a subsequent explicit refresh always starts a new operation.
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

/// Runs state-dependent operations in order. An error reaches its caller but
/// does not prevent later operations from running.
class AsyncSerialExecutor {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final result = _tail.then<T>((_) => Future<T>.sync(operation));
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
