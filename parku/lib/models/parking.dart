class Parking {
  final String id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final int carSpaces;
  final int motorcycleSpaces;
  final double pricePerMinute;
  final String? openingTime;
  final String? closingTime;
  final int availableCarSpaces;
  final int availableMotorcycleSpaces;

  Parking({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    required this.carSpaces,
    required this.motorcycleSpaces,
    required this.pricePerMinute,
    this.openingTime,
    this.closingTime,
    required this.availableCarSpaces,
    required this.availableMotorcycleSpaces,
  });

  factory Parking.fromMap(Map<String, dynamic> map) {
    return Parking(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      carSpaces: map['car_spaces'] as int? ?? 0,
      motorcycleSpaces: map['motorcycle_spaces'] as int? ?? 0,
      pricePerMinute:
          (map['price_per_minute'] as num?)?.toDouble() ?? 0,
      openingTime: map['opening_time']?.toString(),
      closingTime: map['closing_time']?.toString(),
      availableCarSpaces:
          map['available_car_spaces'] as int? ??
          map['car_spaces'] as int? ??
          0,

      availableMotorcycleSpaces:
          map['available_motorcycle_spaces'] as int? ??
          map['motorcycle_spaces'] as int? ??
          0,
    );
  }
}