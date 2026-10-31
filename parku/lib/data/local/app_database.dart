import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase({this.factory, this.databasePath});

  static final AppDatabase instance = AppDatabase();
  final DatabaseFactory? factory;
  final String? databasePath;

  Future<Database>? _database;

  Future<Database> get database {
    return _database ??= _openDatabase();
  }

  Future<Database> _openDatabase() async {
    try {
      final activeFactory = factory ?? databaseFactory;
      final path =
          databasePath ??
          p.join(await activeFactory.getDatabasesPath(), 'parku.db');

      return await activeFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE parking_cache (
              id TEXT PRIMARY KEY NOT NULL,
              name TEXT NOT NULL,
              address TEXT NOT NULL,
              latitude REAL,
              longitude REAL,
              car_spaces INTEGER NOT NULL,
              motorcycle_spaces INTEGER NOT NULL,
              price_per_minute REAL NOT NULL,
              opening_time TEXT,
              closing_time TEXT,
              image_url TEXT,
              available_car_spaces INTEGER NOT NULL,
              available_motorcycle_spaces INTEGER NOT NULL,
              cached_at TEXT NOT NULL
            )
          ''');

            await db.execute('''
            CREATE TABLE cache_metadata (
              cache_key TEXT PRIMARY KEY NOT NULL,
              last_updated_at TEXT NOT NULL
            )
          ''');
            await _createParkingDetailCache(db);
            await _createAnalyticsQueue(db);
            await _createUserStorage(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 2) {
              await _createParkingDetailCache(db);
            }
            if (oldVersion < 3) {
              await _createAnalyticsQueue(db);
            }
            if (oldVersion < 4) {
              await _createUserStorage(db);
            }
            if (oldVersion < 5) {
              for (final table in ['parking_cache', 'parking_detail_cache']) {
                final columns = await db.rawQuery('PRAGMA table_info($table)');
                if (!columns.any((column) => column['name'] == 'image_url')) {
                  await db.execute(
                    'ALTER TABLE $table ADD COLUMN image_url TEXT',
                  );
                }
              }
            }
          },
        ),
      );
    } catch (_) {
      _database = null;
      rethrow;
    }
  }

  Future<void> close() async {
    final pending = _database;
    _database = null;
    if (pending != null) await (await pending).close();
  }

  Future<void> _createParkingDetailCache(Database db) async {
    await db.execute('''
      CREATE TABLE parking_detail_cache (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        car_spaces INTEGER NOT NULL,
        motorcycle_spaces INTEGER NOT NULL,
        price_per_minute REAL NOT NULL,
        opening_time TEXT,
        closing_time TEXT,
        image_url TEXT,
        available_car_spaces INTEGER NOT NULL,
        available_motorcycle_spaces INTEGER NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createAnalyticsQueue(Database db) async {
    await db.execute('''
      CREATE TABLE pending_analytics_events (
        id TEXT PRIMARY KEY NOT NULL,
        user_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        next_attempt_ms INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX pending_analytics_events_due
      ON pending_analytics_events(user_id, next_attempt_ms, created_at_ms)
    ''');
  }

  Future<void> _createUserStorage(Database db) async {
    await db.execute('''
      CREATE TABLE favorite_cache (
        user_id TEXT NOT NULL,
        parking_id TEXT NOT NULL,
        parking_json TEXT,
        is_favorite INTEGER NOT NULL CHECK(is_favorite IN (0, 1)),
        updated_at TEXT NOT NULL,
        PRIMARY KEY(user_id, parking_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE favorite_snapshot_metadata (
        user_id TEXT PRIMARY KEY NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE pending_favorite_actions (
        action_id TEXT PRIMARY KEY NOT NULL,
        user_id TEXT NOT NULL,
        parking_id TEXT NOT NULL,
        desired_state INTEGER NOT NULL CHECK(desired_state IN (0, 1)),
        created_at_ms INTEGER NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        next_attempt_ms INTEGER NOT NULL DEFAULT 0,
        UNIQUE(user_id, parking_id)
      )
    ''');
    await db.execute('''
      CREATE INDEX pending_favorite_actions_due
      ON pending_favorite_actions(user_id, next_attempt_ms, created_at_ms)
    ''');
    await db.execute('''
      CREATE TABLE confirmed_sessions_cache (
        user_id TEXT NOT NULL,
        id TEXT NOT NULL,
        parking_id TEXT NOT NULL,
        vehicle_id TEXT,
        vehicle_type TEXT NOT NULL,
        vehicle_plate TEXT,
        pickup_time TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        status TEXT NOT NULL,
        confirmed_at TEXT NOT NULL,
        PRIMARY KEY(user_id, id)
      )
    ''');
    await db.execute('''
      CREATE TABLE session_snapshot_metadata (
        user_id TEXT PRIMARY KEY NOT NULL,
        active_session_id TEXT,
        checked_at TEXT NOT NULL
      )
    ''');
  }
}
