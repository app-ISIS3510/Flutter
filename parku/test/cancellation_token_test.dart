import 'package:flutter_test/flutter_test.dart';
import 'package:parku/utils/async_operations.dart';

void main() {
  group('CancellationToken', () {
    test('starts in a non-cancelled state', () {
      final token = CancellationToken();

      expect(token.isCancelled, isFalse);
      expect(token.throwIfCancelled, returnsNormally);
    });

    test('marks the operation as cancelled', () {
      final token = CancellationToken();

      token.cancel();

      expect(token.isCancelled, isTrue);
    });

    test('throws when reaching a cancelled checkpoint', () {
      final token = CancellationToken();

      token.cancel();

      expect(
        token.throwIfCancelled,
        throwsA(isA<OperationCancelledException>()),
      );
    });

    test('supports repeated cancellation safely', () {
      final token = CancellationToken();

      token.cancel();
      token.cancel();

      expect(token.isCancelled, isTrue);
    });

    test('cancellation does not affect independent requests', () {
      final previousToken = CancellationToken();
      final latestToken = CancellationToken();

      previousToken.cancel();

      expect(previousToken.isCancelled, isTrue);
      expect(latestToken.isCancelled, isFalse);
      expect(latestToken.throwIfCancelled, returnsNormally);
    });
  });
}
