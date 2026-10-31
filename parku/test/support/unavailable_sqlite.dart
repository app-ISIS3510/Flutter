import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
// sqflite's factory must implement its plugin protocol, not only DatabaseFactory.
// ignore: implementation_imports
import 'package:sqflite/src/factory_impl.dart';

/// Exercises remote UI flows when disk storage is unavailable. These tests use
/// explicit memory stores for profile/session recovery; SQLite persistence is
/// covered separately. A fresh factory keeps locks out of previous FakeAsync
/// zones and never opens the developer's database.
void useUnavailableSqlite() {
  final previous = databaseFactoryOrNull;
  databaseFactoryOrNull = _UnavailableDatabaseFactory();
  addTearDown(() => databaseFactoryOrNull = previous);
}

class _UnavailableDatabaseFactory extends SqfliteDatabaseFactoryImpl {
  @override
  Future<T> invokeMethod<T>(String method, [Object? arguments]) async {
    throw UnsupportedError('Local SQLite is unavailable in this test.');
  }
}
