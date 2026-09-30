enum VehicleType {
  car('car', 'Car'),
  motorcycle('motorcycle', 'Motorcycle');

  final String value;
  final String label;
  const VehicleType(this.value, this.label);
}

class Vehicle {
  final String id;
  final VehicleType type;
  final String plate;
  final bool isSelected;

  const Vehicle({
    required this.id,
    required this.type,
    required this.plate,
    this.isSelected = false,
  });

  factory Vehicle.fromMap(Map<String, dynamic> map) => Vehicle(
    id: map['id'] as String,
    type: VehicleType.values.byName(map['vehicle_type'] as String),
    plate: map['plate'] as String,
    isSelected: map['is_selected'] as bool,
  );
}
