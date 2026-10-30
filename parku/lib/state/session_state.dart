import 'package:flutter/foundation.dart';

import '../models/parking_session.dart';

class SessionState extends ChangeNotifier {
  ParkingSession? _activeSession;
  bool isFromCache = false;

  ParkingSession? get activeSession => _activeSession;

  bool get hasActiveSession => _activeSession != null;

  void setActiveSession(ParkingSession? session, {bool isFromCache = false}) {
    _activeSession = session;
    this.isFromCache = isFromCache || session?.isFromCache == true;
    notifyListeners();
  }

  void clearSession() {
    _activeSession = null;
    isFromCache = false;
    notifyListeners();
  }
}
