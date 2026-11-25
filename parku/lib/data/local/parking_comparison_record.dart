import 'package:objectbox/objectbox.dart';

@Entity()
class ParkingComparisonRecord {
  @Id()
  int id;

  @Unique()
  String owner;

  String selectionJson;

  ParkingComparisonRecord({
    this.id = 0,
    required this.owner,
    required this.selectionJson,
  });
}
