import '../services/dashboard_service.dart';

class DashboardController {
  final DashboardService service;

  DashboardController(this.service);

  Future<List<Map<String, dynamic>>> loadBq1() =>
      service.getBq1();

  Future<List<Map<String, dynamic>>> loadBq2() =>
      service.getBq2();

  Future<List<Map<String, dynamic>>> loadBq3() =>
      service.getBq3();

  Future<List<Map<String, dynamic>>> loadBq4() =>
      service.getBq4();

  Future<List<Map<String, dynamic>>> loadBq5() =>
      service.getBq5();

  Future<List<Map<String, dynamic>>> loadBq6() =>
      service.getBq6();
}