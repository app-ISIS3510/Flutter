import 'dart:async';
import 'dart:io';

import 'package:parku/utils/async_operations.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<Object> failureOf(Future<Object?> future) async {
  try {
    await future;
  } catch (error) {
    return error;
  }
  throw StateError('Expected the operation to fail.');
}

Future<void> main() async {
  final reads = SingleFlight<String, int>();
  final response = Completer<int>();
  var requests = 0;
  final callers = List.generate(
    100,
    (_) => reads.run('parking', () {
      requests++;
      return response.future;
    }),
  );
  check(requests == 1, 'Concurrent readers must share one request.');
  check(
    callers.every((future) => identical(future, callers.first)),
    'Readers must receive the same pending Future.',
  );
  var independentStarted = false;
  final independent = reads.run('other parking', () async {
    independentStarted = true;
    return 20;
  });
  check(independentStarted, 'Different keys must start independently.');
  response.complete(7);
  check(
    (await Future.wait(callers)).every((value) => value == 7),
    'Every reader must receive the response.',
  );
  check(await independent == 20, 'Independent results must be preserved.');
  check(
    await reads.run('parking', () async => ++requests) == 2,
    'A completed request must not prevent an explicit refresh.',
  );

  final failedResponse = Completer<int>();
  final error = StateError('Network failed');
  final failed = reads.run('failure', () => failedResponse.future);
  final firstFailure = failureOf(failed);
  final secondFailure = failureOf(reads.run('failure', () async => 999));
  failedResponse.completeError(error, StackTrace.current);
  check(
    identical(await firstFailure, error) &&
        identical(await secondFailure, error),
    'All pending readers must receive the original error.',
  );
  check(
    await reads.run('failure', () async => 3) == 3,
    'A failed request must release its key for retry.',
  );

  final synchronousError = StateError('Synchronous failure');
  final failedSynchronously = reads.run('sync', () => throw synchronousError);
  check(
    identical(await failureOf(failedSynchronously), synchronousError),
    'Synchronous exceptions must be delivered through the Future.',
  );
  check(
    await reads.run('sync', () async => 4) == 4,
    'A synchronous failure must also release its key.',
  );

  Future<int>? reentrant;
  final outer = reads.run('reentrant', () {
    reentrant = reads.run('reentrant', () async => 999);
    return Future.value(8);
  });
  check(
    identical(reentrant, outer) && await outer == 8,
    'Synchronous reentry must see the already registered request.',
  );

  final writes = AsyncSerialExecutor();
  final firstGate = Completer<int>();
  final started = <int>[];
  final first = writes.run(() {
    started.add(1);
    return firstGate.future;
  });
  final second = writes.run(() async {
    started.add(2);
    return 2;
  });
  await Future<void>.delayed(Duration.zero);
  check(
    started.join(',') == '1',
    'A second operation must wait for the first to finish.',
  );
  firstGate.complete(1);
  check(
    (await Future.wait([first, second])).join(',') == '1,2' &&
        started.join(',') == '1,2',
    'Operations must finish in submission order.',
  );

  final writeError = StateError('Write failed');
  final writeGate = Completer<int>();
  final failedWrite = failureOf(writes.run(() => writeGate.future));
  final nextWrite = writes.run(() async => 5);
  writeGate.completeError(writeError, StackTrace.current);
  check(
    identical(await failedWrite, writeError) && await nextWrite == 5,
    'An asynchronous error must not block subsequent operations.',
  );
  final syncWrite = failureOf(writes.run<int>(() => throw synchronousError));
  final afterSyncWrite = writes.run(() async => 6);
  check(
    identical(await syncWrite, synchronousError) && await afterSyncWrite == 6,
    'A synchronous error must not break the serial queue.',
  );

  var active = 0;
  final order = <int>[];
  final queued = List.generate(
    100,
    (index) => writes.run(() async {
      active++;
      check(active == 1, 'Serial operations must never overlap.');
      await Future<void>.delayed(Duration.zero);
      order.add(index);
      active--;
      return index;
    }),
  );
  final results = await Future.wait(queued);
  check(
    order.length == 100 &&
        active == 0 &&
        List.generate(
          100,
          (index) => order[index] == index && results[index] == index,
        ).every((matches) => matches),
    'All queued operations and results must preserve FIFO order.',
  );

  stdout.writeln(
    'Async operations checks passed: shared reads, retries, errors, reentry, and 100 ordered operations.',
  );
}
