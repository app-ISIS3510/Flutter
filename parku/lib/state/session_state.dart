import 'package:flutter/foundation.dart';

import '../models/parking_session.dart';

class SessionState extends ChangeNotifier {
  ParkingSession? _activeSession;

  ParkingSession? get activeSession => _activeSession;

  bool get hasActiveSession => _activeSession != null;

  void setActiveSession(ParkingSession? session) {
    _activeSession = session;
    notifyListeners();
  }

  void clearSession() {
    _activeSession = null;
    notifyListeners();
  }
}
