import '../repositories/dashboard_repository.dart';

class DashboardService {
  final DashboardRepository repository;

  DashboardService(this.repository);

  Future<List<Map<String, dynamic>>> getBq1() =>
      repository.getBq1();

  Future<List<Map<String, dynamic>>> getBq2() =>
      repository.getBq2();

  Future<List<Map<String, dynamic>>> getBq3() =>
      repository.getBq3();

  Future<List<Map<String, dynamic>>> getBq4() =>
      repository.getBq4();

  Future<List<Map<String, dynamic>>> getBq5() =>
      repository.getBq5();

  Future<List<Map<String, dynamic>>> getBq6() =>
      repository.getBq6();
}