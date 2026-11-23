import 'package:flutter/foundation.dart';

import '../models/parking.dart';

class ParkingComparisonController extends ChangeNotifier {
  static const minSelection = 2;
  static const maxSelection = 3;

  final _selection = <String, Parking>{};

  List<Parking> get selection => List.unmodifiable(_selection.values);
  int get count => _selection.length;
  bool get canCompare => count >= minSelection;
  bool get hasCapacity => count < maxSelection;

  bool contains(String id) => _selection.containsKey(id);

  void toggle(Parking parking) {
    if (contains(parking.id)) {
      remove(parking.id);
    } else if (hasCapacity) {
      _selection[parking.id] = parking;
      notifyListeners();
    }
  }

  void remove(String id) {
    if (_selection.remove(id) != null) notifyListeners();
  }

  void clear() {
    if (_selection.isEmpty) return;
    _selection.clear();
    notifyListeners();
  }
}
