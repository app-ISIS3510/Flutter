import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../models/compared_parking.dart';
import '../../models/parking.dart';
import '../../objectbox.g.dart';
import 'parking_comparison_record.dart';
import 'parking_comparison_store.dart';

final _store = ObjectBoxParkingComparisonStore(_openStore);

ParkingComparisonStore? createParkingComparisonStore() =>
    Platform.isAndroid || Platform.isIOS ? _store : null;

Future<Store> _openStore() async {
  final directory = await getApplicationSupportDirectory();
  return openStore(directory: path.join(directory.path, 'parking_comparisons'));
}

class ObjectBoxParkingComparisonStore implements ParkingComparisonStore {
  final Future<Store> Function() open;
  Future<Store>? _opening;

  ObjectBoxParkingComparisonStore(this.open);

  Future<Store> _database() async {
    final opening = _opening ??= Future.sync(open);
    try {
      return await opening;
    } catch (_) {
      if (identical(_opening, opening)) _opening = null;
      rethrow;
    }
  }

  ParkingComparisonRecord? _find(
    Box<ParkingComparisonRecord> box,
    String owner,
  ) {
    final query = box
        .query(ParkingComparisonRecord_.owner.equals(owner))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  @override
  Future<List<ComparedParking>> read(String owner) async {
    final store = await _database();
    final record = _find(store.box<ParkingComparisonRecord>(), owner);
    if (record == null) return [];

    final items = jsonDecode(record.selectionJson) as List<dynamic>;
    return [
      for (final item in items)
        ComparedParking(
          Parking.fromMap(item['parking'] as Map<String, dynamic>),
          updatedAt: DateTime.tryParse(item['updated_at'] as String? ?? ''),
          isFromCache: true,
          isUnavailable: item['unavailable'] == true,
        ),
    ];
  }

  @override
  Future<void> write(String owner, List<ComparedParking> selection) async {
    final data = jsonEncode([
      for (final item in selection)
        {
          'parking': item.parking.toMap(),
          'updated_at': item.updatedAt?.toUtc().toIso8601String(),
          'unavailable': item.isUnavailable,
        },
    ]);
    final store = await _database();
    final box = store.box<ParkingComparisonRecord>();
    store.runInTransaction(TxMode.write, () {
      final previous = _find(box, owner);
      if (selection.isEmpty) {
        if (previous != null) box.remove(previous.id);
      } else {
        box.put(
          ParkingComparisonRecord(
            id: previous?.id ?? 0,
            owner: owner,
            selectionJson: data,
          ),
        );
      }
    });
  }
}
