import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parku/data/local/app_database.dart';
import 'package:parku/data/local/favorite_local_data_source.dart';
import 'package:parku/models/parking.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/parking_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory directory;
  late AppDatabase database;
  late FavoriteLocalDataSource local;

  final parking = Parking.fromMap(parkingData());

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'parku-offline-favorites-',
    );

    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/favorites.db',
    );

    local = FavoriteLocalDataSource(database: database);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('stores favorites locally and restores them after reopening', () async {
    await local.saveSnapshot('user-1', [
      parking,
    ], requestedAt: DateTime.now().toUtc());

    final saved = await local.read('user-1');

    expect(saved, isNotNull);
    expect(saved!.isFromCache, isTrue);
    expect(saved.favorites, hasLength(1));
    expect(saved.favorites.single.id, parking.id);
    expect(saved.pendingCount, 0);

    await database.close();

    final reopenedDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/favorites.db',
    );

    final reopened = FavoriteLocalDataSource(database: reopenedDatabase);

    final restored = await reopened.read('user-1');

    expect(restored, isNotNull);
    expect(restored!.favorites.single.id, parking.id);
    expect(restored.isFromCache, isTrue);

    await reopenedDatabase.close();
  });

  test('removing a favorite offline creates a pending action', () async {
    await local.saveSnapshot('user-1', [
      parking,
    ], requestedAt: DateTime.now().toUtc());

    await local.setDesired('user-1', parking.id, false, parking);

    final saved = await local.read('user-1');
    final pending = await local.due('user-1');

    expect(saved!.favorites, isEmpty);
    expect(saved.pendingCount, 1);
    expect(pending, hasLength(1));
    expect(pending.single['parking_id'], parking.id);
    expect(pending.single['desired_state'], 0);
  });

  test('acknowledging a synchronized action clears the queue', () async {
    await local.setDesired('user-1', parking.id, true, parking);

    final pending = await local.due('user-1');

    expect(pending, hasLength(1));

    await local.acknowledge(pending.single['action_id'] as String, 'user-1');

    final saved = await local.read('user-1');

    expect(saved!.favorites, hasLength(1));
    expect(saved.pendingCount, 0);
    expect(await local.due('user-1'), isEmpty);
  });

  test('failed actions remain stored for a later retry', () async {
    await local.setDesired('user-1', parking.id, true, parking);

    final pending = await local.due('user-1');
    final actionId = pending.single['action_id'] as String;

    await local.postpone(actionId, 0);

    final saved = await local.read('user-1');

    expect(saved!.pendingCount, 1);
    expect(saved.favorites.single.id, parking.id);

    // The action remains stored, but is not due immediately.
    expect(await local.due('user-1'), isEmpty);

    final rows = await (await database.database).query(
      'pending_favorite_actions',
      where: 'action_id = ?',
      whereArgs: [actionId],
    );

    expect(rows, hasLength(1));
    expect(rows.single['attempt_count'], 1);
    expect(
      rows.single['next_attempt_ms'] as int,
      greaterThan(DateTime.now().millisecondsSinceEpoch),
    );
  });

  test('keeps favorite data separated by user', () async {
    await local.setDesired('user-1', parking.id, true, parking);

    final firstUser = await local.read('user-1');
    final secondUser = await local.read('user-2');

    expect(firstUser!.favorites, hasLength(1));
    expect(firstUser.pendingCount, 1);
    expect(secondUser, isNull);
    expect(await local.due('user-2'), isEmpty);
  });

  test('keeps only the latest pending action for each parking', () async {
    await local.setDesired('user-1', parking.id, true, parking);
    await local.setDesired('user-1', parking.id, false, parking);
    await local.setDesired('user-1', parking.id, true, parking);

    final pending = await local.due('user-1');
    final saved = await local.read('user-1');

    expect(pending, hasLength(1));
    expect(pending.single['desired_state'], 1);
    expect(saved!.favorites, hasLength(1));
    expect(saved.pendingCount, 1);
  });
}
